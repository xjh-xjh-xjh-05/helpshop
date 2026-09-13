import { CareModeToggle } from '../components/CareModeToggle';
import { AccountRole } from '../models/AuthModels';
import { BackendResult, PaymentWorkflowBackendData } from '../models/BackendModels';
import { Address, PaymentMethod, PaymentStatus, ProductCandidate } from '../models/ShoppingModels';
import { AppBackendService } from '../services/AppBackendService';
import { common } from '@kit.AbilityKit';
import { AgentSessionManager } from '../agent/AgentSessionManager';
import { ShoppingAgentOrchestrator } from '../agent/ShoppingAgentOrchestrator';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';
import EntryAbility from '../entryability/EntryAbility';

interface PaymentParams {
  productId?: string;
  quantity?: string;
}

@Entry
@Component
struct PaymentConfirm {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @State product: ProductCandidate = AppBackendService.getDefaultProduct();
  @State quantity: number = 1;
  @State hasAddress: boolean = false;
  @State addresses: Address[] = [];
  @State address: Address = {
    id: '',
    receiver: '',
    phone: '',
    detail: '',
    isDefault: false
  };
  @State paymentMessage: string = '';
  @State paymentStatus: PaymentStatus = PaymentStatus.Pending;
  @State orderMessage: string = '';

  async aboutToAppear(): Promise<void> {
    const role = AppBackendService.getCurrentRole();
    if (role === AccountRole.Unverified) {
      RouteUtils.showToast(this.getUIContext(), '请先完成身份认证');
      RouteUtils.pushPage(this.getUIContext(), 'pages/IdentityAuth');
      return;
    }
    if (!AppBackendService.canEnterShopping()) {
      RouteUtils.showToast(this.getUIContext(), '请先绑定老人账号，再帮助老人购物');
      RouteUtils.pushPage(this.getUIContext(), 'pages/BindFamily');
      return;
    }
    const agentSession = AgentSessionManager.getSession();
    if (agentSession.selectedProduct.id.length > 0) {
      this.product = agentSession.selectedProduct;
      this.quantity = agentSession.quantity > 0 ? agentSession.quantity : 1;
    } else {
      const routerParams: PaymentParams = this.getUIContext().getRouter().getParams() as PaymentParams;
      const productIdParam: string = routerParams?.productId ?? '';
      const quantityParam: string = routerParams?.quantity ?? '';
      if (productIdParam.length > 0) {
      try {
        const productResult: BackendResult<ProductCandidate> = await AppBackendService.getProductByIdRemote(productIdParam);
        if (productResult.success && productResult.data) {
          this.product = productResult.data;
          AgentSessionManager.setSelectedProduct(productResult.data, 1);
        }
      } catch (error) {
        RouteUtils.showToast(this.getUIContext(), '加载商品失败，请稍后重试');
      }
      }
      if (quantityParam.length > 0) {
        const parsed = Number(quantityParam);
        this.quantity = parsed > 0 ? parsed : 1;
        AgentSessionManager.setSelectedProduct(this.product, this.quantity);
      }
    }
    if (agentSession.addressId.length > 0) {
      AgentSessionManager.setAddress(agentSession.addressId);
    }
    this.loadAddresses();
  }

  private async loadAddresses(): Promise<void> {
    try {
      const addressResult: BackendResult<Address[]> = await AppBackendService.listAddressesRemote();
      this.addresses = addressResult.data ? addressResult.data : [];
      const selected = this.addresses.find((item: Address) => item.isDefault);
      if (selected) {
        this.address = selected;
        this.hasAddress = true;
        return;
      }
      if (this.addresses.length > 0) {
        this.address = this.addresses[0];
        this.hasAddress = true;
        return;
      }
      this.hasAddress = false;
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '加载地址失败，请稍后重试');
    }
  }

  private totalPrice(): string {
    return (this.product.price * this.quantity).toFixed(2);
  }

  private increaseQuantity(): void {
    if (this.quantity < 99) {
      this.quantity += 1;
    }
  }

  private decreaseQuantity(): void {
    if (this.quantity > 1) {
      this.quantity -= 1;
    }
  }

  private selectAddress(address: Address): void {
    this.address = address;
    this.hasAddress = true;
    AgentSessionManager.setAddress(address.id);
  }

  private async handleHuaWeiPay(): Promise<void> {
    if (!this.hasAddress) {
      RouteUtils.showToast(this.getUIContext(), '请先添加默认收货地址');
      return;
    }
    AgentSessionManager.setSelectedProduct(this.product, this.quantity);
    AgentSessionManager.setPaymentMethod(PaymentMethod.HuaWeiPay);
    try {
      const context: common.UIAbilityContext | undefined = EntryAbility.abilityContext;
      if (!context) {
        RouteUtils.showToast(this.getUIContext(), '应用上下文未就绪');
        return;
      }
      const result: BackendResult<PaymentWorkflowBackendData> =
        await AppBackendService.agentPayAndCreateOrder(context);
      if (result.data) {
        this.paymentStatus = result.data.payment.status;
        this.paymentMessage = result.data.payment.message;
      }
      if (result.success && result.data && result.data.order && result.data.reminder) {
        this.orderMessage = '订单 ' + result.data.order.id + ' 已生成，' + result.data.reminder.title + '已写入子女端提醒记录。';
      } else {
        this.orderMessage = '';
      }
      RouteUtils.showToast(this.getUIContext(), result.message);
      if (result.success) {
        this.goToWorkbench();
      }
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '华为支付调用失败');
    }
  }

  private async handleSuccess(method: PaymentMethod): Promise<void> {
    if (!this.hasAddress) {
      RouteUtils.showToast(this.getUIContext(), '请先添加默认收货地址');
      return;
    }
    AgentSessionManager.setSelectedProduct(this.product, this.quantity);
    AgentSessionManager.setPaymentMethod(method);
    const result: BackendResult<PaymentWorkflowBackendData> =
      await AppBackendService.payAndCreateOrderRemote(this.product, this.quantity, this.address, method);
    if (result.data) {
      this.paymentStatus = result.data.payment.status;
      this.paymentMessage = result.data.payment.message;
    }
    if (result.success && result.data && result.data.order && result.data.reminder) {
      this.orderMessage = '订单 ' + result.data.order.id + ' 已生成，' + result.data.reminder.title + '已写入子女端提醒记录。';
    } else {
      this.orderMessage = '';
    }
    RouteUtils.showToast(this.getUIContext(), result.message);
    // 支付成功：清栈回对应工作台，不经过比价页
    if (result.success) {
      this.goToWorkbench();
    }
  }

  private goToWorkbench(): void {
    const role: AccountRole = AppBackendService.getCurrentRole();
    let homeUrl: string = 'pages/UserHome';
    if (role === AccountRole.Child) {
      homeUrl = 'pages/ChildHome';
    } else if (role === AccountRole.Admin) {
      homeUrl = 'pages/AdminHome';
    } else if (role === AccountRole.CustomerService) {
      homeUrl = 'pages/CustomerServiceHome';
    }
    RouteUtils.clearAndPush(this.getUIContext(), homeUrl);
  }

  private async handleFailure(): Promise<void> {
    if (!this.hasAddress) {
      RouteUtils.showToast(this.getUIContext(), '请先添加默认收货地址');
      return;
    }
    const result: BackendResult<PaymentWorkflowBackendData> = await AppBackendService.simulatePaymentFailedRemote(this.product, this.quantity, this.address);
    if (result.data) {
      this.paymentStatus = result.data.payment.status;
      this.paymentMessage = result.data.payment.message;
    }
    this.orderMessage = '';
    RouteUtils.showToast(this.getUIContext(), result.message);
  }

  private async handleCancel(): Promise<void> {
    if (!this.hasAddress) {
      RouteUtils.showToast(this.getUIContext(), '请先添加默认收货地址');
      return;
    }
    const result: BackendResult<PaymentWorkflowBackendData> = await AppBackendService.simulatePaymentCancelledRemote(this.product, this.quantity, this.address);
    if (result.data) {
      this.paymentStatus = result.data.payment.status;
      this.paymentMessage = result.data.payment.message;
    }
    this.orderMessage = '';
    RouteUtils.showToast(this.getUIContext(), result.message);
  }

  private goAddressManage(): void {
    RouteUtils.pushPage(this.getUIContext(), 'pages/AddressManage');
  }

  private goOrderHistory(): void {
    RouteUtils.pushPage(this.getUIContext(), 'pages/OrderHistory');
  }

  build() {
    Scroll() {
      Row() {
        Column({ space: 18 }) {
          Row() {
            Button('返回')
              .fontSize(this.careMode ? 18 : 15)
              .fontColor('#2B7068')
              .backgroundColor('#EFFAF8')
              .borderRadius(18)
              .onClick(() => {
                RouteUtils.clearAndPush(this.getUIContext(), 'pages/UserHome');
              })
            Blank()
            CareModeToggle()
          }
          .width('100%')

          Text('支付确认')
            .fontSize(this.careMode ? 32 : 26)
            .fontWeight(FontWeight.Bold)
            .fontColor('#431407')
            .width('100%')

          Column({ space: 12 }) {
            Text(this.product.name)
              .fontSize(this.careMode ? 26 : 21)
              .fontWeight(FontWeight.Bold)
              .fontColor('#431407')
              .width('100%')
            Text(this.product.platform + ' · ' + this.product.shopName)
              .fontSize(this.careMode ? 18 : 15)
              .fontColor('#6B4E3D')
              .width('100%')
            Row() {
              Text('单价：¥' + this.product.price.toString())
                .fontSize(this.careMode ? 20 : 16)
                .fontColor('#5C5048')
              Blank()
              Row({ space: 10 }) {
                Button('-')
                  .width(38)
                  .height(38)
                  .fontSize(20)
                  .fontColor('#2B7068')
                  .backgroundColor('#EFFAF8')
                  .borderRadius(19)
                  .onClick(() => {
                    this.decreaseQuantity();
                  })
                Text(this.quantity.toString())
                  .fontSize(this.careMode ? 22 : 18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#431407')
                  .width(42)
                  .textAlign(TextAlign.Center)
                Button('+')
                  .width(38)
                  .height(38)
                  .fontSize(20)
                  .fontColor(Color.White)
                  .backgroundColor('#378F85')
                  .borderRadius(19)
                  .onClick(() => {
                    this.increaseQuantity();
                  })
              }
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')
            Text('数量范围：1-99，当前数量 ' + this.quantity.toString())
              .fontSize(this.careMode ? 20 : 16)
              .fontColor('#7A5C45')
              .width('100%')
            Text('合计：¥' + this.totalPrice())
              .fontSize(this.careMode ? 30 : 25)
              .fontWeight(FontWeight.Bold)
              .fontColor('#378F85')
              .width('100%')
          }
          .width('100%')
          .padding(18)
          .backgroundColor(Color.White)
          .borderRadius(18)
          .border({ width: 1, color: '#E8DDD2' })

          Column({ space: 10 }) {
            Text('收货地址')
              .fontSize(this.careMode ? 24 : 20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#431407')
              .width('100%')

            if (this.hasAddress) {
              ForEach(this.addresses, (item: Address) => {
                Column({ space: 6 }) {
                  Row() {
                    Text(item.receiver + '  ' + item.phone)
                      .fontSize(this.careMode ? 20 : 16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#431407')
                    Blank()
                    if (this.address.id === item.id) {
                      Text('已选择')
                        .fontSize(this.careMode ? 16 : 13)
                        .fontColor('#2B7068')
                        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                        .backgroundColor('#EFFAF8')
                        .borderRadius(10)
                    }
                  }
                  .width('100%')
                  Text(item.detail)
                    .fontSize(this.careMode ? 18 : 15)
                    .fontColor('#5C5048')
                    .lineHeight(this.careMode ? 28 : 22)
                    .width('100%')
                }
                .width('100%')
                .padding(12)
                .backgroundColor(this.address.id === item.id ? '#FAF7F2' : Color.White)
                .borderRadius(12)
                .border({ width: this.address.id === item.id ? 2 : 1, color: this.address.id === item.id ? '#378F85' : '#E8DDD2' })
                .onClick(() => {
                  this.selectAddress(item);
                })
              }, (item: Address) => item.id)
            } else {
              Text('暂无可用收货地址，请让子女在子女端先添加地址。')
                .fontSize(this.careMode ? 18 : 15)
                .fontColor('#2B7068')
                .width('100%')
              Button('去子女端添加地址')
                .width('100%')
                .height(this.careMode ? 52 : 46)
                .fontSize(this.careMode ? 18 : 15)
                .fontColor(Color.White)
                .backgroundColor('#378F85')
                .borderRadius(23)
                .onClick(() => {
                  this.goAddressManage();
                })
            }
          }
          .width('100%')
          .padding(18)
          .backgroundColor('#FAF7F2')
          .borderRadius(18)
          .border({ width: 1, color: '#E8DDD2' })

          Column({ space: 12 }) {
            Text('选择支付方式')
              .fontSize(this.careMode ? 24 : 20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#431407')
              .width('100%')

            Button('华为支付')
              .width('100%')
              .height(this.careMode ? 56 : 48)
              .fontSize(this.careMode ? 19 : 16)
              .fontColor(Color.White)
              .backgroundColor('#CF2B1D')
              .borderRadius(24)
              .onClick(() => {
                this.handleHuaWeiPay();
              })

            Text('模拟支付（开发测试）')
              .fontSize(this.careMode ? 16 : 13)
              .fontColor('#7A5C45')
              .width('100%')
              .padding({ top: 8 })

            Button('人脸支付成功')
              .width('100%')
              .height(this.careMode ? 56 : 48)
              .fontSize(this.careMode ? 19 : 16)
              .fontColor(Color.White)
              .backgroundColor('#378F85')
              .borderRadius(24)
              .onClick(() => {
                this.handleSuccess(PaymentMethod.Face);
              })

            Row({ space: 12 }) {
              Button('指纹支付成功')
                .layoutWeight(1)
                .height(this.careMode ? 52 : 44)
                .fontSize(this.careMode ? 17 : 14)
                .fontColor(Color.White)
                .backgroundColor('#2B7068')
                .borderRadius(22)
                .onClick(() => {
                  this.handleSuccess(PaymentMethod.Fingerprint);
                })

              Button('密码支付成功')
                .layoutWeight(1)
                .height(this.careMode ? 52 : 44)
                .fontSize(this.careMode ? 17 : 14)
                .fontColor(Color.White)
                .backgroundColor('#2B7068')
                .borderRadius(22)
                .onClick(() => {
                  this.handleSuccess(PaymentMethod.Password);
                })
            }
            .width('100%')

            Row({ space: 12 }) {
              Button('模拟失败')
                .layoutWeight(1)
                .height(this.careMode ? 52 : 44)
                .fontSize(this.careMode ? 17 : 14)
                .fontColor('#B91C1C')
                .backgroundColor('#FEE2E2')
                .borderRadius(22)
                .onClick(() => {
                  this.handleFailure();
                })

              Button('模拟取消')
                .layoutWeight(1)
                .height(this.careMode ? 52 : 44)
                .fontSize(this.careMode ? 17 : 14)
                .fontColor('#7A5C45')
                .backgroundColor('#EEE8E0')
                .borderRadius(22)
                .onClick(() => {
                  this.handleCancel();
                })
            }
            .width('100%')

            if (this.paymentMessage.length > 0) {
              Text(this.paymentMessage)
                .fontSize(this.careMode ? 18 : 15)
                .fontColor(this.paymentStatus === PaymentStatus.Success ? '#2B7068' : '#7A5C45')
                .lineHeight(this.careMode ? 28 : 22)
                .width('100%')
                .padding(14)
                .backgroundColor(this.paymentStatus === PaymentStatus.Success ? '#EFFAF8' : '#FAF7F2')
                .borderRadius(12)
            }

            if (this.orderMessage.length > 0) {
              Text(this.orderMessage)
                .fontSize(this.careMode ? 18 : 15)
                .fontColor('#2B7068')
                .lineHeight(this.careMode ? 28 : 22)
                .width('100%')
                .padding(14)
                .backgroundColor('#EFFAF8')
                .borderRadius(12)

              Row({ space: 12 }) {
                Button('查看购物历史')
                  .layoutWeight(1)
                  .height(this.careMode ? 52 : 44)
                  .fontSize(this.careMode ? 17 : 14)
                  .fontColor('#2B7068')
                  .backgroundColor('#EFFAF8')
                  .borderRadius(22)
                  .onClick(() => {
                    this.goOrderHistory();
                  })

                Button('返回用户端')
                  .layoutWeight(1)
                  .height(this.careMode ? 52 : 44)
                  .fontSize(this.careMode ? 17 : 14)
                  .fontColor('#2B7068')
                  .backgroundColor('#EFFAF8')
                  .borderRadius(22)
                  .onClick(() => {
              RouteUtils.clearAndPush(this.getUIContext(), 'pages/UserHome');
                  })
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding(18)
          .backgroundColor(Color.White)
          .borderRadius(18)
          .border({ width: 1, color: '#E8DDD2' })
        }
        .width('100%')
        .padding(20)
        .constraintSize({ maxWidth: this.breakpoint === 'sm' ? 10000 : 720 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .height('100%')
    .width('100%')
    .backgroundColor('#F3EFE8')
  }
}
