# HelpShop 统一账号、身份认证与角色数据表设计

本项目采用统一登录注册：注册和登录只创建账号，不在登录页区分老人或子女。账号进入应用后，再完成老人身份认证或子女身份认证；子女账号绑定老人账号后，可以帮助老人购物。

## account_user
统一账号主表，保存所有可登录账号。

| 字段 | 说明 |
| --- | --- |
| id | 主键 |
| phone | 手机号，唯一 |
| password_hash | 密码摘要，演示版使用明文模拟 |
| display_name | 昵称或姓名 |
| default_role | 当前已认证身份：unverified / elderly / child |
| status | 账号状态：active / disabled |
| created_at | 创建时间 |
| updated_at | 更新时间 |

## elderly_profile
老人身份认证资料表。账号认证为老人后生成。

| 字段 | 说明 |
| --- | --- |
| id | 主键 |
| account_id | 关联 account_user.id |
| real_name | 真实姓名 |
| age | 年龄 |
| care_mode_enabled | 是否默认启用关怀模式 |
| emergency_phone | 紧急联系人手机号 |
| binding_code | 给子女绑定使用的绑定码 |
| created_at | 创建时间 |
| updated_at | 更新时间 |

## child_profile
子女身份认证资料表。账号认证为子女后生成。

| 字段 | 说明 |
| --- | --- |
| id | 主键 |
| account_id | 关联 account_user.id |
| real_name | 真实姓名 |
| relation | 与老人关系 |
| notification_enabled | 是否接收提醒 |
| created_at | 创建时间 |
| updated_at | 更新时间 |

## family_binding
老人账号与子女账号绑定关系表。子女绑定老人后，才能帮助老人购物。

| 字段 | 说明 |
| --- | --- |
| id | 主键 |
| elderly_account_id | 老人账号 id |
| child_account_id | 子女账号 id |
| binding_code | 绑定码 |
| status | pending / active / removed |
| created_at | 创建时间 |
| updated_at | 更新时间 |

## 业务表归属字段
后续真实数据库落地时，现有业务表需要增加账号归属字段。

| 表 | 新增字段 |
| --- | --- |
| address | elderly_account_id, managed_by_child_account_id |
| order | elderly_account_id |
| reminder | elderly_account_id, child_account_id |
