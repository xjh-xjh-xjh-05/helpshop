# HelpShop 纯血鸿蒙 App 前后端规范

## 工程边界

`entry` 是 HarmonyOS App 模块，只放 ArkTS、ArkUI、资源、Ability、页面、组件、模型、服务封装和设备能力调用。

`backend` 是外部服务端工程，只用于本地开发或部署到服务器。它不属于 HAP 包，不应被当作 App 内部后端。

## App 端规范

- 页面放在 `entry/src/main/ets/pages`。
- 复用 UI 放在 `entry/src/main/ets/components`。
- App 内模型放在 `entry/src/main/ets/models`。
- App 内本地服务、Mock 服务、远程客户端放在 `entry/src/main/ets/services`。
- 环境配置放在 `entry/src/main/ets/config`。
- 远程请求统一走 `RemoteBackendClient`，页面不直接写 HTTP URL。
- 当前演示默认走本地 Mock 服务，远程后端作为逐步替换能力。

## 后端规范

- 后端使用 FastAPI + SQLite，目录为 `backend`。
- 数据库文件位于 `backend/data`，属于运行产物，不提交。
- 后端负责账号、Token、验证码、数据库、模拟支付、同步事件、通知 outbox 和审计日志。
- 商品数据暂时仍为模拟数据，不接淘宝、京东、拼多多真实接口。

## 当前替换策略

第一阶段：App 内 Mock 闭环保持可演示。

第二阶段：新增 `RemoteBackendClient`，完成 App 到外部后端的 HTTP 连接能力。

第三阶段：逐个把登录、地址、订单、提醒、支付记录从 App 内 Mock 服务切到远程后端。

第四阶段：接入真实鸿蒙分布式 KV、分布式通知和真实支付能力。

## 不应出现的做法

- 不把 Python、Node、Java 服务端代码打包进 HAP。
- 不在 ArkTS 前端保存平台密钥、支付密钥或短信服务密钥。
- 不让页面直接调用散落的 URL。
- 不把 SQLite 服务端数据库文件提交进 App 工程交付。
