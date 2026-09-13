# HelpShop 项目进度总结（2026-09-12）

## 一、项目定位

纯血鸿蒙（HarmonyOS API 6.1.1）银发购物辅助 App，面向老人 + 子女两种核心用户，含 AI 助手购物、多平台比价、家庭账号绑定、模拟支付。Bundle：`com.wuit.xjh.helpshop`。

## 二、已完成

### 1. 前端（entry，27 个页面）
- **账号体系**：Login / Register / IdentityAuth / BindFamily，4 角色路由（Elderly → UserHome、Child → ChildHome、Admin → AdminHome、CustomerService → CustomerServiceHome）
- **老人购物闭环**：UserHome → UserCategory → ProductDetail → CompareResult → PaymentConfirm → OrderHistory，另有 AddressManage、ReminderList、AgentAssistant
- **子女端**：ChildHome（家庭看板、代买、实时支付通知）、ChildProfile
- **管理端**：AdminUserManage、AdminOrderMonitor、AdminAuditLog、AdminProfile
- **客服端**：CSTicketManage、CSOrderList、CustomerServiceHome、CSProfile

### 2. Agent 智能助手（agent/，28 个文件）
- 管线：Orchestrator → IntentEngine（关键词意图识别 + 属性抽取）→ TaskDispatcher → SkillRegistry → Skill
- 已注册 Skill：商品搜索、比价、选品、下单确认、支付、语音输入、地址管理、提醒管理、家庭绑定、订单查询、管理看板、客服
- 双模式：Native（规则）/ **Copilot（当前默认，DeepSeek LLM + ToolRegistry 前端工具调用）**
- 会话状态机：Shopping → Comparing → WaitingConfirm → WaitingPayment → Completed
- 比价引擎：价格 30% / 评分 25% / 销量 20% / 属性匹配 25%

### 3. 服务层（services/，30 个文件，Facade 模式）
- 页面不直接调服务，统一走 AppBackendService → Facade → LocalMock 或 RemoteBackendClient
- **当前 backendMode = RemoteApi**（AppConfig.ets）
- RemoteBackendClient 已覆盖 30+ 接口：登录注册、验证码、华为账号、家庭绑定、商品、比价、地址、模拟支付、订单、提醒、四端看板、同步事件、通知、审计日志

### 4. 后端（backend-spring，Spring Boot + H2 + JWT）
- 15 个实体（账号、四类角色 Profile、家庭绑定、商品、订单、支付记录、提醒、工单、通知、同步事件、审计日志）
- JwtAuthenticationFilter + SecurityConfig 已接入
- 旧 FastAPI 后端（backend/）已废弃

### 5. 外部集成（配置就绪）
- 华为账号登录、华为支付（HuaWeiPaymentService）
- 拼多多 API 适配器（PddApiAdapter，enabled）、万邦多平台 API（enabled=false）
- 语音识别 + TTS

### 6. 文档
- PRODUCT.md（产品定位、设计原则、无障碍要求）、CLAUDE.md（架构与开发规范）、docs/ 两篇

## 三、当前阶段决策（2026-09-12）

**本阶段只使用本地数据**：演示闭环跑在 App 内 Mock 数据上（`LocalMock` 模式），当前任务就是**按产品要求编写/完善本地数据**，包括：

1. 按 PRODUCT.md 的品类与银发用户定位，补齐 `mock/` 下的商品数据（名称、价格、评分、销量、属性，供比价引擎打分）——**数据参照各大商城 App 的真实商品生成**（见下方"商品数据来源策略"）
2. 演示账号数据（13800000001 老人 / 13900000001 子女等 4 个角色）与家庭绑定码 HS2026
3. 各角色看板所需的订单、提醒、工单、审计日志示例数据
4. 保证商品关键词与 `IntentEngine` 动态关键词（从 MockData 提取）对得上，Agent 搜索/比价可命中

由此，以下依赖外部环境的事项**全部移入后续计划，本阶段不做**：远程后端切换回归、真实电商 API、**真实支付闭环**、分布式 KV/通知。

**支付按"调用即走通"处理**：本阶段支付只要求功能可被调用、流程可演示（选择支付方式 → PaymentConfirm → MockPaymentService 返回结果 → 生成订单/支付记录 → 触发支付事件通知），**无需完全实现真实支付，直接模拟支付成功即可**，不做真实扣款、华为支付服务端预下单与回调闭环（后续如无明确要求也不再接入）。

**商品数据来源策略**：
1. **取数接口原样保留**——`PlatformProductGatewayService`（统一网关）+ `PddApiAdapter` / `PublicProductApiAdapter` / `WanbangApiAdapter`（适配器）+ `ProductFacadeService` / `MockProductService`（门面与本地实现）这套结构不动，页面和 Agent 侧的调用方式不变
2. **数据源切换为本地数据**——适配器取数改为指向本地商品数据，不再请求真实外部 API；后续如需再接真实平台，只需换回适配器数据源，接口层无需改动
3. **本地数据参照各大商城 App 生成**——编写 `mock/` 商品数据时，参照淘宝/京东/拼多多等主流商城 App 的真实商品信息（品类结构、命名风格、价格区间、评分销量、规格属性）生成仿真数据，并构造"同款商品多平台不同价"的比价场景，保证比价引擎有区分度可演示

## 四、后续计划明细（按优先级，本阶段不实施）

> 本阶段只做本地数据编写，以下条目均已列入"后续计划"，此处保留备查。注意：`AppConfig.backendMode` 当前为 `RemoteApi`，纯本地演示时可切回 `LocalMock`（远程不可达时 Facade 也会自动回退本地 Mock，不影响演示）。

### P0 — 安全与合规（接外部服务前必须处理）
1. **前端硬编码密钥**：AppConfig.ets 中 DeepSeek apiKey、拼多多 clientSecret、万邦 apiSecret 全部明文写在前端，违反项目自身规范"不在 ArkTS 前端保存平台密钥"。建议：LLM 调用走后端代理，电商 API 密钥只留在服务端。
2. **华为支付回调 URL 是占位符**（`https://your-server.com/...`），`useServerPreOrder=true` 时服务端预下单无法闭环 → 本阶段用 MockPaymentService 模拟支付即可，真实支付闭环移入后续计划。

### P1 — 功能补全
3. **订单详情/售后缺失**：有 OrderHistory 列表，但没有 OrderDetail、取消订单、退款/售后流程页面。
4. **提醒功能偏弱**：ReminderList 只支持"查看 + 全部已读"，缺新增/编辑/删除提醒（虽然 ReminderManageSkill 已有意图，页面端未打通）。
5. **商品数据**：已决策为"接口保留、数据源切本地"——现有商品取数接口（Gateway/Adapter/Facade）不动，数据源换成本地数据（参照各大商城 App 生成），不接真实淘宝/京东接口；比价来源在 UI 标注为本地仿真数据即可。
6. **通知实时性**：支付事件目前靠 AppStorage('lastPaymentEvent') 本地广播，跨设备场景需走后端 SyncEvent 轮询或推送。

### P2 — 环境与工程化
7. **后端地址硬编码**：`remoteBackendBaseUrl = http://10.80.35.138:8000`（局域网 IP），换网络即失效，应改为构建配置或运行时设置页。
8. **Token 存储**：后端 token 内存态，重启即丢（JWT 已缓解，但刷新/续期策略未做）。
9. **无测试**：前端无 ArkTS 单测，backend-spring 无 test 目录；演示关键路径建议至少补接口冒烟测试。
10. **仓库卫生**：无 git 仓库；根目录有临时文件（`nul`、`screenshot_*.jpeg`、`agent_config.json`、`tmp/` 49 个 jar）需清理/加 .gitignore。
11. **文档不一致**：`docs/harmony_app_backend_standard.md` 仍写"FastAPI + SQLite 后端"，与现状（Spring Boot + H2）不符；四阶段替换策略文档里第三阶段实际已基本完成，需更新。

### P3 — 打磨
12. 关怀模式（careMode 大字号/大按钮）与无障碍要求需逐页核对覆盖情况。
13. 语音输入 Skill 与真实 SpeechService 的错误兜底、弱网体验。
14. 演示数据初始化脚本（后端 seed 演示账号 13800000001 等）。

## 五、对照替换策略的进度

| 阶段 | 内容 | 状态 |
|------|------|------|
| 一 | App 内 Mock 闭环 | ✅ 完成（**当前主用模式，本阶段只需按需补数据**） |
| 二 | RemoteBackendClient HTTP 连接 | ✅ 能力已具备（暂不使用） |
| 三 | 登录/地址/订单/提醒/支付切到远程 | ⏸ 移入后续计划 |
| 四 | 真实分布式 KV、分布式通知 | ⏸ 移入后续计划（依赖真机 + 华为开发者资质）；真实支付不做，仅调用功能并模拟支付成功 |

## 六、后续计划（本阶段完成后）

1. 远程模式回归：`backendMode` 切回 `RemoteApi`，验证登录/订单/提醒/支付全链路
2. 支付：**只需调用支付功能并模拟支付成功**（MockPaymentService 返回成功结果、生成订单与支付记录），不接华为支付服务端预下单与回调；后续如无明确要求，不再计划真实支付接入
3. 真实分布式 KV：`DistributedDataSync.ets` 由当前模拟实现切换为 `@kit.ArkData`（distributedKVStore）分布式键值数据库，家庭绑定关系、订单/提醒数据跨设备同步
4. 真实分布式通知：当前支付事件靠 `AppStorage('lastPaymentEvent')` 本地广播 + 后端 SyncEvent 模拟，后续切换为分布式软总线事件通知/推送服务，实现子女端实时收到老人支付/订单事件
5. **Agent 智能化优化**（当前未达到预期智能目标，重点改进）：
   - 意图识别增强：`IntentEngine` 关键词匹配升级为语义理解（相似词、口语化表达、方言常见说法），减少误判和漏判
   - Copilot 模式可靠性：DeepSeek 调用失败/超时的降级策略（自动回退 Native 规则模式），工具调用结果校验，避免编造商品
   - 多轮对话上下文：跨轮次的偏好记忆（常买商品、预算、品牌偏好），追问补全缺失属性而不是直接猜
   - 主动性与建议质量：比价推荐理由（`ReasonBuilder`）更贴合老人表达习惯，支持主动提醒（如常购商品降价、复购时间到）
   - 语音链路：语音识别 → Agent → TTS 回播的端到端稳定性与错误兜底
6. P0 安全整改：前端明文密钥迁移到后端代理
7. P1 功能补全：订单详情/取消/售后页面、提醒新增编辑页面
8. P2 工程化：后端地址改构建配置、补测试、建 git 仓库并清理临时文件、修正 backend 文档
9. P3 打磨：关怀模式逐页核对、弱网兜底、演示数据 seed 脚本
