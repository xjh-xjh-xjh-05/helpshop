import { BottomNav } from '../components/BottomNav';
import { AccountRole, CustomerTicket } from '../models/AuthModels';
import { AppBackendService } from '../services/AppBackendService';
import { CustomerServiceDashboardBackendData } from '../models/BackendModels';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';
import { RemoteBackendClient } from '../services/RemoteBackendClient';

interface TicketItem { id: string; user: string; title: string; priority: string; status: string; time: string; }

@Entry
@Component
struct CSTicketManage {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @State tickets: TicketItem[] = [];
  @State filterTab: string = 'pending';
  @State loading: boolean = false;
  private resolvedIds: Set<string> = new Set();

  async aboutToAppear(): Promise<void> {
    if (AppBackendService.getCurrentRole() !== AccountRole.CustomerService) {
      RouteUtils.replacePage(this.getUIContext(), 'pages/Index'); return;
    }
    await this.loadTickets();
  }

  private async loadTickets(): Promise<void> {
    this.loading = true;
    const result = await AppBackendService.csListTicketsRemote();
    if (result.success && result.data && result.data.pendingTickets && result.data.pendingTickets.length > 0) {
      this.tickets = result.data.pendingTickets.map((t: CustomerTicket): TicketItem => {
        const isResolved = this.resolvedIds.has(t.id);
        return {
          id: t.id,
          user: t.userDisplay ? t.userDisplay : (t.elderlyAccountId ? AppBackendService.getAccountName(t.elderlyAccountId) : ''),
          title: t.title,
          priority: this.priorityLabel(t.priority),
          status: isResolved ? '已处理' : this.statusLabel(t.status),
          time: t.createdAt
        } as TicketItem;
      });
      this.loading = false;
      return;
    }
    const allTickets: CustomerTicket[] = AppBackendService.listAllTickets();
    if (allTickets.length > 0) {
      this.tickets = allTickets.map((t: CustomerTicket): TicketItem => {
        const isResolved = this.resolvedIds.has(t.id);
        return {
          id: t.id,
          user: t.userDisplay ? t.userDisplay : (t.elderlyAccountId ? AppBackendService.getAccountName(t.elderlyAccountId) : ''),
          title: t.title,
          priority: this.priorityLabel(t.priority),
          status: isResolved ? '已处理' : this.statusLabel(t.status),
          time: t.createdAt
        } as TicketItem;
      });
      this.loading = false;
      return;
    }
    this.tickets = [];
    this.loading = false;
  }

  private priorityLabel(priority: string): string {
    if (priority === 'urgent') return '紧急';
    if (priority === 'high') return '高';
    if (priority === 'normal') return '普通';
    if (priority === '紧急') return '紧急';
    if (priority === '普通') return '普通';
    return '普通';
  }

  private statusLabel(status: string): string {
    if (status === 'open') return '待处理';
    if (status === 'processing') return '处理中';
    if (status === 'resolved') return '已处理';
    if (status === '待处理') return '待处理';
    if (status === '已处理') return '已处理';
    return '待处理';
  }

  private updateTicketStatus(ticketId: string, newStatus: string): void {
    this.tickets = this.tickets.map((t: TicketItem): TicketItem => {
      if (t.id === ticketId) {
        return {
          id: t.id,
          user: t.user,
          title: t.title,
          priority: t.priority,
          status: newStatus,
          time: t.time
        } as TicketItem;
      }
      return t;
    });
  }

  private handleTicket(ticket: TicketItem): void {
    if (ticket.status === '待处理' || ticket.status === '处理中') {
      this.getUIContext().showAlertDialog({
        title: '处理工单',
        message: '工单：' + ticket.title + '\n用户：' + ticket.user + '\n优先级：' + ticket.priority + '\n\n点击"标记解决"完成处理',
        primaryButton: {
          value: '标记解决',
          action: async () => {
            const assignResult = await RemoteBackendClient.csAssignTicket(ticket.id);
            if (assignResult.success) {
              const resolveResult = await RemoteBackendClient.csResolveTicket(ticket.id, '已协助用户解决问题');
              if (resolveResult.success) {
                this.resolvedIds.add(ticket.id);
                this.updateTicketStatus(ticket.id, '已处理');
                this.getUIContext().getPromptAction().showToast({ message: '工单已标记为已解决' });
              } else {
                AppBackendService.resolveTicket(ticket.id, '已协助用户解决问题');
                this.resolvedIds.add(ticket.id);
                this.updateTicketStatus(ticket.id, '已处理');
                this.getUIContext().getPromptAction().showToast({ message: '工单已标记为已解决（本地模式）' });
              }
            } else {
              AppBackendService.assignTicket(ticket.id, AppBackendService.getCurrentAccount()?.id ?? '');
              AppBackendService.resolveTicket(ticket.id, '已协助用户解决问题');
              this.resolvedIds.add(ticket.id);
              this.updateTicketStatus(ticket.id, '已处理');
              this.getUIContext().getPromptAction().showToast({ message: '工单已标记为已解决（本地模式）' });
            }
          }
        },
        secondaryButton: {
          value: '取消',
          action: () => {}
        }
      });
    } else {
      this.getUIContext().getPromptAction().showToast({ message: '该工单已处理完成' });
    }
  }

  private escalateTicket(ticket: TicketItem): void {
    this.getUIContext().showAlertDialog({
      title: '升级工单',
      message: '确认将工单 "' + ticket.title + '" 升级为紧急？',
      primaryButton: {
        value: '确认升级',
        action: async () => {
          const result = await RemoteBackendClient.csEscalateTicket(ticket.id);
          if (!result.success) {
            AppBackendService.escalateTicket(ticket.id);
          }
          this.tickets = this.tickets.map((t: TicketItem): TicketItem => {
            if (t.id === ticket.id) {
              return {
                id: t.id,
                user: t.user,
                title: t.title,
                priority: '紧急',
                status: t.status,
                time: t.time
              } as TicketItem;
            }
            return t;
          });
          this.getUIContext().getPromptAction().showToast({ message: '工单已升级为紧急' });
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    });
  }

  @Builder
  private TicketRow(ticket: TicketItem) {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text(ticket.title)
            .fontSize(this.careMode ? 18 : 15).fontWeight(FontWeight.Bold).fontColor('#004D40').maxLines(2)
          Row({ space: 8 }) {
            Text(ticket.user).fontSize(this.careMode ? 14 : 12).fontColor('#80CBC4')
            Text(ticket.time).fontSize(this.careMode ? 13 : 11).fontColor('#B2DFDB')
          }
          Row({ space: 6 }) {
            Text(ticket.priority)
              .fontSize(this.careMode ? 13 : 10)
              .fontColor(ticket.priority === '紧急' ? '#E65100' : '#00695C')
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(ticket.priority === '紧急' ? '#FFF3E0' : '#E0F2F1').borderRadius(4)
            Text(ticket.status)
              .fontSize(this.careMode ? 13 : 10).fontColor('#00695C')
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor('#E0F2F1').borderRadius(4)
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')

      if (ticket.status === '待处理' || ticket.status === '处理中') {
        Row({ space: 10 }) {
          Button('处理')
            .layoutWeight(1)
            .height(this.careMode ? 40 : 34).fontSize(this.careMode ? 15 : 12)
            .fontColor('#FFFFFF').backgroundColor('#00695C').borderRadius(8)
            .onClick(() => { this.handleTicket(ticket); })
          Button('升级')
            .height(this.careMode ? 40 : 34).fontSize(this.careMode ? 15 : 12)
            .fontColor('#E65100').backgroundColor('#FFF3E0').borderRadius(8)
            .onClick(() => { this.escalateTicket(ticket); })
        }.width('100%')
      } else {
        Row() {
          Text('已处理 ✓').fontSize(this.careMode ? 15 : 13).fontColor('#2E7D32')
        }.width('100%').justifyContent(FlexAlign.End)
      }
    }
    .width('100%').padding(14).backgroundColor(Color.White).borderRadius(12)
    .shadow({ radius: 6, color: '#004D4008', offsetX: 0, offsetY: 2 })
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Text('工单管理').fontSize(this.careMode ? 28 : 22).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        Blank()
        Text(this.tickets.filter((t: TicketItem) => t.status === '待处理' || t.status === '处理中').length.toString() + ' 待处理')
          .fontSize(this.careMode ? 15 : 12).fontColor('#B2DFDB')
      }.width('100%').padding({ left: 18, right: 18, top: 16, bottom: 12 })
      .backgroundColor('#004D40')

      Row({ space: 8 }) {
        ForEach(['pending', 'done'], (tab: string) => {
          Text(tab === 'pending' ? '待处理' : '已处理')
            .fontSize(this.careMode ? 16 : 13)
            .fontColor(this.filterTab === tab ? '#FFFFFF' : '#80CBC4')
            .fontWeight(this.filterTab === tab ? FontWeight.Bold : FontWeight.Normal)
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .backgroundColor(this.filterTab === tab ? '#00695C' : '#E0F2F1').borderRadius(8)
            .onClick(() => { this.filterTab = tab; })
        }, (tab: string) => tab)
      }.width('100%').padding({ left: 18, right: 18, bottom: 10 })

      if (this.loading) {
        Column() {
          Text('加载中...').fontSize(this.careMode ? 18 : 15).fontColor('#80CBC4').margin({ top: 40 })
        }.layoutWeight(1)
      } else {
        Scroll() {
          Column({ space: 10 }) {
            ForEach(this.tickets.filter((t: TicketItem) =>
              this.filterTab === 'pending' ? (t.status === '待处理' || t.status === '处理中') : t.status === '已处理'
            ), (t: TicketItem) => { this.TicketRow(t) }, (t: TicketItem) => t.id)
          }.width('100%').padding({ left: 18, right: 18, top: 6, bottom: 100 })
        }.layoutWeight(1).backgroundColor('#F0FAF8')
      }

      BottomNav({ role: 'cs', active: 'tickets', careMode: this.careMode,
        onNavigate: (url: string) => { RouteUtils.replacePage(this.getUIContext(), url); } })
    }.width('100%').height('100%').backgroundColor('#F0FAF8')
    .constraintSize({ maxWidth: this.breakpoint === 'sm' ? 10000 : 900 })
  }
}
