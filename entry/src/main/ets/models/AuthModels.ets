export enum AccountRole {
  Unverified = 'unverified',
  Elderly = 'elderly',
  Child = 'child',
  Admin = 'admin',
  CustomerService = 'customer_service'
}

export enum AccountStatus {
  Active = 'active',
  Disabled = 'disabled'
}

export enum FamilyBindingStatus {
  Pending = 'pending',
  Active = 'active',
  Removed = 'removed'
}

export interface Account {
  id: string;
  idUser: number;
  phone: string;
  passwordHash: string;
  displayName: string;
  defaultRole: AccountRole;
  status: AccountStatus;
  huaweiOpenId?: string;
  huaweiUnionId?: string;
  avatarUri?: string;
  nickName?: string;
  createdAt: string;
  updatedAt: string;
}

export interface ElderlyProfile {
  id: string;
  accountId: string;
  realName: string;
  age: number;
  careModeEnabled: boolean;
  emergencyPhone: string;
  bindingCode: string;
  createdAt: string;
  updatedAt: string;
}

export interface ChildProfile {
  id: string;
  accountId: string;
  realName: string;
  relation: string;
  notificationEnabled: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface FamilyBinding {
  id: string;
  elderlyAccountId: string;
  childAccountId: string;
  bindingCode: string;
  status: FamilyBindingStatus;
  createdAt: string;
  updatedAt: string;
}

export interface AuthResult {
  success: boolean;
  message: string;
  account?: Account;
}

export interface BindingResult {
  success: boolean;
  message: string;
  binding?: FamilyBinding;
}

export interface HarmonyOSLoginResult {
  success: boolean;
  openID: string;
  unionID: string;
  authorizationCode: string;
  idToken?: string;
  message: string;
}

export interface HarmonyOSPhoneAuthResult {
  success: boolean;
  phoneAuthorizationCode: string;
  openID?: string;
  message: string;
}

export interface HarmonyOSFullAuthResult {
  success: boolean;
  loginResult?: HarmonyOSLoginResult;
  phoneAuthResult?: HarmonyOSPhoneAuthResult;
  phoneDenied: boolean;
  message: string;
}

export interface AdminProfile {
  id: string;
  accountId: string;
  realName: string;
  department: string;
  permissions: string[];
  createdAt: string;
  updatedAt: string;
}

export interface CustomerServiceProfile {
  id: string;
  accountId: string;
  realName: string;
  serviceGroup: string;
  maxConcurrent: number;
  status: string;
  createdAt: string;
  updatedAt: string;
}

export interface CustomerTicket {
  id: string;
  csAccountId: string;
  elderlyAccountId: string;
  orderId: string;
  title: string;
  content: string;
  status: string;
  priority: string;
  userDisplay?: string;
  createdAt: string;
  updatedAt: string;
}