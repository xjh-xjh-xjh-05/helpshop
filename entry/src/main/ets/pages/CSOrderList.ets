import { BottomNav } from '../components/BottomNav';
import { AccountRole } from '../models/AuthModels';
import { AppBackendService } from '../services/AppBackendService';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';
import { OrderDraft, PaymentStatus } from '../models/ShoppingModels';

interface OrderItem { id: string; elderlyName: string; childName: string; product: string; amount: number; status: string; time: string; }

@Entry
@Component
struct CSOrderList {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @State orders: OrderItem[] = [];
  @State allOrders: OrderItem[] = [];
  @State filterStatus: string = 'all';
  @State loading: boolean = false;

  async aboutToAppear(): Promise<void> {
    if (AppBackendService.getCurrentRole() !== AccountRole.CustomerService) {
      RouteUtils.replacePage(this.getUIContext(), 'pages/Index'); return;
    }
    await this.loadOrders();
  }

  private async loadOrders(): Promise<void> {
    this.loading = true;
    const result = await AppBackendService.listCsOrdersRemote();
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

  private getStatusColor(status: string): string {
    if (status === '已完成') return '#2E7D32';
    if (status === '待支付') return '#C62828';
    if (status === '支付失败') return '#C62828';
    if (status === '已取消') return '#7B6B5D';
    return '#C62828';
  }

  private getStatusBg(status: string): string {
    if (status === '已完成') return '#E8F5E9';
    if (status === '待支付') return '#FFEBEE';
    if (status === '支付失败') return '#FFEBEE';
    if (status === '已取消') return '#F6EDE7';
    return '#FFEBEE';
  }

  @Builder
  private OrderRow(order: OrderItem) {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(order.product).fontSize(this.careMode ? 18 : 15).fontWeight(FontWeight.Bold).fontColor('#004D40').maxLines(1)
        Text(order.elderlyName + (order.childName.length > 0 ? '（代买：' + order.childName + '）' : '') + ' · ' + order.time).fontSize(this.careMode ? 14 : 12).fontColor('#80CBC4')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text('¥' + order.amount.toString()).fontSize(this.careMode ? 19 : 16).fontWeight(FontWeight.Bold).fontColor('#00695C')
      Column({ space: 6 }) {
        Text(order.status).fontSize(this.careMode ? 14 : 11).fontColor(this.getStatusColor(order.status))
          .padding({ left: 8, right: 8, top: 3, bottom: 3 }).backgroundColor(this.getStatusBg(order.status)).borderRadius(6)
        Button('详情').height(this.careMode ? 34 : 28).fontSize(this.careMode ? 13 : 11)
          .fontColor('#00695C').backgroundColor('#E0F2F1').borderRadius(6)
          .onClick(() => { this.viewOrderDetail(order); })
      }
    }
    .width('100%').padding(14).backgroundColor(Color.White).borderRadius(12)
    .shadow({ radius: 6, color: '#004D4008', offsetX: 0, offsetY: 1 })
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Text('订单查询').fontSize(this.careMode ? 28 : 22).fontWeight(FontWeight.Bold).fontColor('#004D40')
        Blank()
        Text('共 ' + this.orders.length.toString() + ' 笔').fontSize(this.careMode ? 15 : 12).fontColor('#80CBC4')
      }.width('100%').padding({ left: 18, right: 18, top: 16, bottom: 12 })

      Row({ space: 8 }) {
        ForEach(['all', '已完成', '待支付', '支付失败', '已取消'], (s: string) => {
          Text(s === 'all' ? '全部' : s)
            .fontSize(this.careMode ? 16 : 13)
            .fontColor(this.filterStatus === s ? '#FFFFFF' : '#80CBC4')
            .fontWeight(this.filterStatus === s ? FontWeight.Bold : FontWeight.Normal)
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .backgroundColor(this.filterStatus === s ? '#00695C' : '#E0F2F1').borderRadius(8)
            .onClick(() => { this.selectFilter(s); })
        }, (s: string) => s)
      }.width('100%').padding({ left: 18, right: 18, bottom: 10 })

      if (this.loading) {
        Column() {
          Text('加载中...').fontSize(this.careMode ? 18 : 15).fontColor('#80CBC4').margin({ top: 40 })
        }.layoutWeight(1)
      } else if (this.orders.length === 0) {
        Column() {
          Text('暂无订单数据').fontSize(this.careMode ? 18 : 15).fontColor('#80CBC4').margin({ top: 40 })
        }.layoutWeight(1)
      } else {
        Scroll() {
          Column({ space: 10 }) {
            ForEach(this.orders, (o: OrderItem) => { this.OrderRow(o) }, (o: OrderItem) => o.id)
          }.width('100%').padding({ left: 18, right: 18, top: 6, bottom: 100 })
        }.layoutWeight(1).backgroundColor('#F0FAF8')
      }

      BottomNav({ role: 'cs', active: 'orders', careMode: this.careMode,
        onNavigate: (url: string) => { RouteUtils.replacePage(this.getUIContext(), url); } })
    }.width('100%').height('100%').backgroundColor('#F0FAF8')
    .constraintSize({ maxWidth: this.breakpoint === 'sm' ? 10000 : 900 })
  }
}
