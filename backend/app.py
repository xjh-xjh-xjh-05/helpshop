from __future__ import annotations

import hashlib
import hmac
import os
import random
import sqlite3
import time
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import jwt
from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field


BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
DB_PATH = DATA_DIR / "helpshop.db"
JWT_SECRET = os.getenv("HELPSHOP_JWT_SECRET", "helpshop-local-dev-secret")
JWT_ALGORITHM = "HS256"
TOKEN_EXPIRE_HOURS = 24


def now_text() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def new_id(prefix: str) -> str:
    return f"{prefix}-{uuid.uuid4().hex[:16]}"


def hash_password(password: str, salt: str) -> str:
    digest = hashlib.sha256(f"{salt}:{password}".encode("utf-8")).hexdigest()
    return digest


def verify_password(password: str, salt: str, password_hash: str) -> bool:
    return hmac.compare_digest(hash_password(password, salt), password_hash)


def get_conn() -> sqlite3.Connection:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def row_to_dict(row: sqlite3.Row | None) -> dict[str, Any] | None:
    if row is None:
        return None
    return {key: row[key] for key in row.keys()}


def create_token(account_id: str, role: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(hours=TOKEN_EXPIRE_HOURS)
    payload = {
        "sub": account_id,
        "role": role,
        "exp": expire,
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def decode_token(authorization: str | None) -> dict[str, Any]:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = authorization.removeprefix("Bearer ").strip()
    try:
      return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except jwt.ExpiredSignatureError as exc:
        raise HTTPException(status_code=401, detail="Token expired") from exc
    except jwt.InvalidTokenError as exc:
        raise HTTPException(status_code=401, detail="Invalid token") from exc


def current_account(authorization: str | None = Header(default=None)) -> dict[str, Any]:
    payload = decode_token(authorization)
    account_id = payload.get("sub")
    with get_conn() as conn:
        row = conn.execute(
            "SELECT id, phone, display_name, default_role, status, created_at, updated_at FROM account_user WHERE id = ?",
            (account_id,),
        ).fetchone()
    account = row_to_dict(row)
    if not account or account["status"] != "active":
        raise HTTPException(status_code=401, detail="Account unavailable")
    return account


def get_current_elderly_account_id(conn: sqlite3.Connection, account: dict[str, Any]) -> str:
    if account["default_role"] == "elderly":
        return account["id"]
    row = conn.execute(
        """
        SELECT elderly_account_id
        FROM family_binding
        WHERE child_account_id = ? AND status = 'active'
        ORDER BY created_at DESC
        LIMIT 1
        """,
        (account["id"],),
    ).fetchone()
    if row:
        return row["elderly_account_id"]
    raise HTTPException(status_code=403, detail="Child account is not bound to an elderly account")


def audit(conn: sqlite3.Connection, actor_id: str | None, elderly_id: str | None, action: str, detail: str) -> None:
    conn.execute(
        """
        INSERT INTO audit_log(id, actor_account_id, elderly_account_id, action, detail, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        (new_id("audit"), actor_id, elderly_id, action, detail, now_text()),
    )


def init_db() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    with get_conn() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS account_user (
              id TEXT PRIMARY KEY,
              phone TEXT NOT NULL UNIQUE,
              password_hash TEXT NOT NULL,
              password_salt TEXT NOT NULL,
              display_name TEXT NOT NULL,
              default_role TEXT NOT NULL CHECK(default_role IN ('elderly', 'child', 'unverified')),
              status TEXT NOT NULL DEFAULT 'active',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS elderly_profile (
              id TEXT PRIMARY KEY,
              account_id TEXT NOT NULL UNIQUE,
              real_name TEXT NOT NULL,
              age INTEGER DEFAULT 0,
              care_mode_enabled INTEGER DEFAULT 0,
              emergency_phone TEXT DEFAULT '',
              binding_code TEXT NOT NULL UNIQUE,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              FOREIGN KEY(account_id) REFERENCES account_user(id)
            );

            CREATE TABLE IF NOT EXISTS child_profile (
              id TEXT PRIMARY KEY,
              account_id TEXT NOT NULL UNIQUE,
              real_name TEXT NOT NULL,
              relation TEXT DEFAULT '子女',
              notification_enabled INTEGER DEFAULT 1,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              FOREIGN KEY(account_id) REFERENCES account_user(id)
            );

            CREATE TABLE IF NOT EXISTS family_binding (
              id TEXT PRIMARY KEY,
              elderly_account_id TEXT NOT NULL,
              child_account_id TEXT NOT NULL,
              binding_code TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'active',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              FOREIGN KEY(elderly_account_id) REFERENCES account_user(id),
              FOREIGN KEY(child_account_id) REFERENCES account_user(id)
            );

            CREATE TABLE IF NOT EXISTS sms_code (
              id TEXT PRIMARY KEY,
              phone TEXT NOT NULL,
              code TEXT NOT NULL,
              purpose TEXT NOT NULL,
              expires_at INTEGER NOT NULL,
              used INTEGER DEFAULT 0,
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS address (
              id TEXT PRIMARY KEY,
              elderly_account_id TEXT NOT NULL,
              managed_by_child_account_id TEXT,
              receiver TEXT NOT NULL,
              phone TEXT NOT NULL,
              detail TEXT NOT NULL,
              is_default INTEGER DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS product_mock (
              id TEXT PRIMARY KEY,
              platform TEXT NOT NULL,
              name TEXT NOT NULL,
              price REAL NOT NULL,
              rating REAL NOT NULL,
              sales INTEGER NOT NULL,
              shop_name TEXT NOT NULL,
              description TEXT NOT NULL,
              tags TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS order_record (
              id TEXT PRIMARY KEY,
              elderly_account_id TEXT NOT NULL,
              managed_by_child_account_id TEXT,
              product_id TEXT NOT NULL,
              product_name TEXT NOT NULL,
              platform TEXT NOT NULL,
              quantity INTEGER NOT NULL,
              address_id TEXT NOT NULL,
              total_price REAL NOT NULL,
              payment_method TEXT NOT NULL,
              payment_status TEXT NOT NULL,
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS payment_record (
              id TEXT PRIMARY KEY,
              order_id TEXT,
              elderly_account_id TEXT,
              product_id TEXT,
              amount REAL NOT NULL,
              method TEXT NOT NULL,
              status TEXT NOT NULL,
              message TEXT NOT NULL,
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS reminder (
              id TEXT PRIMARY KEY,
              order_id TEXT NOT NULL,
              elderly_account_id TEXT,
              child_account_id TEXT,
              title TEXT NOT NULL,
              content TEXT NOT NULL,
              read INTEGER DEFAULT 0,
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS sync_event (
              id TEXT PRIMARY KEY,
              elderly_account_id TEXT NOT NULL,
              event_type TEXT NOT NULL,
              payload TEXT NOT NULL,
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS notification_outbox (
              id TEXT PRIMARY KEY,
              elderly_account_id TEXT,
              child_account_id TEXT,
              title TEXT NOT NULL,
              content TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'pending',
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS audit_log (
              id TEXT PRIMARY KEY,
              actor_account_id TEXT,
              elderly_account_id TEXT,
              action TEXT NOT NULL,
              detail TEXT NOT NULL,
              created_at TEXT NOT NULL
            );
            """
        )
        order_columns = {
            row["name"]
            for row in conn.execute("PRAGMA table_info(order_record)").fetchall()
        }
        if "managed_by_child_account_id" not in order_columns:
            conn.execute("ALTER TABLE order_record ADD COLUMN managed_by_child_account_id TEXT")
        user_columns = {
            row["name"]
            for row in conn.execute("PRAGMA table_info(account_user)").fetchall()
        }
        if "nick_name" not in user_columns:
            conn.execute("ALTER TABLE account_user ADD COLUMN nick_name TEXT DEFAULT ''")
        if "avatar_uri" not in user_columns:
            conn.execute("ALTER TABLE account_user ADD COLUMN avatar_uri TEXT DEFAULT ''")
        seed_demo_data(conn)
        conn.commit()


def insert_account(conn: sqlite3.Connection, account_id: str, phone: str, password: str, name: str, role: str) -> None:
    salt = uuid.uuid4().hex[:12]
    created = now_text()
    conn.execute(
        """
        INSERT OR IGNORE INTO account_user(id, phone, password_hash, password_salt, display_name, default_role, status, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, 'active', ?, ?)
        """,
        (account_id, phone, hash_password(password, salt), salt, name, role, created, created),
    )


def seed_demo_data(conn: sqlite3.Connection) -> None:
    existing = conn.execute("SELECT COUNT(*) AS count FROM account_user").fetchone()["count"]
    if existing > 0:
        return
    insert_account(conn, "acct-elderly-001", "13800000001", "123456", "徐叔叔", "elderly")
    insert_account(conn, "acct-child-001", "13900000001", "123456", "徐女士", "child")
    created = now_text()
    conn.execute(
        "INSERT INTO elderly_profile VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        ("elderly-profile-001", "acct-elderly-001", "徐叔叔", 68, 1, "13900000001", "HS2026", created, created),
    )
    conn.execute(
        "INSERT INTO child_profile VALUES (?, ?, ?, ?, ?, ?, ?)",
        ("child-profile-001", "acct-child-001", "徐女士", "子女", 1, created, created),
    )
    conn.execute(
        "INSERT INTO family_binding VALUES (?, ?, ?, ?, 'active', ?, ?)",
        ("binding-001", "acct-elderly-001", "acct-child-001", "HS2026", created, created),
    )
    conn.execute(
        "INSERT INTO address VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        ("addr-001", "acct-elderly-001", "acct-child-001", "徐叔叔", "138****6688", "上海市浦东新区康桥镇安心小区 12 号楼 302 室", 1, created, created),
    )
    products = [
        ("shoe-001", "京东", "轻便软底老人健步鞋", 189, 4.8, 23500, "安心步行旗舰店", "软底防滑，鞋面透气，适合日常散步。", "鞋,不累脚,防滑,老人"),
        ("milk-001", "京东", "高钙无糖中老年奶粉", 168, 4.8, 28400, "营养生活旗舰店", "无蔗糖配方，添加钙和维生素D。", "奶粉,高钙,无糖,中老年"),
        ("phone-001", "京东", "大按键老人手机", 299, 4.7, 12800, "银发数码", "大字体、大音量、长续航，支持一键拨号。", "手机,老人,大按键,长续航"),
        ("bp-001", "京东", "家用上臂式血压计", 229, 4.8, 31000, "康养医疗器械", "大屏显示，语音播报，适合老人居家测量。", "血压计,上臂式,语音,老人"),
    ]
    conn.executemany("INSERT INTO product_mock VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", products)


class SmsSendRequest(BaseModel):
    phone: str
    purpose: str = Field(default="login")


class RegisterRequest(BaseModel):
    phone: str
    password: str
    display_name: str
    role: str = Field(default="unverified")
    sms_code: str | None = None


class LoginRequest(BaseModel):
    phone: str
    password: str
    sms_code: str | None = None


class CertifyRoleRequest(BaseModel):
    role: str


class BindFamilyRequest(BaseModel):
    keyword: str


class AddressCreateRequest(BaseModel):
    receiver: str
    phone: str
    detail: str


class ProfileUpdateRequest(BaseModel):
    real_name: str | None = None
    age: int | None = None
    emergency_phone: str | None = None
    relation: str | None = None
    nick_name: str | None = None
    display_name: str | None = None


class AddressIdRequest(BaseModel):
    id: str


class PaymentRequest(BaseModel):
    product_id: str
    address_id: str
    quantity: int = Field(default=1, ge=1, le=99)
    method: str = Field(default="password")
    outcome: str = Field(default="success")


app = FastAPI(title="HelpShop Backend", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def startup() -> None:
    init_db()


@app.get("/health")
def health() -> dict[str, Any]:
    return {"status": "ok", "db": str(DB_PATH), "time": now_text()}


@app.post("/api/auth/sms/send")
def send_sms_code(payload: SmsSendRequest) -> dict[str, Any]:
    code = f"{random.randint(100000, 999999)}"
    expires_at = int(time.time()) + 300
    with get_conn() as conn:
        conn.execute(
            "INSERT INTO sms_code VALUES (?, ?, ?, ?, ?, 0, ?)",
            (new_id("sms"), payload.phone, code, payload.purpose, expires_at, now_text()),
        )
        conn.commit()
    return {"success": True, "message": "验证码已生成。演示环境直接返回验证码。", "demo_code": code, "expires_in": 300}


def verify_sms_if_present(conn: sqlite3.Connection, phone: str, code: str | None, purpose: str) -> None:
    if not code:
        return
    row = conn.execute(
        """
        SELECT * FROM sms_code
        WHERE phone = ? AND code = ? AND purpose = ? AND used = 0
        ORDER BY expires_at DESC LIMIT 1
        """,
        (phone, code, purpose),
    ).fetchone()
    if not row or row["expires_at"] < int(time.time()):
        raise HTTPException(status_code=400, detail="Invalid or expired SMS code")
    conn.execute("UPDATE sms_code SET used = 1 WHERE id = ?", (row["id"],))


@app.post("/api/auth/register")
def register(payload: RegisterRequest) -> dict[str, Any]:
    role = payload.role if payload.role in ("elderly", "child", "unverified") else "unverified"
    with get_conn() as conn:
        verify_sms_if_present(conn, payload.phone, payload.sms_code, "register")
        exists = conn.execute("SELECT id FROM account_user WHERE phone = ?", (payload.phone,)).fetchone()
        if exists:
            raise HTTPException(status_code=409, detail="Phone already registered")
        account_id = new_id("acct")
        insert_account(conn, account_id, payload.phone, payload.password, payload.display_name, role)
        created = now_text()
        if role == "elderly":
            binding_code = f"HS{payload.phone[-4:]}"
            conn.execute(
                "INSERT INTO elderly_profile VALUES (?, ?, ?, 0, 0, '', ?, ?, ?)",
                (new_id("elderly-profile"), account_id, payload.display_name, binding_code, created, created),
            )
        if role == "child":
            conn.execute(
                "INSERT INTO child_profile VALUES (?, ?, ?, '子女', 1, ?, ?)",
                (new_id("child-profile"), account_id, payload.display_name, created, created),
            )
        audit(conn, account_id, account_id if role == "elderly" else None, "auth.register", f"注册账号 {payload.phone}")
        conn.commit()
    token = create_token(account_id, role)
    return {"success": True, "access_token": token, "token_type": "Bearer", "account": {"id": account_id, "phone": payload.phone, "display_name": payload.display_name, "role": role}}


@app.post("/api/auth/login")
def login(payload: LoginRequest) -> dict[str, Any]:
    with get_conn() as conn:
        verify_sms_if_present(conn, payload.phone, payload.sms_code, "login")
        row = conn.execute("SELECT * FROM account_user WHERE phone = ?", (payload.phone,)).fetchone()
        if not row or not verify_password(payload.password, row["password_salt"], row["password_hash"]):
            raise HTTPException(status_code=401, detail="Invalid phone or password")
        if row["status"] != "active":
            raise HTTPException(status_code=403, detail="Account disabled")
        audit(conn, row["id"], row["id"] if row["default_role"] == "elderly" else None, "auth.login", f"登录账号 {payload.phone}")
        conn.commit()
        token = create_token(row["id"], row["default_role"])
        account = row_to_dict(row)
        account.pop("password_hash", None)
        account.pop("password_salt", None)
        return {"success": True, "access_token": token, "token_type": "Bearer", "account": account}


@app.get("/api/auth/me")
def me(account: dict[str, Any] = Depends(current_account)) -> dict[str, Any]:
    return {"success": True, "account": account}


@app.post("/api/auth/certify")
def certify_role(payload: CertifyRoleRequest, account: dict[str, Any] = Depends(current_account)) -> dict[str, Any]:
    if payload.role not in ("elderly", "child"):
        raise HTTPException(status_code=400, detail="Role must be elderly or child")
    created = now_text()
    with get_conn() as conn:
        conn.execute(
            "UPDATE account_user SET default_role = ?, updated_at = ? WHERE id = ?",
            (payload.role, created, account["id"]),
        )
        if payload.role == "elderly":
            exists = conn.execute("SELECT id FROM elderly_profile WHERE account_id = ?", (account["id"],)).fetchone()
            if not exists:
                binding_code = f"HS{account['phone'][-4:]}"
                code_exists = conn.execute("SELECT id FROM elderly_profile WHERE binding_code = ?", (binding_code,)).fetchone()
                if code_exists:
                    binding_code = f"HS{uuid.uuid4().hex[:6].upper()}"
                conn.execute(
                    "INSERT INTO elderly_profile VALUES (?, ?, ?, 0, 0, '', ?, ?, ?)",
                    (new_id("elderly-profile"), account["id"], account["display_name"], binding_code, created, created),
                )
        if payload.role == "child":
            exists = conn.execute("SELECT id FROM child_profile WHERE account_id = ?", (account["id"],)).fetchone()
            if not exists:
                conn.execute(
                    "INSERT INTO child_profile VALUES (?, ?, ?, '子女', 1, ?, ?)",
                    (new_id("child-profile"), account["id"], account["display_name"], created, created),
                )
        audit(conn, account["id"], account["id"] if payload.role == "elderly" else None, "auth.certify", f"认证身份 {payload.role}")
        row = conn.execute(
            "SELECT id, phone, display_name, default_role, status, created_at, updated_at FROM account_user WHERE id = ?",
            (account["id"],),
        ).fetchone()
        conn.commit()
    certified = row_to_dict(row)
    token = create_token(account["id"], payload.role)
    return {"success": True, "message": "身份认证成功", "access_token": token, "token_type": "Bearer", "account": certified}


@app.post("/api/family/bind")
def bind_family(payload: BindFamilyRequest, account: dict[str, Any] = Depends(current_account)) -> dict[str, Any]:
    if account["default_role"] != "child":
        raise HTTPException(status_code=403, detail="Only child accounts can bind elderly accounts")
    with get_conn() as conn:
        elderly = conn.execute(
            """
            SELECT a.id, a.display_name, a.phone, e.binding_code
            FROM account_user a
            JOIN elderly_profile e ON e.account_id = a.id
            WHERE a.default_role = 'elderly' AND (a.phone = ? OR e.binding_code = ?)
            """,
            (payload.keyword, payload.keyword),
        ).fetchone()
        if not elderly:
            raise HTTPException(status_code=404, detail="Elderly account not found")
        exists = conn.execute(
            "SELECT * FROM family_binding WHERE elderly_account_id = ? AND child_account_id = ? AND status = 'active'",
            (elderly["id"], account["id"]),
        ).fetchone()
        binding_id = exists["id"] if exists else new_id("binding")
        if not exists:
            created = now_text()
            conn.execute(
                "INSERT INTO family_binding VALUES (?, ?, ?, ?, 'active', ?, ?)",
                (binding_id, elderly["id"], account["id"], elderly["binding_code"], created, created),
            )
        binding = conn.execute("SELECT * FROM family_binding WHERE id = ?", (binding_id,)).fetchone()
        audit(conn, account["id"], elderly["id"], "family.bind", f"绑定老人账号 {elderly['display_name']}")
        conn.commit()
    return {
        "success": True,
        "message": "绑定成功",
        "binding": row_to_dict(binding),
        "elderly": row_to_dict(elderly),
    }


@app.get("/api/family/bindings")
def list_family_bindings(account: dict[str, Any] = Depends(current_account)) -> dict[str, Any]:
    if account["default_role"] != "child":
        return {"success": True, "bindings": []}
    with get_conn() as conn:
        rows = conn.execute(
            """
            SELECT b.*, a.display_name AS elderly_name, a.phone AS elderly_phone
            FROM family_binding b
            JOIN account_user a ON a.id = b.elderly_account_id
            WHERE b.child_account_id = ? AND b.status = 'active'
            ORDER BY b.created_at DESC
            """,
            (account["id"],),
        ).fetchall()
    return {"success": True, "bindings": [row_to_dict(row) for row in rows]}


@app.get("/api/profile/stats")
def profile_stats(account: dict[str, Any] = Depends(current_account)) -> dict[str, Any]:
    with get_conn() as conn:
        elderly_id = get_current_elderly_account_id(conn, account) if account["default_role"] in ("elderly", "child") else None
        address_count = conn.execute("SELECT COUNT(*) AS c FROM address WHERE elderly_account_id = ?", (elderly_id,)).fetchone()["c"] if elderly_id else 0
        order_count = conn.execute("SELECT COUNT(*) AS c FROM order_record WHERE elderly_account_id = ?", (elderly_id,)).fetchone()["c"] if elderly_id else 0
        reminder_count = conn.execute("SELECT COUNT(*) AS c FROM reminder WHERE elderly_account_id = ? OR child_account_id = ?", (elderly_id, account["id"])).fetchone()["c"] if elderly_id else 0
        unread_count = conn.execute("SELECT COUNT(*) AS c FROM reminder WHERE (elderly_account_id = ? OR child_account_id = ?) AND read = 0", (elderly_id, account["id"])).fetchone()["c"] if elderly_id else 0
        binding_count = 0
        if account["default_role"] == "child":
            binding_count = conn.execute("SELECT COUNT(*) AS c FROM family_binding WHERE child_account_id = ? AND status = 'active'", (account["id"],)).fetchone()["c"]
    return {
        "success": True,
        "account": account,
        "order_count": order_count,
        "address_count": address_count,
        "reminder_count": reminder_count,
        "unread_reminder_count": unread_count,
        "binding_count": binding_count,
    }


@app.post("/api/profile/update")
def update_profile(payload: ProfileUpdateRequest, account: dict[str, Any] = Depends(current_account)) -> dict[str, Any]:
    with get_conn() as conn:
        updated = now_text()
        if payload.display_name:
            conn.execute(
                "UPDATE account_user SET display_name = ?, updated_at = ? WHERE id = ?",
                (payload.display_name, updated, account["id"]),
            )
        if payload.nick_name is not None:
            existing_row = conn.execute("SELECT nick_name FROM account_user WHERE id = ?", (account["id"],)).fetchone()
            columns = {row["name"] for row in conn.execute("PRAGMA table_info(account_user)").fetchall()}
            if "nick_name" in columns:
                conn.execute(
                    "UPDATE account_user SET nick_name = ?, updated_at = ? WHERE id = ?",
                    (payload.nick_name, updated, account["id"]),
                )
        role = account["default_role"]
        if role == "elderly":
            if payload.real_name is not None or payload.age is not None or payload.emergency_phone is not None:
                profile = conn.execute("SELECT * FROM elderly_profile WHERE account_id = ?", (account["id"],)).fetchone()
                if profile:
                    new_real_name = payload.real_name if payload.real_name is not None else profile["real_name"]
                    new_age = payload.age if payload.age is not None else profile["age"]
                    new_emergency = payload.emergency_phone if payload.emergency_phone is not None else profile["emergency_phone"]
                    conn.execute(
                        "UPDATE elderly_profile SET real_name = ?, age = ?, emergency_phone = ?, updated_at = ? WHERE account_id = ?",
                        (new_real_name, new_age, new_emergency, updated, account["id"]),
                    )
                else:
                    binding_code = f"HS{account['phone'][-4:]}"
                    conn.execute(
                        "INSERT INTO elderly_profile VALUES (?, ?, ?, ?, 0, ?, ?, ?, ?)",
                        (new_id("elderly-profile"), account["id"], payload.real_name or account["display_name"], payload.age or 0, payload.emergency_phone or "", binding_code, updated, updated),
                    )
        if role == "child":
            if payload.real_name is not None or payload.relation is not None:
                profile = conn.execute("SELECT * FROM child_profile WHERE account_id = ?", (account["id"],)).fetchone()
                if profile:
                    new_real_name = payload.real_name if payload.real_name is not None else profile["real_name"]
                    new_relation = payload.relation if payload.relation is not None else profile["relation"]
                    conn.execute(
                        "UPDATE child_profile SET real_name = ?, relation = ?, updated_at = ? WHERE account_id = ?",
                        (new_real_name, new_relation, updated, account["id"]),
                    )
                else:
                    conn.execute(
                        "INSERT INTO child_profile VALUES (?, ?, ?, ?, 1, ?, ?)",
                        (new_id("child-profile"), account["id"], payload.real_name or account["display_name"], payload.relation or "子女", updated, updated),
                    )
        updated_row = conn.execute(
            "SELECT id, phone, display_name, default_role, status, created_at, updated_at FROM account_user WHERE id = ?",
            (account["id"],),
        ).fetchone()
        audit(conn, account["id"], account["id"] if role == "elderly" else None, "profile.update", "更新个人档案")
        conn.commit()
    return {"success": True, "message": "档案更新成功", "account": row_to_dict(updated_row)}


@app.get("/api/addresses")
def list_addresses(account: dict[str, Any] = Depends(current_account)) -> dict[str, Any]:
    with get_conn() as conn:
        elderly_id = get_current_elderly_account_id(conn, account)
        rows = conn.execute("SELECT * FROM address WHERE elderly_account_id = ? ORDER BY is_default DESC, created_at DESC", (elderly_id,)).fetchall()
    return {"success": True, "addresses": [row_to_dict(row) for row in rows]}


@app.post("/api/addresses")
def create_address(payload: AddressCreateRequest, account: dict[str, Any] = Depends(current_account)) -> dict[str, Any]:
    with get_conn() as conn:
        elderly_id = get_current_elderly_account_id(conn, account)
        has_default = conn.execute("SELECT 1 FROM address WHERE elderly_account_id = ? AND is_default = 1", (elderly_id,)).fetchone()
        created = now_text()
        address_id = new_id("addr")
        conn.execute(
            "INSERT INTO address VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (address_id, elderly_id, account["id"], payload.receiver, payload.phone, payload.detail, 0 if has_default else 1, created, created),
        )
        conn.execute(
            "INSERT INTO sync_event VALUES (?, ?, 'address.created', ?, ?)",
            (new_id("sync"), elderly_id, f"address_id={address_id}", created),
        )
        audit(conn, account["id"], elderly_id, "address.create", f"新增地址 {payload.receiver}")
        conn.commit()
    return {"success": True, "address_id": address_id}


@app.post("/api/addresses/default")
def set_default_address(payload: AddressIdRequest, account: dict[str, Any] = Depends(current_account)) -> dict[str, Any]:
    with get_conn() as conn:
        elderly_id = get_current_elderly_account_id(conn, account)
        address = conn.execute("SELECT id FROM address WHERE id = ? AND elderly_account_id = ?", (payload.id, elderly_id)).fetchone()
        if not address:
            raise HTTPException(status_code=404, detail="Address not found")
        updated = now_text()
        conn.execute("UPDATE address SET is_default = 0, updated_at = ? WHERE elderly_account_id = ?", (updated, elderly_id))
        conn.execute("UPDATE address SET is_default = 1, updated_at = ? WHERE id = ?", (updated, payload.id))
        conn.execute(
            "INSERT INTO sync_event VALUES (?, ?, 'address.default', ?, ?)",
            (new_id("sync"), elderly_id, f"address_id={payload.id}", updated),
        )
        audit(conn, account["id"], elderly_id, "address.default", f"设置默认地址 {payload.id}")
        conn.commit()
    return {"success": True, "message": "默认地址已更新"}


@app.post("/api/addresses/delete")
def delete_address(payload: AddressIdRequest, account: dict[str, Any] = Depends(current_account)) -> dict[str, Any]:
    with get_conn() as conn:
        elderly_id = get_current_elderly_account_id(conn, account)
        address = conn.execute("SELECT id, is_default FROM address WHERE id = ? AND elderly_account_id = ?", (payload.id, elderly_id)).fetchone()
        if not address:
            raise HTTPException(status_code=404, detail="Address not found")
        conn.execute("DELETE FROM address WHERE id = ? AND elderly_account_id = ?", (payload.id, elderly_id))
        next_address = conn.execute(
            "SELECT id FROM address WHERE elderly_account_id = ? ORDER BY created_at DESC LIMIT 1",
            (elderly_id,),
        ).fetchone()
        if next_address:
            conn.execute("UPDATE address SET is_default = 1, updated_at = ? WHERE id = ?", (now_text(), next_address["id"]))
        created = now_text()
        conn.execute(
            "INSERT INTO sync_event VALUES (?, ?, 'address.deleted', ?, ?)",
            (new_id("sync"), elderly_id, f"address_id={payload.id}", created),
        )
        audit(conn, account["id"], elderly_id, "address.delete", f"删除地址 {payload.id}")
        conn.commit()
    return {"success": True, "message": "地址已删除"}


@app.get("/api/products/mock")
def list_mock_products() -> dict[str, Any]:
    with get_conn() as conn:
        rows = conn.execute("SELECT * FROM product_mock ORDER BY sales DESC").fetchall()
    return {"success": True, "products": [row_to_dict(row) for row in rows]}


@app.post("/api/payments/mock")
def create_payment(payload: PaymentRequest, account: dict[str, Any] = Depends(current_account)) -> dict[str, Any]:
    with get_conn() as conn:
        elderly_id = get_current_elderly_account_id(conn, account)
        product = conn.execute("SELECT * FROM product_mock WHERE id = ?", (payload.product_id,)).fetchone()
        address = conn.execute("SELECT * FROM address WHERE id = ? AND elderly_account_id = ?", (payload.address_id, elderly_id)).fetchone()
        if not product:
            raise HTTPException(status_code=404, detail="Product not found")
        if not address:
            raise HTTPException(status_code=404, detail="Address not found")
        amount = float(product["price"]) * payload.quantity
        status = "success" if payload.outcome == "success" else ("cancelled" if payload.outcome == "cancelled" else "failed")
        message = "模拟支付成功" if status == "success" else ("模拟支付取消" if status == "cancelled" else "模拟支付失败")
        order_id = None
        created = now_text()
        if status == "success":
            order_id = new_id("order")
            managed_by_child_id = account["id"] if account["default_role"] == "child" else None
            conn.execute(
                """
                INSERT INTO order_record(
                    id,
                    elderly_account_id,
                    managed_by_child_account_id,
                    product_id,
                    product_name,
                    platform,
                    quantity,
                    address_id,
                    total_price,
                    payment_method,
                    payment_status,
                    created_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    order_id,
                    elderly_id,
                    managed_by_child_id,
                    product["id"],
                    product["name"],
                    product["platform"],
                    payload.quantity,
                    address["id"],
                    amount,
                    payload.method,
                    "success",
                    created,
                ),
            )
            child = conn.execute("SELECT child_account_id FROM family_binding WHERE elderly_account_id = ? AND status = 'active' LIMIT 1", (elderly_id,)).fetchone()
            child_id = child["child_account_id"] if child else None
            content = f"{address['receiver']} 在 {product['platform']} 购买了 {product['name']}，数量 {payload.quantity}，金额 ¥{amount:.2f}。"
            conn.execute(
                "INSERT INTO reminder VALUES (?, ?, ?, ?, '老人购物提醒', ?, 0, ?)",
                (new_id("reminder"), order_id, elderly_id, child_id, content, created),
            )
            conn.execute(
                "INSERT INTO notification_outbox VALUES (?, ?, ?, '老人购物提醒', ?, 'pending', ?)",
                (new_id("notification"), elderly_id, child_id, content, created),
            )
        payment_id = new_id("payment")
        conn.execute(
            "INSERT INTO payment_record VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (payment_id, order_id, elderly_id, product["id"], amount if status == "success" else 0, payload.method, status, message, created),
        )
        audit(conn, account["id"], elderly_id, f"payment.{status}", message)
        conn.commit()
    return {"success": status == "success", "payment_id": payment_id, "order_id": order_id, "status": status, "message": message}


@app.get("/api/orders")
def list_orders(account: dict[str, Any] = Depends(current_account)) -> dict[str, Any]:
    with get_conn() as conn:
        elderly_id = get_current_elderly_account_id(conn, account)
        rows = conn.execute(
            """
            SELECT
              o.*,
              p.shop_name,
              p.price AS product_price,
              p.rating,
              p.sales,
              p.description,
              p.tags,
              a.receiver AS address_receiver,
              a.phone AS address_phone,
              a.detail AS address_detail
            FROM order_record o
            LEFT JOIN product_mock p ON p.id = o.product_id
            LEFT JOIN address a ON a.id = o.address_id
            WHERE o.elderly_account_id = ?
            ORDER BY o.created_at DESC
            """,
            (elderly_id,),
        ).fetchall()
    return {"success": True, "orders": [row_to_dict(row) for row in rows]}


@app.get("/api/reminders")
def list_reminders(account: dict[str, Any] = Depends(current_account)) -> dict[str, Any]:
    with get_conn() as conn:
        elderly_id = get_current_elderly_account_id(conn, account)
        rows = conn.execute(
            "SELECT * FROM reminder WHERE elderly_account_id = ? OR child_account_id = ? ORDER BY created_at DESC",
            (elderly_id, account["id"]),
        ).fetchall()
    return {"success": True, "reminders": [row_to_dict(row) for row in rows]}


@app.post("/api/reminders/read-all")
def mark_reminders_read(account: dict[str, Any] = Depends(current_account)) -> dict[str, Any]:
    with get_conn() as conn:
        elderly_id = get_current_elderly_account_id(conn, account)
        conn.execute(
            "UPDATE reminder SET read = 1 WHERE elderly_account_id = ? OR child_account_id = ?",
            (elderly_id, account["id"]),
        )
        audit(conn, account["id"], elderly_id, "reminder.read_all", "标记全部提醒为已读")
        conn.commit()
        rows = conn.execute(
            "SELECT * FROM reminder WHERE elderly_account_id = ? OR child_account_id = ? ORDER BY created_at DESC",
            (elderly_id, account["id"]),
        ).fetchall()
    return {"success": True, "message": "提醒已全部标记为已读", "reminders": [row_to_dict(row) for row in rows]}


@app.get("/api/sync/events")
def list_sync_events(account: dict[str, Any] = Depends(current_account)) -> dict[str, Any]:
    with get_conn() as conn:
        elderly_id = get_current_elderly_account_id(conn, account)
        rows = conn.execute("SELECT * FROM sync_event WHERE elderly_account_id = ? ORDER BY created_at DESC", (elderly_id,)).fetchall()
    return {"success": True, "events": [row_to_dict(row) for row in rows], "mode": "server-sync-placeholder"}


@app.get("/api/notifications")
def list_notifications(account: dict[str, Any] = Depends(current_account)) -> dict[str, Any]:
    with get_conn() as conn:
        elderly_id = get_current_elderly_account_id(conn, account)
        rows = conn.execute(
            "SELECT * FROM notification_outbox WHERE elderly_account_id = ? OR child_account_id = ? ORDER BY created_at DESC",
            (elderly_id, account["id"]),
        ).fetchall()
    return {"success": True, "notifications": [row_to_dict(row) for row in rows], "mode": "distributed-notification-placeholder"}


@app.get("/api/audit-logs")
def list_audit_logs(account: dict[str, Any] = Depends(current_account)) -> dict[str, Any]:
    with get_conn() as conn:
        elderly_id = get_current_elderly_account_id(conn, account)
        rows = conn.execute(
            "SELECT * FROM audit_log WHERE elderly_account_id = ? OR actor_account_id = ? ORDER BY created_at DESC",
            (elderly_id, account["id"]),
        ).fetchall()
    return {"success": True, "logs": [row_to_dict(row) for row in rows]}


init_db()
