import { AppHeader } from '../components/AppHeader';
import { BottomNav } from '../components/BottomNav';
import { FamilyBinding } from '../models/AuthModels';
import { BackendResult, BindingListBackendData } from '../models/BackendModels';
import { AppBackendService } from '../services/AppBackendService';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';

@Entry
@Component
struct BindFamily {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @State keyword: string = 'HS2026';
  @State message: string = '';
  @State bindings: FamilyBinding[] = [];

  async aboutToAppear(): Promise<void> {
    await this.refresh();
  }

  private async refresh(): Promise<void> {
    const remoteResult = await AppBackendService.listFamilyBindingsRemote();
    if (remoteResult.success && remoteResult.data && remoteResult.data.bindings.length > 0) {
      this.bindings = remoteResult.data.bindings;
      return;
    }
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
      RouteUtils.showToast(this.getUIContext(), '绑定异常，请稍后重试');
    }
  }

  private accountCenter(): void {
    RouteUtils.replacePage(this.getUIContext(), 'pages/Index');
  }

  private assistShopping(): void {
    if (!AppBackendService.canEnterShopping()) {
      RouteUtils.showToast(this.getUIContext(), '请先绑定老人账号');
      return;
    }
    RouteUtils.replacePage(this.getUIContext(), 'pages/UserHome');
  }

  build() {
    Column() {
      AppHeader({
        title: '绑定老人账号',
        subtitle: '绑定后可维护地址、查看提醒，并帮助老人购物',
        roleText: '子女端',
        actionText: '账号',
        careMode: this.careMode,
        onSwitchRole: () => {
          this.accountCenter();
        }
      })

      Scroll() {
        Row() {
          Column({ space: 14 }) {
          Column({ space: 12 }) {
            Text('输入绑定信息')
              .fontSize(this.careMode ? 24 : 20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#431407')
              .width('100%')
            Text('演示绑定码：HS2026，也可以输入老人手机号 13800000001。')
              .fontSize(this.careMode ? 17 : 14)
              .fontColor('#6D6258')
              .lineHeight(this.careMode ? 26 : 20)
              .width('100%')
            TextInput({ placeholder: '老人手机号或绑定码', text: $$this.keyword })
              .height(this.careMode ? 60 : 50)
              .fontSize(this.careMode ? 20 : 16)
              .backgroundColor('#FAF7F2')
              .borderRadius(8)
              .padding({ left: 12, right: 12 })
            Button('立即绑定')
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
              Text('已绑定老人')
                .fontSize(this.careMode ? 24 : 20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#431407')
              Blank()
              Button('帮助购物')
                .height(this.careMode ? 40 : 34)
                .fontSize(this.careMode ? 16 : 13)
                .fontColor(Color.White)
                .backgroundColor('#2B7068')
                .borderRadius(8)
                .onClick(() => {
                  this.assistShopping();
                })
            }
            .width('100%')

            if (this.bindings.length === 0) {
              Text('暂无绑定记录')
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
                  Text('手机号：' + AppBackendService.getAccountPhone(item.elderlyAccountId) + ' · 绑定码：' + item.bindingCode)
                    .fontSize(this.careMode ? 17 : 14)
                    .fontColor('#6B4E3D')
                    .width('100%')
                  Text('状态：' + item.status + ' · 时间：' + item.createdAt)
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
        }
        .width('100%')
        .padding(16)
        .constraintSize({ maxWidth: this.breakpoint === 'sm' ? 10000 : 720 })
        .onAppear(() => {
          this.refresh();
        })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .layoutWeight(1)

      BottomNav({
        role: 'child',
        active: 'profile',
        careMode: this.careMode,
        onNavigate: (url: string) => {
          RouteUtils.replacePage(this.getUIContext(), url);
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3EFE8')
  }
}
