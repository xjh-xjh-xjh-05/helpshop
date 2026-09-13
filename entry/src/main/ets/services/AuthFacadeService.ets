import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { Account, AccountRole, AccountStatus, AuthResult, BindingResult, CustomerTicket } from '../models/AuthModels';
import { AuthBackendData, BackendErrorCode, BackendResult, BindingListBackendData } from '../models/BackendModels';
import { RemoteAuthResponse, RemoteBindResponse, RemoteHuaweiLoginResponse, RemoteAdminAccountCrudResponse, RemoteAdminUserItem } from '../models/RemoteModels';
import { AuthService } from './AuthService';
import { AuditLogService } from './AuditLogService';
import { HuaweiAccountService } from './HuaweiAccountService';
import { RemoteBackendClient, RemoteBackendResult } from './RemoteBackendClient';
import { RemoteDataMapper } from './RemoteDataMapper';
import { TimeUtils } from '../utils/TimeUtils';

export class AuthFacadeService {
  static isLoggedIn(): boolean {
    return AuthService.isLoggedIn();
  }

  static getCurrentAccount(): Account | undefined {
    return AuthService.getCurrentAccount();
  }

  static getCurrentRole(): AccountRole {
    return AuthService.getCurrentRole();
  }

  static canEnterShopping(): boolean {
    return AuthService.canEnterShopping();
  }

  static login(phone: string, password: string): BackendResult<AuthBackendData> {
    const result: AuthResult = AuthService.login(phone, password);
    if (!result.success) {
      return RemoteDataMapper.fail<AuthBackendData>(BackendErrorCode.Unauthorized, result.message);
    }
    AuditLogService.record('auth.login', '账号 ' + phone.trim() + ' 登录成功');
    return RemoteDataMapper.ok<AuthBackendData>(result.message, {
      account: result.account,
      role: AuthService.getCurrentRole(),
      canShop: AuthService.canEnterShopping()
    });
  }

  static register(phone: string, password: string, displayName: string): BackendResult<AuthBackendData> {
    const result: AuthResult = AuthService.register(phone, password, displayName);
    if (!result.success) {
      return RemoteDataMapper.fail<AuthBackendData>(BackendErrorCode.ValidationError, result.message);
    }
    AuditLogService.record('auth.register', '账号 ' + phone.trim() + ' 注册成功');
    return RemoteDataMapper.ok<AuthBackendData>(result.message, {
      account: result.account,
      role: AuthService.getCurrentRole(),
      canShop: AuthService.canEnterShopping()
    });
  }

  static certifyCurrentAccount(role: AccountRole): BackendResult<AuthBackendData> {
    const result: AuthResult = AuthService.certifyCurrentAccount(role);
    if (!result.success) {
      return RemoteDataMapper.fail<AuthBackendData>(BackendErrorCode.Forbidden, result.message);
    }
    AuditLogService.record('auth.certify', '账号认证为 ' + AuthService.roleName(role));
    return RemoteDataMapper.ok<AuthBackendData>(result.message, {
      account: result.account,
      role: AuthService.getCurrentRole(),
      canShop: AuthService.canEnterShopping()
    });
  }

  static logout(): void {
    hilog.info(0x0001, 'AuthFacade', 'logout called, isLoggedIn=' + AuthService.isLoggedIn().toString() + ' role=' + AuthService.getCurrentRole().toString());
    AuthService.logout();
    RemoteBackendClient.setAccessToken('');
    hilog.info(0x0001, 'AuthFacade', 'logout done, isLoggedIn=' + AuthService.isLoggedIn().toString() + ' token cleared');
  }

  static bindCurrentChildToElderly(keyword: string): BackendResult<BindingListBackendData> {
    const result: BindingResult = AuthService.bindCurrentChildToElderly(keyword);
    if (!result.success) {
      return RemoteDataMapper.fail<BindingListBackendData>(BackendErrorCode.ValidationError, result.message);
    }
    AuditLogService.record('family.bind', '子女绑定老人账号：' + keyword.trim());
    return RemoteDataMapper.ok<BindingListBackendData>(result.message, {
      bindings: AuthService.listCurrentChildBindings()
    });
  }

  static listCurrentChildBindings(): BackendResult<BindingListBackendData> {
    return RemoteDataMapper.ok<BindingListBackendData>('已获取绑定关系', {
      bindings: AuthService.listCurrentChildBindings()
    });
  }

  static getAccountName(accountId: string): string {
    return AuthService.getAccountName(accountId);
  }

  static getAccountPhone(accountId: string): string {
    return AuthService.getAccountPhone(accountId);
  }

  static roleName(role: AccountRole): string {
    return AuthService.roleName(role);
  }

  static getCurrentAuth(): BackendResult<AuthBackendData> {
    return RemoteDataMapper.ok<AuthBackendData>('已获取当前账号', {
      account: AuthService.getCurrentAccount(),
      role: AuthService.getCurrentRole(),
      canShop: AuthService.canEnterShopping()
    });
  }

  static async loginRemote(phone: string, password: string): Promise<BackendResult<AuthBackendData>> {
    const remoteResult: RemoteBackendResult = await RemoteBackendClient.login(phone.trim(), password);
    if (!remoteResult.success) {
      hilog.warn(0x0001, 'AuthFacade', 'loginRemote failed statusCode=' + remoteResult.statusCode.toString() + ' msg=' + remoteResult.message + ', fallback to local login');
      const localResult: AuthResult = AuthService.login(phone.trim(), password);
      if (!localResult.success) {
        return RemoteDataMapper.fail<AuthBackendData>(BackendErrorCode.Unauthorized, remoteResult.statusCode === 0 ? localResult.message : remoteResult.message);
      }
      AuditLogService.record('auth.loginRemote', '账号 ' + phone.trim() + ' 远程登录不可用，回退本地登录成功');
      return RemoteDataMapper.ok<AuthBackendData>('登录成功（离线模式）', {
        account: AuthService.getCurrentAccount(),
        role: AuthService.getCurrentRole(),
        canShop: AuthService.canEnterShopping()
      });
    }
    const parsed: RemoteAuthResponse | undefined = AuthFacadeService.parseAuthResponse(remoteResult.body);
    if (!parsed || !parsed.account) {
      return RemoteDataMapper.fail<AuthBackendData>(BackendErrorCode.InternalError, '登录返回数据异常');
    }
    const role: AccountRole = RemoteDataMapper.parseAccountRole(parsed.account.default_role ? parsed.account.default_role : 'unverified');
    AuthService.syncRemoteAccount(
      parsed.account.id,
      parsed.account.phone,
      parsed.account.display_name ? parsed.account.display_name : '',
      role,
      parsed.account.huawei_open_id,
      parsed.account.huawei_union_id
    );
    if (parsed.access_token && parsed.access_token.length > 0) {
      RemoteBackendClient.setAccessToken(parsed.access_token);
    }
    if (role === AccountRole.Child) {
      try {
        await AuthFacadeService.listFamilyBindingsRemote();
      } catch (error) {
        hilog.warn(0x0001, 'AuthFacade', 'loginRemote: failed to sync family bindings');
      }
    }
    AuditLogService.record('auth.loginRemote', '账号 ' + phone.trim() + ' 远程登录成功');
    return RemoteDataMapper.ok<AuthBackendData>('登录成功', {
      account: AuthService.getCurrentAccount(),
      role: AuthService.getCurrentRole(),
      canShop: AuthService.canEnterShopping()
    });
  }

  static async registerRemote(phone: string, password: string, displayName: string): Promise<BackendResult<AuthBackendData>> {
    const remoteResult: RemoteBackendResult =
      await RemoteBackendClient.register(phone.trim(), password, displayName.trim(), 'unverified');
    if (!remoteResult.success) {
      hilog.warn(0x0001, 'AuthFacade', 'registerRemote failed statusCode=' + remoteResult.statusCode.toString() + ' msg=' + remoteResult.message + ', fallback to local register');
      const localResult: AuthResult = AuthService.register(phone.trim(), password, displayName.trim());
      if (!localResult.success) {
        return RemoteDataMapper.fail<AuthBackendData>(BackendErrorCode.ValidationError, remoteResult.statusCode === 0 ? localResult.message : remoteResult.message);
      }
      AuditLogService.record('auth.registerRemote', '账号 ' + phone.trim() + ' 远程注册不可用，回退本地注册成功');
      return RemoteDataMapper.ok<AuthBackendData>('注册成功，请完成身份认证（离线模式）', {
        account: AuthService.getCurrentAccount(),
        role: AuthService.getCurrentRole(),
        canShop: AuthService.canEnterShopping()
      });
    }
    const parsed: RemoteAuthResponse | undefined = AuthFacadeService.parseAuthResponse(remoteResult.body);
    if (!parsed || !parsed.account) {
      return RemoteDataMapper.fail<AuthBackendData>(BackendErrorCode.InternalError, '注册返回数据异常');
    }
    const role: AccountRole = RemoteDataMapper.parseAccountRole(parsed.account.default_role ? parsed.account.default_role : 'unverified');
    AuthService.syncRemoteAccount(
      parsed.account.id,
      parsed.account.phone,
      parsed.account.display_name ? parsed.account.display_name : '',
      role,
      parsed.account.huawei_open_id,
      parsed.account.huawei_union_id
    );
    if (parsed.access_token && parsed.access_token.length > 0) {
      RemoteBackendClient.setAccessToken(parsed.access_token);
    }
    AuditLogService.record('auth.registerRemote', '账号 ' + phone.trim() + ' 远程注册成功');
    return RemoteDataMapper.ok<AuthBackendData>('注册成功，请完成身份认证', {
      account: AuthService.getCurrentAccount(),
      role: AuthService.getCurrentRole(),
      canShop: AuthService.canEnterShopping()
    });
  }

  static async certifyRoleRemote(role: AccountRole): Promise<BackendResult<AuthBackendData>> {
    const remoteRole: string = AuthFacadeService.remoteRoleName(role);
    hilog.info(0x0001, 'AuthFacade', 'certifyRoleRemote: role=' + remoteRole);
    const remoteResult: RemoteBackendResult = await RemoteBackendClient.certifyRole(remoteRole);
    hilog.info(0x0001, 'AuthFacade', 'certifyRoleRemote: success=' + remoteResult.success.toString() + ' statusCode=' + remoteResult.statusCode.toString());
    if (!remoteResult.success) {
      if (remoteResult.statusCode === 0) {
        hilog.warn(0x0001, 'AuthFacade', 'certifyRoleRemote remote unreachable, fallback to local certify');
        const localResult: BackendResult<AuthBackendData> = AuthFacadeService.certifyCurrentAccount(role);
        if (role === AccountRole.Child) {
          try {
            await AuthFacadeService.listFamilyBindingsRemote();
            hilog.info(0x0001, 'AuthFacade', 'certifyRoleRemote fallback: synced family bindings, canShop=' + AuthService.canEnterShopping().toString());
          } catch (error) {
            hilog.warn(0x0001, 'AuthFacade', 'certifyRoleRemote fallback: failed to sync family bindings');
          }
        }
        AuditLogService.record('auth.certifyRoleRemote', '远程认证不可用，回退本地认证');
        return localResult;
      }
      return RemoteDataMapper.fail<AuthBackendData>(BackendErrorCode.Forbidden, '远程身份认证失败：' + remoteResult.message);
    }
    const parsed: RemoteAuthResponse | undefined = AuthFacadeService.parseAuthResponse(remoteResult.body);
    if (parsed && parsed.account) {
      const parsedRole: AccountRole = RemoteDataMapper.parseAccountRole(parsed.account.default_role ? parsed.account.default_role : 'unverified');
      AuthService.syncRemoteAccount(
        parsed.account.id,
        parsed.account.phone,
        parsed.account.display_name ? parsed.account.display_name : '',
        parsedRole,
        parsed.account.huawei_open_id,
        parsed.account.huawei_union_id
      );
      if (parsed.access_token && parsed.access_token.length > 0) {
        RemoteBackendClient.setAccessToken(parsed.access_token);
      }
      if (role === AccountRole.Child) {
        try {
          await AuthFacadeService.listFamilyBindingsRemote();
          hilog.info(0x0001, 'AuthFacade', 'certifyRoleRemote: synced family bindings, canShop=' + AuthService.canEnterShopping().toString());
        } catch (error) {
          hilog.warn(0x0001, 'AuthFacade', 'certifyRoleRemote: failed to sync family bindings');
        }
      }
    } else {
      hilog.warn(0x0001, 'AuthFacade', 'certifyRoleRemote: parsed.account is null');
    }
    const localResult: BackendResult<AuthBackendData> = AuthFacadeService.certifyCurrentAccount(role);
    hilog.info(0x0001, 'AuthFacade', 'certifyRoleRemote: final canShop=' + AuthService.canEnterShopping().toString());
    return localResult;
  }

  static async bindFamilyRemote(keyword: string): Promise<BackendResult<BindingListBackendData>> {
    const remoteResult: RemoteBackendResult = await RemoteBackendClient.bindFamily(keyword.trim());
    if (!remoteResult.success) {
      return RemoteDataMapper.fail<BindingListBackendData>(BackendErrorCode.ValidationError, '远程绑定失败：' + remoteResult.message);
    }
    const parsed: RemoteBindResponse | undefined = AuthFacadeService.parseBindResponse(remoteResult.body);
    if (parsed && parsed.binding && parsed.elderly) {
      AuthService.syncRemoteFamilyBinding(
        parsed.binding.id,
        parsed.binding.elderly_account_id,
        parsed.elderly.phone,
        parsed.elderly.display_name,
        parsed.binding.binding_code
      );
      const message: string = parsed.message ? parsed.message : '绑定成功';
      AuditLogService.record('family.bindRemote', '子女远程绑定老人账号：' + keyword.trim());
      return RemoteDataMapper.ok<BindingListBackendData>(message, {
        bindings: AuthService.listCurrentChildBindings()
      });
    }
    return AuthFacadeService.bindCurrentChildToElderly(keyword);
  }

  static async listFamilyBindingsRemote(): Promise<BackendResult<BindingListBackendData>> {
    const remoteResult: RemoteBackendResult = await RemoteBackendClient.listFamilyBindings();
    if (!remoteResult.success) {
      return AuthService.listCurrentChildBindingsResult();
    }
    try {
      const parsed: Record<string, Object> = JSON.parse(remoteResult.body) as Record<string, Object>;
      const bindings = parsed['bindings'];
      if (bindings && Array.isArray(bindings)) {
        AuthService.syncRemoteFamilyBindings(bindings);
        return RemoteDataMapper.ok<BindingListBackendData>('已从远程获取绑定关系', {
          bindings: AuthService.listCurrentChildBindings()
        });
      }
    } catch (error) {
    }
    return AuthService.listCurrentChildBindingsResult();
  }

  static async loginWithHuaweiIDRemote(context: common.UIAbilityContext): Promise<BackendResult<AuthBackendData>> {
    const fullResult = await HuaweiAccountService.loginAndGetPhone(context);
    if (!fullResult.success || !fullResult.loginResult) {
      return RemoteDataMapper.fail<AuthBackendData>(BackendErrorCode.Unauthorized, fullResult.message);
    }
    const phoneAuthCode: string = fullResult.phoneAuthResult ? fullResult.phoneAuthResult.phoneAuthorizationCode : '';
    const remoteResult: RemoteBackendResult = await RemoteBackendClient.huaweiLogin(
      fullResult.loginResult.openID,
      fullResult.loginResult.unionID,
      fullResult.loginResult.authorizationCode,
      fullResult.loginResult.idToken,
      phoneAuthCode
    );
    const storedAvatarUri: string = AppStorage.get<string>('avatarUri') ?? '';
    const storedNickName: string = AppStorage.get<string>('nickName') ?? '';
    if (!remoteResult.success) {
      if (remoteResult.statusCode === 0) {
        hilog.warn(0x0001, 'AuthFacade', 'huaweiLogin remote unreachable, fallback to local login');
        const localRole: AccountRole = AuthService.findRoleByHuaweiOpenId(fullResult.loginResult.openID);
        AuthService.syncRemoteAccount(
          'hw-' + fullResult.loginResult.openID,
          '',
          storedNickName.length > 0 ? storedNickName : '\u534e\u4e3a\u7528\u6237',
          localRole,
          fullResult.loginResult.openID,
          fullResult.loginResult.unionID,
          storedAvatarUri,
          storedNickName
        );
        if (localRole === AccountRole.Child) {
          try {
            await AuthFacadeService.listFamilyBindingsRemote();
            hilog.info(0x0001, 'AuthFacade', 'huaweiLogin fallback: synced family bindings, canShop=' + AuthService.canEnterShopping().toString());
          } catch (error) {
            hilog.warn(0x0001, 'AuthFacade', 'huaweiLogin fallback: failed to sync family bindings');
          }
        }
        const phoneMissing: boolean = fullResult.phoneDenied;
        if (phoneMissing) {
          AuditLogService.record('auth.huaweiLogin', '\u534e\u4e3a\u8d26\u53f7\u767b\u5f55\u6210\u529f-\u79bb\u7ebf\u6a21\u5f0f\uff08\u7f3a\u5c11\u624b\u673a\u53f7\uff09 openID=' + fullResult.loginResult.openID);
          return RemoteDataMapper.ok<AuthBackendData>('\u534e\u4e3a\u8d26\u53f7\u767b\u5f55\u6210\u529f\uff0c\u8bf7\u5173\u8054\u624b\u673a\u53f7', {
            account: AuthService.getCurrentAccount(),
            role: AuthService.getCurrentRole(),
            canShop: AuthService.canEnterShopping()
          });
        }
        AuditLogService.record('auth.huaweiLogin', '\u534e\u4e3a\u8d26\u53f7\u767b\u5f55\u6210\u529f-\u79bb\u7ebf\u6a21\u5f0f openID=' + fullResult.loginResult.openID + ' role=' + localRole.toString());
        return RemoteDataMapper.ok<AuthBackendData>('\u534e\u4e3a\u8d26\u53f7\u767b\u5f55\u6210\u529f', {
          account: AuthService.getCurrentAccount(),
          role: AuthService.getCurrentRole(),
          canShop: AuthService.canEnterShopping()
        });
      }
      return RemoteDataMapper.fail<AuthBackendData>(
        BackendErrorCode.Unauthorized,
        '\u534e\u4e3a\u8d26\u53f7\u6388\u6743\u5df2\u6210\u529f\uff0c\u4f46\u5e94\u7528\u540e\u7aef\u767b\u5f55\u5931\u8d25\uff1a' + remoteResult.message
      );
    }
    const parsed: RemoteHuaweiLoginResponse | undefined = AuthFacadeService.parseHuaweiLoginResponse(remoteResult.body);
    if (!parsed || !parsed.account) {
      return RemoteDataMapper.fail<AuthBackendData>(BackendErrorCode.InternalError, '\u534e\u4e3a\u8d26\u53f7\u767b\u5f55\u8fd4\u56de\u6570\u636e\u5f02\u5e38');
    }
    const role: AccountRole = RemoteDataMapper.parseAccountRole(parsed.account.default_role ? parsed.account.default_role : 'unverified');
    const displayName: string = storedNickName.length > 0 ? storedNickName :
      (parsed.account.display_name ? parsed.account.display_name : '');
    AuthService.syncRemoteAccount(
      parsed.account.id,
      parsed.account.phone ? parsed.account.phone : '',
      displayName,
      role,
      parsed.account.huawei_open_id,
      parsed.account.huawei_union_id,
      storedAvatarUri,
      storedNickName
    );
    if (parsed.access_token && parsed.access_token.length > 0) {
      RemoteBackendClient.setAccessToken(parsed.access_token);
    }
    if (role === AccountRole.Child) {
      try {
        await AuthFacadeService.listFamilyBindingsRemote();
        hilog.info(0x0001, 'AuthFacade', 'huaweiLogin: synced family bindings, canShop=' + AuthService.canEnterShopping().toString());
      } catch (error) {
        hilog.warn(0x0001, 'AuthFacade', 'huaweiLogin: failed to sync family bindings');
      }
    }
    const phoneMissing: boolean = parsed.phone_missing ? parsed.phone_missing : false;
    if (phoneMissing) {
      AuditLogService.record('auth.huaweiLogin', '华为账号登录成功（缺少手机号） openID=' + fullResult.loginResult.openID);
      return RemoteDataMapper.ok<AuthBackendData>('华为账号登录成功，请关联手机号', {
        account: AuthService.getCurrentAccount(),
        role: AuthService.getCurrentRole(),
        canShop: AuthService.canEnterShopping()
      });
    }
    AuditLogService.record('auth.huaweiLogin', '华为账号登录成功 openID=' + fullResult.loginResult.openID);
    return RemoteDataMapper.ok<AuthBackendData>('华为账号登录成功', {
      account: AuthService.getCurrentAccount(),
      role: AuthService.getCurrentRole(),
      canShop: AuthService.canEnterShopping()
    });
  }

  static async loginWithHuaweiIDByCredential(openID: string, unionID: string, authCode: string, idToken: string): Promise<BackendResult<AuthBackendData>> {
    const remoteResult: RemoteBackendResult = await RemoteBackendClient.huaweiLogin(
      openID, unionID, authCode, idToken, ''
    );
    const storedAvatarUri: string = AppStorage.get<string>('avatarUri') ?? '';
    const storedNickName: string = AppStorage.get<string>('nickName') ?? '';
    if (!remoteResult.success) {
      if (remoteResult.statusCode === 0) {
        hilog.warn(0x0001, 'AuthFacade', 'huaweiLoginByCredential remote unreachable, fallback to local');
        const localRole: AccountRole = AuthService.findRoleByHuaweiOpenId(openID);
        AuthService.syncRemoteAccount(
          'hw-' + openID,
          '',
          storedNickName.length > 0 ? storedNickName : '\u534e\u4e3a\u7528\u6237',
          localRole,
          openID,
          unionID,
          storedAvatarUri,
          storedNickName
        );
        if (localRole === AccountRole.Child) {
          try {
            await AuthFacadeService.listFamilyBindingsRemote();
            hilog.info(0x0001, 'AuthFacade', 'huaweiLoginByCredential fallback: synced family bindings, canShop=' + AuthService.canEnterShopping().toString());
          } catch (error) {
            hilog.warn(0x0001, 'AuthFacade', 'huaweiLoginByCredential fallback: failed to sync family bindings');
          }
        }
        AuditLogService.record('auth.huaweiLogin', '\u534e\u4e3a\u8d26\u53f7\u767b\u5f55\u6210\u529f-\u79bb\u7ebf\u6a21\u5f0f openID=' + openID + ' role=' + localRole.toString());
        return RemoteDataMapper.ok<AuthBackendData>('\u534e\u4e3a\u8d26\u53f7\u767b\u5f55\u6210\u529f\uff0c\u8bf7\u5173\u8054\u624b\u673a\u53f7', {
          account: AuthService.getCurrentAccount(),
          role: AuthService.getCurrentRole(),
          canShop: AuthService.canEnterShopping()
        });
      }
      return RemoteDataMapper.fail<AuthBackendData>(
        BackendErrorCode.Unauthorized,
        '\u534e\u4e3a\u8d26\u53f7\u6388\u6743\u5df2\u6210\u529f\uff0c\u4f46\u5e94\u7528\u540e\u7aef\u767b\u5f55\u5931\u8d25\uff1a' + remoteResult.message
      );
    }
    const parsed: RemoteHuaweiLoginResponse | undefined = AuthFacadeService.parseHuaweiLoginResponse(remoteResult.body);
    if (!parsed || !parsed.account) {
      return RemoteDataMapper.fail<AuthBackendData>(BackendErrorCode.InternalError, '\u534e\u4e3a\u8d26\u53f7\u767b\u5f55\u8fd4\u56de\u6570\u636e\u5f02\u5e38');
    }
    const role: AccountRole = RemoteDataMapper.parseAccountRole(parsed.account.default_role ? parsed.account.default_role : 'unverified');
    const displayName: string = storedNickName.length > 0 ? storedNickName :
      (parsed.account.display_name ? parsed.account.display_name : '');
    AuthService.syncRemoteAccount(
      parsed.account.id,
      parsed.account.phone ? parsed.account.phone : '',
      displayName,
      role,
      parsed.account.huawei_open_id,
      parsed.account.huawei_union_id,
      storedAvatarUri,
      storedNickName
    );
    if (parsed.access_token && parsed.access_token.length > 0) {
      RemoteBackendClient.setAccessToken(parsed.access_token);
    }
    if (role === AccountRole.Child) {
      try {
        await AuthFacadeService.listFamilyBindingsRemote();
        hilog.info(0x0001, 'AuthFacade', 'huaweiLoginByCredential: synced family bindings, canShop=' + AuthService.canEnterShopping().toString());
      } catch (error) {
        hilog.warn(0x0001, 'AuthFacade', 'huaweiLoginByCredential: failed to sync family bindings');
      }
    }
    const phoneMissing: boolean = parsed.phone_missing ? parsed.phone_missing : false;
    if (phoneMissing) {
      AuditLogService.record('auth.huaweiLogin', '华为账号登录成功（缺少手机号） openID=' + openID);
      return RemoteDataMapper.ok<AuthBackendData>('华为账号登录成功，请关联手机号', {
        account: AuthService.getCurrentAccount(),
        role: AuthService.getCurrentRole(),
        canShop: AuthService.canEnterShopping()
      });
    }
    AuditLogService.record('auth.huaweiLogin', '华为账号登录成功 openID=' + openID);
    return RemoteDataMapper.ok<AuthBackendData>('华为账号登录成功', {
      account: AuthService.getCurrentAccount(),
      role: AuthService.getCurrentRole(),
      canShop: AuthService.canEnterShopping()
    });
  }

  static async linkPhoneRemote(phone: string): Promise<BackendResult<AuthBackendData>> {
    const remoteResult: RemoteBackendResult = await RemoteBackendClient.linkPhone(phone.trim());
    if (!remoteResult.success) {
      if (remoteResult.statusCode === 0) {
        hilog.warn(0x0001, 'AuthFacade', 'linkPhoneRemote remote unreachable, fallback to local');
        const account: Account | undefined = AuthService.getCurrentAccount();
        if (account) {
          AuthService.syncRemoteAccount(
            account.id,
            phone.trim(),
            account.displayName,
            AuthService.getCurrentRole(),
            account.huaweiOpenId,
            account.huaweiUnionId,
            AppStorage.get<string>('avatarUri') ?? '',
            AppStorage.get<string>('nickName') ?? ''
          );
        }
        AuditLogService.record('auth.linkPhone', '手机号关联成功（离线模式） ' + phone.trim());
        return RemoteDataMapper.ok<AuthBackendData>('手机号关联成功（离线模式）', {
          account: AuthService.getCurrentAccount(),
          role: AuthService.getCurrentRole(),
          canShop: AuthService.canEnterShopping()
        });
      }
      return RemoteDataMapper.fail<AuthBackendData>(BackendErrorCode.ValidationError, remoteResult.message);
    }
    const parsed: RemoteHuaweiLoginResponse | undefined = AuthFacadeService.parseHuaweiLoginResponse(remoteResult.body);
    if (parsed && parsed.account) {
    const role: AccountRole = RemoteDataMapper.parseAccountRole(parsed.account.default_role ? parsed.account.default_role : 'unverified');
    hilog.info(0x0001, 'AuthFacade', 'loginRemote: parsedRole=' + role.toString());
    AuthService.syncRemoteAccount(
        parsed.account.id,
        parsed.account.phone,
        parsed.account.display_name ? parsed.account.display_name : '',
        role,
        parsed.account.huawei_open_id,
        parsed.account.huawei_union_id
      );
    }
    AuditLogService.record('auth.linkPhone', '手机号关联成功 ' + phone.trim());
    return RemoteDataMapper.ok<AuthBackendData>('手机号关联成功', {
      account: AuthService.getCurrentAccount(),
      role: AuthService.getCurrentRole(),
      canShop: AuthService.canEnterShopping()
    });
  }

  private static parseAuthResponse(body: string): RemoteAuthResponse | undefined {
    try {
      return JSON.parse(body);
    } catch (error) {
      return undefined;
    }
  }

  private static parseBindResponse(body: string): RemoteBindResponse | undefined {
    try {
      return JSON.parse(body);
    } catch (error) {
      return undefined;
    }
  }

  private static parseHuaweiLoginResponse(body: string): RemoteHuaweiLoginResponse | undefined {
    try {
      return JSON.parse(body);
    } catch (error) {
      return undefined;
    }
  }

  private static remoteRoleName(role: AccountRole): string {
    if (role === AccountRole.Elderly) {
      return 'elderly';
    }
    if (role === AccountRole.Child) {
      return 'child';
    }
    if (role === AccountRole.Admin) {
      return 'admin';
    }
    if (role === AccountRole.CustomerService) {
      return 'customer_service';
    }
    return 'unverified';
  }

  static listAllAccounts(): Account[] {
    return AuthService.listAllAccounts();
  }

  static updateAccountStatus(accountId: string, status: AccountStatus): BackendResult<AuthBackendData> {
    const result: AuthResult = AuthService.updateAccountStatus(accountId, status);
    if (!result.success) {
      return RemoteDataMapper.fail<AuthBackendData>(BackendErrorCode.Forbidden, result.message);
    }
    AuditLogService.record('admin.account_status', '账号 ' + accountId + ' 状态更新为 ' + (status === AccountStatus.Active ? '启用' : '停用'));
    return RemoteDataMapper.ok<AuthBackendData>(result.message, {
      account: result.account,
      role: AuthService.getCurrentRole(),
      canShop: AuthService.canEnterShopping()
    });
  }

  static updateAccountRole(accountId: string, role: AccountRole): BackendResult<AuthBackendData> {
    const result: AuthResult = AuthService.updateAccountRole(accountId, role);
    if (!result.success) {
      return RemoteDataMapper.fail<AuthBackendData>(BackendErrorCode.Forbidden, result.message);
    }
    AuditLogService.record('admin.account_role', '账号 ' + accountId + ' 角色更新为 ' + AuthService.roleName(role));
    return RemoteDataMapper.ok<AuthBackendData>(result.message, {
      account: result.account,
      role: AuthService.getCurrentRole(),
      canShop: AuthService.canEnterShopping()
    });
  }

  static listAllTickets(): CustomerTicket[] {
    return AuthService.listAllTickets();
  }

  static listOpenTickets(): CustomerTicket[] {
    return AuthService.listOpenTickets();
  }

  static assignTicket(ticketId: string, csAccountId: string): CustomerTicket | undefined {
    const ticket = AuthService.assignTicket(ticketId, csAccountId);
    if (ticket) {
      AuditLogService.record('cs.ticket_assign', '工单 ' + ticketId + ' 已接单');
    }
    return ticket;
  }

  static resolveTicket(ticketId: string, resolution: string): CustomerTicket | undefined {
    const ticket = AuthService.resolveTicket(ticketId, resolution);
    if (ticket) {
      AuditLogService.record('cs.ticket_resolve', '工单 ' + ticketId + ' 已解决');
    }
    return ticket;
  }

  static escalateTicket(ticketId: string): CustomerTicket | undefined {
    const ticket = AuthService.escalateTicket(ticketId);
    if (ticket) {
      AuditLogService.record('cs.ticket_escalate', '工单 ' + ticketId + ' 已升级');
    }
    return ticket;
  }

  static countOpenTickets(): number {
    return AuthService.countOpenTickets();
  }

  static countResolvedToday(): number {
    return AuthService.countResolvedToday();
  }

  static createAccount(phone: string, password: string, displayName: string, role: AccountRole): BackendResult<AuthBackendData> {
    const result: AuthResult = AuthService.createAccount(phone, password, displayName, role);
    if (!result.success) {
      return RemoteDataMapper.fail<AuthBackendData>(BackendErrorCode.ValidationError, result.message);
    }
    AuditLogService.record('admin.account_create', '创建账号 ' + phone.trim() + ' 角色 ' + AuthService.roleName(role));
    return RemoteDataMapper.ok<AuthBackendData>(result.message, {
      account: result.account,
      role: AuthService.getCurrentRole(),
      canShop: AuthService.canEnterShopping()
    });
  }

  static updateAccount(accountId: string, phone: string, displayName: string, role: AccountRole, status: AccountStatus): BackendResult<AuthBackendData> {
    const result: AuthResult = AuthService.updateAccount(accountId, phone, displayName, role, status);
    if (!result.success) {
      return RemoteDataMapper.fail<AuthBackendData>(BackendErrorCode.ValidationError, result.message);
    }
    AuditLogService.record('admin.account_update', '更新账号 ' + accountId);
    return RemoteDataMapper.ok<AuthBackendData>(result.message, {
      account: result.account,
      role: AuthService.getCurrentRole(),
      canShop: AuthService.canEnterShopping()
    });
  }

  static softDeleteAccount(accountId: string): BackendResult<AuthBackendData> {
    const result: AuthResult = AuthService.softDeleteAccount(accountId);
    if (!result.success) {
      return RemoteDataMapper.fail<AuthBackendData>(BackendErrorCode.Forbidden, result.message);
    }
    AuditLogService.record('admin.account_soft_delete', '软删除账号 ' + accountId);
    return RemoteDataMapper.ok<AuthBackendData>(result.message, {
      account: result.account,
      role: AuthService.getCurrentRole(),
      canShop: AuthService.canEnterShopping()
    });
  }

  static restoreAccount(accountId: string): BackendResult<AuthBackendData> {
    const result: AuthResult = AuthService.restoreAccount(accountId);
    if (!result.success) {
      return RemoteDataMapper.fail<AuthBackendData>(BackendErrorCode.Forbidden, result.message);
    }
    AuditLogService.record('admin.account_restore', '恢复账号 ' + accountId);
    return RemoteDataMapper.ok<AuthBackendData>(result.message, {
      account: result.account,
      role: AuthService.getCurrentRole(),
      canShop: AuthService.canEnterShopping()
    });
  }

  static listDeletedAccounts(): Account[] {
    return AuthService.listAllAccountsIncludingDeleted().filter((item: Account) => item.idUser === 1);
  }

  static async listAdminUsersRemote(): Promise<BackendResult<AuthBackendData>> {
    const remoteResult: RemoteBackendResult = await RemoteBackendClient.listAdminUsers();
    if (!remoteResult.success) {
      return RemoteDataMapper.ok<AuthBackendData>('本地用户列表', {
        account: AuthService.getCurrentAccount(),
        role: AuthService.getCurrentRole(),
        canShop: AuthService.canEnterShopping()
      });
    }
    const parsed = RemoteDataMapper.parseAdminUserList(remoteResult.body);
    if (!parsed || !parsed.users) {
      return RemoteDataMapper.ok<AuthBackendData>('本地用户列表（远程数据异常）', {
        account: AuthService.getCurrentAccount(),
        role: AuthService.getCurrentRole(),
        canShop: AuthService.canEnterShopping()
      });
    }
    return RemoteDataMapper.ok<AuthBackendData>('已从远程获取用户列表', {
      account: AuthService.getCurrentAccount(),
      role: AuthService.getCurrentRole(),
      canShop: AuthService.canEnterShopping()
    });
  }

  static async listAdminAccountsRemote(): Promise<BackendResult<AuthBackendData>> {
    const remoteResult: RemoteBackendResult = await RemoteBackendClient.listAdminAccounts();
    if (!remoteResult.success) {
      return RemoteDataMapper.ok<AuthBackendData>('本地账号列表', {
        account: AuthService.getCurrentAccount(),
        role: AuthService.getCurrentRole(),
        canShop: AuthService.canEnterShopping()
      });
    }
    const parsed = RemoteDataMapper.parseAdminUserList(remoteResult.body);
    if (!parsed || !parsed.users) {
      return RemoteDataMapper.ok<AuthBackendData>('本地账号列表（远程数据异常）', {
        account: AuthService.getCurrentAccount(),
        role: AuthService.getCurrentRole(),
        canShop: AuthService.canEnterShopping()
      });
    }
    return RemoteDataMapper.ok<AuthBackendData>('已从远程获取账号列表', {
      account: AuthService.getCurrentAccount(),
      role: AuthService.getCurrentRole(),
      canShop: AuthService.canEnterShopping()
    });
  }

  static async createAccountRemote(phone: string, password: string, displayName: string, role: AccountRole): Promise<BackendResult<AuthBackendData>> {
    const remoteRole: string = AuthFacadeService.remoteRoleName(role);
    const remoteResult: RemoteBackendResult = await RemoteBackendClient.adminCreateAccount(phone, password, displayName, remoteRole);
    if (!remoteResult.success) {
      return AuthFacadeService.createAccount(phone, password, displayName, role);
    }
    const parsed: RemoteAdminAccountCrudResponse | undefined = RemoteDataMapper.parseAdminAccountCrud(remoteResult.body);
    if (!parsed || !parsed.account) {
      return AuthFacadeService.createAccount(phone, password, displayName, role);
    }
    const parsedRole: AccountRole = RemoteDataMapper.parseAccountRole(parsed.account.default_role ? parsed.account.default_role : 'unverified');
    AuthService.syncRemoteAccount(
      parsed.account.id,
      parsed.account.phone,
      parsed.account.display_name ? parsed.account.display_name : displayName,
      parsedRole,
      parsed.account.huawei_open_id,
      parsed.account.huawei_union_id
    );
    AuditLogService.record('admin.account_create', '远程创建账号 ' + phone + ' 角色 ' + AuthFacadeService.remoteRoleName(role));
    return RemoteDataMapper.ok<AuthBackendData>('远程创建账号成功', {
      account: AuthService.getCurrentAccount(),
      role: AuthService.getCurrentRole(),
      canShop: AuthService.canEnterShopping()
    });
  }

  static async updateAccountRemote(accountId: string, phone: string, displayName: string, role: AccountRole, status: AccountStatus): Promise<BackendResult<AuthBackendData>> {
    const remoteRole: string = AuthFacadeService.remoteRoleName(role);
    const remoteResult: RemoteBackendResult = await RemoteBackendClient.adminUpdateAccount(accountId, phone, displayName, remoteRole, status);
    if (!remoteResult.success) {
      return AuthFacadeService.updateAccount(accountId, phone, displayName, role, status);
    }
    const parsed: RemoteAdminAccountCrudResponse | undefined = RemoteDataMapper.parseAdminAccountCrud(remoteResult.body);
    if (!parsed || !parsed.account) {
      return AuthFacadeService.updateAccount(accountId, phone, displayName, role, status);
    }
    AuthService.updateAccount(accountId, phone, displayName, role, status);
    AuditLogService.record('admin.account_update', '远程更新账号 ' + accountId);
    return RemoteDataMapper.ok<AuthBackendData>('远程更新账号成功', {
      account: AuthService.getCurrentAccount(),
      role: AuthService.getCurrentRole(),
      canShop: AuthService.canEnterShopping()
    });
  }

  static async softDeleteAccountRemote(accountId: string): Promise<BackendResult<AuthBackendData>> {
    const remoteResult: RemoteBackendResult = await RemoteBackendClient.adminSoftDeleteAccount(accountId);
    if (!remoteResult.success) {
      return AuthFacadeService.softDeleteAccount(accountId);
    }
    AuthService.softDeleteAccount(accountId);
    AuditLogService.record('admin.account_soft_delete', '远程软删除账号 ' + accountId);
    return RemoteDataMapper.ok<AuthBackendData>('远程软删除账号成功', {
      account: AuthService.getCurrentAccount(),
      role: AuthService.getCurrentRole(),
      canShop: AuthService.canEnterShopping()
    });
  }

  static async restoreAccountRemote(accountId: string): Promise<BackendResult<AuthBackendData>> {
    const remoteResult: RemoteBackendResult = await RemoteBackendClient.adminRestoreAccount(accountId);
    if (!remoteResult.success) {
      return AuthFacadeService.restoreAccount(accountId);
    }
    AuthService.restoreAccount(accountId);
    AuditLogService.record('admin.account_restore', '远程恢复账号 ' + accountId);
    return RemoteDataMapper.ok<AuthBackendData>('远程恢复账号成功', {
      account: AuthService.getCurrentAccount(),
      role: AuthService.getCurrentRole(),
      canShop: AuthService.canEnterShopping()
    });
  }

  static syncRemoteUsers(users: RemoteAdminUserItem[]): void {
    AuthService.syncRemoteUsers(users);
  }

  static submitFeedbackLocal(title: string, content: string): CustomerTicket {
    const ticket: CustomerTicket = {
      id: 'ticket-' + Date.now().toString(),
      csAccountId: '',
      elderlyAccountId: AuthService.getCurrentElderlyAccountId(),
      orderId: '',
      title: title,
      content: content,
      status: 'open',
      priority: 'normal',
      createdAt: TimeUtils.formatDate(new Date()),
      updatedAt: TimeUtils.formatDate(new Date())
    };
    AuthService.addTicket(ticket);
    AuditLogService.record('feedback.submit', '提交反馈：' + title);
    return ticket;
  }

  static async submitFeedbackRemote(title: string, content: string): Promise<BackendResult<AuthBackendData>> {
    const remoteResult: RemoteBackendResult = await RemoteBackendClient.submitFeedback(title, content, 'normal');
    if (!remoteResult.success) {
      if (remoteResult.statusCode === 0) {
        const ticket = AuthFacadeService.submitFeedbackLocal(title, content);
        return RemoteDataMapper.ok<AuthBackendData>('反馈已提交（离线模式）', {
          account: AuthService.getCurrentAccount(),
          role: AuthService.getCurrentRole(),
          canShop: AuthService.canEnterShopping()
        });
      }
      return RemoteDataMapper.fail<AuthBackendData>(BackendErrorCode.ValidationError, '反馈提交失败：' + remoteResult.message);
    }
    AuthFacadeService.submitFeedbackLocal(title, content);
    return RemoteDataMapper.ok<AuthBackendData>('反馈已提交，客服将尽快处理', {
      account: AuthService.getCurrentAccount(),
      role: AuthService.getCurrentRole(),
      canShop: AuthService.canEnterShopping()
    });
  }

  static async updateElderlyProfileRemote(realName: string, age: number, emergencyPhone: string, nickName: string): Promise<BackendResult<AuthBackendData>> {
    const displayName = realName.trim().length > 0 ? realName.trim() : undefined;
    const remoteResult: RemoteBackendResult = await RemoteBackendClient.updateProfile(
      realName.trim(), age, emergencyPhone.trim(), undefined, nickName.trim(), displayName
    );
    if (!remoteResult.success) {
      hilog.warn(0x0001, 'AuthFacade', 'updateElderlyProfileRemote failed statusCode=' + remoteResult.statusCode.toString());
      return RemoteDataMapper.fail<AuthBackendData>(BackendErrorCode.InternalError, '档案更新失败：' + remoteResult.message);
    }
    const account: Account | undefined = AuthService.getCurrentAccount();
    if (account) {
      AuthService.updateElderlyProfile(account.id, realName, age, emergencyPhone);
      AuthService.updateAccountNickName(account.id, nickName);
    }
    AuditLogService.record('profile.updateElderly', '老人档案远程更新成功');
    return RemoteDataMapper.ok<AuthBackendData>('档案更新成功', {
      account: AuthService.getCurrentAccount(),
      role: AuthService.getCurrentRole(),
      canShop: AuthService.canEnterShopping()
    });
  }

  static async updateChildProfileRemote(realName: string, relation: string, nickName: string): Promise<BackendResult<AuthBackendData>> {
    const displayName = realName.trim().length > 0 ? realName.trim() : undefined;
    const remoteResult: RemoteBackendResult = await RemoteBackendClient.updateProfile(
      realName.trim(), undefined, undefined, relation.trim(), nickName.trim(), displayName
    );
    if (!remoteResult.success) {
      hilog.warn(0x0001, 'AuthFacade', 'updateChildProfileRemote failed statusCode=' + remoteResult.statusCode.toString());
      return RemoteDataMapper.fail<AuthBackendData>(BackendErrorCode.InternalError, '档案更新失败：' + remoteResult.message);
    }
    const account: Account | undefined = AuthService.getCurrentAccount();
    if (account) {
      AuthService.updateChildProfile(account.id, realName, relation);
      AuthService.updateAccountNickName(account.id, nickName);
    }
    AuditLogService.record('profile.updateChild', '子女档案远程更新成功');
    return RemoteDataMapper.ok<AuthBackendData>('档案更新成功', {
      account: AuthService.getCurrentAccount(),
      role: AuthService.getCurrentRole(),
      canShop: AuthService.canEnterShopping()
    });
  }
}
