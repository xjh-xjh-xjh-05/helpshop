import { BottomNav } from '../components/BottomNav';
import { AccountRole } from '../models/AuthModels';
import { AppBackendService } from '../services/AppBackendService';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';

@Entry
@Component
struct AdminProfile {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @State adminName: string = '';
  @State department: string = '运营管理部';
  @State permissions: string = '用户管理, 订单监控, 审计日志, 系统配置';
  @State totalAccounts: number = 4;
  @State totalOrders: number = 4;

  aboutToAppear(): void {
    const account = AppBackendService.getCurrentAccount();
    if (!account) { RouteUtils.replacePage(this.getUIContext(), 'pages/Login'); return; }
    if (account.defaultRole !== AccountRole.Admin) {
      RouteUtils.replacePage(this.getUIContext(), 'pages/Index'); return;
    }
    this.adminName = account.displayName;
    this.totalAccounts = AppBackendService.listAllAccounts().length;
    this.totalOrders = AppBackendService.listAllOrders().length;
  }

  @Builder
  private InfoRow(label: string, value: string) {
    Row({ space: 8 }) {
      Text(label).fontSize(this.careMode ? 16 : 14).fontColor('#7986CB').width(80)
      Text(value).fontSize(this.careMode ? 16 : 14).fontWeight(FontWeight.Medium).fontColor('#1A237E')
    }.width('100%').padding({ top: 6, bottom: 6 })
  }

  @Builder
  private MenuItem(icon: string, title: string, desc: string, route: string) {
    Row({ space: 12 }) {
      Text(icon).fontSize(22)
      Column({ space: 2 }) {
        Text(title).fontSize(this.careMode ? 17 : 14).fontWeight(FontWeight.Bold).fontColor('#1A237E')
        Text(desc).fontSize(this.careMode ? 14 : 12).fontColor('#7986CB')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Button('›').fontSize(24).fontColor('#7986CB').backgroundColor(Color.Transparent)
    }
    .width('100%').padding(14).backgroundColor(Color.White).borderRadius(12)
    .shadow({ radius: 6, color: '#1A237E08', offsetX: 0, offsetY: 1 })
    .onClick(() => { RouteUtils.replacePage(this.getUIContext(), route); })
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Text('管理员中心').fontSize(this.careMode ? 28 : 22).fontWeight(FontWeight.Bold).fontColor('#1A237E')
        Blank()
        Text('Admin').fontSize(this.careMode ? 15 : 12).fontColor('#7986CB')
      }.width('100%').padding({ left: 18, right: 18, top: 16, bottom: 8 })

      Scroll() {
        Column({ space: 14 }) {
          // 管理员信息卡片
          Column({ space: 8 }) {
            Row({ space: 14 }) {
              Column({ space: 4 }) {
                Text(this.adminName).fontSize(this.careMode ? 26 : 22).fontWeight(FontWeight.Bold).fontColor('#1A237E')
                Text('系统管理员 · ' + this.department).fontSize(this.careMode ? 15 : 13).fontColor('#7986CB')
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Column({ space: 2 }) {
                Text(this.totalAccounts.toString()).fontSize(this.careMode ? 26 : 22).fontWeight(FontWeight.Bold).fontColor('#1A237E')
                Text('平台用户').fontSize(this.careMode ? 13 : 11).fontColor('#7986CB')
              }.alignItems(HorizontalAlign.Center)
              Column({ space: 2 }) {
                Text(this.totalOrders.toString()).fontSize(this.careMode ? 26 : 22).fontWeight(FontWeight.Bold).fontColor('#283593')
                Text('总订单').fontSize(this.careMode ? 13 : 11).fontColor('#7986CB')
              }.alignItems(HorizontalAlign.Center)
            }.width('100%')
          }.width('100%').padding(18).backgroundColor('#E8EAF6').borderRadius(16)

          // 权限信息
          Column({ space: 4 }) {
            Text('管理权限').fontSize(this.careMode ? 18 : 15).fontWeight(FontWeight.Bold).fontColor('#1A237E').width('100%')
            Text(this.permissions).fontSize(this.careMode ? 15 : 13).fontColor('#5C6BC0').width('100%')
          }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(12)

          // 快捷功能
          Text('管理功能').fontSize(this.careMode ? 20 : 16).fontWeight(FontWeight.Bold).fontColor('#1A237E').width('100%')
          this.MenuItem('👥', '用户管理', '查看和管理所有注册用户', 'pages/AdminUserManage')
          this.MenuItem('📋', '订单监控', '全平台订单状态追踪', 'pages/AdminOrderMonitor')
          this.MenuItem('📝', '审计日志', '系统操作完整记录', 'pages/AdminAuditLog')
          this.MenuItem('⚙', '系统控制台', '平台数据总览', 'pages/AdminHome')

          // 退出
          Button('退出登录').width('100%').height(this.careMode ? 48 : 40)
            .fontSize(this.careMode ? 17 : 14).fontColor('#C62828').backgroundColor(Color.White)
            .borderRadius(10).margin({ top: 10 })
            .onClick(() => { AppBackendService.logout(); RouteUtils.clearAndPush(this.getUIContext(), 'pages/Login'); })
        }.width('100%').padding({ left: 18, right: 18, top: 6, bottom: 100 })
      }.layoutWeight(1).backgroundColor('#F5F7FF')

      BottomNav({ role: 'admin', active: 'profile', careMode: this.careMode,
        onNavigate: (url: string) => { RouteUtils.replacePage(this.getUIContext(), url); } })
    }.width('100%').height('100%')
    .constraintSize({ maxWidth: this.breakpoint === 'sm' ? 10000 : 900 }).backgroundColor('#F5F7FF')
  }
}
