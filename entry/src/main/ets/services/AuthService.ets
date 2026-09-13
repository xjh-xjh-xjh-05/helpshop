import { hilog } from '@kit.PerformanceAnalysisKit';
import { MOCK_ACCOUNTS, MOCK_ADMIN_PROFILES, MOCK_CHILD_PROFILES, MOCK_CS_PROFILES, MOCK_ELDERLY_PROFILES, MOCK_FAMILY_BINDINGS } from '../mock/MockAccountData';
import { RemoteAdminUserItem } from '../models/RemoteModels';
import {
  Account,
  AccountRole,
  AccountStatus,
  AdminProfile,
  AuthResult,
  BindingResult,
  ChildProfile,
  CustomerServiceProfile,
  CustomerTicket,
  ElderlyProfile,
  FamilyBinding,
  FamilyBindingStatus
} from '../models/AuthModels';
import { TimeUtils } from '../utils/TimeUtils';
import { CloneUtils } from '../utils/CloneUtils';
import { RemoteDataMapper } from './RemoteDataMapper';
import { BackendResult, BindingListBackendData } from '../models/BackendModels';

export class AuthService {
  private static accounts: Account[] = MOCK_ACCOUNTS.map((item: Account) => CloneUtils.cloneAccount(item));
  private static elderlyProfiles: ElderlyProfile[] = MOCK_ELDERLY_PROFILES.map((item: ElderlyProfile) => CloneUtils.cloneElderlyProfile(item));
  private static childProfiles: ChildProfile[] = MOCK_CHILD_PROFILES.map((item: ChildProfile) => CloneUtils.cloneChildProfile(item));
  private static adminProfiles: AdminProfile[] = MOCK_ADMIN_PROFILES.map((item: AdminProfile) => CloneUtils.cloneAdminProfile(item));
  private static customerServiceProfiles: CustomerServiceProfile[] = MOCK_CS_PROFILES.map((item: CustomerServiceProfile) => CloneUtils.cloneCustomerServiceProfile(item));
  private static bindings: FamilyBinding[] = MOCK_FAMILY_BINDINGS.map((item: FamilyBinding) => CloneUtils.cloneBinding(item));
  private static currentAccountId: string = '';
  private static currentRole: AccountRole = AccountRole.Unverified;

  static isLoggedIn(): boolean {
    return AuthService.currentAccountId.length > 0;
  }

  static getCurrentAccount(): Account | undefined {
    const account = AuthService.accounts.find((item: Account) => item.id === AuthService.currentAccountId);
    return account ? CloneUtils.cloneAccount(account) : undefined;
  }

  static getCurrentRole(): AccountRole {
    const account = AuthService.getCurrentAccount();
    if (!account) {
      return AccountRole.Unverified;
    }
    return AuthService.currentRole;
  }

  static register(phone: string, password: string, displayName: string): AuthResult {
    const normalizedPhone = phone.trim();
    const normalizedName = displayName.trim();
    if (normalizedPhone.length === 0 || password.length === 0 || normalizedName.length === 0) {
      return { success: false, message: '请填写手机号、密码和姓名' };
    }
    if (AuthService.accounts.some((item: Account) => item.phone === normalizedPhone)) {
      return { success: false, message: '该手机号已注册' };
    }
    const now = TimeUtils.formatDate(new Date());
    const account: Account = {
      id: 'acct-' + Date.now().toString(),
      idUser: 0,
      phone: normalizedPhone,
      passwordHash: password,
      displayName: normalizedName,
      defaultRole: AccountRole.Unverified,
      status: AccountStatus.Active,
      createdAt: now,
      updatedAt: now
    };
    AuthService.accounts.push(account);
    AuthService.currentAccountId = account.id;
    AuthService.currentRole = AccountRole.Unverified;
    return {
      success: true,
      message: '注册成功，请完成身份认证',
      account: CloneUtils.cloneAccount(account)
    };
  }

  static login(phone: string, password: string): AuthResult {
    const account = AuthService.accounts.find((item: Account) => item.phone === phone.trim());
    if (!account) {
      return { success: false, message: '账号不存在，请先注册' };
    }
    if (account.status !== AccountStatus.Active) {
      return { success: false, message: '账号已停用' };
    }
    if (account.passwordHash !== password) {
      return { success: false, message: '密码错误' };
    }
    AuthService.currentAccountId = account.id;
    AuthService.currentRole = account.defaultRole;
    return {
      success: true,
      message: '登录成功',
      account: CloneUtils.cloneAccount(account)
    };
  }

  static findRoleByHuaweiOpenId(openId: string): AccountRole {
    const account = AuthService.accounts.find((item: Account) => item.huaweiOpenId === openId);
    return account ? account.defaultRole : AccountRole.Unverified;
  }

  static syncRemoteAccount(accountId: string, phone: string, displayName: string, role: AccountRole,
    huaweiOpenId?: string, huaweiUnionId?: string, avatarUri?: string, nickName?: string): AuthResult {
    const normalizedPhone = phone.trim();
    const normalizedName = displayName.trim().length > 0 ? displayName.trim() : normalizedPhone.length > 0 ? normalizedPhone : '华为用户';
    const now = TimeUtils.formatDate(new Date());
    let account = AuthService.accounts.find((item: Account) => {
      if (item.id === accountId) {
        return true;
      }
      if (huaweiOpenId && item.huaweiOpenId === huaweiOpenId) {
        return true;
      }
      if (normalizedPhone.length > 0 && item.phone === normalizedPhone && !accountId.startsWith('hw-')) {
        return true;
      }
      return false;
    });
    if (account) {
      if (normalizedPhone.length > 0) {
        account.phone = normalizedPhone;
      }
      account.displayName = normalizedName;
      const effectiveRole: AccountRole = (role === AccountRole.Unverified && account.defaultRole !== AccountRole.Unverified) ? account.defaultRole : role;
      account.defaultRole = effectiveRole;
      account.status = AccountStatus.Active;
      if (huaweiOpenId) {
        account.huaweiOpenId = huaweiOpenId;
      }
      if (huaweiUnionId) {
        account.huaweiUnionId = huaweiUnionId;
      }
      if (avatarUri) {
        account.avatarUri = avatarUri;
      }
      if (nickName) {
        account.nickName = nickName;
      }
      account.updatedAt = now;
    } else {
      account = {
        id: accountId,
        idUser: 0,
        phone: normalizedPhone,
        passwordHash: 'remote-managed',
        displayName: normalizedName,
        defaultRole: role,
        status: AccountStatus.Active,
        huaweiOpenId: huaweiOpenId,
        huaweiUnionId: huaweiUnionId,
        avatarUri: avatarUri,
        nickName: nickName,
        createdAt: now,
        updatedAt: now
      };
      AuthService.accounts.push(account);
    }
    AuthService.currentAccountId = account.id;
    AuthService.currentRole = account.defaultRole;
    hilog.info(0x0001, 'AuthService', 'syncRemoteAccount: id=' + account.id + ' role=' + account.defaultRole.toString() + ' currentAccountId=' + AuthService.currentAccountId + ' currentRole=' + AuthService.currentRole.toString());
    if (account.defaultRole !== AccountRole.Unverified) {
      AuthService.ensureProfile(account, account.defaultRole);
    }
    return {
      success: true,
      message: '远程账号登录成功',
      account: CloneUtils.cloneAccount(account)
    };
  }

  static logout(): void {
    hilog.info(0x0001, 'AuthService', 'logout called, clearing currentAccountId and currentRole');
    AuthService.currentAccountId = '';
    AuthService.currentRole = AccountRole.Unverified;
  }

  static certifyCurrentAccount(role: AccountRole): AuthResult {
    const account = AuthService.accounts.find((item: Account) => item.id === AuthService.currentAccountId);
    if (!account) {
      return { success: false, message: '请先登录' };
    }
    if (role === AccountRole.Unverified) {
      return { success: false, message: '请选择有效身份' };
    }
    account.defaultRole = role;
    account.updatedAt = TimeUtils.formatDate(new Date());
    AuthService.currentRole = role;
    AuthService.ensureProfile(account, role);
    const roleName = AuthService.roleName(role);
    return {
      success: true,
      message: '已认证为' + roleName,
      account: CloneUtils.cloneAccount(account)
    };
  }

  static switchRole(role: AccountRole): AuthResult {
    const account = AuthService.getCurrentAccount();
    if (!account) {
      return { success: false, message: '请先登录' };
    }
    if (account.defaultRole !== role) {
      return { success: false, message: '当前账号尚未认证该身份' };
    }
    AuthService.currentRole = role;
    return {
      success: true,
      message: '身份切换成功',
      account: account
    };
  }

  static canEnterShopping(): boolean {
    const account = AuthService.getCurrentAccount();
    if (!account) {
      return false;
    }
    if (account.defaultRole === AccountRole.Elderly) {
      return true;
    }
    // 子女需绑定老人，管理员可直接查看商城数据
    if (account.defaultRole === AccountRole.Admin || account.defaultRole === AccountRole.CustomerService) {
      return true;
    }
    return AuthService.listCurrentChildBindings().length > 0;
  }

  static canEnterWorkbench(): boolean {
    const account = AuthService.getCurrentAccount();
    if (!account) {
      return false;
    }
    return account.defaultRole !== AccountRole.Unverified;
  }

  static isBackendRole(): boolean {
    const role: AccountRole = AuthService.getCurrentRole();
    return role === AccountRole.Admin || role === AccountRole.CustomerService;
  }

  static hasActiveElderlyContext(): boolean {
    return AuthService.getCurrentElderlyAccountId().length > 0;
  }

  static getCurrentElderlyAccountId(): string {
    const account = AuthService.getCurrentAccount();
    if (!account) {
      return '';
    }
    if (account.defaultRole === AccountRole.Elderly) {
      return account.id;
    }
    if (account.defaultRole !== AccountRole.Child) {
      return '';
    }
    const binding = AuthService.bindings.find((item: FamilyBinding) => {
      return item.childAccountId === account.id && item.status === FamilyBindingStatus.Active;
    });
    return binding ? binding.elderlyAccountId : '';
  }

  static getCurrentChildAccountId(): string {
    const account = AuthService.getCurrentAccount();
    if (account && account.defaultRole === AccountRole.Child) {
      return account.id;
    }
    if (!account || account.defaultRole !== AccountRole.Elderly) {
      return '';
    }
    const binding = AuthService.bindings.find((item: FamilyBinding) => {
      return item.elderlyAccountId === AuthService.getCurrentElderlyAccountId() && item.status === FamilyBindingStatus.Active;
    });
    return binding ? binding.childAccountId : '';
  }

  // ---- 新角色 profile 查询 ----
  static getAdminProfile(accountId: string): AdminProfile | undefined {
    return AuthService.adminProfiles.find((item: AdminProfile) => item.accountId === accountId);
  }

  static getCustomerServiceProfile(accountId: string): CustomerServiceProfile | undefined {
    return AuthService.customerServiceProfiles.find((item: CustomerServiceProfile) => item.accountId === accountId);
  }

  static getElderlyProfile(accountId: string): ElderlyProfile | undefined {
    const profile = AuthService.elderlyProfiles.find((item: ElderlyProfile) => item.accountId === accountId);
    return profile ? CloneUtils.cloneElderlyProfile(profile) : undefined;
  }

  static getChildProfile(accountId: string): ChildProfile | undefined {
    const profile = AuthService.childProfiles.find((item: ChildProfile) => item.accountId === accountId);
    return profile ? CloneUtils.cloneChildProfile(profile) : undefined;
  }

  static updateElderlyProfile(accountId: string, realName: string, age: number, emergencyPhone: string): AuthResult {
    const profile = AuthService.elderlyProfiles.find((item: ElderlyProfile) => item.accountId === accountId);
    if (!profile) {
      return { success: false, message: '老人档案不存在' };
    }
    profile.realName = realName.trim();
    profile.age = age;
    profile.emergencyPhone = emergencyPhone.trim();
    profile.updatedAt = TimeUtils.formatDate(new Date());
    const account = AuthService.accounts.find((item: Account) => item.id === accountId);
    if (account && realName.trim().length > 0) {
      account.displayName = realName.trim();
      account.updatedAt = TimeUtils.formatDate(new Date());
    }
    return {
      success: true,
      message: '老人档案更新成功',
      account: account ? CloneUtils.cloneAccount(account) : undefined
    };
  }

  static updateChildProfile(accountId: string, realName: string, relation: string): AuthResult {
    const profile = AuthService.childProfiles.find((item: ChildProfile) => item.accountId === accountId);
    if (!profile) {
      return { success: false, message: '子女档案不存在' };
    }
    profile.realName = realName.trim();
    profile.relation = relation.trim();
    profile.updatedAt = TimeUtils.formatDate(new Date());
    const account = AuthService.accounts.find((item: Account) => item.id === accountId);
    if (account && realName.trim().length > 0) {
      account.displayName = realName.trim();
      account.updatedAt = TimeUtils.formatDate(new Date());
    }
    return {
      success: true,
      message: '子女档案更新成功',
      account: account ? CloneUtils.cloneAccount(account) : undefined
    };
  }

  static updateAccountNickName(accountId: string, nickName: string): void {
    const account = AuthService.accounts.find((item: Account) => item.id === accountId);
    if (account) {
      account.nickName = nickName.trim();
      account.updatedAt = TimeUtils.formatDate(new Date());
    }
  }

  static bindCurrentChildToElderly(keyword: string): BindingResult {
    const current = AuthService.getCurrentAccount();
    if (!current) {
      return { success: false, message: '请先登录' };
    }
    if (current.defaultRole !== AccountRole.Child) {
      return { success: false, message: '请先在账号中心认证为子女身份' };
    }
    const normalized = keyword.trim();
    if (normalized.length === 0) {
      return { success: false, message: '请输入老人手机号或绑定码' };
    }
    const elderlyAccount = AuthService.accounts.find((account: Account) => {
      if (account.defaultRole !== AccountRole.Elderly) {
        return false;
      }
      const profile = AuthService.elderlyProfiles.find((item: ElderlyProfile) => item.accountId === account.id);
      return account.phone === normalized || (profile ? profile.bindingCode === normalized : false) || (account.huaweiOpenId ? account.huaweiOpenId === normalized : false);
    });
    if (!elderlyAccount) {
      return { success: false, message: '未找到可绑定的老人账号' };
    }
    const exists = AuthService.bindings.find((item: FamilyBinding) => {
      return item.elderlyAccountId === elderlyAccount.id && item.childAccountId === current.id && item.status === FamilyBindingStatus.Active;
    });
    if (exists) {
      return {
        success: true,
        message: '该老人账号已绑定',
        binding: CloneUtils.cloneBinding(exists)
      };
    }
    const profile = AuthService.getElderlyProfile(elderlyAccount.id);
    const now = TimeUtils.formatDate(new Date());
    const binding: FamilyBinding = {
      id: `binding-${Date.now()}`,
      elderlyAccountId: elderlyAccount.id,
      childAccountId: current.id,
      bindingCode: profile ? profile.bindingCode : normalized,
      status: FamilyBindingStatus.Active,
      createdAt: now,
      updatedAt: now
    };
    AuthService.bindings.unshift(binding);
    return {
      success: true,
      message: '绑定成功，现在可以帮助老人购物',
      binding: CloneUtils.cloneBinding(binding)
    };
  }

  static syncRemoteFamilyBinding(
    bindingId: string,
    elderlyAccountId: string,
    elderlyPhone: string,
    elderlyName: string,
    bindingCode: string
  ): BindingResult {
    const current = AuthService.getCurrentAccount();
    if (!current) {
      return { success: false, message: '请先登录' };
    }
    if (current.defaultRole !== AccountRole.Child) {
      return { success: false, message: '当前账号不是子女身份' };
    }
    const now = TimeUtils.formatDate(new Date());
    let elderlyFound = AuthService.accounts.find((item: Account) => item.id === elderlyAccountId || item.phone === elderlyPhone);
    if (elderlyFound) {
      elderlyFound.id = elderlyAccountId;
      elderlyFound.phone = elderlyPhone;
      elderlyFound.displayName = elderlyName;
      elderlyFound.defaultRole = AccountRole.Elderly;
      elderlyFound.status = AccountStatus.Active;
      elderlyFound.updatedAt = now;
    } else {
      const newElderly: Account = {
        id: elderlyAccountId,
        idUser: 0,
        phone: elderlyPhone,
        passwordHash: 'remote-managed',
        displayName: elderlyName,
        defaultRole: AccountRole.Elderly,
        status: AccountStatus.Active,
        createdAt: now,
        updatedAt: now
      };
      AuthService.accounts.push(newElderly);
    }
    let elderlyProfile = AuthService.elderlyProfiles.find((item: ElderlyProfile) => item.accountId === elderlyAccountId);
    if (elderlyProfile) {
      elderlyProfile.realName = elderlyName;
      elderlyProfile.bindingCode = bindingCode;
      elderlyProfile.updatedAt = now;
    } else {
      AuthService.elderlyProfiles.push({
        id: `elderly-profile-${Date.now()}`,
        accountId: elderlyAccountId,
        realName: elderlyName,
        age: 0,
        careModeEnabled: false,
        emergencyPhone: '',
        bindingCode: bindingCode,
        createdAt: now,
        updatedAt: now
      });
    }
    let binding = AuthService.bindings.find((item: FamilyBinding) => {
      return item.elderlyAccountId === elderlyAccountId && item.childAccountId === current.id && item.status === FamilyBindingStatus.Active;
    });
    if (binding) {
      binding.bindingCode = bindingCode;
      binding.updatedAt = now;
    } else {
      binding = {
        id: bindingId.length > 0 ? bindingId : `binding-${Date.now()}`,
        elderlyAccountId: elderlyAccountId,
        childAccountId: current.id,
        bindingCode: bindingCode,
        status: FamilyBindingStatus.Active,
        createdAt: now,
        updatedAt: now
      };
      AuthService.bindings.unshift(binding);
    }
    return {
      success: true,
      message: '远程绑定关系已同步',
      binding: CloneUtils.cloneBinding(binding)
    };
  }

  static listCurrentChildBindings(): FamilyBinding[] {
    const current = AuthService.getCurrentAccount();
    if (!current) {
      hilog.info(0x0001, 'AuthService', 'listCurrentChildBindings: no current account');
      return [];
    }
    if (current.defaultRole !== AccountRole.Child) {
      hilog.info(0x0001, 'AuthService', 'listCurrentChildBindings: role=' + current.defaultRole.toString() + ' not Child');
      return [];
    }
    const result = AuthService.bindings.filter((item: FamilyBinding) => {
      return item.childAccountId === current.id && item.status === FamilyBindingStatus.Active;
    }).map((item: FamilyBinding) => CloneUtils.cloneBinding(item));
    hilog.info(0x0001, 'AuthService', 'listCurrentChildBindings: accountId=' + current.id + ' totalBindings=' + AuthService.bindings.length.toString() + ' matched=' + result.length.toString());
    return result;
  }

  static listCurrentChildBindingsResult(): BackendResult<BindingListBackendData> {
    return RemoteDataMapper.ok<BindingListBackendData>('已获取本地绑定关系', {
      bindings: AuthService.listCurrentChildBindings()
    });
  }

  static syncRemoteFamilyBindings(remoteBindings: Object[]): void {
    const current = AuthService.getCurrentAccount();
    if (!current) {
      return;
    }
    for (const rb of remoteBindings) {
      const item = rb as Record<string, string>;
      const existing = AuthService.bindings.find((b: FamilyBinding) => b.id === item['id']);
      if (!existing) {
        const statusStr = item['status'] ? item['status'] : 'active';
        let bindingStatus: FamilyBindingStatus = FamilyBindingStatus.Active;
        if (statusStr === 'pending') {
          bindingStatus = FamilyBindingStatus.Pending;
        } else if (statusStr === 'removed') {
          bindingStatus = FamilyBindingStatus.Removed;
        }
        AuthService.bindings.push({
          id: item['id'] ? item['id'] : '',
          elderlyAccountId: item['elderly_account_id'] ? item['elderly_account_id'] : '',
          childAccountId: item['child_account_id'] ? item['child_account_id'] : '',
          bindingCode: item['binding_code'] ? item['binding_code'] : '',
          status: bindingStatus,
          createdAt: item['created_at'] ? item['created_at'] : '',
          updatedAt: item['updated_at'] ? item['updated_at'] : ''
        } as FamilyBinding);
      }
    }
  }

  static getAccountName(accountId: string): string {
    const account = AuthService.accounts.find((item: Account) => item.id === accountId);
    return account ? account.displayName : '未知账号';
  }

  static getAccountPhone(accountId: string): string {
    const account = AuthService.accounts.find((item: Account) => item.id === accountId);
    return account ? account.phone : '';
  }

  static roleName(role: AccountRole): string {
    if (role === AccountRole.Elderly) {
      return '老人身份';
    }
    if (role === AccountRole.Child) {
      return '子女身份';
    }
    if (role === AccountRole.Admin) {
      return '管理员';
    }
    if (role === AccountRole.CustomerService) {
      return '客服';
    }
    return '未认证';
  }

  private static ensureProfile(account: Account, role: AccountRole): void {
    const now = TimeUtils.formatDate(new Date());
    if (role === AccountRole.Elderly && !AuthService.elderlyProfiles.some((item: ElderlyProfile) => item.accountId === account.id)) {
      AuthService.elderlyProfiles.push({
        id: `elderly-profile-${Date.now()}`,
        accountId: account.id,
        realName: account.displayName,
        age: 0,
        careModeEnabled: false,
        emergencyPhone: '',
        bindingCode: AuthService.createBindingCode(account.phone),
        createdAt: now,
        updatedAt: now
      });
    }
    if (role === AccountRole.Child && !AuthService.childProfiles.some((item: ChildProfile) => item.accountId === account.id)) {
      AuthService.childProfiles.push({
        id: `child-profile-${Date.now()}`,
        accountId: account.id,
        realName: account.displayName,
        relation: '子女',
        notificationEnabled: true,
        createdAt: now,
        updatedAt: now
      });
    }
    if (role === AccountRole.Admin && !AuthService.adminProfiles.some((item: AdminProfile) => item.accountId === account.id)) {
      AuthService.adminProfiles.push({
        id: `admin-profile-${Date.now()}`,
        accountId: account.id,
        realName: account.displayName,
        department: '运营管理部',
        permissions: ['account_manage', 'audit_view', 'system_config'],
        createdAt: now,
        updatedAt: now
      });
    }
    if (role === AccountRole.CustomerService && !AuthService.customerServiceProfiles.some((item: CustomerServiceProfile) => item.accountId === account.id)) {
      AuthService.customerServiceProfiles.push({
        id: `cs-profile-${Date.now()}`,
        accountId: account.id,
        realName: account.displayName,
        serviceGroup: '综合服务组',
        maxConcurrent: 10,
        status: 'active',
        createdAt: now,
        updatedAt: now
      });
    }
  }

  private static createBindingCode(phone: string): string {
    const tail = phone.length >= 4 ? phone.substring(phone.length - 4) : `${Date.now()}`.substring(9);
    return `HS${tail}`;
  }

  static listAllAccounts(): Account[] {
    return AuthService.accounts.filter((item: Account) => item.idUser === 0).map((item: Account) => CloneUtils.cloneAccount(item));
  }

  static listAllAccountsIncludingDeleted(): Account[] {
    return AuthService.accounts.map((item: Account) => CloneUtils.cloneAccount(item));
  }

  static createAccount(phone: string, password: string, displayName: string, role: AccountRole): AuthResult {
    const normalizedPhone = phone.trim();
    const normalizedName = displayName.trim();
    if (normalizedPhone.length === 0 || password.length === 0 || normalizedName.length === 0) {
      return { success: false, message: '请填写手机号、密码和姓名' };
    }
    if (AuthService.accounts.some((item: Account) => item.phone === normalizedPhone)) {
      return { success: false, message: '该手机号已注册' };
    }
    const now = TimeUtils.formatDate(new Date());
    const account: Account = {
      id: 'acct-' + Date.now().toString(),
      idUser: 0,
      phone: normalizedPhone,
      passwordHash: password,
      displayName: normalizedName,
      defaultRole: role,
      status: AccountStatus.Active,
      createdAt: now,
      updatedAt: now
    };
    AuthService.accounts.push(account);
    AuthService.ensureProfile(account, role);
    return {
      success: true,
      message: '账号创建成功',
      account: CloneUtils.cloneAccount(account)
    };
  }

  static updateAccount(accountId: string, phone: string, displayName: string, role: AccountRole, status: AccountStatus): AuthResult {
    const account = AuthService.accounts.find((item: Account) => item.id === accountId);
    if (!account) {
      return { success: false, message: '账号不存在' };
    }
    const normalizedPhone = phone.trim();
    if (normalizedPhone.length > 0 && normalizedPhone !== account.phone) {
      if (AuthService.accounts.some((item: Account) => item.phone === normalizedPhone && item.id !== accountId)) {
        return { success: false, message: '该手机号已被其他账号使用' };
      }
      account.phone = normalizedPhone;
    }
    if (displayName.trim().length > 0) {
      account.displayName = displayName.trim();
    }
    if (role !== account.defaultRole) {
      account.defaultRole = role;
      AuthService.ensureProfile(account, role);
    }
    account.status = status;
    account.updatedAt = TimeUtils.formatDate(new Date());
    return {
      success: true,
      message: '账号更新成功',
      account: CloneUtils.cloneAccount(account)
    };
  }

  static softDeleteAccount(accountId: string): AuthResult {
    const account = AuthService.accounts.find((item: Account) => item.id === accountId);
    if (!account) {
      return { success: false, message: '账号不存在' };
    }
    if (account.defaultRole === AccountRole.Admin) {
      return { success: false, message: '不能删除管理员账号' };
    }
    account.idUser = 1;
    account.status = AccountStatus.Disabled;
    account.updatedAt = TimeUtils.formatDate(new Date());
    return {
      success: true,
      message: '账号已软删除',
      account: CloneUtils.cloneAccount(account)
    };
  }

  static restoreAccount(accountId: string): AuthResult {
    const account = AuthService.accounts.find((item: Account) => item.id === accountId);
    if (!account) {
      return { success: false, message: '账号不存在' };
    }
    account.idUser = 0;
    account.status = AccountStatus.Active;
    account.updatedAt = TimeUtils.formatDate(new Date());
    return {
      success: true,
      message: '账号已恢复',
      account: CloneUtils.cloneAccount(account)
    };
  }

  static updateAccountStatus(accountId: string, status: AccountStatus): AuthResult {
    const account = AuthService.accounts.find((item: Account) => item.id === accountId);
    if (!account) {
      return { success: false, message: '账号不存在' };
    }
    account.status = status;
    account.updatedAt = TimeUtils.formatDate(new Date());
    return {
      success: true,
      message: status === AccountStatus.Active ? '账号已启用' : '账号已停用',
      account: CloneUtils.cloneAccount(account)
    };
  }

  static updateAccountRole(accountId: string, role: AccountRole): AuthResult {
    const account = AuthService.accounts.find((item: Account) => item.id === accountId);
    if (!account) {
      return { success: false, message: '账号不存在' };
    }
    account.defaultRole = role;
    account.updatedAt = TimeUtils.formatDate(new Date());
    AuthService.ensureProfile(account, role);
    return {
      success: true,
      message: '角色已更新',
      account: CloneUtils.cloneAccount(account)
    };
  }

  private static tickets: CustomerTicket[] = [
    {
      id: 'ticket-001',
      csAccountId: '',
      elderlyAccountId: 'acct-elderly-001',
      orderId: '',
      title: '老人咨询订单状态',
      content: '徐叔叔想知道血压计的物流进度',
      status: 'open',
      priority: 'normal',
      createdAt: '2026-07-20 10:00',
      updatedAt: '2026-07-20 10:00'
    },
    {
      id: 'ticket-002',
      csAccountId: '',
      elderlyAccountId: 'acct-elderly-001',
      orderId: '',
      title: '支付失败求助',
      content: '子女帮老人支付的订单显示失败但已扣款',
      status: 'open',
      priority: 'urgent',
      createdAt: '2026-07-20 09:30',
      updatedAt: '2026-07-20 09:30'
    },
    {
      id: 'ticket-003',
      csAccountId: '',
      elderlyAccountId: 'acct-elderly-001',
      orderId: '',
      title: '收货地址修改请求',
      content: '老人不会操作修改地址，需要协助添加新地址',
      status: 'open',
      priority: 'normal',
      createdAt: '2026-07-20 09:00',
      updatedAt: '2026-07-20 09:00'
    }
  ];

  private static cloneTicket(ticket: CustomerTicket): CustomerTicket {
    return {
      id: ticket.id,
      csAccountId: ticket.csAccountId,
      elderlyAccountId: ticket.elderlyAccountId,
      orderId: ticket.orderId,
      title: ticket.title,
      content: ticket.content,
      status: ticket.status,
      priority: ticket.priority,
      userDisplay: ticket.userDisplay,
      createdAt: ticket.createdAt,
      updatedAt: ticket.updatedAt
    };
  }

  static listAllTickets(): CustomerTicket[] {
    return AuthService.tickets.map((item: CustomerTicket) => AuthService.cloneTicket(item));
  }

  static syncRemoteTickets(remoteTickets: CustomerTicket[]): void {
    for (const rt of remoteTickets) {
      const existing = AuthService.tickets.find((item: CustomerTicket) => item.id === rt.id);
      if (existing) {
        if (existing.status === 'resolved' && rt.status !== 'resolved') {
          continue;
        }
        existing.csAccountId = rt.csAccountId;
        existing.elderlyAccountId = rt.elderlyAccountId;
        existing.orderId = rt.orderId;
        existing.title = rt.title;
        existing.content = rt.content;
        existing.status = rt.status;
        existing.priority = rt.priority;
        existing.userDisplay = rt.userDisplay;
        existing.updatedAt = rt.updatedAt;
      } else {
        AuthService.tickets.push(AuthService.cloneTicket(rt));
      }
    }
  }

  static listOpenTickets(): CustomerTicket[] {
    return AuthService.tickets.filter((item: CustomerTicket) => item.status === 'open')
      .map((item: CustomerTicket) => AuthService.cloneTicket(item));
  }

  static assignTicket(ticketId: string, csAccountId: string): CustomerTicket | undefined {
    const ticket = AuthService.tickets.find((item: CustomerTicket) => item.id === ticketId);
    if (!ticket) {
      return undefined;
    }
    ticket.csAccountId = csAccountId;
    ticket.status = 'processing';
    ticket.updatedAt = TimeUtils.formatDate(new Date());
    return AuthService.cloneTicket(ticket);
  }

  static resolveTicket(ticketId: string, resolution: string): CustomerTicket | undefined {
    const ticket = AuthService.tickets.find((item: CustomerTicket) => item.id === ticketId);
    if (!ticket) {
      return undefined;
    }
    ticket.status = 'resolved';
    ticket.content = ticket.content + '\n\n解决结果：' + resolution;
    ticket.updatedAt = TimeUtils.formatDate(new Date());
    return AuthService.cloneTicket(ticket);
  }

  static escalateTicket(ticketId: string): CustomerTicket | undefined {
    const ticket = AuthService.tickets.find((item: CustomerTicket) => item.id === ticketId);
    if (!ticket) {
      return undefined;
    }
    ticket.priority = 'urgent';
    ticket.updatedAt = TimeUtils.formatDate(new Date());
    return AuthService.cloneTicket(ticket);
  }

  static countOpenTickets(): number {
    return AuthService.tickets.filter((item: CustomerTicket) => item.status === 'open').length;
  }

  static countResolvedToday(): number {
    const today = TimeUtils.formatDate(new Date()).substring(0, 10);
    return AuthService.tickets.filter((item: CustomerTicket) =>
      item.status === 'resolved' && item.updatedAt.substring(0, 10) === today
    ).length;
  }

  static addTicket(ticket: CustomerTicket): void {
    AuthService.tickets.unshift(AuthService.cloneTicket(ticket));
  }

  static syncRemoteUsers(users: RemoteAdminUserItem[]): void {
    const now = TimeUtils.formatDate(new Date());
    for (let i = 0; i < users.length; i++) {
      const item = users[i];
      const role = RemoteDataMapper.parseAccountRole(item.default_role ? item.default_role : 'unverified');
      const status = (item.status === 'disabled') ? AccountStatus.Disabled : AccountStatus.Active;
      let existing = AuthService.accounts.find((a: Account) => a.id === item.id);
      if (existing) {
        existing.phone = item.phone;
        existing.displayName = item.display_name ? item.display_name : existing.displayName;
        existing.defaultRole = role;
        existing.status = status;
        existing.idUser = item.id_user !== undefined ? item.id_user : existing.idUser;
        existing.updatedAt = item.updated_at ? item.updated_at : now;
      } else {
        const newAccount: Account = {
          id: item.id,
          idUser: item.id_user !== undefined ? item.id_user : 0,
          phone: item.phone,
          passwordHash: 'remote-managed',
          displayName: item.display_name ? item.display_name : '',
          defaultRole: role,
          status: status,
          createdAt: item.created_at ? item.created_at : now,
          updatedAt: item.updated_at ? item.updated_at : now
        };
        AuthService.accounts.push(newAccount);
        AuthService.ensureProfile(newAccount, role);
      }
    }
  }


}
