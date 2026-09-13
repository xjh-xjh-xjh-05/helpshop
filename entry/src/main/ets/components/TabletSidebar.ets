import { BreakpointType } from '../utils/BreakpointSystem';
import { CareModeToggle } from './CareModeToggle';

interface NavItem {
  key: string;
  icon: string;
  label: string;
  url: string;
}

@Component
export struct TabletSidebar {
  role: string = 'user';
  active: string = 'home';
  careMode: boolean = false;
  onNavigate: (url: string) => void = () => {};
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @StorageLink('careMode') careModeLinked: boolean = false;

  private get sidebarWidth(): number {
    return this.breakpoint === 'lg' ? 240 : 220;
  }

  private get accentColor(): string {
    if (this.role === 'admin') return '#1A237E';
    if (this.role === 'cs') return '#00695C';
    if (this.role === 'child') return '#378F85';
    return '#9C5A2C';
  }

  private get accentLight(): string {
    if (this.role === 'admin') return '#E8EAF6';
    if (this.role === 'cs') return '#E0F2F1';
    if (this.role === 'child') return '#FEF5F0';
    return '#FEF5F0';
  }

  private get mutedColor(): string {
    if (this.role === 'admin') return '#7986CB';
    if (this.role === 'cs') return '#80CBC4';
    if (this.role === 'child') return '#A09080';
    return '#A09080';
  }

  private get roleLabel(): string {
    if (this.role === 'admin') return '管理员';
    if (this.role === 'cs') return '客服';
    if (this.role === 'child') return '子女端';
    return '帮买';
  }

  private get navItems(): NavItem[] {
    if (this.role === 'admin') {
      return [
        { key: 'home', icon: '⚙', label: '控制台', url: 'pages/AdminHome' },
        { key: 'users', icon: '👥', label: '用户管理', url: 'pages/AdminUserManage' },
        { key: 'orders', icon: '📋', label: '订单监控', url: 'pages/AdminOrderMonitor' },
        { key: 'audit', icon: '📜', label: '审计日志', url: 'pages/AdminAuditLog' },
        { key: 'profile', icon: '☺', label: '我的', url: 'pages/AdminProfile' }
      ];
    }
    if (this.role === 'cs') {
      return [
        { key: 'tickets', icon: '📋', label: '工单台', url: 'pages/CSTicketManage' },
        { key: 'orders', icon: '☑', label: '订单', url: 'pages/OrderHistory' },
        { key: 'shop', icon: '🤝', label: '帮买', url: 'pages/UserHome' },
        { key: 'profile', icon: '☺', label: '我的', url: 'pages/CSProfile' }
      ];
    }
    if (this.role === 'child') {
      return [
        { key: 'home', icon: '⌂', label: '首页', url: 'pages/ChildHome' },
        { key: 'address', icon: '📍', label: '地址', url: 'pages/AddressManage' },
        { key: 'reminder', icon: '☉', label: '提醒', url: 'pages/ReminderList' },
        { key: 'profile', icon: '☺', label: '我的', url: 'pages/ChildProfile' }
      ];
    }
    return [
      { key: 'home', icon: '⌂', label: '首页', url: 'pages/UserHome' },
      { key: 'assistant', icon: '✦', label: '助手', url: 'pages/AgentAssistant' },
      { key: 'category', icon: '☰', label: '分类', url: 'pages/UserCategory' },
      { key: 'order', icon: '☑', label: '订单', url: 'pages/OrderHistory' },
      { key: 'profile', icon: '☺', label: '我的', url: 'pages/UserProfile' }
    ];
  }

  build() {
    Column() {
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Text('HS')
            .fontSize(this.careMode ? 22 : 18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor(this.accentColor)
            .borderRadius(8)
          Text(this.roleLabel)
            .fontSize(this.careMode ? 15 : 12)
            .fontColor(this.accentColor)
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 4 })
      }
      .width('100%')
      .padding({ top: 16, bottom: 8 })

      Scroll() {
        Column({ space: 2 }) {
          ForEach(this.navItems, (item: NavItem) => {
            Row({ space: 10 }) {
              Text(item.icon)
                .fontSize(this.careMode ? 22 : 18)
                .fontColor(this.active === item.key ? this.accentColor : this.mutedColor)
              Text(item.label)
                .fontSize(this.careMode ? 17 : 14)
                .fontWeight(this.active === item.key ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.active === item.key ? this.accentColor : this.mutedColor)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .borderRadius(10)
            .backgroundColor(this.active === item.key ? this.accentLight : Color.Transparent)
            .onClick(() => {
              if (this.active !== item.key) {
                this.onNavigate(item.url);
              }
            })
          }, (item: NavItem) => item.key)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      Column({ space: 8 }) {
        CareModeToggle()
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 16 })
    }
    .width(this.sidebarWidth)
    .height('100%')
    .backgroundColor('#FAFAFA')
    .border({ width: { right: 0.5 }, color: '#E8DDD2' })
  }
}
