# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HelpShop is a HarmonyOS (API 6.1.1) shopping app designed for elderly users, with a companion Spring Boot backend. The app features AI-powered voice/agent shopping, multi-platform price comparison, family account binding (elderly ↔ child), and simulated payments.

**Bundle**: `com.wuit.xjh.helpshop`

## Build & Run

### HarmonyOS Frontend (DevEco Studio)

Open the project root in DevEco Studio, then use the IDE's build/run. No CLI-only build flow exists.

### Spring Boot Backend

```powershell
cd backend-spring
mvn spring-boot:run
```

Default port `8000`. Uses H2 file database at `backend-spring/data`. Token storage is in-memory and lost on restart.

**Frontend backend URL** is configured in `entry/src/main/ets/config/AppConfig.ets` (`remoteBackendBaseUrl`). When running on emulator, use the host machine's LAN IP (e.g., `http://192.168.x.x:8000`).

### Legacy FastAPI Backend (deprecated in favor of Spring Boot)

```powershell
python -m uvicorn backend.app:app --host 127.0.0.1 --port 8000
```

## Demo Accounts

| Role | Phone | Password | Notes |
|------|-------|----------|-------|
| Elderly | 13800000001 | 123456 | Binding code: HS2026 |
| Child | 13900000001 | 123456 | Bound to elderly |
| Admin | 13700000001 | 123456 | |
| Customer Service | 13600000001 | 123456 | |

## Architecture

### Frontend: Facade Pattern

Pages never call services directly. All business logic goes through `AppBackendService` → `*FacadeService` → local service or `RemoteBackendClient`.

```
Pages → AppBackendService → AuthFacadeService / ProductFacadeService / OrderFacadeService / ProfileFacadeService
  → Local Service (in-memory mock) —OR— RemoteBackendClient (HTTP to Spring Boot)
```

**Dual-mode**: `AppConfig.backendMode` toggles between `LocalMock` and `RemoteApi`. All `*Remote()` methods in Facades automatically fall back to local mock when the backend is unreachable.

### Agent Pipeline

The agent is a rule-based (keyword matching) shopping assistant. Entry points:

```
ShoppingAgentOrchestrator.process(input)
  → IntentEngine.parse() — keyword-based intent classification + product/attribute extraction
  → AgentTaskDispatcher.dispatch() — routes to Skill based on IntentType
  → SkillRegistry.findSkill() — linear search for first matching Skill
  → Skill.execute() — ShoppingCompareSkill / ProductSearchSkill / OrderConfirmSkill / PaymentSkill / VoiceInputSkill / AdminDashboardSkill / CustomerServiceSkill
  → Returns AgentResponse { intent, action, result, session }
```

Key files:
- `entry/src/main/ets/agent/ShoppingAgentOrchestrator.ets` — main orchestrator
- `entry/src/main/ets/agent/IntentEngine.ets` — keyword-based NLP (product keywords, triggers, attribute extraction)
- `entry/src/main/ets/agent/SkillRegistry.ets` — skill registration
- `entry/src/main/ets/agent/AgentSessionManager.ets` — global singleton session (Shopping → Comparing → WaitingConfirm → WaitingPayment → Completed)
- `entry/src/main/ets/agent/CompareEngine.ets` — scoring algorithm (price 30% / rating 25% / sales 20% / attribute match 25%)

### Role System

4 roles in `AccountRole` enum:
- `Elderly` → `UserHome` (shopping)
- `Child` → `ChildHome` (family dashboard, address management, proxy shopping)
- `Admin` → `AdminHome` (user stats, order monitoring, audit logs)
- `CustomerService` → `CustomerServiceHome` (ticket management, customer inquiry)

Role routing is manual in each page's `aboutToAppear()` via `AppBackendService.getCurrentRole()` — there is no centralized route guard.

### Key Directories

| Path | Purpose |
|------|---------|
| `entry/src/main/ets/pages/` | All ArkUI pages |
| `entry/src/main/ets/agent/` | Agent engine: orchestrator, intent parser, skills, session |
| `entry/src/main/ets/services/` | Facade and local services |
| `entry/src/main/ets/models/` | TypeScript interfaces and enums |
| `entry/src/main/ets/mock/` | Mock data (products, accounts) |
| `entry/src/main/ets/components/` | Reusable UI components |
| `entry/src/main/ets/config/` | AppConfig, payment config |
| `entry/src/main/ets/utils/` | RouteUtils, CloneUtils, TimeUtils, PermissionUtils |
| `backend-spring/src/main/java/com/helpshop/backend/` | Spring Boot: controller, service, entity, repository, config |

## Coding Conventions

- **Language**: ArkTS (`.ets` files) for frontend, Java 8 for backend
- **State management**: `@StorageLink` for cross-page state (`careMode`, `avatarUri`, `nickName`, `lastPaymentEvent`)
- **Navigation**: `RouteUtils` wrappers around router API — use `pushPage`, `replacePage`, `clearAndPush`, `navigate`, `goBack`
- **Data cloning**: Always use `CloneUtils` for deep copies of model objects passed across layers
- **Error handling**: `RemoteDataMapper.fail<T>(code, message)` and `RemoteDataMapper.ok<T>(message, data)` for standardized `BackendResult<T>`
- **Agent intents**: New intent types go in `IntentType` enum (`AgentModels.ets`); new skills implement the `Skill` interface and register via `SkillRegistry`
- **Care mode**: All UI must respond to `@StorageLink('careMode')` with larger fonts (typically +4-6px) and larger touch targets (typically +6-10px height)

## Backend Extension

When adding new API endpoints:
1. Add the endpoint in `HelpShopController.java`
2. Add the service method in `HelpShopService.java`
3. Add the remote client method in `RemoteBackendClient.ets`
4. Add the facade method in the relevant `*FacadeService.ets`
5. Expose through `AppBackendService.ets`
6. Update `RemoteModels.ets` and `RemoteDataMapper.ets` for any new DTOs

## When Working with Agent Code

- `IntentEngine` product keywords are now **dynamic** — extracted from `MockData.MOCK_PRODUCTS` at runtime via `getProductKeywords()`. Do not add to the old hardcoded array.
- `mergeSupplement` logic is centralized in `IntentEngine.mergeSupplementIntent()`. `ConversationManager.mergeSupplement()` delegates to it.
- `AgentSessionManager.startShopping(query, role)` accepts an optional role parameter; default is `'elderly'`.
- `SkillResultData.payload` is the extension point for new skills — use it instead of adding more fields to the existing compound interface.
- `DistributedEventEmitter` writes payment events to `AppStorage('lastPaymentEvent')` as JSON; `ChildHome` subscribes to this for real-time order notifications.
