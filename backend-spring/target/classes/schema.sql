CREATE DATABASE IF NOT EXISTS helpshop DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE helpshop;

DROP TABLE IF EXISTS audit_log;
DROP TABLE IF EXISTS payment_record;
DROP TABLE IF EXISTS reminder;
DROP TABLE IF EXISTS order_record;
DROP TABLE IF EXISTS address;
DROP TABLE IF EXISTS product_mock;
DROP TABLE IF EXISTS family_binding;
DROP TABLE IF EXISTS child_profile;
DROP TABLE IF EXISTS elderly_profile;
DROP TABLE IF EXISTS account_user;

CREATE TABLE account_user (
    id                  VARCHAR(64)  NOT NULL PRIMARY KEY,
    phone               VARCHAR(20)  NOT NULL UNIQUE,
    password            VARCHAR(128) NOT NULL,
    display_name        VARCHAR(64)  NOT NULL,
    default_role        VARCHAR(20)  NOT NULL DEFAULT 'unverified',
    status              VARCHAR(20)  NOT NULL DEFAULT 'active',
    huawei_open_id      VARCHAR(128) DEFAULT NULL,
    huawei_union_id     VARCHAR(128) DEFAULT NULL,
    created_at          VARCHAR(32)  NOT NULL,
    updated_at          VARCHAR(32)  NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE elderly_profile (
    id                  VARCHAR(64)  NOT NULL PRIMARY KEY,
    account_id          VARCHAR(64)  NOT NULL UNIQUE,
    real_name           VARCHAR(64)  NOT NULL DEFAULT '',
    age                 INT          NOT NULL DEFAULT 0,
    care_mode_enabled   TINYINT      NOT NULL DEFAULT 0,
    emergency_phone     VARCHAR(20)  NOT NULL DEFAULT '',
    binding_code        VARCHAR(20)  NOT NULL DEFAULT '',
    created_at          VARCHAR(32)  NOT NULL,
    updated_at          VARCHAR(32)  NOT NULL,
    CONSTRAINT fk_elderly_account FOREIGN KEY (account_id) REFERENCES account_user(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE child_profile (
    id                  VARCHAR(64)  NOT NULL PRIMARY KEY,
    account_id          VARCHAR(64)  NOT NULL UNIQUE,
    real_name           VARCHAR(64)  NOT NULL DEFAULT '',
    relation            VARCHAR(20)  NOT NULL DEFAULT '子女',
    notification_enabled TINYINT     NOT NULL DEFAULT 1,
    created_at          VARCHAR(32)  NOT NULL,
    updated_at          VARCHAR(32)  NOT NULL,
    CONSTRAINT fk_child_account FOREIGN KEY (account_id) REFERENCES account_user(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE family_binding (
    id                  VARCHAR(64)  NOT NULL PRIMARY KEY,
    elderly_account_id  VARCHAR(64)  NOT NULL,
    child_account_id    VARCHAR(64)  NOT NULL,
    binding_code        VARCHAR(20)  NOT NULL DEFAULT '',
    status              VARCHAR(20)  NOT NULL DEFAULT 'active',
    created_at          VARCHAR(32)  NOT NULL,
    updated_at          VARCHAR(32)  NOT NULL,
    CONSTRAINT fk_binding_elderly FOREIGN KEY (elderly_account_id) REFERENCES account_user(id),
    CONSTRAINT fk_binding_child   FOREIGN KEY (child_account_id)   REFERENCES account_user(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE address (
    id                          VARCHAR(64)  NOT NULL PRIMARY KEY,
    elderly_account_id          VARCHAR(64)  NOT NULL,
    managed_by_child_account_id VARCHAR(64)  DEFAULT '',
    receiver                    VARCHAR(64)  NOT NULL,
    phone                       VARCHAR(20)  NOT NULL,
    detail                      VARCHAR(256) NOT NULL,
    is_default                  TINYINT      NOT NULL DEFAULT 0,
    created_at                  VARCHAR(32)  NOT NULL,
    updated_at                  VARCHAR(32)  NOT NULL,
    CONSTRAINT fk_address_elderly FOREIGN KEY (elderly_account_id) REFERENCES account_user(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE product_mock (
    id                  VARCHAR(64)   NOT NULL PRIMARY KEY,
    platform            VARCHAR(32)   NOT NULL,
    name                VARCHAR(128)  NOT NULL,
    price               DOUBLE        NOT NULL,
    rating              DOUBLE        NOT NULL DEFAULT 0,
    sales               INT           NOT NULL DEFAULT 0,
    shop_name           VARCHAR(128)  NOT NULL DEFAULT '',
    description         TEXT,
    tags                VARCHAR(512)  DEFAULT '',
    image_key           VARCHAR(64),
    image_url           VARCHAR(512),
    recommend_score     DOUBLE        DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE order_record (
    id                          VARCHAR(64)  NOT NULL PRIMARY KEY,
    elderly_account_id          VARCHAR(64),
    managed_by_child_account_id VARCHAR(64)  DEFAULT '',
    product_id                  VARCHAR(64)  NOT NULL,
    product_name                VARCHAR(128) NOT NULL,
    platform                    VARCHAR(32)  NOT NULL DEFAULT '',
    quantity                    INT          NOT NULL DEFAULT 1,
    address_id                  VARCHAR(64),
    total_price                 DOUBLE       NOT NULL,
    payment_method              VARCHAR(20)  NOT NULL,
    payment_status              VARCHAR(20)  NOT NULL,
    created_at                  VARCHAR(32)  NOT NULL,
    CONSTRAINT fk_order_product FOREIGN KEY (product_id) REFERENCES product_mock(id),
    CONSTRAINT fk_order_address FOREIGN KEY (address_id) REFERENCES address(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE payment_record (
    id                  VARCHAR(64)  NOT NULL PRIMARY KEY,
    order_id            VARCHAR(64),
    elderly_account_id  VARCHAR(64),
    product_id          VARCHAR(64),
    amount              DOUBLE       NOT NULL DEFAULT 0,
    method              VARCHAR(20)  NOT NULL,
    status              VARCHAR(20)  NOT NULL,
    message             VARCHAR(256) NOT NULL DEFAULT '',
    created_at          VARCHAR(32)  NOT NULL,
    CONSTRAINT fk_payment_order FOREIGN KEY (order_id) REFERENCES order_record(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE reminder (
    id                  VARCHAR(64) NOT NULL PRIMARY KEY,
    order_id            VARCHAR(64) NOT NULL,
    elderly_account_id  VARCHAR(64),
    child_account_id    VARCHAR(64),
    title               VARCHAR(128) NOT NULL,
    content             TEXT,
    read_flag           TINYINT     NOT NULL DEFAULT 0,
    created_at          VARCHAR(32) NOT NULL,
    CONSTRAINT fk_reminder_order FOREIGN KEY (order_id) REFERENCES order_record(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE audit_log (
    id                  VARCHAR(64) NOT NULL PRIMARY KEY,
    actor_account_id    VARCHAR(64),
    elderly_account_id  VARCHAR(64),
    action              VARCHAR(64) NOT NULL,
    detail              VARCHAR(512) NOT NULL DEFAULT '',
    created_at          VARCHAR(32) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_account_phone       ON account_user(phone);
CREATE INDEX idx_account_role        ON account_user(default_role);
CREATE INDEX idx_elderly_account_id  ON elderly_profile(account_id);
CREATE INDEX idx_child_account_id    ON child_profile(account_id);
CREATE INDEX idx_binding_elderly     ON family_binding(elderly_account_id);
CREATE INDEX idx_binding_child       ON family_binding(child_account_id);
CREATE INDEX idx_binding_status      ON family_binding(status);
CREATE INDEX idx_address_elderly     ON address(elderly_account_id);
CREATE INDEX idx_product_tags        ON product_mock(tags(100));
CREATE INDEX idx_order_elderly       ON order_record(elderly_account_id);
CREATE INDEX idx_order_created       ON order_record(created_at);
CREATE INDEX idx_payment_elderly     ON payment_record(elderly_account_id);
CREATE INDEX idx_payment_order       ON payment_record(order_id);
CREATE INDEX idx_reminder_elderly    ON reminder(elderly_account_id);
CREATE INDEX idx_reminder_child      ON reminder(child_account_id);
CREATE INDEX idx_audit_elderly       ON audit_log(elderly_account_id);
