import { Account, AccountRole, AccountStatus, AdminProfile, ChildProfile, CustomerServiceProfile, ElderlyProfile, FamilyBinding, FamilyBindingStatus } from '../models/AuthModels';

export const MOCK_ACCOUNTS: Account[] = [
  {
    id: 'acct-elderly-001',
    idUser: 0,
    phone: '13800000001',
    passwordHash: '123456',
    displayName: '徐叔叔',
    defaultRole: AccountRole.Elderly,
    status: AccountStatus.Active,
    createdAt: '2026-07-01 09:00',
    updatedAt: '2026-07-01 09:00'
  },
  {
    id: 'acct-child-001',
    idUser: 0,
    phone: '13900000001',
    passwordHash: '123456',
    displayName: '徐女士',
    defaultRole: AccountRole.Child,
    status: AccountStatus.Active,
    createdAt: '2026-07-01 09:10',
    updatedAt: '2026-07-01 09:10'
  },
  {
    id: 'acct-admin-001',
    idUser: 0,
    phone: '13700000001',
    passwordHash: '123456',
    displayName: '王管理',
    defaultRole: AccountRole.Admin,
    status: AccountStatus.Active,
    createdAt: '2026-07-01 08:00',
    updatedAt: '2026-07-01 08:00'
  },
  {
    id: 'acct-cs-001',
    idUser: 0,
    phone: '13600000001',
    passwordHash: '123456',
    displayName: '李客服',
    defaultRole: AccountRole.CustomerService,
    status: AccountStatus.Active,
    createdAt: '2026-07-01 08:30',
    updatedAt: '2026-07-01 08:30'
  }
];

export const MOCK_ELDERLY_PROFILES: ElderlyProfile[] = [
  {
    id: 'elderly-profile-001',
    accountId: 'acct-elderly-001',
    realName: '徐叔叔',
    age: 68,
    careModeEnabled: true,
    emergencyPhone: '13900000001',
    bindingCode: 'HS2026',
    createdAt: '2026-07-01 09:00',
    updatedAt: '2026-07-01 09:00'
  }
];

export const MOCK_CHILD_PROFILES: ChildProfile[] = [
  {
    id: 'child-profile-001',
    accountId: 'acct-child-001',
    realName: '徐女士',
    relation: '子女',
    notificationEnabled: true,
    createdAt: '2026-07-01 09:10',
    updatedAt: '2026-07-01 09:10'
  }
];

export const MOCK_ADMIN_PROFILES: AdminProfile[] = [
  {
    id: 'admin-profile-001',
    accountId: 'acct-admin-001',
    realName: '王管理',
    department: '运营管理部',
    permissions: ['account_manage', 'audit_view', 'system_config'],
    createdAt: '2026-07-01 08:00',
    updatedAt: '2026-07-01 08:00'
  }
];

export const MOCK_CS_PROFILES: CustomerServiceProfile[] = [
  {
    id: 'cs-profile-001',
    accountId: 'acct-cs-001',
    realName: '李客服',
    serviceGroup: '综合服务组',
    maxConcurrent: 10,
    status: 'active',
    createdAt: '2026-07-01 08:30',
    updatedAt: '2026-07-01 08:30'
  }
];

export const MOCK_FAMILY_BINDINGS: FamilyBinding[] = [
  {
    id: 'binding-001',
    elderlyAccountId: 'acct-elderly-001',
    childAccountId: 'acct-child-001',
    bindingCode: 'HS2026',
    status: FamilyBindingStatus.Active,
    createdAt: '2026-07-01 09:20',
    updatedAt: '2026-07-01 09:20'
  }
];
