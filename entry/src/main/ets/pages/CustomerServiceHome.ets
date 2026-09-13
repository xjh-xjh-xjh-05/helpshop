import { BottomNav } from '../components/BottomNav';
import { AccountRole, CustomerTicket } from '../models/AuthModels';
import { AppBackendService } from '../services/AppBackendService';
import { CustomerServiceDashboardBackendData } from '../models/BackendModels';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';
import { RemoteBackendClient } from '../services/RemoteBackendClient';

interface TicketItem { id: string; user: string; title: string; priority: string; time: string; }

@Entry
@Component
struct CustomerServiceHome {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @State csName: string = '';
  @State openTickets: number = 0;
  @State resolvedToday: number = 0;
  @State avgResponseMin: number = 12;
  @State recentTickets: TicketItem[] = [];

  async aboutToAppear(): Promise<void> {
    const account = AppBackendService.getCurrentAccount();
    if (!account) { RouteUtils.replacePage(this.getUIContext(), 'pages/Login'); return; }
    if (account.defaultRole !== AccountRole.CustomerService) {
      RouteUtils.replacePage(this.getUIContext(), 'pages/Index'); return;
    }
    this.csName = account.displayName;
    await this.loadDashboard();
  }

  private priorityLabel(priority: string): string {
    if (priority === 'urgent') return '紧急';
    if (priority === 'high') return '高';
    if (priority === 'normal') return '普通';
    return '普通';
  }

  private async loadDashboard(): Promise<void> {
    const result = await AppBackendService.getCsDashboardRemote();
    if (result.success && result.data) {
      const data: CustomerServiceDashboardBackendData = result.data;
      this.openTickets = data.openTickets;
      this.resolvedToday = data.resolvedToday;
    }
    const ticketResult = await AppBackendService.csListTicketsRemote();
    if (ticketResult.success && ticketResult.data && ticketResult.data.pendingTickets && ticketResult.data.pendingTickets.length > 0) {
      this.recentTickets = ticketResult.data.pendingTickets
        .filter((t: CustomerTicket) => t.status === 'open' || t.status === 'processing')
        .map((t: CustomerTicket): TicketItem => {
        return {
          id: t.id,
          user: t.userDisplay ? t.userDisplay : (t.elderlyAccountId ? AppBackendService.getAccountName(t.elderlyAccountId) : ''),
          title: t.title,
          priority: this.priorityLabel(t.priority),
          time: t.createdAt
        } as TicketItem;
      });
    }
    if (this.recentTickets.length === 0) {
      const allTickets: CustomerTicket[] = AppBackendService.listAllTickets();
      if (allTickets.length > 0) {
        this.recentTickets = allTickets
          .filter((t: CustomerTicket) => t.status === 'open' || t.status === 'processing')
          .map((t: CustomerTicket): TicketItem => {
          return {
            id: t.id,
            user: t.userDisplay ? t.userDisplay : (t.elderlyAccountId ? AppBackendService.getAccountName(t.elderlyAccountId) : ''),
            title: t.title,
            priority: this.priorityLabel(t.priority),
            time: t.createdAt
          } as TicketItem;
        });
        this.openTickets = allTickets.filter((t: CustomerTicket) => t.status === 'open').length;
      }
    }
    if (this.openTickets === 0 && this.recentTickets.length > 0) {
      this.openTickets = this.recentTickets.length;
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

  private handleTicketFromHome(ticket: TicketItem): void {
    this.getUIContext().showAlertDialog({
      title: '处理工单',
      message: '工单：' + ticket.title + '\n用户：' + ticket.user + '\n优先级：' + ticket.priority,
      primaryButton: {
        value: '标记解决',
        action: async () => {
          const assignResult = await RemoteBackendClient.csAssignTicket(ticket.id);
          if (assignResult.success) {
            const resolveResult = await RemoteBackendClient.csResolveTicket(ticket.id, '已协助用户解决问题');
            if (!resolveResult.success) {
              AppBackendService.resolveTicket(ticket.id, '已协助用户解决问题');
            }
          } else {
            AppBackendService.assignTicket(ticket.id, AppBackendService.getCurrentAccount()?.id ?? '');
            AppBackendService.resolveTicket(ticket.id, '已协助用户解决问题');
          }
          const idx = this.recentTickets.findIndex((t: TicketItem) => t.id === ticket.id);
          if (idx >= 0) {
            this.recentTickets.splice(idx, 1);
            this.openTickets = Math.max(0, this.openTickets - 1);
            this.resolvedToday = this.resolvedToday + 1;
          }
          this.getUIContext().getPromptAction().showToast({ message: '工单已解决' });
        }
      },
      secondaryButton: {
        value: '去工单管理',
        action: () => {
          RouteUtils.replacePage(this.getUIContext(), 'pages/CSTicketManage');
        }
      }
    });
  }

  @Builder
  private TicketRow(ticket: TicketItem) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(ticket.title).fontSize(this.careMode ? 18 : 15).fontWeight(FontWeight.Bold).fontColor('#004D40').maxLines(2)
        Row({ space: 8 }) {
          Text(ticket.user).fontSize(this.careMode ? 14 : 12).fontColor('#00695C')
          Text(ticket.time).fontSize(this.careMode ? 13 : 11).fontColor('#80CBC4')
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Column({ space: 6 }) {
        Text(ticket.priority)
          .fontSize(this.careMode ? 13 : 10)
          .fontColor(ticket.priority === '紧急' ? '#C62828' : '#00695C')
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(ticket.priority === '紧急' ? '#FFEBEE' : '#E0F2F1').borderRadius(4)
        Button('处理').height(this.careMode ? 38 : 32).fontSize(this.careMode ? 14 : 11)
          .fontColor('#FFFFFF').backgroundColor('#00695C').borderRadius(8)
          .onClick(() => { this.handleTicketFromHome(ticket); })
      }
    }
    .width('100%').padding(14).backgroundColor(Color.White).borderRadius(12)
    .shadow({ radius: 6, color: '#004D4008', offsetX: 0, offsetY: 1 })
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
        Text('客服工作台').fontSize(this.careMode ? 28 : 22).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        Blank()
        Text(this.csName).fontSize(this.careMode ? 15 : 12).fontColor('#B2DFDB')
      }.width('100%').padding({ left: 18, right: 18, top: 16, bottom: 12 })
      .backgroundColor('#004D40')

      Scroll() {
        Column({ space: 14 }) {
          Text('今日概况').fontSize(this.careMode ? 22 : 18).fontWeight(FontWeight.Bold).fontColor('#004D40').width('100%')

          Row({ space: 10 }) {
            this.StatCard('待处理工单', this.openTickets.toString(), '#004D40', '#E0F2F1')
            this.StatCard('今日已解决', this.resolvedToday.toString(), '#00695C', '#E0F2F1')
          }.width('100%')

          Row({ space: 10 }) {
            this.StatCard('平均响应', this.avgResponseMin.toString() + '分钟', '#00695C', '#F0FAF8')
            this.StatCard('在线状态', '在线', '#2E7D32', '#E8F5E9')
          }.width('100%')

          Text('最新工单').fontSize(this.careMode ? 22 : 18).fontWeight(FontWeight.Bold).fontColor('#004D40').width('100%')

          ForEach(this.recentTickets, (ticket: TicketItem) => {
            this.TicketRow(ticket)
          }, (ticket: TicketItem) => ticket.id)

          Text('快捷入口').fontSize(this.careMode ? 22 : 18).fontWeight(FontWeight.Bold).fontColor('#004D40').width('100%')
          this.ActionCard('订单查询', '查看用户订单和支付状态', 'pages/CSOrderList')
          this.ActionCard('工单管理', '处理用户咨询和投诉工单', 'pages/CSTicketManage')
        }.width('100%').padding({ left: 18, right: 18, top: 6, bottom: 100 })
      }.layoutWeight(1).backgroundColor('#F0FAF8')

      BottomNav({ role: 'cs', active: 'home', careMode: this.careMode,
        onNavigate: (url: string) => { RouteUtils.replacePage(this.getUIContext(), url); } })
    }.width('100%').height('100%').backgroundColor('#F0FAF8')
    .constraintSize({ maxWidth: this.breakpoint === 'sm' ? 10000 : 900 })
  }
}
