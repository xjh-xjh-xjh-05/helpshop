import { BottomNav } from '../components/BottomNav';
import { BackendResult } from '../models/BackendModels';
import { OrderDraft } from '../models/ShoppingModels';
import { AppBackendService } from '../services/AppBackendService';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';

@Entry
@Component
struct OrderHistory {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @State orders: OrderDraft[] = [];

  private async refresh(): Promise<void> {
    try {
      const result: BackendResult<OrderDraft[]> = await AppBackendService.listOrdersRemote();
      this.orders = result.data ? result.data : [];
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '加载订单失败，请稍后重试');
    }
  }

  build() {
    Column() {
      Column({ space: 8 }) {
        Row() {
          Text('订单')
            .fontSize(this.careMode ? 30 : 24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#431407')
          Blank()
          Button('账号')
            .height(34)
            .fontSize(this.careMode ? 16 : 13)
            .fontColor('#2B7068')
            .backgroundColor('#EFFAF8')
            .borderRadius(8)
            .onClick(() => {
              RouteUtils.replacePage(this.getUIContext(), 'pages/Index');
            })
        }
        .width('100%')
        Text('查看已完成支付的购物记录。')
          .fontSize(this.careMode ? 17 : 13)
          .fontColor('#6F5B4B')
          .width('100%')
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#F3EFE8')

      Scroll() {
        Row() {
          Column({ space: 12 }) {
            if (this.orders.length === 0) {
              Column({ space: 8 }) {
                Text('暂无订单')
                  .fontSize(this.careMode ? 24 : 20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#431407')
                Text('完成一次模拟支付后，订单会显示在这里。')
                  .fontSize(this.careMode ? 18 : 14)
                  .fontColor('#6D6258')
                  .textAlign(TextAlign.Center)
              }
              .width('100%')
              .padding(28)
              .backgroundColor(Color.White)
              .borderRadius(8)
              .border({ width: 1, color: '#E8DDD2' })
            } else {
              ForEach(this.orders, (item: OrderDraft) => {
                Column({ space: 9 }) {
                  Row() {
                    Text(item.product.name)
                      .fontSize(this.careMode ? 23 : 19)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#431407')
                      .layoutWeight(1)
                      .maxLines(2)
                    Text('已支付')
                      .fontSize(this.careMode ? 15 : 12)
                      .fontColor('#2B7068')
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .backgroundColor('#EFFAF8')
                      .borderRadius(8)
                  }
                  .width('100%')

                  Text(item.product.platform + ' · ' + item.product.shopName)
                    .fontSize(this.careMode ? 16 : 13)
                    .fontColor('#6D6258')
                    .width('100%')
                  Text('订单号：' + item.id)
                    .fontSize(this.careMode ? 16 : 13)
                    .fontColor('#6D6258')
                    .width('100%')
                  if (item.managedByChildAccountId && item.managedByChildAccountId.length > 0) {
                    Text('代买人：' + AppBackendService.getAccountName(item.managedByChildAccountId))
                      .fontSize(this.careMode ? 16 : 13)
                      .fontColor('#2B7068')
                      .width('100%')
                  }
                  Text('时间：' + item.createdAt + ' · 数量：' + item.quantity.toString() + ' · ' + AppBackendService.paymentMethodName(item.paymentMethod))
                    .fontSize(this.careMode ? 17 : 14)
                    .fontColor('#5C5048')
                    .width('100%')
                  Text('收货：' + item.address.receiver + '，' + item.address.detail)
                    .fontSize(this.careMode ? 17 : 14)
                    .fontColor('#5C5048')
                    .lineHeight(this.careMode ? 26 : 21)
                    .width('100%')
                  Row() {
                    Text('实付：¥' + item.totalPrice.toFixed(2))
                      .fontSize(this.careMode ? 26 : 22)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#378F85')
                    Blank()
                    Button('再次购买')
                      .height(this.careMode ? 42 : 36)
                      .fontSize(this.careMode ? 16 : 13)
                      .fontColor(Color.White)
                      .backgroundColor('#378F85')
                      .borderRadius(8)
                      .onClick(() => {
                        RouteUtils.navigate(this.getUIContext(),'pages/UserCategory');
                      })
                  }
                  .width('100%')
                }
                .width('100%')
                .padding(16)
                .backgroundColor(Color.White)
                .borderRadius(8)
                .border({ width: 1, color: '#E8DDD2' })
             }, (item: OrderDraft) => item.id)
           }
         }
         .width('100%')
         .constraintSize({ maxWidth: this.breakpoint === 'sm' ? 10000 : 720 })
         .padding(12)
         .onAppear(() => {
           this.refresh();
         })
       }
       .width('100%')
       .justifyContent(FlexAlign.Center)
     }
     .layoutWeight(1)

      BottomNav({
        role: 'user',
        active: 'order',
        careMode: this.careMode,
        onNavigate: (url: string) => {
          RouteUtils.replacePage(this.getUIContext(), url);
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3EFE8')
  }
}
