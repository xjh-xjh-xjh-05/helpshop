import { authentication } from '@kit.AccountKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { HarmonyOSFullAuthResult, HarmonyOSLoginResult, HarmonyOSPhoneAuthResult } from '../models/AuthModels';
import { AgcConfigService } from './AgcConfigService';

interface HuaweiAuthErrorInfo {
  code: number;
  message: string;
  rawMessage: string;
}

export interface UserInfoResult {
  success: boolean;
  avatarUri: string;
  nickName: string;
  message: string;
}

enum AuthErrorCode {
  ERROR_CODE_LOGIN_OUT = 1001502001,
  ERROR_CODE_NETWORK_ERROR = 1001502005,
  ERROR_CODE_USER_CANCEL = 1001502012,
  ERROR_CODE_SYSTEM_SERVICE = 12300001,
  ERROR_CODE_REQUEST_REFUSE = 1001500002
}

export class HuaweiAccountService {
  static async loginWithHuaweiID(context: common.UIAbilityContext): Promise<HarmonyOSLoginResult> {
    try {
      const provider: authentication.HuaweiIDProvider = new authentication.HuaweiIDProvider();
      const loginRequest: authentication.LoginWithHuaweiIDRequest = provider.createLoginWithHuaweiIDRequest();
      loginRequest.forceLogin = true;
      const controller: authentication.AuthenticationController = new authentication.AuthenticationController(context);
      const response: authentication.LoginWithHuaweiIDResponse = await controller.executeRequest(loginRequest);
      const credential: authentication.LoginWithHuaweiIDCredential | undefined = response.data;
      if (!credential) {
        hilog.warn(0x0001, 'HuaweiAccountService', 'loginWithHuaweiID credential is undefined');
        return {
          success: false,
          openID: '',
          unionID: '',
          authorizationCode: '',
          message: '\u534e\u4e3a\u8d26\u53f7\u767b\u5f55\u8fd4\u56de\u7684\u6570\u636e\u4e3a\u7a7a'
        };
      }
      hilog.info(0x0001, 'HuaweiAccountService', 'loginWithHuaweiID success, openID=%{public}s', credential.openID);
      return {
        success: true,
        openID: credential.openID,
        unionID: credential.unionID,
        authorizationCode: credential.authorizationCode ? credential.authorizationCode : '',
        idToken: credential.idToken,
        message: '\u534e\u4e3a\u8d26\u53f7\u767b\u5f55\u6210\u529f'
      };
    } catch (error) {
      const code: number = (error && typeof error === 'object' && error.code) ? Number(error.code) : 0;
      const rawMessage: string = (error && error.message) ? String(error.message) : '';
      const authError: HuaweiAuthErrorInfo = HuaweiAccountService.parseAuthError(code, rawMessage);
      hilog.error(
        0x0001,
        'HuaweiAccountService',
        'loginWithHuaweiID error code=%{public}d message=%{public}s',
        authError.code,
        authError.rawMessage
      );
      return {
        success: false,
        openID: '',
        unionID: '',
        authorizationCode: '',
        message: HuaweiAccountService.buildDiagnosticMessage(authError)
      };
    }
  }

  static async authorizePhoneNumber(context: common.UIAbilityContext): Promise<HarmonyOSPhoneAuthResult> {
    try {
      const provider: authentication.HuaweiIDProvider = new authentication.HuaweiIDProvider();
      const authRequest: authentication.AuthorizationWithHuaweiIDRequest = provider.createAuthorizationWithHuaweiIDRequest();
      authRequest.scopes = ['https://www.huawei.com/auth/account/mobile.number'];
      authRequest.permissions = ['serviceauthcode'];
      authRequest.forceAuthorization = false;
      const controller: authentication.AuthenticationController = new authentication.AuthenticationController(context);
      const response: authentication.AuthorizationWithHuaweiIDResponse = await controller.executeRequest(authRequest);
      const credential: authentication.AuthorizationWithHuaweiIDCredential | undefined = response.data;
      if (!credential) {
        hilog.warn(0x0001, 'HuaweiAccountService', 'authorizePhoneNumber credential is undefined');
        return { success: false, phoneAuthorizationCode: '', message: '\u624b\u673a\u53f7\u6388\u6743\u8fd4\u56de\u7684\u6570\u636e\u4e3a\u7a7a' };
      }
      hilog.info(0x0001, 'HuaweiAccountService', 'authorizePhoneNumber success');
      return {
        success: true,
        phoneAuthorizationCode: credential.authorizationCode ? credential.authorizationCode : '',
        openID: credential.openID,
        message: '\u624b\u673a\u53f7\u6388\u6743\u6210\u529f'
      };
    } catch (error) {
      const code: number = (error && typeof error === 'object' && error.code) ? Number(error.code) : 0;
      const rawMessage: string = (error && error.message) ? String(error.message) : '';
      hilog.warn(
        0x0001,
        'HuaweiAccountService',
        'authorizePhoneNumber error code=%{public}d message=%{public}s',
        code,
        rawMessage
      );
      return {
        success: false,
        phoneAuthorizationCode: '',
        message: '\u624b\u673a\u53f7\u6388\u6743\u5931\u8d25\uff08\u4e0d\u5f71\u54cd\u767b\u5f55\uff09'
      };
    }
  }

  static async loginAndGetPhone(context: common.UIAbilityContext): Promise<HarmonyOSFullAuthResult> {
    const loginResult: HarmonyOSLoginResult = await HuaweiAccountService.loginWithHuaweiID(context);
    if (!loginResult.success) {
      return { success: false, loginResult: loginResult, phoneDenied: true, message: loginResult.message };
    }
    let phoneResult: HarmonyOSPhoneAuthResult | undefined = undefined;
    try {
      phoneResult = await HuaweiAccountService.authorizePhoneNumber(context);
    } catch (error) {
      hilog.warn(0x0001, 'HuaweiAccountService', 'loginAndGetPhone phone auth skipped');
    }
    const phoneDenied: boolean = !phoneResult || !phoneResult.success;
    return {
      success: true,
      loginResult: loginResult,
      phoneAuthResult: phoneResult && phoneResult.success ? phoneResult : undefined,
      phoneDenied: phoneDenied,
      message: phoneDenied ? '\u534e\u4e3a\u8d26\u53f7\u767b\u5f55\u6210\u529f' : '\u534e\u4e3a\u8d26\u53f7\u767b\u5f55\u5e76\u83b7\u53d6\u624b\u673a\u53f7\u6388\u6743\u6210\u529f'
    };
  }

  static getChecklistItems(): string[] {
    return AgcConfigService.getChecklistItems();
  }

  static getCurrentConfigSummary(): string[] {
    return AgcConfigService.getCurrentConfigSummary();
  }

  static async requestUserInfo(context: common.UIAbilityContext): Promise<UserInfoResult> {
    try {
      const provider: authentication.HuaweiIDProvider = new authentication.HuaweiIDProvider();
      const authRequest: authentication.AuthorizationWithHuaweiIDRequest =
        provider.createAuthorizationWithHuaweiIDRequest();
      authRequest.scopes = ['profile'];
      authRequest.forceAuthorization = true;
      authRequest.state = util.generateRandomUUID();
      const controller: authentication.AuthenticationController =
        new authentication.AuthenticationController(context);
      const response: authentication.AuthorizationWithHuaweiIDResponse =
        await controller.executeRequest(authRequest);
      const state: string | undefined = response.state;
      if (state && authRequest.state !== state) {
        hilog.warn(0x0001, 'HuaweiAccountService', 'requestUserInfo state mismatch');
        return { success: false, avatarUri: '', nickName: '', message: '\u6388\u6743\u72b6\u6001\u6821\u9a8c\u5931\u8d25' };
      }
      const credential: authentication.AuthorizationWithHuaweiIDCredential | undefined = response.data;
      if (!credential) {
        hilog.warn(0x0001, 'HuaweiAccountService', 'requestUserInfo credential is undefined');
        return { success: false, avatarUri: '', nickName: '', message: '\u83b7\u53d6\u7528\u6237\u4fe1\u606f\u5931\u8d25' };
      }
      const avatarUri: string = credential.avatarUri ? credential.avatarUri : '';
      const nickName: string = credential.nickName ? credential.nickName : '';
      hilog.info(0x0001, 'HuaweiAccountService', 'requestUserInfo success nickName=%{public}s', nickName);
      AppStorage.setOrCreate('avatarUri', avatarUri);
      AppStorage.setOrCreate('nickName', nickName);
      return { success: true, avatarUri, nickName, message: '\u83b7\u53d6\u7528\u6237\u4fe1\u606f\u6210\u529f' };
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      const userMsg: string = HuaweiAccountService.dealAuthError(err);
      hilog.error(0x0001, 'HuaweiAccountService',
        'requestUserInfo error code=%{public}d msg=%{public}s', err.code, err.message);
      return { success: false, avatarUri: '', nickName: '', message: userMsg };
    }
  }

  private static dealAuthError(error: BusinessError): string {
    if (error.code === AuthErrorCode.ERROR_CODE_LOGIN_OUT) {
      return '\u8bbe\u5907\u672a\u767b\u5f55\u534e\u4e3a\u8d26\u53f7\uff0c\u8bf7\u5148\u767b\u5f55';
    }
    if (error.code === AuthErrorCode.ERROR_CODE_NETWORK_ERROR) {
      return '\u7f51\u7edc\u5f02\u5e38\uff0c\u8bf7\u68c0\u67e5\u7f51\u7edc\u5e76\u91cd\u8bd5';
    }
    if (error.code === AuthErrorCode.ERROR_CODE_USER_CANCEL) {
      return '\u7528\u6237\u53d6\u6d88\u6388\u6743';
    }
    if (error.code === AuthErrorCode.ERROR_CODE_SYSTEM_SERVICE) {
      return '\u7cfb\u7edf\u670d\u52a1\u5f02\u5e38\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5';
    }
    if (error.code === AuthErrorCode.ERROR_CODE_REQUEST_REFUSE) {
      return '';
    }
    return '\u83b7\u53d6\u7528\u6237\u4fe1\u606f\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5';
  }

  private static buildDiagnosticMessage(authError: HuaweiAuthErrorInfo): string {
    const parts: string[] = [];
    if (authError.code > 0) {
      parts.push(`\u9519\u8bef\u7801 ${authError.code}`);
    }
    parts.push(authError.message);
    const hint: string = AgcConfigService.getShortHint(authError.code);
    if (hint.length > 0) {
      parts.push(hint);
    }
    return parts.join('\uff1b');
  }

  private static parseAuthError(code: number, rawMessage: string): HuaweiAuthErrorInfo {
    switch (code) {
      case 1001502001:
        return { code, rawMessage, message: '\u8bbe\u5907\u672a\u767b\u5f55\u534e\u4e3a\u8d26\u53f7\uff0c\u8bf7\u5148\u5728\u6a21\u62df\u5668\u6216\u8bbe\u5907\u8bbe\u7f6e\u4e2d\u767b\u5f55' };
      case 1001502012:
        return { code, rawMessage, message: '\u4f60\u53d6\u6d88\u4e86\u534e\u4e3a\u8d26\u53f7\u767b\u5f55' };
      case 1001502002:
        return { code, rawMessage, message: '\u5e94\u7528\u672a\u83b7\u5f97\u534e\u4e3a\u8d26\u53f7\u670d\u52a1\u6388\u6743\uff0c\u8bf7\u68c0\u67e5 AGC \u7684 API \u7ba1\u7406\u662f\u5426\u5df2\u5f00\u542f\u534e\u4e3a\u8d26\u53f7\u670d\u52a1' };
      case 1001502003:
        return { code, rawMessage, message: '\u6388\u6743\u53c2\u6570\u65e0\u6548\uff0c\u8bf7\u68c0\u67e5 scope \u662f\u5426\u6b63\u786e\uff08\u624b\u673a\u53f7\u9700\u4f7f\u7528 https://www.huawei.com/auth/account/mobile.number\uff09\u53ca AGC \u6743\u9650\u914d\u7f6e' };
      case 1001502005:
        return { code, rawMessage, message: '\u7f51\u7edc\u5f02\u5e38\uff0c\u8bf7\u68c0\u67e5\u6a21\u62df\u5668\u7f51\u7edc\u548c\u540e\u7aef\u5730\u5740' };
      case 1001502014:
        return { code, rawMessage, message: '\u5f53\u524d\u5e94\u7528\u672a\u83b7\u5f97\u624b\u673a\u53f7\u6388\u6743\u80fd\u529b\uff0c\u8bf7\u68c0\u67e5\u534e\u4e3a\u8d26\u53f7\u624b\u673a\u53f7\u76f8\u5173\u6743\u9650\u6216\u670d\u52a1\u914d\u7f6e' };
      case 1001500001:
        return { code, rawMessage, message: '\u534e\u4e3a\u8d26\u53f7\u670d\u52a1\u914d\u7f6e\u4e0d\u5b8c\u6574\uff0c\u901a\u5e38\u662f client_id\u3001\u5305\u540d\u3001SHA-256 \u6307\u7eb9\u6216 AGC \u914d\u7f6e\u6587\u4ef6\u4e0d\u5339\u914d' };
      case 1001500003:
        return { code, rawMessage, message: '\u5f53\u524d\u534e\u4e3a\u8d26\u53f7\u4e0d\u652f\u6301\u8be5\u6388\u6743\uff0c\u8bf7\u66f4\u6362\u8d26\u53f7\u91cd\u8bd5' };
      default:
        return { code, rawMessage, message: `\u534e\u4e3a\u8d26\u53f7\u670d\u52a1\u5f02\u5e38${code > 0 ? ` (${code})` : ''}` };
    }
  }
}
