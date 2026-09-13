import { BottomNav } from '../components/BottomNav';
import { AccountRole } from '../models/AuthModels';
import { AppBackendService } from '../services/AppBackendService';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';
import { AdminDashboardBackendData } from '../models/BackendModels';

@Entry
@Component
struct AdminHome {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @State adminName: string = '';
  @State totalAccounts: number = 0;
  @State elderlyCount: number = 0;
  @State childCount: number = 0;
  @State csCount: number = 0;
  @State adminCount: number = 0;
  @State totalOrders: number = 0;
  @State pendingOrders: number = 0;

  aboutToAppear(): void {
    const account = AppBackendService.getCurrentAccount();
    if (!account) { RouteUtils.replacePage(this.getUIContext(), 'pages/Login'); return; }
    if (account.defaultRole !== AccountRole.Admin) {
      RouteUtils.replacePage(this.getUIContext(), 'pages/Index'); return;
    }
    this.adminName = account.displayName;
    this.loadDashboard();
  }

  private async loadDashboard(): Promise<void> {
    const result = await AppBackendService.getAdminDashboardRemote();
    if (result.success && result.data) {
      const data: AdminDashboardBackendData = result.data;
      this.totalAccounts = data.totalAccounts;
      this.elderlyCount = data.elderlyCount;
      this.childCount = data.childCount;
      this.csCount = data.csCount;
      this.adminCount = data.adminCount;
      this.totalOrders = data.totalOrders;
      this.pendingOrders = data.pendingOrders;
    }
  }

  @Builder
  private StatCard(label: string, value: string, color: string, bgColor: string) {
    Column({ space: 4 }) {
      Text(value).fontSize(this.careMode ? 30 : 26).fontWeight(FontWeight.Bold).fontColor(color)
      Text(label).fontSize(this.careMode ? 15 : 12).fontColor('#5C6BC0')
    }
    .layoutWeight(1).padding(16).backgroundColor(bgColor).borderRadius(14)
  }

  @Builder
  private ActionCard(title: string, desc: string, route: string) {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text(title).fontSize(this.careMode ? 18 : 15).fontWeight(FontWeight.Bold).fontColor('#1A237E')
        Text(desc).fontSize(this.careMode ? 14 : 12).fontColor('#7986CB')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Button('进入').height(this.careMode ? 38 : 32).fontSize(this.careMode ? 15 : 12)
        .fontColor('#FFFFFF').backgroundColor('#1A237E').borderRadius(8)
        .onClick(() => { RouteUtils.replacePage(this.getUIContext(), route); })
    }
    .width('100%').padding(14).backgroundColor(Color.White).borderRadius(12)
    .shadow({ radius: 6, color: '#1A237E08', offsetX: 0, offsetY: 1 })
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Text('管理控制台').fontSize(this.careMode ? 28 : 22).fontWeight(FontWeight.Bold).fontColor('#1A237E')
        Blank()
        Text(this.adminName).fontSize(this.careMode ? 15 : 12).fontColor('#7986CB')
      }.width('100%').padding({ left: 18, right: 18, top: 16, bottom: 8 })

      Scroll() {
        Column({ space: 14 }) {
          Text('平台概况').fontSize(this.careMode ? 22 : 18).fontWeight(FontWeight.Bold).fontColor('#1A237E').width('100%')

          Row({ space: 10 }) {
            this.StatCard('总用户', this.totalAccounts.toString(), '#1A237E', '#E8EAF6')
            this.StatCard('总订单', this.totalOrders.toString(), '#283593', '#E8EAF6')
          }.width('100%')

          Row({ space: 10 }) {
            this.StatCard('老人', this.elderlyCount.toString(), '#1A237E', '#F5F7FF')
            this.StatCard('子女', this.childCount.toString(), '#283593', '#F5F7FF')
          }.width('100%')

          Row({ space: 10 }) {
            this.StatCard('客服', this.csCount.toString(), '#3949AB', '#F5F7FF')
            this.StatCard('管理员', this.adminCount.toString(), '#1A237E', '#F5F7FF')
          }.width('100%')

          Row({ space: 10 }) {
            this.StatCard('待处理订单', this.pendingOrders.toString(), '#C62828', '#FFEBEE')
            this.StatCard('已完成订单', (this.totalOrders - this.pendingOrders).toString(), '#2E7D32', '#E8F5E9')
          }.width('100%')

          Text('快捷操作').fontSize(this.careMode ? 22 : 18).fontWeight(FontWeight.Bold).fontColor('#1A237E').width('100%')
          this.ActionCard('用户管理', '查看和管理所有注册用户', 'pages/AdminUserManage')
          this.ActionCard('订单监控', '全平台订单状态追踪', 'pages/AdminOrderMonitor')
          this.ActionCard('审计日志', '系统操作完整记录', 'pages/AdminAuditLog')
        }.width('100%').padding({ left: 18, right: 18, top: 6, bottom: 100 })
      }.layoutWeight(1).backgroundColor('#F5F7FF')

      BottomNav({ role: 'admin', active: 'home', careMode: this.careMode,
        onNavigate: (url: string) => { RouteUtils.replacePage(this.getUIContext(), url); } })
    }.width('100%').height('100%').backgroundColor('#F5F7FF')
    .constraintSize({ maxWidth: this.breakpoint === 'sm' ? 10000 : 900 })
  }
}
