import { BottomNav } from '../components/BottomNav';
import { AccountRole } from '../models/AuthModels';
import { AppBackendService } from '../services/AppBackendService';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';
import { OrderDraft, PaymentStatus } from '../models/ShoppingModels';

interface OrderItem { id: string; elderlyName: string; childName: string; product: string; amount: number; status: string; time: string; }
interface StatusStyle { color: string; bg: string; }

@Entry
@Component
struct AdminOrderMonitor {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @State orders: OrderItem[] = [];
  @State allOrders: OrderItem[] = [];
  @State filterStatus: string = 'all';
  @State loading: boolean = false;

  async aboutToAppear(): Promise<void> {
    if (AppBackendService.getCurrentRole() !== AccountRole.Admin) {
      RouteUtils.replacePage(this.getUIContext(), 'pages/Index'); return;
    }
    await this.loadOrdersFromBackend();
  }

  private async loadOrdersFromBackend(): Promise<void> {
    this.loading = true;
    const result = await AppBackendService.listAdminOrdersRemote();
    if (result.success && result.data) {
      this.allOrders = result.data.map((order: OrderDraft): OrderItem => {
        return {
          id: order.id,
          elderlyName: order.elderlyAccountId ? AppBackendService.getAccountName(order.elderlyAccountId) : '',
          childName: (order.managedByChildAccountId && order.managedByChildAccountId.length > 0) ? AppBackendService.getAccountName(order.managedByChildAccountId) : '',
          product: order.product.name,
          amount: order.totalPrice,
          status: this.paymentStatusToLabel(order.paymentStatus),
          time: order.createdAt
        } as OrderItem;
      });
      this.applyFilter();
      this.loading = false;
      return;
    }
    this.allOrders = [];
    this.applyFilter();
    this.loading = false;
  }

  private paymentStatusToLabel(status: PaymentStatus): string {
    if (status === PaymentStatus.Success) return '已完成';
    if (status === PaymentStatus.Pending) return '待支付';
    if (status === PaymentStatus.Failed) return '支付失败';
    if (status === PaymentStatus.Cancelled) return '已取消';
    return '待支付';
  }

  private selectFilter(status: string): void {
    this.filterStatus = status;
    this.applyFilter();
  }

  private applyFilter(): void {
    if (this.filterStatus === 'all') { this.orders = [...this.allOrders]; }
    else { this.orders = this.allOrders.filter((o: OrderItem) => o.status === this.filterStatus); }
  }

  private updateOrderInList(orderId: string, newStatus: string): void {
    this.allOrders = this.allOrders.map((o: OrderItem): OrderItem => {
      if (o.id === orderId) {
        return { id: o.id, elderlyName: o.elderlyName, childName: o.childName, product: o.product, amount: o.amount, status: newStatus, time: o.time } as OrderItem;
      }
      return o;
    });
    this.applyFilter();
  }

  private getStatusStyle(status: string): StatusStyle {
    if (status === '已完成') { const s: StatusStyle = { color: '#2E7D32', bg: '#E8F5E9' }; return s; }
    if (status === '待发货') { const s: StatusStyle = { color: '#E65100', bg: '#FFF3E0' }; return s; }
    if (status === '待支付') { const s: StatusStyle = { color: '#C62828', bg: '#FFEBEE' }; return s; }
    if (status === '支付失败') { const s: StatusStyle = { color: '#C62828', bg: '#FFEBEE' }; return s; }
    if (status === '已取消') { const s: StatusStyle = { color: '#7B6B5D', bg: '#F6EDE7' }; return s; }
    const s: StatusStyle = { color: '#C62828', bg: '#FFEBEE' }; return s;
  }

  private viewOrderDetail(order: OrderItem): void {
    const buyerInfo: string = order.childName.length > 0
      ? order.elderlyName + '（代买：' + order.childName + '）'
      : order.elderlyName;
    this.getUIContext().showAlertDialog({
      title: '订单详情',
      message: '订单号：' + order.id + '\n商品：' + order.product + '\n金额：¥' + order.amount +
        '\n状态：' + order.status + '\n下单人：' + buyerInfo + '\n时间：' + order.time,
      primaryButton: {
        value: '关闭',
        action: () => {}
      }
    });
  }

  private cancelOrder(order: OrderItem): void {
    if (order.status === '已完成' || order.status === '已取消') {
      this.getUIContext().getPromptAction().showToast({ message: '该订单无法取消' });
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '取消订单',
      message: '确认取消订单 ' + order.id + '（' + order.product + '）？',
      primaryButton: {
        value: '确认取消',
        action: () => {
          this.updateOrderInList(order.id, '已取消');
          this.getUIContext().getPromptAction().showToast({ message: '订单已取消' });
        }
      },
      secondaryButton: {
        value: '返回',
        action: () => {}
      }
    });
  }

  private deleteOrder(order: OrderItem): void {
    this.getUIContext().showAlertDialog({
      title: '删除订单',
      message: '确认永久删除订单 ' + order.id + '（' + order.product + '）？此操作不可恢复。',
      primaryButton: {
        value: '确认删除',
        action: async () => {
          const result = await AppBackendService.adminDeleteOrderRemote(order.id);
          if (result.success) {
            this.allOrders = this.allOrders.filter((o: OrderItem) => o.id !== order.id);
            this.applyFilter();
            this.getUIContext().getPromptAction().showToast({ message: '订单已删除' });
          } else {
            this.getUIContext().getPromptAction().showToast({ message: '删除失败：' + result.message });
          }
        }
      },
      secondaryButton: {
        value: '返回',
        action: () => {}
      }
    });
  }

  private markShipped(order: OrderItem): void {
    if (order.status !== '待发货') {
      this.getUIContext().getPromptAction().showToast({ message: '只有待发货订单可标记发货' });
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '标记发货',
      message: '确认将订单 ' + order.id + ' 标记为已发货？',
      primaryButton: {
        value: '确认发货',
        action: () => {
          this.updateOrderInList(order.id, '已完成');
          this.getUIContext().getPromptAction().showToast({ message: '订单已标记发货' });
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    });
  }

  @Builder
  private OrderRow(order: OrderItem) {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        Column({ space: 3 }) {
          Text(order.product).fontSize(this.careMode ? 18 : 15).fontWeight(FontWeight.Bold).fontColor('#1A237E').maxLines(1)
          Text(order.elderlyName + (order.childName.length > 0 ? '（代买：' + order.childName + '）' : '') + ' · ' + order.time).fontSize(this.careMode ? 14 : 12).fontColor('#7986CB')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text('¥' + order.amount.toString()).fontSize(this.careMode ? 19 : 16).fontWeight(FontWeight.Bold).fontColor('#283593')
        Text(order.status).fontSize(this.careMode ? 14 : 11).fontColor(this.getStatusStyle(order.status).color)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 }).backgroundColor(this.getStatusStyle(order.status).bg).borderRadius(6)
      }.width('100%')

      Row({ space: 8 }) {
        Button('详情')
          .height(this.careMode ? 34 : 28).fontSize(this.careMode ? 13 : 11)
          .fontColor('#1A237E').backgroundColor('#E8EAF6').borderRadius(6)
          .onClick(() => { this.viewOrderDetail(order); })
        if (order.status === '待发货') {
          Button('发货')
            .height(this.careMode ? 34 : 28).fontSize(this.careMode ? 13 : 11)
            .fontColor('#2E7D32').backgroundColor('#E8F5E9').borderRadius(6)
            .onClick(() => { this.markShipped(order); })
        }
        if (order.status !== '已完成' && order.status !== '已取消') {
          Button('取消')
            .height(this.careMode ? 34 : 28).fontSize(this.careMode ? 13 : 11)
            .fontColor('#C62828').backgroundColor('#FFEBEE').borderRadius(6)
            .onClick(() => { this.cancelOrder(order); })
        }
        Button('删除')
          .height(this.careMode ? 34 : 28).fontSize(this.careMode ? 13 : 11)
          .fontColor('#C62828').backgroundColor('#FFEBEE').borderRadius(6)
          .onClick(() => { this.deleteOrder(order); })
      }.width('100%').justifyContent(FlexAlign.End)
    }
    .width('100%').padding(14).backgroundColor(Color.White).borderRadius(12)
    .shadow({ radius: 6, color: '#1A237E08', offsetX: 0, offsetY: 2 })
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Text('订单监控').fontSize(this.careMode ? 28 : 22).fontWeight(FontWeight.Bold).fontColor('#1A237E')
        Blank()
        Text('共 ' + this.orders.length.toString() + ' 笔').fontSize(this.careMode ? 15 : 12).fontColor('#7986CB')
      }.width('100%').padding({ left: 18, right: 18, top: 16, bottom: 12 })

      Row({ space: 8 }) {
        ForEach(['all', '已完成', '待发货', '待支付'], (s: string) => {
          Text(s === 'all' ? '全部' : s)
            .fontSize(this.careMode ? 16 : 13)
            .fontColor(this.filterStatus === s ? '#FFFFFF' : '#7986CB')
            .fontWeight(this.filterStatus === s ? FontWeight.Bold : FontWeight.Normal)
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .backgroundColor(this.filterStatus === s ? '#1A237E' : '#E8EAF6').borderRadius(8)
            .onClick(() => { this.selectFilter(s); })
        }, (s: string) => s)
      }.width('100%').padding({ left: 18, right: 18, bottom: 10 })

      if (this.loading) {
        Column() {
          Text('加载中...').fontSize(this.careMode ? 18 : 15).fontColor('#7986CB').margin({ top: 40 })
        }.layoutWeight(1)
      } else if (this.orders.length === 0) {
        Column() {
          Text('暂无订单数据').fontSize(this.careMode ? 18 : 15).fontColor('#7986CB').margin({ top: 40 })
        }.layoutWeight(1)
      } else {
        Scroll() {
          Column({ space: 10 }) {
            ForEach(this.orders, (o: OrderItem) => { this.OrderRow(o) }, (o: OrderItem) => o.id)
          }.width('100%').padding({ left: 18, right: 18, top: 6, bottom: 100 })
        }.layoutWeight(1).backgroundColor('#F5F7FF')
      }

      BottomNav({ role: 'admin', active: 'orders', careMode: this.careMode,
        onNavigate: (url: string) => { RouteUtils.replacePage(this.getUIContext(), url); } })
    }.width('100%').height('100%')
    .constraintSize({ maxWidth: this.breakpoint === 'sm' ? 10000 : 900 }).backgroundColor('#F5F7FF')
  }
}
