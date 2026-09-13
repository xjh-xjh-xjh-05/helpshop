import { AppHeader } from '../components/AppHeader';
import { BottomNav } from '../components/BottomNav';
import { BackendResult } from '../models/BackendModels';
import { ReminderRecord } from '../models/ShoppingModels';
import { AppBackendService } from '../services/AppBackendService';
import { ReminderService } from '../services/ReminderService';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';

@Entry
@Component
struct ReminderList {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @State reminders: ReminderRecord[] = [];

  private async refresh(): Promise<void> {
    try {
      const localReminders: ReminderRecord[] = ReminderService.listReminders();
      const allLocalReminders: ReminderRecord[] = localReminders.length > 0 ? localReminders : ReminderService.listAllReminders();
      const result: BackendResult<ReminderRecord[]> = await AppBackendService.listRemindersRemote();
      const remoteReminders: ReminderRecord[] = result.data ? result.data : [];
      if (allLocalReminders.length > remoteReminders.length) {
        this.reminders = allLocalReminders;
      } else {
        this.reminders = remoteReminders;
        ReminderService.mergeReminders(remoteReminders.filter((remote: ReminderRecord) => {
          return !allLocalReminders.some((local: ReminderRecord) => local.id === remote.id);
        }));
      }
    } catch (error) {
      this.reminders = ReminderService.listReminders();
      if (this.reminders.length === 0) {
        this.reminders = ReminderService.listAllReminders();
      }
    }
  }

  private switchRole(): void {
    RouteUtils.replacePage(this.getUIContext(), 'pages/Index');
  }

  private async markAllRead(): Promise<void> {
    try {
      const result: BackendResult<ReminderRecord[]> = await AppBackendService.markAllRemindersReadRemote();
      this.reminders = result.data ? result.data : [];
      RouteUtils.showToast(this.getUIContext(), result.message);
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '标记已读异常，请稍后重试');
    }
  }

  build() {
    Column() {
      AppHeader({
        title: '购物提醒',
        subtitle: '老人端支付成功后自动生成子女端提醒记录',
        roleText: '子女端',
        careMode: this.careMode,
        onSwitchRole: () => {
          this.switchRole();
        }
      })

      Scroll() {
        Row() {
         Column({ space: 14 }) {
          Row() {
            Text('提醒列表')
              .fontSize(this.careMode ? 24 : 20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#431407')
            Blank()
            Button('全部已读')
              .height(this.careMode ? 40 : 34)
              .fontSize(this.careMode ? 16 : 13)
              .fontColor('#2B7068')
              .backgroundColor('#EFFAF8')
              .borderRadius(8)
              .onClick(() => {
                this.markAllRead();
              })
          }
          .width('100%')

          if (this.reminders.length === 0) {
            Column({ space: 10 }) {
              Text('暂无提醒记录')
                .fontSize(this.careMode ? 24 : 20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#431407')
              Text('老人完成模拟支付后，子女端提醒会显示在这里。')
                .fontSize(this.careMode ? 18 : 15)
                .fontColor('#7A5C45')
            }
            .width('100%')
            .padding(24)
            .backgroundColor(Color.White)
            .borderRadius(8)
            .border({ width: 1, color: '#E8DDD2' })
          } else {
            ForEach(this.reminders, (item: ReminderRecord) => {
              Column({ space: 10 }) {
                Row() {
                  Text(item.title)
                    .fontSize(this.careMode ? 23 : 19)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#431407')
                  Blank()
                  Text(item.read ? '已读' : '未读')
                    .fontSize(this.careMode ? 17 : 14)
                    .fontColor(item.read ? '#7A5C45' : '#2B7068')
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .backgroundColor(item.read ? '#FAF7F2' : '#EFFAF8')
                    .borderRadius(8)
                }
                .width('100%')

                Text(item.content)
                  .fontSize(this.careMode ? 18 : 15)
                  .fontColor('#5C5048')
                  .lineHeight(this.careMode ? 28 : 22)
                  .width('100%')
                Text('时间：' + item.createdAt + ' · 关联订单：' + item.orderId)
                  .fontSize(this.careMode ? 17 : 14)
                  .fontColor('#7A5C45')
                  .width('100%')
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Color.White)
              .borderRadius(8)
              .border({ width: item.read ? 1 : 2, color: item.read ? '#E8DDD2' : '#378F85' })
             }, (item: ReminderRecord) => item.id)
           }
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
        active: 'reminder',
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
