import { Account, AccountRole, FamilyBinding } from '../models/AuthModels';
import { AuthBackendData, BackendResult, BindingListBackendData } from '../models/BackendModels';
import { AppBackendService } from '../services/AppBackendService';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';

@Entry
@Component
struct Welcome {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @StorageLink('avatarUri') avatarUri: string = '';
  @StorageLink('nickName') nickName: string = '';
  @State step: number = 0;
  @State manualPhone: string = '';
  @State keyword: string = 'HS2026';
  @State message: string = '';
  @State bindings: FamilyBinding[] = [];
  @State accountName: string = '';
  @State accountPhone: string = '';

  aboutToAppear(): void {
    const account: Account | undefined = AppBackendService.getCurrentAccount();
    if (!account) {
      RouteUtils.replacePage(this.getUIContext(), 'pages/Login');
      return;
    }
    if (account.phone.length === 0) {
      this.step = 1;
    } else if (AppBackendService.getCurrentRole() === AccountRole.Unverified) {
      this.step = 2;
    } else if (AppBackendService.getCurrentRole() === AccountRole.Child) {
      if (AppBackendService.canEnterShopping()) {
        RouteUtils.clearAndPush(this.getUIContext(), 'pages/ChildHome');
        return;
      }
      this.step = 3;
      this.refreshBindings();
    } else {
      this.goAfterSetup();
    }
    this.accountName = account.displayName;
    this.accountPhone = account.phone;
  }

  private goAfterSetup(): void {
    const role = AppBackendService.getCurrentRole();
    if (role === AccountRole.Elderly) {
      RouteUtils.clearAndPush(this.getUIContext(), 'pages/UserHome');
    } else if (role === AccountRole.Admin) {
      RouteUtils.clearAndPush(this.getUIContext(), 'pages/AdminHome');
    } else if (role === AccountRole.CustomerService) {
      RouteUtils.clearAndPush(this.getUIContext(), 'pages/CustomerServiceHome');
    } else if (role === AccountRole.Child) {
      if (AppBackendService.canEnterShopping()) {
        RouteUtils.clearAndPush(this.getUIContext(), 'pages/ChildHome');
      } else {
        this.step = 3;
        this.refreshBindings();
      }
    } else {
      this.step = 2;
    }
  }

  private async linkPhone(): Promise<void> {
    if (this.manualPhone.trim().length === 0) {
      RouteUtils.showToast(this.getUIContext(), '\u8bf7\u8f93\u5165\u624b\u673a\u53f7');
      return;
    }
    try {
      const result: BackendResult<AuthBackendData> = await AppBackendService.linkPhoneRemote(this.manualPhone.trim());
      if (!result.success) {
        RouteUtils.showToast(this.getUIContext(), result.message);
        return;
      }
      RouteUtils.showToast(this.getUIContext(), '\u624b\u673a\u53f7\u5173\u8054\u6210\u529f');
      this.step = 2;
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '\u624b\u673a\u53f7\u5173\u8054\u5f02\u5e38\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5');
    }
  }

  private async certify(role: AccountRole): Promise<void> {
    try {
      const result: BackendResult<AuthBackendData> = await AppBackendService.certifyRoleRemote(role);
      RouteUtils.showToast(this.getUIContext(), result.message);
      if (!result.success) {
        return;
      }
      if (role === AccountRole.Elderly) {
        RouteUtils.clearAndPush(this.getUIContext(), 'pages/UserHome');
      } else if (role === AccountRole.Admin) {
        RouteUtils.clearAndPush(this.getUIContext(), 'pages/AdminHome');
      } else if (role === AccountRole.CustomerService) {
        RouteUtils.clearAndPush(this.getUIContext(), 'pages/CustomerServiceHome');
      } else if (role === AccountRole.Child) {
        try {
          await AppBackendService.listFamilyBindingsRemote();
        } catch (error) {
        }
        if (AppBackendService.canEnterShopping()) {
          RouteUtils.clearAndPush(this.getUIContext(), 'pages/ChildHome');
        } else {
          this.step = 3;
          this.refreshBindings();
        }
      }
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '\u8ba4\u8bc1\u5f02\u5e38\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5');
    }
  }

  private refreshBindings(): void {
    const result: BackendResult<BindingListBackendData> = AppBackendService.listCurrentChildBindings();
    this.bindings = result.data ? result.data.bindings : [];
  }

  private async bindFamily(): Promise<void> {
    try {
      const result: BackendResult<BindingListBackendData> = await AppBackendService.bindFamilyRemote(this.keyword.trim());
      this.message = result.message;
      RouteUtils.showToast(this.getUIContext(), result.message);
      if (result.success && result.data) {
        this.bindings = result.data.bindings;
      }
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '\u7ed1\u5b9a\u5f02\u5e38\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5');
    }
  }

  @Builder
  private buildStep1LinkPhone(): void {
    Column({ space: 14 }) {
      Text('\u5173\u8054\u624b\u673a\u53f7')
        .fontSize(this.careMode ? 28 : 22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#431407')
        .width('100%')
      Text('\u767b\u5f55\u6210\u529f\uff0c\u8bf7\u5148\u5173\u8054\u624b\u673a\u53f7\uff0c\u518d\u7ee7\u7eed\u8eab\u4efd\u8ba4\u8bc1\u4e0e\u5bb6\u5ead\u7ed1\u5b9a\u3002')
        .fontSize(this.careMode ? 17 : 14)
        .fontColor('#6D6258')
        .lineHeight(this.careMode ? 26 : 20)
        .width('100%')
      TextInput({ placeholder: '\u8bf7\u8f93\u5165\u624b\u673a\u53f7', text: $$this.manualPhone })
        .type(InputType.PhoneNumber)
        .height(this.careMode ? 60 : 50)
        .fontSize(this.careMode ? 20 : 16)
        .backgroundColor('#FAF7F2')
        .borderRadius(8)
        .padding({ left: 14, right: 14 })
      Button('\u786e\u8ba4\u5173\u8054')
        .width('100%')
        .height(this.careMode ? 58 : 48)
        .fontSize(this.careMode ? 20 : 17)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor('#378F85')
        .borderRadius(8)
        .onClick(() => {
          this.linkPhone();
        })
      Button('\u7a0d\u540e\u518d\u8bf4')
        .width('100%')
        .height(this.careMode ? 44 : 36)
        .fontSize(this.careMode ? 17 : 14)
        .fontColor('#6D6258')
        .backgroundColor(Color.Transparent)
        .borderRadius(8)
        .onClick(() => {
          this.step = 2;
        })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Color.White)
    .borderRadius(8)
    .border({ width: 1, color: '#E8DDD2' })
  }

  @Builder
  private buildStep2Identity(): void {
    Column({ space: 18 }) {
      Column({ space: 8 }) {
        Text('\u8eab\u4efd\u8ba4\u8bc1')
          .fontSize(this.careMode ? 36 : 30)
          .fontWeight(FontWeight.Bold)
          .fontColor('#431407')
          .width('100%')
        if (this.accountName.length > 0) {
          Text(this.accountName + '  ' + this.accountPhone)
            .fontSize(this.careMode ? 18 : 14)
            .fontColor('#7A5C45')
            .width('100%')
        }
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

      Column({ space: 12 }) {
        Text('\u6211\u662f\u8001\u4eba')
          .fontSize(this.careMode ? 26 : 21)
          .fontWeight(FontWeight.Bold)
          .fontColor('#431407')
          .width('100%')
        Text('\u8fdb\u5165\u8d2d\u7269\u5546\u57ce\uff0c\u53ef\u4ee5\u8f93\u5165\u9700\u6c42\u3001\u67e5\u770b\u6bd4\u4ef7\u3001\u9009\u62e9\u5730\u5740\u5e76\u5b8c\u6210\u6a21\u62df\u652f\u4ed8\u3002')
          .fontSize(this.careMode ? 18 : 14)
          .fontColor('#6B4E3D')
          .lineHeight(this.careMode ? 28 : 21)
          .width('100%')
        Button('\u8ba4\u8bc1\u4e3a\u8001\u4eba\u5e76\u8d2d\u7269')
          .width('100%')
          .height(this.careMode ? 56 : 48)
          .fontSize(this.careMode ? 19 : 16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor('#378F85')
          .borderRadius(8)
          .onClick(() => {
            this.certify(AccountRole.Elderly);
          })
      }
      .width('100%')
      .padding(18)
      .backgroundColor(Color.White)
      .borderRadius(8)
      .border({ width: 1, color: '#E8DDD2' })

      Column({ space: 12 }) {
        Text('\u6211\u662f\u5b50\u5973')
          .fontSize(this.careMode ? 26 : 21)
          .fontWeight(FontWeight.Bold)
          .fontColor('#431407')
          .width('100%')
        Text('\u8fdb\u5165\u5bb6\u5ead\u534f\u52a9\u5de5\u4f5c\u53f0\uff0c\u7ed1\u5b9a\u8001\u4eba\u540e\u53ef\u4ee5\u7ef4\u62a4\u5730\u5740\u3001\u67e5\u770b\u63d0\u9192\uff0c\u4e5f\u53ef\u4ee5\u5e2e\u52a9\u8001\u4eba\u8d2d\u7269\u3002')
          .fontSize(this.careMode ? 18 : 14)
          .fontColor('#6B4E3D')
          .lineHeight(this.careMode ? 28 : 21)
          .width('100%')
        Button('\u8ba4\u8bc1\u4e3a\u5b50\u5973\u5e76\u7ed1\u5b9a\u8001\u4eba')
          .width('100%')
          .height(this.careMode ? 56 : 48)
          .fontSize(this.careMode ? 19 : 16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor('#2B7068')
          .borderRadius(8)
          .onClick(() => {
            this.certify(AccountRole.Child);
          })
      }
      .width('100%')
      .padding(18)
      .backgroundColor(Color.White)
      .borderRadius(8)
      .border({ width: 1, color: '#E8DDD2' })

      Column({ space: 12 }) {
        Text('\u6211\u662f\u7ba1\u7406\u5458')
          .fontSize(this.careMode ? 26 : 21)
          .fontWeight(FontWeight.Bold)
          .fontColor('#431407')
          .width('100%')
        Text('\u8fdb\u5165\u7ba1\u7406\u63a7\u5236\u53f0\uff0c\u7ba1\u7406\u7528\u6237\u3001\u5ba1\u6838\u5165\u9a7b\u3001\u67e5\u770b\u8ba2\u5355\u548c\u5ba1\u8ba1\u65e5\u5fd7\u3002')
          .fontSize(this.careMode ? 18 : 14)
          .fontColor('#6B4E3D')
          .lineHeight(this.careMode ? 28 : 21)
          .width('100%')
        Button('\u8ba4\u8bc1\u4e3a\u7ba1\u7406\u5458')
          .width('100%')
          .height(this.careMode ? 56 : 48)
          .fontSize(this.careMode ? 19 : 16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor('#5C5048')
          .borderRadius(8)
          .onClick(() => {
            this.certify(AccountRole.Admin);
          })
      }
      .width('100%')
      .padding(18)
      .backgroundColor(Color.White)
      .borderRadius(8)
      .border({ width: 1, color: '#E8DDD2' })

      Column({ space: 12 }) {
        Text('\u6211\u662f\u5ba2\u670d')
          .fontSize(this.careMode ? 26 : 21)
          .fontWeight(FontWeight.Bold)
          .fontColor('#431407')
          .width('100%')
        Text('\u8fdb\u5165\u5ba2\u670d\u5de5\u4f5c\u53f0\uff0c\u5904\u7406\u8001\u4eba\u548c\u5b50\u5973\u7684\u54a8\u8be2\u3001\u67e5\u770b\u5de5\u5355\u548c\u8ba2\u5355\u3002')
          .fontSize(this.careMode ? 18 : 14)
          .fontColor('#6B4E3D')
          .lineHeight(this.careMode ? 28 : 21)
          .width('100%')
        Button('\u8ba4\u8bc1\u4e3a\u5ba2\u670d')
          .width('100%')
          .height(this.careMode ? 56 : 48)
          .fontSize(this.careMode ? 19 : 16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor('#6D4C41')
          .borderRadius(8)
          .onClick(() => {
            this.certify(AccountRole.CustomerService);
          })
      }
      .width('100%')
      .padding(18)
      .backgroundColor(Color.White)
      .borderRadius(8)
      .border({ width: 1, color: '#E8DDD2' })

      Button('\u9000\u51fa\u5f53\u524d\u8d26\u53f7')
        .width('100%')
        .height(this.careMode ? 52 : 44)
        .fontSize(this.careMode ? 18 : 15)
        .fontColor('#2B7068')
        .backgroundColor('#EFFAF8')
        .borderRadius(8)
        .onClick(() => {
          AppBackendService.logout();
          RouteUtils.clearAndPush(this.getUIContext(), 'pages/Login');
        })
    }
    .width('100%')
  }

  @Builder
  private buildStep3BindFamily(): void {
    Column({ space: 14 }) {
      Column({ space: 8 }) {
        Text('\u7ed1\u5b9a\u8001\u4eba\u8d26\u53f7')
          .fontSize(this.careMode ? 28 : 22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#431407')
          .width('100%')
        Text('\u8ba4\u8bc1\u6210\u529f\uff01\u8bf7\u7ed1\u5b9a\u8001\u4eba\u8d26\u53f7\uff0c\u7ed1\u5b9a\u540e\u53ef\u5e2e\u52a9\u8001\u4eba\u8d2d\u7269\u3002')
          .fontSize(this.careMode ? 17 : 14)
          .fontColor('#6D6258')
          .lineHeight(this.careMode ? 26 : 20)
          .width('100%')
      }
      .width('100%')
      .padding(14)
      .backgroundColor('#E8F5E9')
      .borderRadius(8)

      Column({ space: 12 }) {
        Text('\u8f93\u5165\u7ed1\u5b9a\u4fe1\u606f')
          .fontSize(this.careMode ? 24 : 20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#431407')
          .width('100%')
        Text('\u6f14\u793a\u7ed1\u5b9a\u7801\uff1aHS2026\uff0c\u4e5f\u53ef\u4ee5\u8f93\u5165\u8001\u4eba\u624b\u673a\u53f7 13800000001\u3002')
          .fontSize(this.careMode ? 17 : 14)
          .fontColor('#6D6258')
          .lineHeight(this.careMode ? 26 : 20)
          .width('100%')
        TextInput({ placeholder: '\u8001\u4eba\u624b\u673a\u53f7\u6216\u7ed1\u5b9a\u7801', text: $$this.keyword })
          .height(this.careMode ? 60 : 50)
          .fontSize(this.careMode ? 20 : 16)
          .backgroundColor('#FAF7F2')
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
        Button('\u7acb\u5373\u7ed1\u5b9a')
          .width('100%')
          .height(this.careMode ? 56 : 48)
          .fontSize(this.careMode ? 19 : 16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor('#378F85')
          .borderRadius(8)
          .onClick(() => {
            this.bindFamily();
          })
        if (this.message.length > 0) {
          Text(this.message)
            .fontSize(this.careMode ? 17 : 14)
            .fontColor('#2B7068')
            .width('100%')
            .padding(12)
            .backgroundColor('#EFFAF8')
            .borderRadius(8)
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Color.White)
      .borderRadius(8)
      .border({ width: 1, color: '#E8DDD2' })

      Column({ space: 12 }) {
        Row() {
          Text('\u5df2\u7ed1\u5b9a\u8001\u4eba')
            .fontSize(this.careMode ? 24 : 20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#431407')
          Blank()
          Button('\u5e2e\u52a9\u8d2d\u7269')
            .height(this.careMode ? 40 : 34)
            .fontSize(this.careMode ? 16 : 13)
            .fontColor(Color.White)
            .backgroundColor('#2B7068')
            .borderRadius(8)
            .onClick(() => {
              if (!AppBackendService.canEnterShopping()) {
                RouteUtils.showToast(this.getUIContext(), '\u8bf7\u5148\u7ed1\u5b9a\u8001\u4eba\u8d26\u53f7');
                return;
              }
              RouteUtils.clearAndPush(this.getUIContext(), 'pages/UserHome');
            })
        }
        .width('100%')

        if (this.bindings.length === 0) {
          Text('\u6682\u65e0\u7ed1\u5b9a\u8bb0\u5f55')
            .fontSize(this.careMode ? 18 : 15)
            .fontColor('#7A5C45')
            .width('100%')
            .padding(14)
            .backgroundColor('#FAF7F2')
            .borderRadius(8)
        } else {
          ForEach(this.bindings, (item: FamilyBinding) => {
            Column({ space: 8 }) {
              Text(AppBackendService.getAccountName(item.elderlyAccountId))
                .fontSize(this.careMode ? 22 : 18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#431407')
                .width('100%')
              Text('\u624b\u673a\u53f7\uff1a' + AppBackendService.getAccountPhone(item.elderlyAccountId) + ' \u00b7 \u7ed1\u5b9a\u7801\uff1a' + item.bindingCode)
                .fontSize(this.careMode ? 17 : 14)
                .fontColor('#6B4E3D')
                .width('100%')
              Text('\u72b6\u6001\uff1a' + item.status + ' \u00b7 \u65f6\u95f4\uff1a' + item.createdAt)
                .fontSize(this.careMode ? 16 : 13)
                .fontColor('#7A5C45')
                .width('100%')
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#FAF7F2')
            .borderRadius(8)
          }, (item: FamilyBinding) => item.id)
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Color.White)
      .borderRadius(8)
      .border({ width: 1, color: '#E8DDD2' })

      Button('\u7a0d\u540e\u7ed1\u5b9a\uff0c\u5148\u770b\u770b')
        .width('100%')
        .height(this.careMode ? 44 : 36)
        .fontSize(this.careMode ? 17 : 14)
        .fontColor('#6D6258')
        .backgroundColor(Color.Transparent)
        .borderRadius(8)
        .onClick(() => {
          RouteUtils.clearAndPush(this.getUIContext(), 'pages/ChildHome');
        })
    }
    .width('100%')
  }

  build() {
    Scroll() {
      Row() {
        Column({ space: 14 }) {
          if (this.step === 1) {
            this.buildStep1LinkPhone()
          } else if (this.step === 2) {
            this.buildStep2Identity()
          } else if (this.step === 3) {
            this.buildStep3BindFamily()
          }
        }
        .width('100%')
        .padding(24)
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
