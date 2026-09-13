import { AppBackendService } from '../services/AppBackendService';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';

@Entry
@Component
struct Register {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @State phone: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';
  @State displayName: string = '';

  private async register(): Promise<void> {
    if (this.phone.trim().length === 0) {
      RouteUtils.showToast(this.getUIContext(), '请输入手机号');
      return;
    }
    if (this.displayName.trim().length === 0) {
      RouteUtils.showToast(this.getUIContext(), '请输入姓名');
      return;
    }
    if (this.password.length === 0) {
      RouteUtils.showToast(this.getUIContext(), '请输入密码');
      return;
    }
    if (this.password !== this.confirmPassword) {
      RouteUtils.showToast(this.getUIContext(), '两次密码不一致');
      return;
    }
    try {
      const result = await AppBackendService.registerRemote(this.phone.trim(), this.password, this.displayName.trim());
      if (!result.success) {
        RouteUtils.showToast(this.getUIContext(), result.message);
        return;
      }
      RouteUtils.showToast(this.getUIContext(), '注册成功，请完成身份认证');
      RouteUtils.pushPage(this.getUIContext(), 'pages/IdentityAuth');
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '注册异常，请稍后重试');
    }
  }

  build() {
    Scroll() {
      Row() {
        Column() {
          Row() {
            Button('<')
              .width(40)
              .height(40)
              .fontSize(18)
              .fontColor('#378F85')
              .backgroundColor('#EFFAF8')
              .borderRadius(8)
              .onClick(() => {
                RouteUtils.goBack(this.getUIContext());
              })
            Blank()
          }
          .width('100%')

          Column({ space: 6 }) {
            Text('创建账号')
              .fontSize(this.careMode ? 34 : 28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#431407')
            Text('注册后完成身份认证')
              .fontSize(this.careMode ? 18 : 14)
              .fontColor('#6F5B4B')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 18, bottom: 18 })

          Column({ space: 12 }) {
            TextInput({ placeholder: '手机号', text: $$this.phone })
              .type(InputType.PhoneNumber)
              .height(this.careMode ? 60 : 50)
              .fontSize(this.careMode ? 20 : 16)
              .backgroundColor('#FAF7F2')
              .borderRadius(8)
              .padding({ left: 14, right: 14 })

            TextInput({ placeholder: '姓名', text: $$this.displayName })
              .height(this.careMode ? 60 : 50)
              .fontSize(this.careMode ? 20 : 16)
              .backgroundColor('#FAF7F2')
              .borderRadius(8)
              .padding({ left: 14, right: 14 })

            TextInput({ placeholder: '密码', text: $$this.password })
              .type(InputType.Password)
              .height(this.careMode ? 60 : 50)
              .fontSize(this.careMode ? 20 : 16)
              .backgroundColor('#FAF7F2')
              .borderRadius(8)
              .padding({ left: 14, right: 14 })

            TextInput({ placeholder: '确认密码', text: $$this.confirmPassword })
              .type(InputType.Password)
              .height(this.careMode ? 60 : 50)
              .fontSize(this.careMode ? 20 : 16)
              .backgroundColor('#FAF7F2')
              .borderRadius(8)
              .padding({ left: 14, right: 14 })

            Button('注册')
              .width('100%')
              .height(this.careMode ? 58 : 48)
              .fontSize(this.careMode ? 20 : 17)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .backgroundColor('#378F85')
              .borderRadius(8)
              .onClick(() => {
                this.register();
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
  }
}
