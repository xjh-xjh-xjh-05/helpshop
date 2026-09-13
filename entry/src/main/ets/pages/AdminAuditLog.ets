import { BottomNav } from '../components/BottomNav';
import { CareModeToggle } from '../components/CareModeToggle';
import { BreakpointType } from '../utils/BreakpointSystem';
import { AccountRole } from '../models/AuthModels';
import { BackendAuditRecord } from '../models/ShoppingModels';
import { AppBackendService } from '../services/AppBackendService';
import { RouteUtils } from '../utils/RouteUtils';

@Entry
@Component
struct AdminAuditLog {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @State auditLogs: BackendAuditRecord[] = [];
  @State filteredLogs: BackendAuditRecord[] = [];
  @State filterAction: string = 'all';
  @State searchText: string = '';

  aboutToAppear(): void {
    const account = AppBackendService.getCurrentAccount();
    if (!account || account.defaultRole !== AccountRole.Admin) {
      RouteUtils.replacePage(this.getUIContext(), 'pages/Login');
      return;
    }
    this.loadAuditLogs();
  }

  private async loadAuditLogs(): Promise<void> {
    const result = await AppBackendService.listAdminAuditLogsRemote();
    if (result.success && result.data) {
      this.auditLogs = result.data;
    } else {
      this.auditLogs = [];
    }
    this.applyFilter();
  }

  private actionDisplayName(action: string): string {
    if (action === 'login') return '登录';
    if (action === 'logout') return '登出';
    if (action === 'register') return '注册';
    if (action === 'certify') return '身份认证';
    if (action === 'bind') return '家庭绑定';
    if (action === 'order.create' || action === 'order') return '下单';
    if (action === 'payment.failed' || action === 'payment.cancelled') return '支付异常';
    if (action.startsWith('payment') || action === 'payment') return '支付';
    if (action.startsWith('admin.order')) return '管理订单';
    if (action.startsWith('admin.audit')) return '管理日志';
    if (action.startsWith('admin.account')) return '管理账号';
    if (action.startsWith('cs.')) return '客服工单';
    if (action.startsWith('order.')) return '订单';
    return action;
  }

  private actionColor(action: string): string {
    if (action === 'login' || action === 'register') return '#2E7D32';
    if (action === 'logout') return '#7B6B5D';
    if (action === 'certify' || action === 'bind') return '#1976D2';
    if (action.startsWith('order') || action.startsWith('payment')) return '#E53935';
    if (action.startsWith('admin')) return '#6A1B9A';
    if (action.startsWith('cs.')) return '#00695C';
    return '#8C2F23';
  }

  @Builder
  private FilterButton(label: string, value: string) {
    Button(label)
      .height(this.careMode ? 38 : 32)
      .fontSize(this.careMode ? 15 : 13)
      .fontColor(this.filterAction === value ? Color.White : '#8C2F23')
      .backgroundColor(this.filterAction === value ? '#1A237E' : '#E8EAF6')
      .borderRadius(8)
      .onClick(() => {
        this.filterAction = value;
        this.applyFilter();
      })
  }

  private matchesFilter(action: string, filter: string): boolean {
    if (filter === 'all') return true;
    if (filter === 'order') return action.startsWith('order') || action === 'order.create';
    if (filter === 'payment') return action.startsWith('payment');
    if (filter === 'admin') return action.startsWith('admin');
    if (filter === 'cs') return action.startsWith('cs.');
    return action === filter;
  }

  private applyFilter(): void {
    let filtered = this.auditLogs;
    if (this.filterAction !== 'all') {
      filtered = filtered.filter((item: BackendAuditRecord) => this.matchesFilter(item.action, this.filterAction));
    }
    if (this.searchText.length > 0) {
      const keyword = this.searchText.toLowerCase();
      filtered = filtered.filter((item: BackendAuditRecord) =>
        item.detail.toLowerCase().includes(keyword) ||
        item.action.toLowerCase().includes(keyword) ||
        (item.actorAccountId && item.actorAccountId.toLowerCase().includes(keyword))
      );
    }
    this.filteredLogs = filtered;
  }

  @Builder
  private LogCard(log: BackendAuditRecord) {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        Text(this.actionDisplayName(log.action))
          .fontSize(this.careMode ? 16 : 13)
          .fontColor(Color.White)
          .backgroundColor(this.actionColor(log.action))
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(8)

        Text(log.createdAt)
          .fontSize(this.careMode ? 14 : 11)
          .fontColor('#7B6B5D')

        Blank()

        Button('删除')
          .height(this.careMode ? 32 : 26)
          .fontSize(this.careMode ? 13 : 10)
          .fontColor('#C62828')
          .backgroundColor('#FFEBEE')
          .borderRadius(6)
          .onClick(() => { this.deleteLog(log); })
      }
      .width('100%')

      Text(log.detail)
        .fontSize(this.careMode ? 16 : 13)
        .fontColor('#431407')
        .lineHeight(this.careMode ? 24 : 19)
        .width('100%')

      if (log.actorAccountId && log.actorAccountId.length > 0) {
        Row({ space: 8 }) {
          Text('操作人:')
            .fontSize(this.careMode ? 14 : 11)
            .fontColor('#6D6258')
          Text(AppBackendService.getAccountName(log.actorAccountId))
            .fontSize(this.careMode ? 14 : 11)
            .fontColor('#431407')
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(8)
    .border({ width: 1, color: '#E8DDD2' })
  }

  private deleteLog(log: BackendAuditRecord): void {
    this.getUIContext().showAlertDialog({
      title: '删除日志',
      message: '确认删除该审计日志？此操作不可恢复。',
      primaryButton: {
        value: '确认删除',
        action: async () => {
          const result = await AppBackendService.adminDeleteAuditLogRemote(log.id);
          if (result.success) {
            this.auditLogs = this.auditLogs.filter((item: BackendAuditRecord) => item.id !== log.id);
            this.applyFilter();
            this.getUIContext().getPromptAction().showToast({ message: '日志已删除' });
          } else {
            this.getUIContext().getPromptAction().showToast({ message: '删除失败' });
          }
        }
      },
      secondaryButton: {
        value: '返回',
        action: () => {}
      }
    });
  }

  private clearAllLogs(): void {
    this.getUIContext().showAlertDialog({
      title: '清空日志',
      message: '确认清空所有审计日志？此操作不可恢复。',
      primaryButton: {
        value: '确认清空',
        action: async () => {
          const result = await AppBackendService.adminClearAuditLogsRemote();
          if (result.success) {
            this.auditLogs = [];
            this.applyFilter();
            this.getUIContext().getPromptAction().showToast({ message: '日志已清空' });
          } else {
            this.getUIContext().getPromptAction().showToast({ message: '清空失败' });
          }
        }
      },
      secondaryButton: {
        value: '返回',
        action: () => {}
      }
    });
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Button('返回')
          .height(38)
          .fontSize(this.careMode ? 18 : 15)
          .fontColor('#1A237E')
          .backgroundColor('#E8EAF6')
          .borderRadius(8)
          .onClick(() => {
            RouteUtils.goBack(this.getUIContext());
          })
        Column({ space: 2 }) {
          Text('审计日志')
            .fontSize(this.careMode ? 22 : 18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text('查看完整的系统操作审计记录')
            .fontSize(this.careMode ? 14 : 11)
            .fontColor('#FFFFFFCC')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        CareModeToggle()
        Button('清空')
          .height(36)
          .fontSize(this.careMode ? 16 : 13)
          .fontColor('#C62828')
          .backgroundColor('#FFEBEE')
          .borderRadius(8)
          .onClick(() => { this.clearAllLogs(); })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: 14, bottom: 10 })
      .backgroundColor('#1A237E')

      Column({ space: 12 }) {
        TextInput({ placeholder: '搜索操作详情', text: this.searchText })
          .height(this.careMode ? 48 : 40)
          .fontSize(this.careMode ? 17 : 14)
          .backgroundColor(Color.White)
          .borderRadius(8)
          .border({ width: 1, color: '#E8DDD2' })
          .onChange((value: string) => {
            this.searchText = value;
            this.applyFilter();
          })

        Scroll({ scrollable: ScrollDirection.Horizontal }) {
          Row({ space: 8 }) {
            Text('筛选:')
              .fontSize(this.careMode ? 16 : 13)
              .fontColor('#6D6258')
            this.FilterButton('全部', 'all')
            this.FilterButton('登录', 'login')
            this.FilterButton('注册', 'register')
            this.FilterButton('认证', 'certify')
            this.FilterButton('绑定', 'bind')
            this.FilterButton('订单', 'order')
            this.FilterButton('支付', 'payment')
            this.FilterButton('管理', 'admin')
            this.FilterButton('客服', 'cs')
          }
        }
        .width('100%')

        Row() {
          Text('共 ' + this.filteredLogs.length + ' 条记录')
            .fontSize(this.careMode ? 16 : 13)
            .fontColor('#6D6258')
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ maxWidth: this.breakpoint === 'sm' ? 10000 : 840 })
      .padding(16)

      if (this.filteredLogs.length === 0) {
        Column() {
          Text('暂无审计日志')
            .fontSize(this.careMode ? 19 : 16)
            .fontColor('#7B6B5D')
            .margin({ top: 60 })
        }
        .layoutWeight(1)
      } else {
        Scroll() {
          Row() {
            Column({ space: 12 }) {
              ForEach(this.filteredLogs, (log: BackendAuditRecord) => {
                this.LogCard(log)
              }, (log: BackendAuditRecord) => log.id)
            }
            .width('100%')
            .constraintSize({ maxWidth: this.breakpoint === 'sm' ? 10000 : 840 })
            .padding({ left: 16, right: 16, bottom: 16 })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .layoutWeight(1)
      }

      BottomNav({
        role: 'admin',
        active: 'audit',
        careMode: this.careMode,
        onNavigate: (url: string) => {
          RouteUtils.replacePage(this.getUIContext(), url);
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#E8EAF6')
  }
}
