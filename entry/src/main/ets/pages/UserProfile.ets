import { BottomNav } from '../components/BottomNav';
import { Account, AccountRole, ElderlyProfile } from '../models/AuthModels';
import { BackendResult, ProfileStatsBackendData } from '../models/BackendModels';
import { Address } from '../models/ShoppingModels';
import { AppBackendService } from '../services/AppBackendService';
import { AuthService } from '../services/AuthService';
import { TTSService } from '../services/TTSService';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';

@Entry
@Component
struct UserProfile {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('avatarUri') avatarUri: string = '';
  @StorageLink('nickName') nickName: string = '';
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @StorageLink('voicePromptEnabled') voicePromptEnabled: boolean = true;
  @State orderCount: number = 0;
  @State addressCount: number = 0;
  @State reminderCount: number = 0;
  @State accountName: string = '\u7528\u6237\u8d26\u53f7';
  @State accountPhone: string = '';
  @State bindingCode: string = '';
  @State showFeedback: boolean = false;
  @State feedbackTitle: string = '';
  @State feedbackContent: string = '';
  @State feedbackSubmitting: boolean = false;
  @State addresses: Address[] = [];
  @State editingProfile: boolean = false;
  @State editRealName: string = '';
  @State editAge: string = '';
  @State editEmergencyPhone: string = '';
  @State editNickName: string = '';
  @State profileSubmitting: boolean = false;

  aboutToAppear(): void {
    this.refresh();
  }

  private async refresh(): Promise<void> {
    try {
      const result: BackendResult<ProfileStatsBackendData> = await AppBackendService.getProfileStatsRemote();
      const account: Account | undefined = result.data ? result.data.account : undefined;
      this.accountName = account ? account.displayName : '用户账号';
      this.accountPhone = account ? account.phone : '';
      this.orderCount = result.data ? result.data.orderCount : 0;
      this.addressCount = result.data ? result.data.addressCount : 0;
      this.reminderCount = result.data ? result.data.reminderCount : 0;
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '加载失败，请稍后重试');
    }
    const account: Account | undefined = AppBackendService.getCurrentAccount();
    if (account) {
      const profile: ElderlyProfile | undefined = AuthService.getElderlyProfile(account.id);
      if (profile) {
        this.bindingCode = profile.bindingCode;
      }
    }
    try {
      const addressResult: BackendResult<Address[]> = await AppBackendService.listAddressesRemote();
      if (addressResult.data) {
        this.addresses = addressResult.data;
        this.addressCount = addressResult.data.length;
      }
    } catch (error) {
    }
  }

  private startEditProfile(): void {
    const account: Account | undefined = AppBackendService.getCurrentAccount();
    if (!account) {
      return;
    }
    const profile: ElderlyProfile | undefined = AuthService.getElderlyProfile(account.id);
    this.editRealName = profile ? profile.realName : account.displayName;
    this.editAge = profile ? profile.age.toString() : '0';
    this.editEmergencyPhone = profile ? profile.emergencyPhone : '';
    this.editNickName = this.nickName.length > 0 ? this.nickName : account.displayName;
    this.editingProfile = true;
  }

  private async saveProfile(): Promise<void> {
    if (this.editRealName.trim().length === 0) {
      RouteUtils.showToast(this.getUIContext(), '请输入真实姓名');
      return;
    }
    const ageNum: number = parseInt(this.editAge) || 0;
    this.profileSubmitting = true;
    try {
      const result = await AppBackendService.updateElderlyProfileRemote(
        this.editRealName.trim(), ageNum, this.editEmergencyPhone.trim(), this.editNickName.trim()
      );
      if (result.success) {
        this.nickName = this.editNickName.trim();
        this.accountName = this.editRealName.trim();
        this.editingProfile = false;
        RouteUtils.showToast(this.getUIContext(), '档案更新成功');
        this.refresh();
      } else {
        RouteUtils.showToast(this.getUIContext(), result.message);
      }
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '更新异常，请稍后重试');
    }
    this.profileSubmitting = false;
  }

  @Builder
  private StatItem(label: string, value: string) {
    Column({ space: 5 }) {
      Text(value)
        .fontSize(this.careMode ? 26 : 22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#378F85')
      Text(label)
        .fontSize(this.careMode ? 16 : 13)
        .fontColor('#6D6258')
    }
    .layoutWeight(1)
  }

  @Builder
  private ActionRow(title: string, desc: string, url: string) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(title)
          .fontSize(this.careMode ? 21 : 17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#431407')
          .width('100%')
        Text(desc)
          .fontSize(this.careMode ? 16 : 13)
          .fontColor('#6D6258')
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('>')
        .fontSize(18)
        .fontColor('#2B7068')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(8)
    .border({ width: 1, color: '#E8DDD2' })
    .onClick(() => {
      RouteUtils.replacePage(this.getUIContext(), url);
    })
  }

  private async submitFeedback(): Promise<void> {
    if (this.feedbackTitle.trim().length === 0) {
      RouteUtils.showToast(this.getUIContext(), '请输入反馈标题');
      return;
    }
    if (this.feedbackContent.trim().length === 0) {
      RouteUtils.showToast(this.getUIContext(), '请输入反馈内容');
      return;
    }
    this.feedbackSubmitting = true;
    try {
      const result = await AppBackendService.submitFeedbackRemote(this.feedbackTitle.trim(), this.feedbackContent.trim());
      if (result.success) {
        RouteUtils.showToast(this.getUIContext(), '反馈已提交，客服将尽快处理');
        this.feedbackTitle = '';
        this.feedbackContent = '';
        this.showFeedback = false;
      } else {
        RouteUtils.showToast(this.getUIContext(), result.message);
      }
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '提交异常，请稍后重试');
    }
    this.feedbackSubmitting = false;
  }

  build() {
    Column() {
      Column({ space: 8 }) {
        Row() {
          Text('我的')
            .fontSize(this.careMode ? 30 : 24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#431407')
          Blank()
          Button('账号')
            .height(34)
            .fontSize(this.careMode ? 16 : 13)
            .fontColor('#2B7068')
            .backgroundColor('#EFFAF8')
            .borderRadius(8)
            .onClick(() => {
              RouteUtils.replacePage(this.getUIContext(), 'pages/Index');
            })
        }
        .width('100%')
        Text('账号、订单和关怀设置。')
          .fontSize(this.careMode ? 17 : 13)
          .fontColor('#6F5B4B')
          .width('100%')
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#F3EFE8')

       Scroll() {
         Row() {
           Column({ space: 12 }) {
          Column({ space: 14 }) {
            Row({ space: 14 }) {
              if (this.avatarUri.length > 0) {
                Image(this.avatarUri)
                  .width(this.careMode ? 64 : 52)
                  .height(this.careMode ? 64 : 52)
                  .borderRadius(this.careMode ? 32 : 26)
                  .objectFit(ImageFit.Cover)
                  .alt($r('app.media.startIcon'))
              } else {
                Image($r('app.media.startIcon'))
                  .width(this.careMode ? 64 : 52)
                  .height(this.careMode ? 64 : 52)
                  .borderRadius(this.careMode ? 32 : 26)
                  .objectFit(ImageFit.Cover)
              }
              Column({ space: 4 }) {
                Text(this.nickName.length > 0 ? this.nickName : this.accountName)
                  .fontSize(this.careMode ? 28 : 23)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#431407')
                  .width('100%')
                Text('\u624b\u673a\u53f7\uff1a' + this.accountPhone)
                  .fontSize(this.careMode ? 17 : 14)
                  .fontColor('#6D6258')
                  .width('100%')
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              if (!this.editingProfile) {
                Button('编辑')
                  .height(32)
                  .fontSize(this.careMode ? 16 : 13)
                  .fontColor('#2B7068')
                  .backgroundColor('#EFFAF8')
                  .borderRadius(8)
                  .onClick(() => {
                    this.startEditProfile();
                  })
              }
            }
            .width('100%')

            if (this.editingProfile) {
              Column({ space: 10 }) {
                Row() {
                  Text('昵称')
                    .fontSize(this.careMode ? 17 : 14)
                    .fontColor('#5C5048')
                    .width(80)
                  TextInput({ placeholder: '昵称', text: $$this.editNickName })
                    .layoutWeight(1)
                    .height(this.careMode ? 52 : 44)
                    .fontSize(this.careMode ? 18 : 15)
                    .backgroundColor('#FAF7F2')
                    .borderRadius(8)
                }
                .width('100%')
                Row() {
                  Text('真实姓名')
                    .fontSize(this.careMode ? 17 : 14)
                    .fontColor('#5C5048')
                    .width(80)
                  TextInput({ placeholder: '真实姓名', text: $$this.editRealName })
                    .layoutWeight(1)
                    .height(this.careMode ? 52 : 44)
                    .fontSize(this.careMode ? 18 : 15)
                    .backgroundColor('#FAF7F2')
                    .borderRadius(8)
                }
                .width('100%')
                Row() {
                  Text('年龄')
                    .fontSize(this.careMode ? 17 : 14)
                    .fontColor('#5C5048')
                    .width(80)
                  TextInput({ placeholder: '年龄', text: $$this.editAge })
                    .layoutWeight(1)
                    .height(this.careMode ? 52 : 44)
                    .fontSize(this.careMode ? 18 : 15)
                    .backgroundColor('#FAF7F2')
                    .borderRadius(8)
                    .type(InputType.Number)
                }
                .width('100%')
                Row() {
                  Text('紧急电话')
                    .fontSize(this.careMode ? 17 : 14)
                    .fontColor('#5C5048')
                    .width(80)
                  TextInput({ placeholder: '紧急联系电话', text: $$this.editEmergencyPhone })
                    .layoutWeight(1)
                    .height(this.careMode ? 52 : 44)
                    .fontSize(this.careMode ? 18 : 15)
                    .backgroundColor('#FAF7F2')
                    .borderRadius(8)
                    .type(InputType.PhoneNumber)
                }
                .width('100%')
                Row({ space: 10 }) {
                  Button('取消')
                    .layoutWeight(1)
                    .height(this.careMode ? 48 : 40)
                    .fontSize(this.careMode ? 17 : 14)
                    .fontColor('#2B7068')
                    .backgroundColor('#EFFAF8')
                    .borderRadius(8)
                    .onClick(() => {
                      this.editingProfile = false;
                    })
                  Button(this.profileSubmitting ? '保存中...' : '保存')
                    .layoutWeight(1)
                    .height(this.careMode ? 48 : 40)
                    .fontSize(this.careMode ? 17 : 14)
                    .fontColor(Color.White)
                    .backgroundColor('#378F85')
                    .borderRadius(8)
                    .enabled(!this.profileSubmitting)
                    .onClick(() => {
                      this.saveProfile();
                    })
                }
                .width('100%')
              }
              .width('100%')
            }

            Row() {
              this.StatItem('订单', this.orderCount.toString())
              this.StatItem('地址', this.addressCount.toString())
              this.StatItem('提醒', this.reminderCount.toString())
            }
            .width('100%')
          }
          .width('100%')
          .padding(18)
          .backgroundColor(Color.White)
          .borderRadius(8)
          .border({ width: 1, color: '#E8DDD2' })

             this.ActionRow('购物订单', '查看已完成支付的记录', 'pages/OrderHistory')

             Column({ space: 12 }) {
               Row() {
                 Text('收货地址')
                   .fontSize(this.careMode ? 22 : 18)
                   .fontWeight(FontWeight.Bold)
                   .fontColor('#431407')
                 Blank()
                 Text(this.addresses.length.toString() + ' 个')
                   .fontSize(this.careMode ? 16 : 13)
                   .fontColor('#2B7068')
                   .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                   .backgroundColor('#EFFAF8')
                   .borderRadius(8)
               }
               .width('100%')
               if (this.addresses.length === 0) {
                 Text('暂无收货地址，可由子女端添加')
                   .fontSize(this.careMode ? 18 : 15)
                   .fontColor('#7A5C45')
                   .width('100%')
                   .padding(14)
                   .backgroundColor('#FAF7F2')
                   .borderRadius(8)
               } else {
                 ForEach(this.addresses, (item: Address) => {
                   Column({ space: 6 }) {
                     Row() {
                       Text(item.receiver)
                         .fontSize(this.careMode ? 20 : 16)
                         .fontWeight(FontWeight.Bold)
                         .fontColor('#431407')
                       Blank()
                       if (item.isDefault) {
                         Text('默认')
                           .fontSize(this.careMode ? 14 : 11)
                           .fontColor('#378F85')
                           .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                           .backgroundColor('#EFFAF8')
                           .borderRadius(4)
                       }
                     }
                     .width('100%')
                     Text(item.phone + ' · ' + item.detail)
                       .fontSize(this.careMode ? 16 : 13)
                       .fontColor('#6B4E3D')
                       .width('100%')
                   }
                   .width('100%')
                   .padding(12)
                   .backgroundColor('#FAF7F2')
                   .borderRadius(8)
                 }, (item: Address) => item.id)
               }
             }
             .width('100%')
             .padding(16)
             .backgroundColor(Color.White)
             .borderRadius(8)
             .border({ width: 1, color: '#E8DDD2' })

            Column({ space: 12 }) {
              Text('账号中心')
                .fontSize(this.careMode ? 22 : 18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#431407')
                .width('100%')

              Column({ space: 8 }) {
                Row() {
                  Text('我的绑定码')
                    .fontSize(this.careMode ? 19 : 15)
                    .fontColor('#5C5048')
                  Blank()
                  Text(this.bindingCode)
                    .fontSize(this.careMode ? 21 : 17)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#378F85')
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .backgroundColor('#EFFAF8')
                    .borderRadius(8)
                }
                .width('100%')
                Text('将此绑定码发给子女，子女输入后即可绑定您的账号')
                  .fontSize(this.careMode ? 15 : 12)
                  .fontColor('#6D6258')
                  .width('100%')
              }
              .width('100%')
              .padding(12)
              .backgroundColor(Color.White)
              .borderRadius(8)
              .border({ width: 1, color: '#E8DDD2' })

              this.ActionRow('开始购物', '浏览商品、比价下单', 'pages/UserHome')

              Button('退出登录')
                .width('100%')
                .height(this.careMode ? 52 : 44)
                .fontSize(this.careMode ? 18 : 15)
                .fontColor(Color.White)
                .backgroundColor('#378F85')
                .borderRadius(8)
                .onClick(() => {
                  AppBackendService.logout();
                  RouteUtils.clearAndPush(this.getUIContext(), 'pages/Index');
                })
            }
            .width('100%')
            .padding(16)
            .backgroundColor(Color.White)
            .borderRadius(8)
            .border({ width: 1, color: '#E8DDD2' })

           Row({ space: 12 }) {
             Column({ space: 4 }) {
               Text('客服反馈')
                 .fontSize(this.careMode ? 21 : 17)
                 .fontWeight(FontWeight.Bold)
                 .fontColor('#431407')
                 .width('100%')
               Text('向客服提交问题或建议')
                 .fontSize(this.careMode ? 16 : 13)
                 .fontColor('#6D6258')
                 .width('100%')
             }
             .layoutWeight(1)
             .alignItems(HorizontalAlign.Start)
             Text('>')
               .fontSize(18)
               .fontColor('#2B7068')
           }
           .width('100%')
           .padding(14)
           .backgroundColor(Color.White)
           .borderRadius(8)
           .border({ width: 1, color: '#E8DDD2' })
           .onClick(() => {
             this.showFeedback = !this.showFeedback;
           })

           if (this.showFeedback) {
             Column({ space: 10 }) {
               Text('提交反馈')
                 .fontSize(this.careMode ? 22 : 18)
                 .fontWeight(FontWeight.Bold)
                 .fontColor('#431407')
                 .width('100%')
               TextInput({ placeholder: '反馈标题', text: $$this.feedbackTitle })
                 .height(this.careMode ? 60 : 50)
                 .fontSize(this.careMode ? 20 : 16)
                 .backgroundColor('#FAF7F2')
                 .borderRadius(8)
                 .padding({ left: 14, right: 14 })
               TextArea({ placeholder: '请详细描述您的问题或建议...', text: $$this.feedbackContent })
                 .height(this.careMode ? 120 : 100)
                 .fontSize(this.careMode ? 20 : 16)
                 .backgroundColor('#FAF7F2')
                 .borderRadius(8)
                 .padding(14)
               Button(this.feedbackSubmitting ? '提交中...' : '提交反馈')
                 .width('100%')
                 .height(this.careMode ? 58 : 48)
                 .fontSize(this.careMode ? 20 : 17)
                 .fontWeight(FontWeight.Bold)
                 .fontColor(Color.White)
                 .backgroundColor('#378F85')
                 .borderRadius(8)
                 .enabled(!this.feedbackSubmitting)
                 .onClick(() => {
                   this.submitFeedback();
                 })
             }
             .width('100%')
             .padding(16)
             .backgroundColor(Color.White)
             .borderRadius(8)
             .border({ width: 1, color: '#E8DDD2' })
           }

           Column({ space: 10 }) {
             Text('关怀设置')
               .fontSize(this.careMode ? 22 : 18)
               .fontWeight(FontWeight.Bold)
               .fontColor('#431407')
               .width('100%')
             Row() {
               Text('关怀模式')
                 .fontSize(this.careMode ? 19 : 15)
                 .fontColor('#5C5048')
               Blank()
               Toggle({ type: ToggleType.Switch, isOn: this.careMode })
                 .onChange((isOn: boolean) => {
                   this.careMode = isOn;
                 })
             }
             .width('100%')
             Row() {
               Column({ space: 2 }) {
                 Text('购物语音提示')
                   .fontSize(this.careMode ? 19 : 15)
                   .fontColor('#5C5048')
                 Text('开启后购物时将语音播报操作提示')
                   .fontSize(this.careMode ? 14 : 11)
                   .fontColor('#9B8E82')
               }
               .layoutWeight(1)
               .alignItems(HorizontalAlign.Start)
               Blank()
               Toggle({ type: ToggleType.Switch, isOn: this.voicePromptEnabled })
                 .onChange((isOn: boolean) => {
                   this.voicePromptEnabled = isOn;
                   TTSService.getInstance().setEnabled(isOn);
                 })
             }
             .width('100%')
           }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
           .borderRadius(8)
           .border({ width: 1, color: '#E8DDD2' })
         }
         .width('100%')
         .constraintSize({ maxWidth: this.breakpoint === 'sm' ? 10000 : 720 })
         .padding(12)
         .onAppear(() => {
           this.refresh();
         })
       }
       .width('100%')
       .justifyContent(FlexAlign.Center)
      }
      .layoutWeight(1)

      BottomNav({
        role: 'user',
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
