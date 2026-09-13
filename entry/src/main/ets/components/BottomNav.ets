import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';

@Component
export struct BottomNav {
  role: string = 'user';
  active: string = 'home';
  careMode: boolean = false;
  onNavigate: (url: string) => void = () => {};
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';

  private get isTablet(): boolean {
    return this.breakpoint === 'md' || this.breakpoint === 'lg';
  }

  private getActiveColor(): string {
    if (this.role === 'admin') return '#1A237E';
    if (this.role === 'cs') return '#00695C';
    return '#2B7068';
  }

  private getActiveBg(): string {
    if (this.role === 'admin') return '#E8EAF6';
    if (this.role === 'cs') return '#E0F2F1';
    return '#EFFAF8';
  }

  private getInactiveColor(): string {
    if (this.role === 'admin') return '#7986CB';
    if (this.role === 'cs') return '#80CBC4';
    return '#9ED4CE';
  }

  // === 手机端：底部标签栏 ===
  @Builder
  private BottomTab(key: string, icon: string, label: string, url: string) {
    Column({ space: 4 }) {
      Text(icon)
        .fontSize(this.careMode ? 22 : 18)
        .fontColor(this.active === key ? this.getActiveColor() : this.getInactiveColor())
        .opacity(this.active === key ? 1.0 : 0.6)
      Text(label)
        .fontSize(this.careMode ? 14 : 11)
        .fontWeight(this.active === key ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.active === key ? this.getActiveColor() : this.getInactiveColor())
        .opacity(this.active === key ? 1.0 : 0.7)
    }
    .layoutWeight(1)
    .padding({ top: 10, bottom: 8 })
    .borderRadius(14)
    .backgroundColor(this.active === key ? this.getActiveBg() : Color.Transparent)
    .onClick(() => { if (this.active !== key) { this.onNavigate(url); } })
  }

  @Builder
  private PhoneNav() {
    Row({ space: 4 }) {
      if (this.role === 'child') {
        this.BottomTab('home', '⌂', '首页', 'pages/ChildHome')
        this.BottomTab('address', '⌂', '地址', 'pages/AddressManage')
        this.BottomTab('reminder', '☉', '提醒', 'pages/ReminderList')
        this.BottomTab('profile', '☺', '我的', 'pages/ChildProfile')
      } else if (this.role === 'admin') {
        this.BottomTab('home', '⚙', '控制台', 'pages/AdminHome')
        this.BottomTab('users', '👥', '用户', 'pages/AdminUserManage')
        this.BottomTab('orders', '📋', '订单', 'pages/AdminOrderMonitor')
        this.BottomTab('audit', '📝', '日志', 'pages/AdminAuditLog')
        this.BottomTab('profile', '☺', '我的', 'pages/AdminProfile')
      } else if (this.role === 'cs') {
        this.BottomTab('home', '☎', '工作台', 'pages/CustomerServiceHome')
        this.BottomTab('orders', '📋', '订单', 'pages/CSOrderList')
        this.BottomTab('tickets', '📑', '工单', 'pages/CSTicketManage')
        this.BottomTab('profile', '☺', '我的', 'pages/CSProfile')
      } else {
        this.BottomTab('home', '⌂', '首页', 'pages/UserHome')
        this.BottomTab('assistant', '✦', '助手', 'pages/AgentAssistant')
        this.BottomTab('order', '☑', '订单', 'pages/OrderHistory')
        this.BottomTab('profile', '☺', '我的', 'pages/UserProfile')
      }
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 6, bottom: 8 })
    .backgroundColor('#FFFFFF')
    .shadow({ radius: 12, color: '#1A000000', offsetX: 0, offsetY: -2 })
    .border({ width: { top: 0.5 }, color: '#E8DDD2' })
    .borderRadius({ topLeft: 20, topRight: 20 })
  }

  // === 平板端：侧边导航栏 ===
  @Builder
  private SideItem(key: string, icon: string, label: string, url: string) {
    Column({ space: 6 }) {
      Text(icon)
        .fontSize(this.careMode ? 24 : 20)
        .fontColor(this.active === key ? this.getActiveColor() : this.getInactiveColor())
        .opacity(this.active === key ? 1.0 : 0.55)
      Text(label)
        .fontSize(this.careMode ? 15 : 12)
        .fontWeight(this.active === key ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.active === key ? this.getActiveColor() : this.getInactiveColor())
        .opacity(this.active === key ? 1.0 : 0.7)
    }
    .width(80)
    .padding({ top: 14, bottom: 14 })
    .borderRadius(14)
    .backgroundColor(this.active === key ? this.getActiveBg() : Color.Transparent)
    .onClick(() => { if (this.active !== key) { this.onNavigate(url); } })
  }

  @Builder
  private TabletNav() {
    Column({ space: 4 }) {
      if (this.role === 'child') {
        this.SideItem('home', '⌂', '首页', 'pages/ChildHome')
        this.SideItem('address', '⌂', '地址', 'pages/AddressManage')
        this.SideItem('reminder', '☉', '提醒', 'pages/ReminderList')
        this.SideItem('profile', '☺', '我的', 'pages/ChildProfile')
      } else if (this.role === 'admin') {
        this.SideItem('home', '⚙', '控制台', 'pages/AdminHome')
        this.SideItem('users', '👥', '用户', 'pages/AdminUserManage')
        this.SideItem('orders', '📋', '订单', 'pages/AdminOrderMonitor')
        this.SideItem('audit', '📝', '日志', 'pages/AdminAuditLog')
        this.SideItem('profile', '☺', '我的', 'pages/AdminProfile')
      } else if (this.role === 'cs') {
        this.SideItem('home', '☎', '工作台', 'pages/CustomerServiceHome')
        this.SideItem('orders', '📋', '订单', 'pages/CSOrderList')
        this.SideItem('tickets', '📑', '工单', 'pages/CSTicketManage')
        this.SideItem('profile', '☺', '我的', 'pages/CSProfile')
      } else {
        this.SideItem('home', '⌂', '首页', 'pages/UserHome')
        this.SideItem('assistant', '✦', '助手', 'pages/AgentAssistant')
        this.SideItem('order', '☑', '订单', 'pages/OrderHistory')
        this.SideItem('profile', '☺', '我的', 'pages/UserProfile')
      }
    }
    .padding({ top: 16, bottom: 16 })
    .backgroundColor('#FFFFFF')
    .shadow({ radius: 8, color: '#1A000000', offsetX: 2, offsetY: 0 })
    .border({ width: { right: 0.5 }, color: '#E8DDD2' })
  }

  build() {
    if (this.isTablet) {
      this.TabletNav()
    } else {
      this.PhoneNav()
    }
  }
}
