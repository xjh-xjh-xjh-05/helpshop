import { Account, AccountRole } from '../models/AuthModels';
import { AppBackendService } from '../services/AppBackendService';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';

@Entry
@Component
struct Index {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @StorageLink('avatarUri') avatarUri: string = '';
  @StorageLink('nickName') nickName: string = '';
  @State accountName: string = '\u672a\u767b\u5f55';
  @State accountPhone: string = '';
  @State roleText: string = '\u672a\u8ba4\u8bc1';
  @State canShop: boolean = false;

  aboutToAppear(): void {
    this.refresh();
    if (!AppBackendService.isLoggedIn()) {
      RouteUtils.replacePage(this.getUIContext(), 'pages/Login');
    }
  }

  private refresh(): void {
    const account: Account | undefined = AppBackendService.getCurrentAccount();
    if (account) {
      this.accountName = account.displayName;
      this.accountPhone = account.phone;
      this.roleText = AppBackendService.roleName(account.defaultRole);
      this.canShop = AppBackendService.canEnterShopping();
    } else {
      this.accountName = '未登录';
      this.accountPhone = '';
      this.roleText = '未认证';
      this.canShop = false;
    }
  }

  private enterHome(): void {
    const role = AppBackendService.getCurrentRole();
    if (role === AccountRole.Unverified) {
      RouteUtils.pushPage(this.getUIContext(), 'pages/IdentityAuth');
      return;
    }
    if (role === AccountRole.Admin) {
      RouteUtils.replacePage(this.getUIContext(), 'pages/AdminHome');
      return;
    }
    if (role === AccountRole.CustomerService) {
      RouteUtils.replacePage(this.getUIContext(), 'pages/CustomerServiceHome');
      return;
    }
    if (role === AccountRole.Elderly) {
      RouteUtils.replacePage(this.getUIContext(), 'pages/UserHome');
      return;
    }
    if (role === AccountRole.Child) {
      if (AppBackendService.canEnterShopping()) {
        RouteUtils.replacePage(this.getUIContext(), 'pages/ChildHome');
      } else {
        RouteUtils.replacePage(this.getUIContext(), 'pages/BindFamily');
      }
      return;
    }
    RouteUtils.replacePage(this.getUIContext(), 'pages/ChildHome');
  }

  private enterShopping(): void {
    const role = AppBackendService.getCurrentRole();
    if (role === AccountRole.Unverified) {
      RouteUtils.showToast(this.getUIContext(), '请先完成身份认证');
      RouteUtils.pushPage(this.getUIContext(), 'pages/IdentityAuth');
      return;
    }
    if (!AppBackendService.canEnterShopping()) {
      RouteUtils.showToast(this.getUIContext(), '子女需要先绑定老人账号，才能帮助购物');
      RouteUtils.pushPage(this.getUIContext(), 'pages/BindFamily');
      return;
    }
    RouteUtils.replacePage(this.getUIContext(), 'pages/UserHome');
  }

  private logout(): void {
    AppBackendService.logout();
    RouteUtils.showToast(this.getUIContext(), '已退出登录');
    RouteUtils.clearAndPush(this.getUIContext(), 'pages/Login');
  }

  build() {
    Scroll() {
      Row() {
        Column({ space: 18 }) {
          Column({ space: 10 }) {
            Text('银发智购')
              .fontSize(this.careMode ? 38 : 32)
              .fontWeight(FontWeight.Bold)
              .fontColor('#431407')
              .width('100%')
            Text('统一账号登录，应用内完成老人或子女身份认证。子女绑定老人后，也可以进入商城帮助老人下单。')
              .fontSize(this.careMode ? 21 : 17)
              .fontColor('#6D6258')
              .lineHeight(this.careMode ? 30 : 24)
              .width('100%')
            Row({ space: 8 }) {
              Text('老人可购物')
                .fontSize(this.careMode ? 16 : 13)
                .fontColor('#2B7068')
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor('#EFFAF8')
                .borderRadius(8)
              Text('子女可代买')
                .fontSize(this.careMode ? 16 : 13)
                .fontColor('#2B7068')
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor('#EFFAF8')
                .borderRadius(8)
              Text('绑定后提醒')
                .fontSize(this.careMode ? 16 : 13)
                .fontColor('#2B7068')
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor('#EFFAF8')
                .borderRadius(8)
            }
            .width('100%')
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#FAF7F2')
          .borderRadius(8)
          .border({ width: 1, color: '#E8DDD2' })

          Column({ space: 12 }) {
            Row({ space: 14 }) {
              if (this.avatarUri.length > 0) {
                Image(this.avatarUri)
                  .width(this.careMode ? 56 : 44)
                  .height(this.careMode ? 56 : 44)
                  .borderRadius(this.careMode ? 28 : 22)
                  .objectFit(ImageFit.Cover)
                  .alt($r('app.media.startIcon'))
              } else {
                Image($r('app.media.startIcon'))
                  .width(this.careMode ? 56 : 44)
                  .height(this.careMode ? 56 : 44)
                  .borderRadius(this.careMode ? 28 : 22)
                  .objectFit(ImageFit.Cover)
              }
              Column({ space: 4 }) {
                Row() {
                  Text(this.roleText)
                    .fontSize(this.careMode ? 16 : 13)
                    .fontColor('#2B7068')
                    .fontWeight(FontWeight.Bold)
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .backgroundColor('#EFFAF8')
                    .borderRadius(8)
                  Blank()
                  Text(this.accountPhone)
                    .fontSize(this.careMode ? 16 : 13)
                    .fontColor('#7A5C45')
                }
                .width('100%')

                Text(this.nickName.length > 0 ? this.nickName : this.accountName)
                  .fontSize(this.careMode ? 30 : 24)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#431407')
                  .width('100%')
              }
              .layoutWeight(1)
            }
            .width('100%')
            Text('登录账号不等于业务身份。请先完成老人或子女身份认证；子女绑定老人后，也可以进入购物商城帮助老人下单。')
              .fontSize(this.careMode ? 18 : 14)
              .fontColor('#6B4E3D')
              .lineHeight(this.careMode ? 28 : 21)
              .width('100%')

            Button('进入我的工作台')
              .width('100%')
              .height(this.careMode ? 56 : 48)
              .fontSize(this.careMode ? 19 : 16)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .backgroundColor('#378F85')
              .borderRadius(8)
              .onClick(() => {
                this.enterHome();
              })

            Button('帮助老人购物')
              .width('100%')
              .height(this.careMode ? 52 : 44)
              .fontSize(this.careMode ? 18 : 15)
              .fontColor(this.canShop ? '#FFFFFF' : '#2B7068')
              .backgroundColor(this.canShop ? '#2B7068' : '#EFFAF8')
              .borderRadius(8)
              .onClick(() => {
                this.enterShopping();
              })

            Button('身份认证 / 家庭绑定')
              .width('100%')
              .height(this.careMode ? 52 : 44)
              .fontSize(this.careMode ? 18 : 15)
              .fontColor('#2B7068')
              .backgroundColor('#EFFAF8')
              .borderRadius(8)
              .onClick(() => {
                RouteUtils.pushPage(this.getUIContext(), AppBackendService.getCurrentRole() === AccountRole.Child ? 'pages/BindFamily' : 'pages/IdentityAuth');
              })

            Button('退出登录')
              .width('100%')
              .height(this.careMode ? 52 : 44)
              .fontSize(this.careMode ? 18 : 15)
              .fontColor('#2B7068')
              .backgroundColor('#FAF7F2')
              .borderRadius(8)
              .onClick(() => {
                this.logout();
              })
          }
          .width('100%')
          .padding(18)
          .backgroundColor(Color.White)
          .borderRadius(8)
          .border({ width: 1, color: '#E8DDD2' })

          Row() {
            Text('关怀模式')
              .fontSize(this.careMode ? 20 : 16)
              .fontColor('#5C5048')
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.careMode })
              .onChange((isOn: boolean) => {
                this.careMode = isOn;
              })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(8)
          .border({ width: 1, color: '#E8DDD2' })
        }
        .width('100%')
        .padding(18)
        .constraintSize({ maxWidth: this.breakpoint === 'sm' ? 10000 : 720 })
        .onAppear(() => {
          this.refresh();
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3EFE8')
  }
}
