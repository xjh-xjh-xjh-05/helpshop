import { Account, AccountRole } from '../models/AuthModels';
import { BackendResult, AuthBackendData } from '../models/BackendModels';
import { AppBackendService } from '../services/AppBackendService';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';

@Entry
@Component
struct IdentityAuth {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @State accountName: string = '当前账号';
  @State accountPhone: string = '';

  aboutToAppear(): void {
    const account: Account | undefined = AppBackendService.getCurrentAccount();
    if (!account) {
      RouteUtils.replacePage(this.getUIContext(), 'pages/Login');
      return;
    }
    this.accountName = account.displayName;
    this.accountPhone = account.phone;
  }

  private async certify(role: AccountRole): Promise<void> {
    try {
      const result: BackendResult<AuthBackendData> = await AppBackendService.certifyRoleRemote(role);
      RouteUtils.showToast(this.getUIContext(), result.message);
      if (!result.success) {
        return;
      }
      if (role === AccountRole.Elderly) {
        RouteUtils.pushPage(this.getUIContext(), 'pages/UserHome');
      } else if (role === AccountRole.Admin) {
        RouteUtils.pushPage(this.getUIContext(), 'pages/AdminHome');
      } else if (role === AccountRole.CustomerService) {
        RouteUtils.pushPage(this.getUIContext(), 'pages/CustomerServiceHome');
      } else if (role === AccountRole.Child) {
        try {
          await AppBackendService.listFamilyBindingsRemote();
        } catch (error) {
        }
        if (AppBackendService.canEnterShopping()) {
          RouteUtils.pushPage(this.getUIContext(), 'pages/ChildHome');
        } else {
          RouteUtils.pushPage(this.getUIContext(), 'pages/BindFamily');
        }
      }
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '认证异常，请稍后重试');
    }
  }

  private logout(): void {
    AppBackendService.logout();
    RouteUtils.clearAndPush(this.getUIContext(), 'pages/Login');
  }

  @Builder
  private IdentityCard(role: AccountRole, title: string, desc: string, action: string) {
    Column({ space: 12 }) {
      Text(title)
        .fontSize(this.careMode ? 26 : 21)
        .fontWeight(FontWeight.Bold)
        .fontColor('#431407')
        .width('100%')
      Text(desc)
        .fontSize(this.careMode ? 18 : 14)
        .fontColor('#6B4E3D')
        .lineHeight(this.careMode ? 28 : 21)
        .width('100%')
      Button(action)
        .width('100%')
        .height(this.careMode ? 56 : 48)
        .fontSize(this.careMode ? 19 : 16)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor(role === AccountRole.Elderly ? '#378F85' : '#2B7068')
        .borderRadius(8)
        .onClick(() => {
          this.certify(role);
        })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Color.White)
    .borderRadius(8)
    .border({ width: 1, color: '#E8DDD2' })
  }

  build() {
    Scroll() {
      Row() {
        Column({ space: 18 }) {
          Column({ space: 8 }) {
            Text('\u8eab\u4efd\u8ba4\u8bc1')
              .fontSize(this.careMode ? 36 : 30)
              .fontWeight(FontWeight.Bold)
              .fontColor('#431407')
              .width('100%')
            Text(this.accountName + '  ' + this.accountPhone)
              .fontSize(this.careMode ? 18 : 14)
              .fontColor('#7A5C45')
              .width('100%')
            Text('\u8bf7\u5728\u5e94\u7528\u5185\u786e\u8ba4\u5f53\u524d\u8d26\u53f7\u7684\u4f7f\u7528\u8eab\u4efd\u3002\u5b50\u5973\u8ba4\u8bc1\u540e\u9700\u8981\u7ed1\u5b9a\u8001\u4eba\u8d26\u53f7\uff0c\u624d\u80fd\u5e2e\u52a9\u8001\u4eba\u8d2d\u7269\u3002')
              .fontSize(this.careMode ? 18 : 14)
              .fontColor('#6B4E3D')
              .lineHeight(this.careMode ? 28 : 21)
              .width('100%')
          }
          .width('100%')
          .padding(18)
          .backgroundColor('#FAF7F2')
          .borderRadius(8)
          .border({ width: 1, color: '#E8DDD2' })

          this.IdentityCard(
            AccountRole.Elderly,
            '\u6211\u662f\u8001\u4eba',
            '\u8fdb\u5165\u8d2d\u7269\u5546\u57ce\uff0c\u53ef\u4ee5\u8f93\u5165\u9700\u6c42\u3001\u67e5\u770b\u6bd4\u4ef7\u3001\u9009\u62e9\u5730\u5740\u5e76\u5b8c\u6210\u6a21\u62df\u652f\u4ed8\u3002',
            '\u8ba4\u8bc1\u4e3a\u8001\u4eba\u5e76\u8d2d\u7269'
          )

          this.IdentityCard(
            AccountRole.Child,
            '\u6211\u662f\u5b50\u5973',
            '\u8fdb\u5165\u5bb6\u5ead\u534f\u52a9\u5de5\u4f5c\u53f0\uff0c\u7ed1\u5b9a\u8001\u4eba\u540e\u53ef\u4ee5\u7ef4\u62a4\u5730\u5740\u3001\u67e5\u770b\u63d0\u9192\uff0c\u4e5f\u53ef\u4ee5\u5e2e\u52a9\u8001\u4eba\u8d2d\u7269\u3002',
            '\u8ba4\u8bc1\u4e3a\u5b50\u5973\u5e76\u7ed1\u5b9a\u8001\u4eba'
          )

          this.IdentityCard(
            AccountRole.Admin,
            '\u6211\u662f\u7ba1\u7406\u5458',
            '\u8fdb\u5165\u7ba1\u7406\u63a7\u5236\u53f0\uff0c\u53ef\u4ee5\u7ba1\u7406\u7528\u6237\u3001\u5ba1\u6838\u5165\u9a7b\u3001\u67e5\u770b\u8ba2\u5355\u548c\u5ba1\u8ba1\u65e5\u5fd7\u3002',
            '\u8ba4\u8bc1\u4e3a\u7ba1\u7406\u5458'
          )

          this.IdentityCard(
            AccountRole.CustomerService,
            '\u6211\u662f\u5ba2\u670d',
            '\u8fdb\u5165\u5ba2\u670d\u5de5\u4f5c\u53f0\uff0c\u5904\u7406\u8001\u4eba\u548c\u5b50\u5973\u7684\u54a8\u8be2\u3001\u67e5\u770b\u5de5\u5355\u548c\u8ba2\u5355\u3002',
            '\u8ba4\u8bc1\u4e3a\u5ba2\u670d'
          )

          Button('\u9000\u51fa\u5f53\u524d\u8d26\u53f7')
            .width('100%')
            .height(this.careMode ? 52 : 44)
            .fontSize(this.careMode ? 18 : 15)
            .fontColor('#2B7068')
            .backgroundColor('#EFFAF8')
            .borderRadius(8)
            .onClick(() => {
              this.logout();
            })
        }
        .width('100%')
        .padding(18)
        .constraintSize({ maxWidth: this.breakpoint === 'sm' ? 10000 : 720 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3EFE8')
  }
}
