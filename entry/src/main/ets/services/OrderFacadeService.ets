import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  ProductCandidate,
  Address,
  OrderDraft,
  PaymentMethod,
  PaymentRecord,
  PaymentResult,
  PaymentStatus,
  BackendAuditRecord,
  ReminderRecord
} from '../models/ShoppingModels';
import {
  PaymentWorkflowBackendData,
  BackendErrorCode,
  BackendResult
} from '../models/BackendModels';
import { AuthService } from './AuthService';
import { OrderService } from './OrderService';
import { PaymentRecordService } from './PaymentRecordService';
import { MockPaymentService } from './MockPaymentService';
import { HuaWeiPaymentService } from './HuaWeiPaymentService';
import { ReminderService } from './ReminderService';
import { AuditLogService } from './AuditLogService';
import { AgentSessionManager } from '../agent/AgentSessionManager';
import { AgentSession, emptyProductCandidate } from '../agent/AgentModels';
import { DistributedEventEmitter } from '../agent/DistributedEventEmitter';
import { RemoteBackendClient, RemoteBackendResult } from './RemoteBackendClient';
import { RemoteDataMapper } from './RemoteDataMapper';
import { TimeUtils } from '../utils/TimeUtils';
import { CloneUtils } from '../utils/CloneUtils';
import { AddressService } from './AddressService';
import { RemoteOrderItem, RemotePaymentRecordItem, RemoteAuditLogItem, RemoteAdminOrderListResponse } from '../models/RemoteModels';

const TAG: string = 'OrderFacadeService';
const DOMAIN: number = 0x0001;

export class OrderFacadeService {
  static payAndCreateOrder(product: ProductCandidate, quantity: number, address: Address, method: PaymentMethod): BackendResult<PaymentWorkflowBackendData> {
    if (!AuthService.canEnterShopping()) {
      return RemoteDataMapper.fail<PaymentWorkflowBackendData>(BackendErrorCode.Forbidden, '请先完成身份认证；子女需要先绑定老人账号，才能帮助老人购物');
    }
    const validation: string = OrderFacadeService.validateOrderInput(product, quantity, address);
    if (validation.length > 0) {
      return RemoteDataMapper.fail<PaymentWorkflowBackendData>(BackendErrorCode.ValidationError, validation);
    }
    const payment: PaymentResult = MockPaymentService.paySuccess(method);
    const order: OrderDraft = OrderService.createOrder(product, quantity, address, payment.method);
    const paymentRecord: PaymentRecord = PaymentRecordService.createRecord(payment, order.totalPrice, product, order.id);
    const reminder: ReminderRecord = ReminderService.createShoppingReminder(order);
    AgentSessionManager.complete(payment);
    AuditLogService.record('order.create', '生成订单 ' + order.id + '，金额 ¥' + order.totalPrice.toFixed(2));
    DistributedEventEmitter.emitPaymentSuccess(order.id, product.name, address.receiver, order.totalPrice, method.toString());
    DistributedEventEmitter.emitOrderCreated(order.id, product.name, address.receiver);
    return RemoteDataMapper.ok<PaymentWorkflowBackendData>('支付成功，订单和提醒已生成', {
      payment: payment,
      paymentRecord: paymentRecord,
      order: order,
      reminder: reminder
    });
  }

  static async huaWeiPayAndCreateOrder(
    context: common.UIAbilityContext,
    product: ProductCandidate,
    quantity: number,
    address: Address
  ): Promise<BackendResult<PaymentWorkflowBackendData>> {
    if (!AuthService.canEnterShopping()) {
      return RemoteDataMapper.fail<PaymentWorkflowBackendData>(BackendErrorCode.Forbidden, '请先完成身份认证');
    }
    const validation: string = OrderFacadeService.validateOrderInput(product, quantity, address);
    if (validation.length > 0) {
      return RemoteDataMapper.fail<PaymentWorkflowBackendData>(BackendErrorCode.ValidationError, validation);
    }
    const orderId: string = 'order-' + Date.now().toString();
    const totalPrice: number = product.price * quantity;
    const huaWeiResult = await HuaWeiPaymentService.requestPayment(context, product.name, totalPrice, orderId);
    const payment: PaymentResult = huaWeiResult.paymentResult;
    if (payment.status === PaymentStatus.Success) {
      const order: OrderDraft = OrderService.createOrder(product, quantity, address, PaymentMethod.HuaWeiPay);
      const paymentRecord: PaymentRecord = PaymentRecordService.createRecord(payment, totalPrice, product, order.id);
      const reminder: ReminderRecord = ReminderService.createShoppingReminder(order);
      AgentSessionManager.complete(payment);
      AuditLogService.record('order.create', '华为支付订单 ' + order.id + '，金额 ¥' + totalPrice.toFixed(2));
      DistributedEventEmitter.emitPaymentSuccess(order.id, product.name, address.receiver, totalPrice, 'huawei_pay');
      DistributedEventEmitter.emitOrderCreated(order.id, product.name, address.receiver);
      await OrderFacadeService.persistHuaweiPayToBackend(product, quantity, address, order.id);
      return RemoteDataMapper.ok<PaymentWorkflowBackendData>('华为支付成功，订单和提醒已生成', {
        payment: payment,
        paymentRecord: paymentRecord,
        order: order,
        reminder: reminder
      });
    }
    if (payment.status === PaymentStatus.Cancelled) {
      const cancelledResult: BackendResult<PaymentWorkflowBackendData> = {
        success: false,
        code: BackendErrorCode.PaymentCancelled,
        message: payment.message,
        data: {
          payment: payment
        }
      };
      return cancelledResult;
    }
    const failedResult: BackendResult<PaymentWorkflowBackendData> = {
      success: false,
      code: BackendErrorCode.PaymentFailed,
      message: payment.message,
      data: {
        payment: payment
      }
    };
    return failedResult;
  }

  private static async persistHuaweiPayToBackend(
    product: ProductCandidate,
    quantity: number,
    address: Address,
    localOrderId: string
  ): Promise<void> {
    try {
      const result: RemoteBackendResult =
        await RemoteBackendClient.createMockPayment(product.id, address.id, quantity, 'huawei_pay', 'success');
      if (!result.success) {
        hilog.warn(DOMAIN, TAG, 'persistHuaweiPayToBackend failed: ' + result.message);
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'persistHuaweiPayToBackend exception');
    }
  }

  static async agentPayAndCreateOrder(context: common.UIAbilityContext): Promise<BackendResult<PaymentWorkflowBackendData>> {
    const session: AgentSession = AgentSessionManager.getSession();
    const product: ProductCandidate = session.selectedProduct.id.length > 0
      ? session.selectedProduct
      : emptyProductCandidate();
    const quantity: number = session.quantity > 0 ? session.quantity : 1;
    if (product.id.length === 0) {
      return RemoteDataMapper.fail<PaymentWorkflowBackendData>(BackendErrorCode.NotFound, '请先选择商品');
    }
    const allAddresses: Address[] = AddressService.listAddresses();
    let address: Address | undefined = undefined;
    if (session.addressId.length > 0) {
      for (let i = 0; i < allAddresses.length; i += 1) {
        if (allAddresses[i].id === session.addressId) {
          address = allAddresses[i];
          break;
        }
      }
    }
    if (!address) {
      for (let i = 0; i < allAddresses.length; i += 1) {
        if (allAddresses[i].isDefault) {
          address = allAddresses[i];
          break;
        }
      }
    }
    if (!address && allAddresses.length > 0) {
      address = allAddresses[0];
    }
    if (!address) {
      return RemoteDataMapper.fail<PaymentWorkflowBackendData>(BackendErrorCode.NotFound, '请先添加收货地址');
    }
    const method: PaymentMethod = session.paymentMethod;
    DistributedEventEmitter.emitPaymentStarted(session.id, method.toString(), product.price * quantity);
    if (method === PaymentMethod.HuaWeiPay) {
      return OrderFacadeService.huaWeiPayAndCreateOrder(context, product, quantity, address);
    }
    return OrderFacadeService.payAndCreateOrder(product, quantity, address, method);
  }

  static simulatePaymentFailed(): BackendResult<PaymentWorkflowBackendData> {
    const payment: PaymentResult = MockPaymentService.payFailed();
    const paymentRecord: PaymentRecord = PaymentRecordService.createFailureRecord(payment);
    AuditLogService.record('payment.failed', payment.message);
    const result: BackendResult<PaymentWorkflowBackendData> = {
      success: false,
      code: BackendErrorCode.PaymentFailed,
      message: payment.message,
      data: {
        payment: payment,
        paymentRecord: paymentRecord
      }
    };
    return result;
  }

  static simulatePaymentCancelled(): BackendResult<PaymentWorkflowBackendData> {
    const payment: PaymentResult = MockPaymentService.payCancelled();
    const paymentRecord: PaymentRecord = PaymentRecordService.createFailureRecord(payment);
    AuditLogService.record('payment.cancelled', payment.message);
    const result: BackendResult<PaymentWorkflowBackendData> = {
      success: false,
      code: BackendErrorCode.PaymentCancelled,
      message: payment.message,
      data: {
        payment: payment,
        paymentRecord: paymentRecord
      }
    };
    return result;
  }

  static listOrders(): BackendResult<OrderDraft[]> {
    return RemoteDataMapper.ok<OrderDraft[]>('已获取订单列表', OrderService.listOrders());
  }

  static listPaymentRecords(): BackendResult<PaymentRecord[]> {
    return RemoteDataMapper.ok<PaymentRecord[]>('已获取支付记录', PaymentRecordService.listRecords());
  }

  static paymentMethodName(method: PaymentMethod): string {
    return OrderService.paymentMethodName(method);
  }

  static listAuditLogs(): BackendResult<BackendAuditRecord[]> {
    return RemoteDataMapper.ok<BackendAuditRecord[]>('已获取后端审计日志', AuditLogService.listRecords());
  }

  static async payAndCreateOrderRemote(product: ProductCandidate, quantity: number, address: Address, method: PaymentMethod): Promise<BackendResult<PaymentWorkflowBackendData>> {
    const validation: string = OrderFacadeService.validateOrderInput(product, quantity, address);
    if (validation.length > 0) {
      return RemoteDataMapper.fail<PaymentWorkflowBackendData>(BackendErrorCode.ValidationError, validation);
    }
    const result: RemoteBackendResult =
      await RemoteBackendClient.createMockPayment(product.id, address.id, quantity, RemoteDataMapper.remotePaymentMethod(method), 'success');
    if (!result.success) {
      return OrderFacadeService.payAndCreateOrder(product, quantity, address, method);
    }
    const parsed = RemoteDataMapper.parsePaymentResponse(result.body);
    if (!parsed) {
      return OrderFacadeService.payAndCreateOrder(product, quantity, address, method);
    }
    const payment: PaymentResult = {
      status: RemoteDataMapper.parsePaymentStatus(parsed.status),
      message: parsed.message,
      method: method,
      paidAt: TimeUtils.nowText()
    };
    const order: OrderDraft = OrderService.createOrder(product, quantity, address, method);
    const paymentRecord: PaymentRecord = PaymentRecordService.createRecord(payment, product.price * quantity, product, order.id);
    let reminder: ReminderRecord | undefined = undefined;
    if (payment.status === PaymentStatus.Success) {
      reminder = ReminderService.createShoppingReminder(order);
      AgentSessionManager.complete(payment);
      AuditLogService.record('order.create', '远程支付订单 ' + order.id + '，金额 ¥' + order.totalPrice.toFixed(2));
      DistributedEventEmitter.emitPaymentSuccess(order.id, product.name, address.receiver, order.totalPrice, method.toString());
      DistributedEventEmitter.emitOrderCreated(order.id, product.name, address.receiver);
    }
    const data: PaymentWorkflowBackendData = {
      payment: payment,
      paymentRecord: paymentRecord,
      order: payment.status === PaymentStatus.Success ? order : undefined,
      reminder: reminder
    };
    return RemoteDataMapper.ok<PaymentWorkflowBackendData>(parsed.message, data);
  }

  static async simulatePaymentFailedRemote(product: ProductCandidate, quantity: number, address: Address): Promise<BackendResult<PaymentWorkflowBackendData>> {
    const result: RemoteBackendResult =
      await RemoteBackendClient.createMockPayment(product.id, address.id, quantity, 'password', 'failed');
    if (!result.success && result.statusCode === 0) {
      return OrderFacadeService.simulatePaymentFailed();
    }
    const parsed = RemoteDataMapper.parsePaymentResponse(result.body);
    if (!parsed) {
      return OrderFacadeService.simulatePaymentFailed();
    }
    const payment: PaymentResult = {
      status: RemoteDataMapper.parsePaymentStatus(parsed.status),
      message: parsed.message,
      method: PaymentMethod.Password,
      paidAt: TimeUtils.nowText()
    };
    const failedResult: BackendResult<PaymentWorkflowBackendData> = {
      success: false,
      code: BackendErrorCode.PaymentFailed,
      message: parsed.message,
      data: {
        payment: payment
      }
    };
    return failedResult;
  }

  static async simulatePaymentCancelledRemote(product: ProductCandidate, quantity: number, address: Address): Promise<BackendResult<PaymentWorkflowBackendData>> {
    const result: RemoteBackendResult =
      await RemoteBackendClient.createMockPayment(product.id, address.id, quantity, 'password', 'cancelled');
    if (!result.success && result.statusCode === 0) {
      return OrderFacadeService.simulatePaymentCancelled();
    }
    const parsed = RemoteDataMapper.parsePaymentResponse(result.body);
    if (!parsed) {
      return OrderFacadeService.simulatePaymentCancelled();
    }
    const payment: PaymentResult = {
      status: RemoteDataMapper.parsePaymentStatus(parsed.status),
      message: parsed.message,
      method: PaymentMethod.Password,
      paidAt: TimeUtils.nowText()
    };
    const cancelledResult: BackendResult<PaymentWorkflowBackendData> = {
      success: false,
      code: BackendErrorCode.PaymentCancelled,
      message: parsed.message,
      data: {
        payment: payment
      }
    };
    return cancelledResult;
  }

  static async listOrdersRemote(): Promise<BackendResult<OrderDraft[]>> {
    const localOrders: OrderDraft[] = OrderService.listOrders();
    const result: RemoteBackendResult = await RemoteBackendClient.listOrders();
    if (!result.success) {
      return RemoteDataMapper.ok<OrderDraft[]>('已获取本地订单列表', localOrders);
    }
    const parsed = RemoteDataMapper.parseOrderList(result.body);
    if (!parsed || !parsed.orders) {
      return RemoteDataMapper.ok<OrderDraft[]>('已获取本地订单列表', localOrders);
    }
    const remoteOrders: OrderDraft[] = parsed.orders.map((item: RemoteOrderItem) => RemoteDataMapper.mapRemoteOrder(item));
    const remoteIds: Set<string> = new Set(remoteOrders.map((o: OrderDraft) => o.id));
    const merged: OrderDraft[] = remoteOrders.slice();
    for (let i = 0; i < localOrders.length; i += 1) {
      if (!remoteIds.has(localOrders[i].id)) {
        merged.push(localOrders[i]);
      }
    }
    if (merged.length > 0) {
      OrderService.replaceOrders(merged);
    }
    return RemoteDataMapper.ok<OrderDraft[]>('已获取订单列表', merged);
  }

  private static validateOrderInput(product: ProductCandidate, quantity: number, address: Address): string {
    if (!product || product.id.length === 0) {
      return '请选择商品';
    }
    if (quantity < 1 || quantity > 99) {
      return '数量必须在 1-99 之间';
    }
    if (!address || address.id.length === 0) {
      return '请先选择收货地址';
    }
    return '';
  }

  static listAllOrders(): OrderDraft[] {
    return OrderService.listAllOrders();
  }

  static async listPaymentRecordsRemote(): Promise<BackendResult<PaymentRecord[]>> {
    const result: RemoteBackendResult = await RemoteBackendClient.listPaymentRecords();
    if (!result.success) {
      return OrderFacadeService.listPaymentRecords();
    }
    const parsed = RemoteDataMapper.parsePaymentRecordList(result.body);
    if (!parsed || !parsed.payment_records) {
      return OrderFacadeService.listPaymentRecords();
    }
    const mappedRecords: PaymentRecord[] = parsed.payment_records.map((item: RemotePaymentRecordItem): PaymentRecord => RemoteDataMapper.mapRemotePaymentRecord(item));
    return RemoteDataMapper.ok<PaymentRecord[]>('已从远程后端获取支付记录', mappedRecords);
  }

  static async listAuditLogsRemote(): Promise<BackendResult<BackendAuditRecord[]>> {
    const result: RemoteBackendResult = await RemoteBackendClient.listAuditLogs();
    if (!result.success) {
      return OrderFacadeService.listAuditLogs();
    }
    const parsed = RemoteDataMapper.parseAuditLogList(result.body);
    if (!parsed || !parsed.logs) {
      return OrderFacadeService.listAuditLogs();
    }
    const mappedLogs: BackendAuditRecord[] = parsed.logs.map((item: RemoteAuditLogItem): BackendAuditRecord => RemoteDataMapper.mapRemoteAuditLog(item));
    return RemoteDataMapper.ok<BackendAuditRecord[]>('已从远程后端获取审计日志', mappedLogs);
  }

  static async listAdminAuditLogsRemote(): Promise<BackendResult<BackendAuditRecord[]>> {
    const localLogs: BackendAuditRecord[] = AuditLogService.listRecords();
    const result: RemoteBackendResult = await RemoteBackendClient.adminListAllAuditLogs();
    if (!result.success) {
      return RemoteDataMapper.ok<BackendAuditRecord[]>('本地审计日志', localLogs);
    }
    const parsed = RemoteDataMapper.parseAuditLogList(result.body);
    if (!parsed || !parsed.logs) {
      return RemoteDataMapper.ok<BackendAuditRecord[]>('本地审计日志', localLogs);
    }
    const mappedLogs: BackendAuditRecord[] = parsed.logs.map((item: RemoteAuditLogItem): BackendAuditRecord => RemoteDataMapper.mapRemoteAuditLog(item));
    return RemoteDataMapper.ok<BackendAuditRecord[]>('已获取全平台审计日志', mappedLogs);
  }

  static async listAdminOrdersRemote(): Promise<BackendResult<OrderDraft[]>> {
    const localOrders: OrderDraft[] = OrderService.listAllOrders();
    const result: RemoteBackendResult = await RemoteBackendClient.listAdminOrders();
    if (!result.success) {
      return RemoteDataMapper.ok<OrderDraft[]>('本地全平台订单', localOrders);
    }
    const parsed = RemoteDataMapper.parseAdminOrderList(result.body);
    if (!parsed || !parsed.orders) {
      return RemoteDataMapper.ok<OrderDraft[]>('本地全平台订单', localOrders);
    }
    const remoteOrders: OrderDraft[] = parsed.orders.map((item: RemoteOrderItem) => RemoteDataMapper.mapRemoteOrder(item));
    const remoteIds: Set<string> = new Set(remoteOrders.map((o: OrderDraft) => o.id));
    const merged: OrderDraft[] = remoteOrders.slice();
    for (let i = 0; i < localOrders.length; i += 1) {
      if (!remoteIds.has(localOrders[i].id)) {
        merged.push(localOrders[i]);
      }
    }
    if (merged.length > 0) {
      OrderService.replaceOrders(merged);
    }
    return RemoteDataMapper.ok<OrderDraft[]>('已获取全平台订单', merged);
  }
}
