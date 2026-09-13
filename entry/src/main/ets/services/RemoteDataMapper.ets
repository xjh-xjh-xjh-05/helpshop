import { Account, AccountRole, AccountStatus, CustomerTicket } from '../models/AuthModels';
import { BackendErrorCode, BackendResult } from '../models/BackendModels';
import { ProductCandidate, Address, OrderDraft, ReminderRecord, RecommendationResult, ParsedIntent, PaymentMethod, PaymentStatus, PaymentRecord, BackendAuditRecord } from '../models/ShoppingModels';
import {
  RemoteAddressItem,
  RemoteAddressListResponse,
  RemoteOrderItem,
  RemoteOrderListResponse,
  RemoteReminderItem,
  RemoteReminderListResponse,
  RemotePaymentResponse,
  RemoteProductItem,
  RemoteProductListResponse,
  RemoteProductDetailResponse,
  RemoteRecommendationItem,
  RemoteCompareResponse,
  RemoteSelectionResponse,
  RemoteAccountItem,
  RemoteProfileStatsResponse,
  RemoteChildDashboardResponse,
  RemoteAdminUserItem,
  RemoteAdminUserListResponse,
  RemoteAdminOrderListResponse,
  RemoteAdminAccountCrudResponse,
  RemoteCsTicketItem,
  RemoteCsTicketListResponse,
  RemotePaymentRecordItem,
  RemotePaymentRecordListResponse,
  RemoteAuditLogItem,
  RemoteAuditLogListResponse,
  RemoteAdminDashboardResponse
} from '../models/RemoteModels';

export class RemoteDataMapper {
  static parseAddressList(body: string): RemoteAddressListResponse | undefined {
    try { return JSON.parse(body); } catch (error) { return undefined; }
  }

  static parseOrderList(body: string): RemoteOrderListResponse | undefined {
    try { return JSON.parse(body); } catch (error) { return undefined; }
  }

  static parseReminderList(body: string): RemoteReminderListResponse | undefined {
    try { return JSON.parse(body); } catch (error) { return undefined; }
  }

  static parsePaymentResponse(body: string): RemotePaymentResponse | undefined {
    try { return JSON.parse(body); } catch (error) { return undefined; }
  }

  static parseProductList(body: string): RemoteProductListResponse | undefined {
    try { return JSON.parse(body); } catch (error) { return undefined; }
  }

  static parseProductDetail(body: string): RemoteProductDetailResponse | undefined {
    try { return JSON.parse(body); } catch (error) { return undefined; }
  }

  static parseCompareResponse(body: string): RemoteCompareResponse | undefined {
    try { return JSON.parse(body); } catch (error) { return undefined; }
  }

  static parseSelectionResponse(body: string): RemoteSelectionResponse | undefined {
    try { return JSON.parse(body); } catch (error) { return undefined; }
  }

  static parseProfileStats(body: string): RemoteProfileStatsResponse | undefined {
    try { return JSON.parse(body); } catch (error) { return undefined; }
  }

  static parseChildDashboard(body: string): RemoteChildDashboardResponse | undefined {
    try { return JSON.parse(body); } catch (error) { return undefined; }
  }

  static parseAdminUserList(body: string): RemoteAdminUserListResponse | undefined {
    try { return JSON.parse(body); } catch (error) { return undefined; }
  }

  static parseAdminOrderList(body: string): RemoteAdminOrderListResponse | undefined {
    try { return JSON.parse(body); } catch (error) { return undefined; }
  }

  static parseAdminAccountCrud(body: string): RemoteAdminAccountCrudResponse | undefined {
    try { return JSON.parse(body); } catch (error) { return undefined; }
  }

  static parseCsTicketList(body: string): RemoteCsTicketListResponse | undefined {
    try { return JSON.parse(body); } catch (error) { return undefined; }
  }

  static parsePaymentRecordList(body: string): RemotePaymentRecordListResponse | undefined {
    try { return JSON.parse(body); } catch (error) { return undefined; }
  }

  static parseAuditLogList(body: string): RemoteAuditLogListResponse | undefined {
    try { return JSON.parse(body); } catch (error) { return undefined; }
  }

  static parseAdminDashboard(body: string): RemoteAdminDashboardResponse | undefined {
    try { return JSON.parse(body); } catch (error) { return undefined; }
  }

  static mapRemoteAdminUser(item: RemoteAdminUserItem): Account {
    return {
      id: item.id,
      idUser: item.id_user !== undefined ? item.id_user : 0,
      phone: item.phone,
      passwordHash: '',
      displayName: item.display_name ? item.display_name : '',
      defaultRole: RemoteDataMapper.parseAccountRole(item.default_role ? item.default_role : 'unverified'),
      status: item.status === AccountStatus.Disabled ? AccountStatus.Disabled : AccountStatus.Active,
      createdAt: item.created_at ? item.created_at : '',
      updatedAt: item.updated_at ? item.updated_at : ''
    };
  }

  static mapRemoteCsTicket(item: RemoteCsTicketItem): CustomerTicket {
    let normalizedStatus = item.status;
    if (item.status === '待处理') {
      normalizedStatus = 'open';
    } else if (item.status === '处理中') {
      normalizedStatus = 'processing';
    } else if (item.status === '已处理') {
      normalizedStatus = 'resolved';
    }
    return {
      id: item.id,
      csAccountId: item.cs_account_id ? item.cs_account_id : '',
      elderlyAccountId: item.elderly_account_id ? item.elderly_account_id : '',
      orderId: '',
      title: item.title,
      content: item.content ? item.content : '',
      status: normalizedStatus,
      priority: item.priority === '紧急' ? 'urgent' : (item.priority === '高' ? 'high' : 'normal'),
      userDisplay: item.user ? item.user : '',
      createdAt: item.created_at ? item.created_at : item.time,
      updatedAt: item.updated_at ? item.updated_at : item.time
    };
  }

  static mapRemotePaymentRecord(item: RemotePaymentRecordItem): PaymentRecord {
    return {
      id: item.id,
      orderId: item.order_id,
      elderlyAccountId: item.elderly_account_id,
      productId: item.product_id,
      amount: Number(item.amount),
      method: RemoteDataMapper.parsePaymentMethod(item.method),
      status: RemoteDataMapper.parsePaymentStatus(item.status),
      message: item.message,
      createdAt: item.created_at
    };
  }

  static mapRemoteAuditLog(item: RemoteAuditLogItem): BackendAuditRecord {
    return {
      id: item.id,
      actorAccountId: item.actor_account_id,
      elderlyAccountId: item.elderly_account_id,
      action: item.action,
      detail: item.detail,
      createdAt: item.created_at
    };
  }

  static mapRemoteAddress(item: RemoteAddressItem): Address {
    return {
      id: item.id,
      elderlyAccountId: item.elderly_account_id,
      managedByChildAccountId: item.managed_by_child_account_id,
      receiver: item.receiver,
      phone: item.phone,
      detail: item.detail,
      isDefault: item.is_default === 1
    };
  }

  static mapRemoteProduct(item: RemoteProductItem): ProductCandidate {
    let tags: string[] = [];
    if (item.tag_list) {
      tags = item.tag_list;
    } else if (item.tags) {
      tags = item.tags.split(',');
    }
    return {
      id: item.id,
      platform: item.platform,
      name: item.name,
      price: Number(item.price),
      rating: Number(item.rating),
      sales: Number(item.sales),
      shopName: item.shopName ? item.shopName : (item.shop_name ? item.shop_name : ''),
      description: item.description,
      tags: tags,
      recommendScore: item.recommendScore !== undefined ? Number(item.recommendScore) : (item.recommend_score !== undefined ? Number(item.recommend_score) : 0),
      imageKey: item.imageKey ? item.imageKey : item.image_key,
      imageUrl: item.imageUrl ? item.imageUrl : item.image_url
    };
  }

  static mapRemoteRecommendation(item: RemoteRecommendationItem): RecommendationResult {
    const candidates: ProductCandidate[] = item.candidates.map((product: RemoteProductItem) => RemoteDataMapper.mapRemoteProduct(product));
    const best = item.bestProduct ? item.bestProduct : item.best_product;
    const intent: ParsedIntent = {
      product: item.intent.product,
      attributes: item.intent.attributes,
      quantity: Number(item.intent.quantity),
      rawText: item.intent.rawText ? item.intent.rawText : (item.intent.raw_text ? item.intent.raw_text : '')
    };
    return {
      intent: intent,
      bestProduct: best ? RemoteDataMapper.mapRemoteProduct(best) : candidates[0],
      candidates: candidates,
      reason: item.reason,
      fallbackUsed: item.fallbackUsed !== undefined ? item.fallbackUsed : (item.fallback_used ? item.fallback_used : false)
    };
  }

  static mapRemoteAccount(item: RemoteAccountItem): Account {
    return {
      id: item.id,
      idUser: item.id_user !== undefined ? Number(item.id_user) : 0,
      phone: item.phone,
      passwordHash: item.password_hash ? item.password_hash : '',
      displayName: item.display_name ? item.display_name : '',
      defaultRole: RemoteDataMapper.parseAccountRole(item.default_role ? item.default_role : 'unverified'),
      status: item.status === AccountStatus.Disabled ? AccountStatus.Disabled : AccountStatus.Active,
      createdAt: item.created_at ? item.created_at : '',
      updatedAt: item.updated_at ? item.updated_at : ''
    };
  }

  static mapRemoteOrder(item: RemoteOrderItem): OrderDraft {
    const unitPrice = item.product_price !== undefined ? Number(item.product_price) : Number(item.total_price) / Math.max(1, Number(item.quantity));
    return {
      id: item.id,
      elderlyAccountId: item.elderly_account_id,
      managedByChildAccountId: item.managed_by_child_account_id,
      createdAt: item.created_at,
      product: {
        id: item.product_id,
        platform: item.platform,
        name: item.product_name,
        price: unitPrice,
        rating: item.rating !== undefined ? Number(item.rating) : 0,
        sales: item.sales !== undefined ? Number(item.sales) : 0,
        shopName: item.shop_name ? item.shop_name : '',
        description: item.description ? item.description : '',
        tags: item.tags ? item.tags.split(',') : [],
        recommendScore: 0
      },
      quantity: Number(item.quantity),
      address: {
        id: item.address_id,
        elderlyAccountId: item.elderly_account_id,
        receiver: item.address_receiver ? item.address_receiver : '',
        phone: item.address_phone ? item.address_phone : '',
        detail: item.address_detail ? item.address_detail : '',
        isDefault: false
      },
      totalPrice: Number(item.total_price),
      paymentMethod: RemoteDataMapper.parsePaymentMethod(item.payment_method),
      paymentStatus: RemoteDataMapper.parsePaymentStatus(item.payment_status)
    };
  }

  static mapRemoteReminder(item: RemoteReminderItem): ReminderRecord {
    return {
      id: item.id,
      orderId: item.order_id,
      elderlyAccountId: item.elderly_account_id,
      childAccountId: item.child_account_id,
      title: item.title,
      content: item.content,
      createdAt: item.created_at,
      read: item.read === 1
    };
  }

  static parsePaymentStatus(status: string): PaymentStatus {
    if (status === PaymentStatus.Success || status === 'success') {
      return PaymentStatus.Success;
    }
    if (status === PaymentStatus.Failed || status === 'failed') {
      return PaymentStatus.Failed;
    }
    if (status === PaymentStatus.Cancelled || status === 'cancelled') {
      return PaymentStatus.Cancelled;
    }
    return PaymentStatus.Pending;
  }

  static parsePaymentMethod(method: string): PaymentMethod {
    if (method === PaymentMethod.Face || method === 'face') {
      return PaymentMethod.Face;
    }
    if (method === PaymentMethod.Fingerprint || method === 'fingerprint') {
      return PaymentMethod.Fingerprint;
    }
    if (method === PaymentMethod.HuaWeiPay || method === 'huawei_pay') {
      return PaymentMethod.HuaWeiPay;
    }
    return PaymentMethod.Password;
  }

  static remotePaymentMethod(method: PaymentMethod): string {
    if (method === PaymentMethod.Face) {
      return 'face';
    }
    if (method === PaymentMethod.Fingerprint) {
      return 'fingerprint';
    }
    if (method === PaymentMethod.HuaWeiPay) {
      return 'huawei_pay';
    }
    return 'password';
  }

  static parseAccountRole(role: string): AccountRole {
    if (role === AccountRole.Elderly || role === 'elderly') {
      return AccountRole.Elderly;
    }
    if (role === AccountRole.Child || role === 'child') {
      return AccountRole.Child;
    }
    if (role === AccountRole.Admin || role === 'admin') {
      return AccountRole.Admin;
    }
    if (role === AccountRole.CustomerService || role === 'customer_service') {
      return AccountRole.CustomerService;
    }
    return AccountRole.Unverified;
  }

  static ok<T>(message: string, data: T): BackendResult<T> {
    return {
      success: true,
      code: BackendErrorCode.Ok,
      message: message,
      data: data
    };
  }

  static fail<T>(code: BackendErrorCode, message: string): BackendResult<T> {
    return {
      success: false,
      code: code,
      message: message
    };
  }
}
