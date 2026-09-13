import { AppHeader } from '../components/AppHeader';
import { BottomNav } from '../components/BottomNav';
import { BackendResult, BindingListBackendData, ChildDashboardBackendData } from '../models/BackendModels';
import { Address, ReminderRecord } from '../models/ShoppingModels';
import { AppBackendService } from '../services/AppBackendService';
import { RouteUtils } from '../utils/RouteUtils';
import { DistributedDataSync, PaymentSyncPayload } from '../agent/DistributedDataSync';
import { BreakpointType } from '../utils/BreakpointSystem';
import { ReminderService } from '../services/ReminderService';
import { AuthService } from '../services/AuthService';

type DataChangeListener = (sessionId: string, fields: Array<string>) => void;

@Entry
@Component
struct ChildHome {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('lastPaymentEvent') lastPaymentEventJson: string = '';
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @State addressCount: number = 0;
  @State unreadCount: number = 0;
  @State bindingCount: number = 0;
  @State defaultAddressText: string = '';
  @State latestReminderText: string = '暂无提醒';
  @State newOrderBanner: string = '';
  private paymentListener: DataChangeListener = (_sessionId: string, _fields: Array<string>) => {
    this.onDistributedPaymentChanged();
  };
  private reminderListener: DataChangeListener = (_sessionId: string, _fields: Array<string>) => {
    this.onDistributedReminderChanged();
  };

  aboutToAppear(): void {
    this.checkPaymentEvent();
    this.refreshLocalReminders();
    const sync = DistributedDataSync.getInstance();
    sync.onPaymentChange(this.paymentListener);
    sync.onReminderChange(this.reminderListener);
  }

  aboutToDisappear(): void {
    const sync = DistributedDataSync.getInstance();
    sync.offPaymentChange(this.paymentListener);
    sync.offReminderChange(this.reminderListener);
  }

  private onDistributedPaymentChanged(): void {
    const payload: PaymentSyncPayload | null = DistributedDataSync.getInstance().getPaymentPayload();
    if (payload && payload.status === 'success') {
      this.newOrderBanner = '新订单：' + payload.elderlyName + ' 购买了 ' + payload.productName +
        '，¥' + payload.amount.toFixed(2) + '，时间 ' + payload.time;
      AppStorage.setOrCreate('lastPaymentEvent', JSON.stringify(payload));
      this.refreshLocalReminders();
    }
  }

  private onDistributedReminderChanged(): void {
    this.refreshLocalReminders();
  }

  private refreshLocalReminders(): void {
    const localReminders: ReminderRecord[] = ReminderService.listReminders();
    if (localReminders.length === 0) {
      const allReminders: ReminderRecord[] = ReminderService.listAllReminders();
      if (allReminders.length > 0) {
        this.unreadCount = allReminders.filter((item: ReminderRecord) => !item.read).length;
        this.latestReminderText = allReminders[0].content;
        return;
      }
    }
    this.unreadCount = localReminders.filter((item: ReminderRecord) => !item.read).length;
    this.latestReminderText = localReminders.length > 0 ? localReminders[0].content : '暂无提醒';
  }

  private checkPaymentEvent(): void {
    const raw: string = this.lastPaymentEventJson;
    if (raw.length > 0) {
      try {
        const event: PaymentSyncPayload = JSON.parse(raw) as PaymentSyncPayload;
        if (event.status === 'success') {
          this.newOrderBanner = '新订单：' + event.elderlyName + ' 购买了 ' + event.productName +
            '，¥' + event.amount.toFixed(2) + '，时间 ' + event.time;
          this.refreshLocalReminders();
          this.refresh();
        }
      } catch (error) {
      }
    }
  }

  private async refresh(): Promise<void> {
    try {
      const dashboardResult: BackendResult<ChildDashboardBackendData> = await AppBackendService.getChildDashboardRemote();
      if (dashboardResult.data) {
        this.addressCount = dashboardResult.data.addressCount;
        this.bindingCount = dashboardResult.data.bindingCount;
        this.defaultAddressText = dashboardResult.data.defaultAddressText;
        this.mergeLocalReminders(dashboardResult.data.unreadReminderCount, dashboardResult.data.latestReminderText);
        return;
      }
      const bindingResult: BackendResult<BindingListBackendData> = AppBackendService.listCurrentChildBindings();
      this.bindingCount = bindingResult.data ? bindingResult.data.bindings.length : 0;
      if (!AppBackendService.canEnterShopping()) {
        this.addressCount = 0;
        this.unreadCount = 0;
        this.defaultAddressText = '请先绑定老人账号，绑定后可维护老人收货地址';
        this.latestReminderText = '暂无提醒，绑定老人并完成购物后会显示在这里';
        return;
      }
      const addressResult: BackendResult<Address[]> = await AppBackendService.listAddressesRemote();
      const addresses: Address[] = addressResult.data ? addressResult.data : [];
      const defaultAddress = addresses.find((item: Address) => item.isDefault);
      const reminderResult: BackendResult<ReminderRecord[]> = await AppBackendService.listRemindersRemote();
      const remoteReminders: ReminderRecord[] = reminderResult.data ? reminderResult.data : [];
      this.addressCount = addresses.length;
      this.defaultAddressText = defaultAddress ? defaultAddress.receiver + '，' + defaultAddress.detail : '暂无默认收货地址';
      const remoteUnread: number = remoteReminders.filter((item: ReminderRecord) => !item.read).length;
      const remoteLatest: string = remoteReminders.length > 0 ? remoteReminders[0].content : '';
      this.mergeLocalReminders(remoteUnread, remoteLatest);
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '加载失败，请稍后重试');
    }
  }

  private mergeLocalReminders(remoteUnreadCount: number, remoteLatestText: string): void {
    const localReminders: ReminderRecord[] = ReminderService.listReminders();
    const localUnread: number = localReminders.filter((item: ReminderRecord) => !item.read).length;
    if (localUnread > remoteUnreadCount) {
      this.unreadCount = localUnread;
      this.latestReminderText = localReminders.length > 0 ? localReminders[0].content : '暂无提醒';
    } else {
      this.unreadCount = remoteUnreadCount;
      this.latestReminderText = remoteLatestText.length > 0 ? remoteLatestText : (localReminders.length > 0 ? localReminders[0].content : '暂无提醒');
    }
  }

  private accountCenter(): void {
    RouteUtils.replacePage(this.getUIContext(), 'pages/Index');
  }

  private assistShopping(): void {
    if (!AppBackendService.canEnterShopping()) {
      RouteUtils.showToast(this.getUIContext(), '请先绑定老人账号，再帮助购物');
      RouteUtils.replacePage(this.getUIContext(), 'pages/BindFamily');
      return;
    }
    RouteUtils.replacePage(this.getUIContext(), 'pages/UserHome');
  }

  @Builder
  private WorkItem(title: string, desc: string, url: string) {
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
          .lineHeight(this.careMode ? 24 : 19)
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button('进入')
        .height(this.careMode ? 42 : 36)
        .fontSize(this.careMode ? 16 : 13)
        .fontColor(Color.White)
        .backgroundColor('#378F85')
        .borderRadius(8)
        .onClick(() => {
          RouteUtils.replacePage(this.getUIContext(), url);
        })
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(8)
    .border({ width: 1, color: '#E8DDD2' })
  }

  build() {
    Column() {
      AppHeader({
        title: '家庭协助工作台',
        subtitle: '绑定老人、维护地址、查看提醒，也可以帮助老人购物',
        roleText: '子女端',
        careMode: this.careMode,
        onSwitchRole: () => {
          this.accountCenter();
        }
      })

      Scroll() {
        Row() {
          Column({ space: 14 }) {
            if (this.newOrderBanner.length > 0) {
              Text(this.newOrderBanner)
                .fontSize(this.careMode ? 18 : 14)
                .fontColor('#378F85')
                .width('100%')
                .padding(12)
                .backgroundColor('#FFF3E0')
                .borderRadius(8)
                .border({ width: 1, color: '#FFB74D' })
            }

            Row({ space: 10 }) {
              Column({ space: 6 }) {
                Text(this.bindingCount.toString())
                  .fontSize(this.careMode ? 28 : 23)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#378F85')
                Text('已绑定老人')
                  .fontSize(this.careMode ? 18 : 14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#431407')
                Text('绑定后可帮助购物')
                  .fontSize(this.careMode ? 15 : 12)
                  .fontColor('#6D6258')
                  .textAlign(TextAlign.Center)
              }
              .layoutWeight(1)
              .padding(14)
              .backgroundColor(Color.White)
              .borderRadius(8)
              .border({ width: 1, color: '#E8DDD2' })

              Column({ space: 6 }) {
                Text(this.unreadCount.toString())
                  .fontSize(this.careMode ? 28 : 23)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#378F85')
                Text('未读提醒')
                  .fontSize(this.careMode ? 18 : 14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#431407')
                Text('支付成功后生成')
                  .fontSize(this.careMode ? 15 : 12)
                  .fontColor('#6D6258')
                  .textAlign(TextAlign.Center)
              }
              .layoutWeight(1)
              .padding(14)
              .backgroundColor(Color.White)
              .borderRadius(8)
              .border({ width: 1, color: '#E8DDD2' })
            }
            .width('100%')

            Column({ space: 10 }) {
              Text('协助购物')
                .fontSize(this.careMode ? 23 : 18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#431407')
                .width('100%')
              Text(this.bindingCount > 0 ? '已绑定老人账号，可以进入购物商城为老人选择商品和下单。' : '请先绑定老人账号，再帮助老人购物。')
                .fontSize(this.careMode ? 18 : 14)
                .fontColor('#6B4E3D')
                .lineHeight(this.careMode ? 27 : 21)
                .width('100%')
              Row({ space: 10 }) {
                Button('绑定老人')
                  .layoutWeight(1)
                  .height(this.careMode ? 48 : 40)
                  .fontSize(this.careMode ? 17 : 14)
                  .fontColor('#2B7068')
                  .backgroundColor('#EFFAF8')
                  .borderRadius(8)
                  .onClick(() => {
                    RouteUtils.navigate(this.getUIContext(),'pages/BindFamily');
                  })
                Button('帮助购物')
                  .layoutWeight(1)
                  .height(this.careMode ? 48 : 40)
                  .fontSize(this.careMode ? 17 : 14)
                  .fontColor(Color.White)
                  .backgroundColor('#378F85')
                  .borderRadius(8)
                  .onClick(() => {
                    this.assistShopping();
                  })
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FAF7F2')
            .borderRadius(8)
            .border({ width: 1, color: '#E8DDD2' })

            Column({ space: 10 }) {
              Text('默认收货地址')
                .fontSize(this.careMode ? 23 : 18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#431407')
                .width('100%')
              Text(this.defaultAddressText)
                .fontSize(this.careMode ? 18 : 14)
                .fontColor('#6B4E3D')
                .lineHeight(this.careMode ? 27 : 21)
                .width('100%')
              Button('管理地址')
                .width('100%')
                .height(this.careMode ? 48 : 40)
                .fontSize(this.careMode ? 17 : 14)
                .fontColor('#2B7068')
                .backgroundColor('#EFFAF8')
                .borderRadius(8)
                .onClick(() => {
                  RouteUtils.replacePage(this.getUIContext(), 'pages/AddressManage');
                })
            }
            .width('100%')
            .padding(16)
            .backgroundColor(Color.White)
            .borderRadius(8)
            .border({ width: 1, color: '#E8DDD2' })

            Column({ space: 10 }) {
              Text('最新购物提醒')
                .fontSize(this.careMode ? 23 : 18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#431407')
                .width('100%')
              Text(this.latestReminderText)
                .fontSize(this.careMode ? 18 : 14)
                .fontColor('#6B4E3D')
                .lineHeight(this.careMode ? 27 : 21)
                .width('100%')
              Button('查看提醒')
                .width('100%')
                .height(this.careMode ? 48 : 40)
                .fontSize(this.careMode ? 17 : 14)
                .fontColor(Color.White)
                .backgroundColor('#378F85')
                .borderRadius(8)
                .onClick(() => {
                  RouteUtils.replacePage(this.getUIContext(), 'pages/ReminderList');
                })
            }
            .width('100%')
            .padding(16)
            .backgroundColor(Color.White)
            .borderRadius(8)
            .border({ width: 1, color: '#E8DDD2' })

            Column({ space: 10 }) {
              Text('常用工作')
                .fontSize(this.careMode ? 24 : 19)
                .fontWeight(FontWeight.Bold)
                .fontColor('#431407')
                .width('100%')
              this.WorkItem('收货地址管理', '新增、删除和设置默认地址', 'pages/AddressManage')
              this.WorkItem('购物提醒记录', '确认老人购买商品和支付状态', 'pages/ReminderList')
            }
            .width('100%')
          }
           .width('100%')
           .constraintSize({ maxWidth: this.breakpoint === 'sm' ? 10000 : 720 })
           .padding(16)
            .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean) => {
              if (isVisible) {
                this.refresh();
              }
            })
         }
         .width('100%')
         .justifyContent(FlexAlign.Center)
       }
       .layoutWeight(1)

      BottomNav({
        role: 'child',
        active: 'home',
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
