import { AppHeader } from '../components/AppHeader';
import { BottomNav } from '../components/BottomNav';
import { Account, ChildProfile as ChildProfileModel } from '../models/AuthModels';
import { BackendResult, ProfileStatsBackendData } from '../models/BackendModels';
import { AppBackendService } from '../services/AppBackendService';
import { AuthService } from '../services/AuthService';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';

@Entry
@Component
struct ChildProfile {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('nickName') nickName: string = '';
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @State addressCount: number = 0;
  @State unreadCount: number = 0;
  @State bindingCount: number = 0;
  @State accountName: string = '子女账号';
  @State accountPhone: string = '';
  @State showFeedback: boolean = false;
  @State feedbackTitle: string = '';
  @State feedbackContent: string = '';
  @State feedbackSubmitting: boolean = false;
  @State editingProfile: boolean = false;
  @State editRealName: string = '';
  @State editRelation: string = '';
  @State editNickName: string = '';
  @State profileSubmitting: boolean = false;

  aboutToAppear(): void {
    this.refresh();
  }

  private async refresh(): Promise<void> {
    try {
      const result: BackendResult<ProfileStatsBackendData> = await AppBackendService.getProfileStatsRemote();
      const account: Account | undefined = result.data ? result.data.account : undefined;
      this.accountName = account ? account.displayName : '子女账号';
      this.accountPhone = account ? account.phone : '';
      this.addressCount = result.data ? result.data.addressCount : 0;
      this.unreadCount = result.data ? result.data.unreadReminderCount : 0;
      this.bindingCount = result.data ? result.data.bindingCount : 0;
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '加载失败，请稍后重试');
    }
  }

  private startEditProfile(): void {
    const account: Account | undefined = AppBackendService.getCurrentAccount();
    if (!account) {
      return;
    }
    const profile: ChildProfileModel | undefined = AuthService.getChildProfile(account.id);
    this.editRealName = profile ? profile.realName : account.displayName;
    this.editRelation = profile ? profile.relation : '子女';
    this.editNickName = this.nickName.length > 0 ? this.nickName : account.displayName;
    this.editingProfile = true;
  }

  private async saveProfile(): Promise<void> {
    if (this.editRealName.trim().length === 0) {
      RouteUtils.showToast(this.getUIContext(), '请输入真实姓名');
      return;
    }
    this.profileSubmitting = true;
    try {
      const result = await AppBackendService.updateChildProfileRemote(
        this.editRealName.trim(), this.editRelation.trim(), this.editNickName.trim()
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
      AppHeader({
        title: '我的',
        subtitle: '子女协助配置和照护状态',
        roleText: '子女端',
        careMode: this.careMode,
        onSwitchRole: () => {
          RouteUtils.replacePage(this.getUIContext(), 'pages/Index');
        }
      })

      Scroll() {
        Row() {
         Column({ space: 14 }) {
          Column({ space: 12 }) {
            Row() {
              Text(this.nickName.length > 0 ? this.nickName : this.accountName)
                .fontSize(this.careMode ? 28 : 23)
                .fontWeight(FontWeight.Bold)
                .fontColor('#431407')
              Blank()
              Text(this.accountPhone)
                .fontSize(this.careMode ? 16 : 13)
                .fontColor('#7A5C45')
              if (!this.editingProfile) {
                Button('编辑')
                  .height(32)
                  .fontSize(this.careMode ? 16 : 13)
                  .fontColor('#2B7068')
                  .backgroundColor('#EFFAF8')
                  .borderRadius(8)
                  .margin({ left: 8 })
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
                  Text('与老人关系')
                    .fontSize(this.careMode ? 17 : 14)
                    .fontColor('#5C5048')
                    .width(80)
                  TextInput({ placeholder: '如：女儿、儿子', text: $$this.editRelation })
                    .layoutWeight(1)
                    .height(this.careMode ? 52 : 44)
                    .fontSize(this.careMode ? 18 : 15)
                    .backgroundColor('#FAF7F2')
                    .borderRadius(8)
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
                    .backgroundColor('#2B7068')
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

            Text('已维护 ' + this.addressCount.toString() + ' 个地址，未读提醒 ' + this.unreadCount.toString() + ' 条，已绑定老人 ' + this.bindingCount.toString() + ' 位。')
              .fontSize(this.careMode ? 18 : 14)
              .fontColor('#6B4E3D')
              .width('100%')
            Row({ space: 10 }) {
              Text('模拟通知')
                .fontSize(this.careMode ? 16 : 13)
                .fontColor('#2B7068')
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor('#EFFAF8')
                .borderRadius(8)
              Text('地址托管')
                .fontSize(this.careMode ? 16 : 13)
                .fontColor('#2B7068')
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor('#EFFAF8')
                .borderRadius(8)
              Text('家庭绑定')
                .fontSize(this.careMode ? 16 : 13)
                .fontColor('#2B7068')
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor('#EFFAF8')
                .borderRadius(8)
            }
            .width('100%')
          }
          .width('100%')
          .padding(18)
          .backgroundColor('#FAF7F2')
          .borderRadius(8)
          .border({ width: 1, color: '#E8DDD2' })

            this.ActionRow('收货地址管理', '新增、删除和设置老人默认收货地址', 'pages/AddressManage')
            this.ActionRow('购物提醒记录', '查看老人端支付后生成的提醒', 'pages/ReminderList')

            Column({ space: 12 }) {
              Text('账号中心')
                .fontSize(this.careMode ? 22 : 18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#431407')
                .width('100%')

              this.ActionRow('家庭绑定', '绑定老人账号，建立照护关系', 'pages/BindFamily')
              this.ActionRow('帮助购物', '代老人浏览商品、比价下单', 'pages/ChildHome')

              Button('退出登录')
                .width('100%')
                .height(this.careMode ? 52 : 44)
                .fontSize(this.careMode ? 18 : 15)
                .fontColor(Color.White)
                .backgroundColor('#2B7068')
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
                 .backgroundColor('#2B7068')
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
            Text('显示设置')
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
          }
          .width('100%')
          .padding(16)
           .backgroundColor(Color.White)
           .borderRadius(8)
           .border({ width: 1, color: '#E8DDD2' })
         }
         .width('100%')
         .constraintSize({ maxWidth: this.breakpoint === 'sm' ? 10000 : 720 })
         .padding(16)
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
