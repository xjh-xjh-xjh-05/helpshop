import { AccountRole } from '../models/AuthModels';
import { AuthBackendData, BackendResult } from '../models/BackendModels';
import { AppBackendService } from '../services/AppBackendService';
import { HuaweiAccountService } from '../services/HuaweiAccountService';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { LoginPanel, loginComponentManager } from '@kit.AccountKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';

@Entry
@Component
struct Login {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @State phone: string = '13800000001';
  @State password: string = '123456';
  @State showLoginPanel: boolean = false;
  @StorageLink('avatarUri') avatarUri: string = '';
  @StorageLink('nickName') nickName: string = '';
  private privacyText: loginComponentManager.PrivacyText[] = [
    {
      text: '\u5df2\u9605\u8bfb\u5e76\u540c\u610f',
      type: loginComponentManager.TextType.PLAIN_TEXT
    },
    {
      text: '\u300a\u7528\u6237\u670d\u52a1\u534f\u8bae\u300b',
      tag: '\u7528\u6237\u670d\u52a1\u534f\u8bae',
      type: loginComponentManager.TextType.RICH_TEXT
    },
    {
      text: '\u300a\u9690\u79c1\u534f\u8bae\u300b',
      tag: '\u9690\u79c1\u534f\u8bae',
      type: loginComponentManager.TextType.RICH_TEXT
    },
    {
      text: '\u548c',
      type: loginComponentManager.TextType.PLAIN_TEXT
    },
    {
      text: '\u300a\u534e\u4e3a\u8d26\u53f7\u7528\u6237\u8ba4\u8bc1\u534f\u8bae\u300b',
      tag: 'https://privacy.consumer.huawei.com/legal/id/authenticationterms.htm?code=CN&language=zh-CN',
      type: loginComponentManager.TextType.RICH_TEXT
    }
  ];
  private loginPanelController: loginComponentManager.LoginPanelController =
    new loginComponentManager.LoginPanelController()
      .onClickLoginWithHuaweiIDButton((error: BusinessError, response: loginComponentManager.HuaweiIDCredential) => {
        if (error) {
          hilog.error(0x0001, 'Login', 'loginPanel error code=%{public}d msg=%{public}s',
            error.code, error.message);
          this.showLoginPanel = false;
          RouteUtils.showToast(this.getUIContext(),
            '\u534e\u4e3a\u8d26\u53f7\u767b\u5f55\u5931\u8d25\uff1a' + error.message);
          return;
        }
        if (response) {
          this.showLoginPanel = false;
          this.onHuaweiLoginResponse(response);
        }
      })
      .onClickOptionalLoginButton(() => {
        hilog.info(0x0001, 'Login', 'onClickOptionalLoginButton');
        this.showLoginPanel = false;
      })
      .onClickPrivacyText((error: BusinessError, tag: string) => {
        if (error) {
          hilog.error(0x0001, 'Login', 'onClickPrivacyText error code=%{public}d', error.code);
          return;
        }
        hilog.info(0x0001, 'Login', 'onClickPrivacyText tag=%{public}s', tag);
      })
      .onClickCloseButton(() => {
        hilog.info(0x0001, 'Login', 'loginPanel closed');
        this.showLoginPanel = false;
      })
      .onChangeAgreementStatus((error: BusinessError, agreementStatus: loginComponentManager.AgreementStatus) => {
        if (error) {
          hilog.error(0x0001, 'Login', 'onChangeAgreementStatus error code=%{public}d', error.code);
          return;
        }
        hilog.info(0x0001, 'Login', 'agreementStatus=%{public}s', agreementStatus.toString());
      });

  aboutToAppear(): void {
    hilog.info(0x0001, 'Login', 'aboutToAppear isLoggedIn=%{public}s',
      AppBackendService.isLoggedIn().toString());
    if (AppBackendService.isLoggedIn()) {
      this.routeAfterLogin();
    }
  }

  private routeAfterLogin(): void {
    const role = AppBackendService.getCurrentRole();
    if (role === AccountRole.Elderly) {
      RouteUtils.clearAndPush(this.getUIContext(), 'pages/UserHome');
      return;
    }
    if (role === AccountRole.Admin) {
      RouteUtils.clearAndPush(this.getUIContext(), 'pages/AdminHome');
      return;
    }
    if (role === AccountRole.CustomerService) {
      RouteUtils.clearAndPush(this.getUIContext(), 'pages/CustomerServiceHome');
      return;
    }
    if (role === AccountRole.Child) {
      if (AppBackendService.canEnterShopping()) {
        RouteUtils.clearAndPush(this.getUIContext(), 'pages/ChildHome');
        return;
      }
      RouteUtils.clearAndPush(this.getUIContext(), 'pages/Welcome');
      return;
    }
    RouteUtils.clearAndPush(this.getUIContext(), 'pages/Welcome');
  }

  private async login(): Promise<void> {
    if (this.phone.trim().length === 0) {
      RouteUtils.showToast(this.getUIContext(), '\u8bf7\u8f93\u5165\u624b\u673a\u53f7');
      return;
    }
    if (this.password.length === 0) {
      RouteUtils.showToast(this.getUIContext(), '\u8bf7\u8f93\u5165\u5bc6\u7801');
      return;
    }
    try {
      const result: BackendResult<AuthBackendData> = await AppBackendService.loginRemote(this.phone.trim(), this.password);
      if (!result.success) {
        RouteUtils.showToast(this.getUIContext(), result.message);
        return;
      }
      RouteUtils.showToast(this.getUIContext(), '\u767b\u5f55\u6210\u529f');
      this.routeAfterLogin();
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '\u767b\u5f55\u5f02\u5e38\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5');
    }
  }

  private async onHuaweiLoginResponse(credential: loginComponentManager.HuaweiIDCredential): Promise<void> {
    try {
      const openID: string = credential.openID ? credential.openID : '';
      const unionID: string = credential.unionID ? credential.unionID : '';
      const authCode: string = credential.authorizationCode ? credential.authorizationCode : '';
      const idToken: string = credential.idToken ? credential.idToken : '';
      hilog.info(0x0001, 'Login', 'onHuaweiLoginResponse openID=%{public}s', openID);

      try {
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        const userInfo = await HuaweiAccountService.requestUserInfo(context);
        if (userInfo.success) {
          this.avatarUri = userInfo.avatarUri;
          this.nickName = userInfo.nickName;
        }
      } catch (e) {
        hilog.warn(0x0001, 'Login', 'requestUserInfo skipped');
      }

      const result: BackendResult<AuthBackendData> = await AppBackendService.loginWithHuaweiIDByCredential(
        openID, unionID, authCode, idToken);
      if (!result.success) {
        RouteUtils.showToast(this.getUIContext(), result.message);
        return;
      }
      RouteUtils.showToast(this.getUIContext(), '\u534e\u4e3a\u8d26\u53f7\u767b\u5f55\u6210\u529f');
      this.routeAfterLogin();
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '\u534e\u4e3a\u8d26\u53f7\u767b\u5f55\u5f02\u5e38\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5');
    }
  }

  build() {
    Stack() {
      Scroll() {
        Row() {
          Column() {
            Column({ space: 14 }) {
              Text('\u767b\u5f55')
                .fontSize(this.careMode ? 28 : 22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#431407')
                .width('100%')

              TextInput({ placeholder: '\u624b\u673a\u53f7', text: $$this.phone })
                .type(InputType.PhoneNumber)
                .height(this.careMode ? 60 : 50)
                .fontSize(this.careMode ? 20 : 16)
                .backgroundColor('#FAF7F2')
                .borderRadius(8)
                .padding({ left: 14, right: 14 })

              TextInput({ placeholder: '\u5bc6\u7801', text: $$this.password })
                .type(InputType.Password)
                .height(this.careMode ? 60 : 50)
                .fontSize(this.careMode ? 20 : 16)
                .backgroundColor('#FAF7F2')
                .borderRadius(8)
                .padding({ left: 14, right: 14 })

              Button('\u767b\u5f55')
                .width('100%')
                .height(this.careMode ? 58 : 48)
                .fontSize(this.careMode ? 20 : 17)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .backgroundColor('#378F85')
                .borderRadius(8)
                .onClick(() => {
                  this.login();
                })

              Row() {
                Text('老人13800000001 / 子女13900000001 / 管理13700000001 / 客服13600000001，密码 123456')
                  .fontSize(this.careMode ? 13 : 10)
                  .fontColor('#6D6258')
                  .layoutWeight(1)
                Button('\u6ce8\u518c')
                  .height(this.careMode ? 40 : 32)
                  .fontSize(this.careMode ? 16 : 13)
                  .fontColor('#378F85')
                  .backgroundColor('#EFFAF8')
                  .borderRadius(8)
                  .onClick(() => {
                    RouteUtils.pushPage(this.getUIContext(), 'pages/Register');
                  })
              }
              .width('100%')

              Row() {
                Divider().width('35%')
                Text('\u6216')
                  .fontSize(this.careMode ? 15 : 12)
                  .fontColor('#6D6258')
                  .padding({ left: 8, right: 8 })
                Divider().width('35%')
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)

              Button('\u534e\u4e3a\u8d26\u53f7\u767b\u5f55')
                .width('100%')
                .height(this.careMode ? 58 : 48)
                .fontSize(this.careMode ? 20 : 17)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .backgroundColor('#378F85')
                .borderRadius(8)
                .onClick(() => {
                  this.showLoginPanel = true;
                })
            }
            .width('100%')
            .padding(18)
            .backgroundColor(Color.White)
            .borderRadius(8)
            .border({ width: 1, color: '#E8DDD2' })
          }
          .width('100%')
          .constraintSize({ maxWidth: this.breakpoint === 'sm' ? 10000 : 720 })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
      .padding(24)
      .backgroundColor('#F3EFE8')

      if (this.showLoginPanel) {
        LoginPanel({
          show: this.showLoginPanel,
          params: {
            appInfo: {
              appIcon: $r('app.media.startIcon'),
              appName: '银发智购'
            },
            loginType: loginComponentManager.LoginType.ID,
            privacyText: this.privacyText,
            optionalLoginButtonAttr: { text: '\u5176\u4ed6\u65b9\u5f0f\u767b\u5f55' }
          },
          controller: this.loginPanelController
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
