import { BottomNav } from '../components/BottomNav';
import { AccountRole } from '../models/AuthModels';
import { AppBackendService } from '../services/AppBackendService';
import { CustomerServiceDashboardBackendData } from '../models/BackendModels';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';

@Entry
@Component
struct CSProfile {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @State csName: string = '';
  @State serviceGroup: string = '综合服务组';
  @State openTickets: number = 0;
  @State resolvedToday: number = 0;
  @State totalHandled: number = 0;

  async aboutToAppear(): Promise<void> {
    const account = AppBackendService.getCurrentAccount();
    if (!account) { RouteUtils.replacePage(this.getUIContext(), 'pages/Login'); return; }
    if (account.defaultRole !== AccountRole.CustomerService) {
      RouteUtils.replacePage(this.getUIContext(), 'pages/Index'); return;
    }
    this.csName = account.displayName;
    await this.loadStats();
  }

  private async loadStats(): Promise<void> {
    const result = await AppBackendService.getCsDashboardRemote();
    if (result.success && result.data) {
      const data: CustomerServiceDashboardBackendData = result.data;
      this.openTickets = data.openTickets;
      this.resolvedToday = data.resolvedToday;
    }
  }

  @Builder
  private StatCard(label: string, value: string, color: string, bgColor: string) {
    Column({ space: 4 }) {
      Text(value).fontSize(this.careMode ? 30 : 26).fontWeight(FontWeight.Bold).fontColor(color)
      Text(label).fontSize(this.careMode ? 15 : 12).fontColor('#00695C')
    }
    .layoutWeight(1).padding(16).backgroundColor(bgColor).borderRadius(14)
  }

  @Builder
  private ActionCard(title: string, desc: string, route: string) {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text(title).fontSize(this.careMode ? 18 : 15).fontWeight(FontWeight.Bold).fontColor('#004D40')
        Text(desc).fontSize(this.careMode ? 14 : 12).fontColor('#80CBC4')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Button('进入').height(this.careMode ? 38 : 32).fontSize(this.careMode ? 15 : 12)
        .fontColor('#FFFFFF').backgroundColor('#00695C').borderRadius(8)
        .onClick(() => { RouteUtils.replacePage(this.getUIContext(), route); })
    }
    .width('100%').padding(14).backgroundColor(Color.White).borderRadius(12)
    .shadow({ radius: 6, color: '#004D4008', offsetX: 0, offsetY: 1 })
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Text('我的').fontSize(this.careMode ? 28 : 22).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        Blank()
        Text(this.csName).fontSize(this.careMode ? 15 : 12).fontColor('#B2DFDB')
      }.width('100%').padding({ left: 18, right: 18, top: 16, bottom: 12 })
      .backgroundColor('#004D40')

      Scroll() {
        Column({ space: 14 }) {
          Text('个人信息').fontSize(this.careMode ? 22 : 18).fontWeight(FontWeight.Bold).fontColor('#004D40').width('100%')

          Column({ space: 8 }) {
            Text(this.csName).fontSize(this.careMode ? 26 : 22).fontWeight(FontWeight.Bold).fontColor('#004D40')
            Text('客服专员 · ' + this.serviceGroup).fontSize(this.careMode ? 15 : 13).fontColor('#80CBC4')
          }.width('100%').padding(18).backgroundColor('#E0F2F1').borderRadius(16)

          Text('工作概况').fontSize(this.careMode ? 22 : 18).fontWeight(FontWeight.Bold).fontColor('#004D40').width('100%')

          Row({ space: 10 }) {
            this.StatCard('待处理', this.openTickets.toString(), '#004D40', '#E0F2F1')
            this.StatCard('今日解决', this.resolvedToday.toString(), '#00695C', '#E0F2F1')
          }.width('100%')

          Row({ space: 10 }) {
            this.StatCard('累计处理', this.totalHandled.toString(), '#00695C', '#F0FAF8')
            this.StatCard('在线状态', '在线', '#2E7D32', '#E8F5E9')
          }.width('100%')

          Column({ space: 4 }) {
            Text('服务技能').fontSize(this.careMode ? 18 : 15).fontWeight(FontWeight.Bold).fontColor('#004D40').width('100%')
            Text('工单处理, 购物协助, 退换货指导, 投诉处理').fontSize(this.careMode ? 15 : 13).fontColor('#00695C').width('100%')
          }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(12)

          Text('快捷入口').fontSize(this.careMode ? 22 : 18).fontWeight(FontWeight.Bold).fontColor('#004D40').width('100%')
          this.ActionCard('工单管理', '处理用户咨询和投诉工单', 'pages/CSTicketManage')
          this.ActionCard('客服工作台', '回到客服工作台首页', 'pages/CustomerServiceHome')

          Button('退出登录').width('100%').height(this.careMode ? 48 : 40)
            .fontSize(this.careMode ? 17 : 14).fontColor('#C62828').backgroundColor(Color.White)
            .borderRadius(10).margin({ top: 10 })
            .onClick(() => { AppBackendService.logout(); RouteUtils.clearAndPush(this.getUIContext(), 'pages/Login'); })
        }.width('100%').padding({ left: 18, right: 18, top: 6, bottom: 100 })
      }.layoutWeight(1).backgroundColor('#F0FAF8')

      BottomNav({ role: 'cs', active: 'profile', careMode: this.careMode,
        onNavigate: (url: string) => { RouteUtils.replacePage(this.getUIContext(), url); } })
    }.width('100%').height('100%').backgroundColor('#F0FAF8')
    .constraintSize({ maxWidth: this.breakpoint === 'sm' ? 10000 : 900 })
  }
}
