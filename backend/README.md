# HelpShop External Backend

本目录是独立后端服务，使用 FastAPI + SQLite。它不是 HarmonyOS HAP 的一部分，不会被打包进 `entry` 模块。

纯血鸿蒙 App 侧只负责 ArkUI 页面、ArkTS 业务编排、设备能力和 HTTP 调用；账号、数据库、Token、短信验证码、模拟支付、通知 outbox 等服务端能力放在这里。

## 启动

```powershell
cd C:\Users\xu\DevEcoStudioProjects\helpshop
python -m uvicorn backend.app:app --host 127.0.0.1 --port 8000
```

## 已实现

- SQLite 持久化数据库
- 注册、登录、Token 鉴权
- 演示短信验证码接口
- 老人/子女账号和家庭绑定
- 地址管理
- 模拟商品数据
- 模拟支付接口
- 订单、提醒、支付记录
- 服务端同步事件接口
- 分布式通知 outbox 占位接口
- 审计日志

购物商城真实平台接口未接入，当前仍使用模拟商品数据。

## App 侧连接

App 侧远程服务地址集中在：

```text
entry/src/main/ets/config/AppConfig.ets
```

真机调试时，不要使用 `127.0.0.1`，需要改成电脑局域网 IP。
