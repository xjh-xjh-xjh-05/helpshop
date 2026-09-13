# HelpShop Spring Boot 后端

这是 HelpShop 的 Spring Boot 版后端，用于逐步替换原 `backend` FastAPI 原型服务。当前目标是先保持前端接口兼容，后续再继续拆分标准 Controller、Service、Repository 分层，并替换为 MySQL、Spring Security 和真实第三方能力。

## 技术栈

- Spring Boot 2.7.18
- Java 8 兼容
- Spring Web
- Spring JDBC
- H2 文件数据库，数据保存在 `backend-spring/data`

选择 Spring Boot 2.7 是因为当前本机 Java 环境为 Java 8；如果后续安装 Java 17，可以升级到 Spring Boot 3。

## 启动

```powershell
cd C:\Users\xu\DevEcoStudioProjects\helpshop\backend-spring
mvn spring-boot:run
```

默认端口是 `8000`，与当前 HarmonyOS 前端的 `http://192.168.80.1:8000` 保持一致。

如果 DevEco 模拟器访问本机服务：

1. 启动 Spring Boot 后端，确认 `http://127.0.0.1:8000/health` 可访问。
2. 保持前端 `entry/src/main/ets/config/AppConfig.ets` 的 `remoteBackendBaseUrl` 为 `http://192.168.80.1:8000`。
3. 在模拟器中重新登录，因为当前演示 Token 保存在后端内存中，后端重启后旧 Token 会失效。

## 演示账号

- 老人账号：`13800000001` / `123456`
- 子女账号：`13900000001` / `123456`
- 老人绑定码：`HS2026`

## 已实现接口

- `GET /health`
- `POST /api/auth/sms/send`
- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/auth/me`
- `POST /api/auth/certify`
- `POST /api/family/bind`
- `GET /api/family/bindings`
- `GET /api/addresses`
- `POST /api/addresses`
- `POST /api/addresses/default`
- `POST /api/addresses/delete`
- `GET /api/products/mock`
- `GET /api/products/{id}`
- `POST /api/agent/compare`
- `POST /api/agent/selection-command`
- `POST /api/payments/mock`
- `GET /api/orders`
- `GET /api/reminders`
- `POST /api/reminders/read-all`
- `GET /api/profile/stats`
- `GET /api/child/dashboard`
- `GET /api/sync/events`
- `GET /api/notifications`
- `GET /api/audit-logs`

## 当前边界

- 商品数据仍是 Mock，但已经放到后端数据库中，前端后续从接口获取。
- HarmonyOS 前端已接入远程商品、Agent 推荐、商品详情、支付模拟、订单提醒和统计接口；网络失败时仍保留本地 Mock 兜底。
- Token 是演示级 Bearer Token，服务重启后需要重新登录。
- 支付、分布式同步、通知均为后端模拟记录，不调用真实系统能力。
