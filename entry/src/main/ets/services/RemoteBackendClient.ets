import { http } from '@kit.NetworkKit';
import { AppConfig } from '../config/AppConfig';

export interface RemoteBackendResult {
  success: boolean;
  statusCode: number;
  message: string;
  body: string;
}

interface ErrorMessagePayload {
  message?: string;
}

interface SmsCodeRequestBody {
  phone: string;
  purpose: string;
}

interface LoginRequestBody {
  phone: string;
  password: string;
  sms_code?: string;
}

interface RegisterRequestBody {
  phone: string;
  password: string;
  display_name: string;
  role: string;
  sms_code?: string;
}

interface CertifyRoleRequestBody {
  role: string;
}

interface BindFamilyRequestBody {
  keyword: string;
}

interface HuaweiLoginRequestBody {
  open_id: string;
  union_id: string;
  authorization_code: string;
  id_token?: string;
  phone_authorization_code?: string;
}

interface LinkPhoneRequestBody {
  phone: string;
}

interface AddressCreateRequestBody {
  receiver: string;
  phone: string;
  detail: string;
}

interface AddressIdRequestBody {
  id: string;
}

interface PaymentRequestBody {
  product_id: string;
  address_id: string;
  quantity: number;
  method: string;
  outcome: string;
}

interface CompareRequestBody {
  query: string;
}

interface SelectionCommandRequestBody {
  command: string;
  candidates: object[];
}

interface EmptyRequestBody {
  noop?: string;
}

interface AdminAccountCreateRequestBody {
  phone: string;
  password: string;
  display_name: string;
  role: string;
}

interface AdminAccountUpdateRequestBody {
  account_id: string;
  phone?: string;
  display_name?: string;
  role?: string;
  status?: string;
}

interface AdminAccountActionRequestBody {
  account_id: string;
}

interface OrderActionRequestBody {
  order_id: string;
}

interface AuditLogActionRequestBody {
  log_id: string;
}

interface TicketActionRequestBody {
  ticket_id: string;
}

interface TicketResolveRequestBody {
  ticket_id: string;
  resolution: string;
}

interface FeedbackRequestBody {
  title: string;
  content: string;
  priority?: string;
}

interface ProfileUpdateRequestBody {
  real_name?: string;
  age?: number;
  emergency_phone?: string;
  relation?: string;
  nick_name?: string;
  display_name?: string;
}

interface TokenResponse {
  access_token?: string;
}

export class RemoteBackendClient {
  private static baseUrl: string = AppConfig.remoteBackendBaseUrl;
  private static accessToken: string = '';
  private static consecutiveFailures: number = 0;
  private static readonly MAX_FAILURES: number = 2;
  private static degraded: boolean = false;

  static setBaseUrl(baseUrl: string): void {
    RemoteBackendClient.baseUrl = baseUrl;
  }

  static setAccessToken(token: string): void {
    RemoteBackendClient.accessToken = token;
  }

  static getAccessToken(): string {
    return RemoteBackendClient.accessToken;
  }

  static isDegraded(): boolean {
    return RemoteBackendClient.degraded;
  }

  static resetDegradation(): void {
    RemoteBackendClient.consecutiveFailures = 0;
    RemoteBackendClient.degraded = false;
  }

  static async health(): Promise<RemoteBackendResult> {
    return RemoteBackendClient.request('GET', '/health');
  }

  static async sendSmsCode(phone: string, purpose: string): Promise<RemoteBackendResult> {
    const body: SmsCodeRequestBody = {
      phone: phone,
      purpose: purpose
    };
    return RemoteBackendClient.request('POST', '/api/auth/sms/send', body);
  }

  static async login(phone: string, password: string, smsCode?: string): Promise<RemoteBackendResult> {
    const body: LoginRequestBody = {
      phone: phone,
      password: password,
      sms_code: smsCode ? smsCode : undefined
    };
    const result = await RemoteBackendClient.request('POST', '/api/auth/login', body);
    RemoteBackendClient.trySaveToken(result.body);
    return result;
  }

  static async register(phone: string, password: string, displayName: string, role: string, smsCode?: string): Promise<RemoteBackendResult> {
    const body: RegisterRequestBody = {
      phone: phone,
      password: password,
      display_name: displayName,
      role: role,
      sms_code: smsCode ? smsCode : undefined
    };
    const result = await RemoteBackendClient.request('POST', '/api/auth/register', body);
    RemoteBackendClient.trySaveToken(result.body);
    return result;
  }

  static async me(): Promise<RemoteBackendResult> {
    return RemoteBackendClient.request('GET', '/api/auth/me');
  }

  static async certifyRole(role: string): Promise<RemoteBackendResult> {
    const body: CertifyRoleRequestBody = {
      role: role
    };
    const result = await RemoteBackendClient.request('POST', '/api/auth/certify', body);
    RemoteBackendClient.trySaveToken(result.body);
    return result;
  }

  static async bindFamily(keyword: string): Promise<RemoteBackendResult> {
    const body: BindFamilyRequestBody = {
      keyword: keyword
    };
    return RemoteBackendClient.request('POST', '/api/family/bind', body);
  }

  static async huaweiLogin(openId: string, unionId: string, authCode: string, idToken?: string, phoneAuthCode?: string): Promise<RemoteBackendResult> {
    const body: HuaweiLoginRequestBody = {
      open_id: openId,
      union_id: unionId,
      authorization_code: authCode,
      id_token: idToken,
      phone_authorization_code: phoneAuthCode
    };
    const result = await RemoteBackendClient.request('POST', '/api/auth/huawei-login', body);
    RemoteBackendClient.trySaveToken(result.body);
    return result;
  }

  static async linkPhone(phone: string): Promise<RemoteBackendResult> {
    const body: LinkPhoneRequestBody = {
      phone: phone
    };
    const result = await RemoteBackendClient.request('POST', '/api/auth/link-phone', body);
    RemoteBackendClient.trySaveToken(result.body);
    return result;
  }

  static async listFamilyBindings(): Promise<RemoteBackendResult> {
    return RemoteBackendClient.request('GET', '/api/family/bindings');
  }

  static async listProducts(): Promise<RemoteBackendResult> {
    return RemoteBackendClient.request('GET', '/api/products/mock');
  }

  static async getProduct(productId: string): Promise<RemoteBackendResult> {
    return RemoteBackendClient.request('GET', `/api/products/${productId}`);
  }

  static async compareProducts(query: string): Promise<RemoteBackendResult> {
    const body: CompareRequestBody = {
      query: query
    };
    return RemoteBackendClient.request('POST', '/api/agent/compare', body);
  }

  static async confirmSelectionCommand(command: string, candidates: object[]): Promise<RemoteBackendResult> {
    const body: SelectionCommandRequestBody = {
      command: command,
      candidates: candidates
    };
    return RemoteBackendClient.request('POST', '/api/agent/selection-command', body);
  }

  static async listAddresses(): Promise<RemoteBackendResult> {
    return RemoteBackendClient.request('GET', '/api/addresses');
  }

  static async createAddress(receiver: string, phone: string, detail: string): Promise<RemoteBackendResult> {
    const body: AddressCreateRequestBody = {
      receiver: receiver,
      phone: phone,
      detail: detail
    };
    return RemoteBackendClient.request('POST', '/api/addresses', body);
  }

  static async setDefaultAddress(id: string): Promise<RemoteBackendResult> {
    const body: AddressIdRequestBody = {
      id: id
    };
    return RemoteBackendClient.request('POST', '/api/addresses/default', body);
  }

  static async deleteAddress(id: string): Promise<RemoteBackendResult> {
    const body: AddressIdRequestBody = {
      id: id
    };
    return RemoteBackendClient.request('POST', '/api/addresses/delete', body);
  }

  static async createMockPayment(productId: string, addressId: string, quantity: number, method: string, outcome: string): Promise<RemoteBackendResult> {
    const body: PaymentRequestBody = {
      product_id: productId,
      address_id: addressId,
      quantity: quantity,
      method: method,
      outcome: outcome
    };
    return RemoteBackendClient.request('POST', '/api/payments/mock', body);
  }

  static async listOrders(): Promise<RemoteBackendResult> {
    return RemoteBackendClient.request('GET', '/api/orders');
  }

  static async listReminders(): Promise<RemoteBackendResult> {
    return RemoteBackendClient.request('GET', '/api/reminders');
  }

  static async markAllRemindersRead(): Promise<RemoteBackendResult> {
    const body: EmptyRequestBody = {};
    return RemoteBackendClient.request('POST', '/api/reminders/read-all', body);
  }

  static async profileStats(): Promise<RemoteBackendResult> {
    return RemoteBackendClient.request('GET', '/api/profile/stats');
  }

  static async childDashboard(): Promise<RemoteBackendResult> {
    return RemoteBackendClient.request('GET', '/api/child/dashboard');
  }

  static async adminDashboard(): Promise<RemoteBackendResult> {
    return RemoteBackendClient.request('GET', '/api/admin/dashboard');
  }

  static async csDashboard(): Promise<RemoteBackendResult> {
    return RemoteBackendClient.request('GET', '/api/cs/dashboard');
  }

  static async listSyncEvents(): Promise<RemoteBackendResult> {
    return RemoteBackendClient.request('GET', '/api/sync/events');
  }

  static async listNotifications(): Promise<RemoteBackendResult> {
    return RemoteBackendClient.request('GET', '/api/notifications');
  }

  static async listAuditLogs(): Promise<RemoteBackendResult> {
    return RemoteBackendClient.request('GET', '/api/audit-logs');
  }

  static async listAdminUsers(): Promise<RemoteBackendResult> {
    return RemoteBackendClient.request('GET', '/api/admin/users');
  }

  static async listAdminOrders(): Promise<RemoteBackendResult> {
    return RemoteBackendClient.request('GET', '/api/admin/orders');
  }

  static async adminDeleteOrder(orderId: string): Promise<RemoteBackendResult> {
    const body: OrderActionRequestBody = { order_id: orderId };
    return RemoteBackendClient.request('POST', '/api/admin/orders/delete', body);
  }

  static async adminClearAuditLogs(): Promise<RemoteBackendResult> {
    const body: EmptyRequestBody = {};
    return RemoteBackendClient.request('POST', '/api/admin/audit-logs/clear', body);
  }

  static async adminDeleteAuditLog(logId: string): Promise<RemoteBackendResult> {
    const body: AuditLogActionRequestBody = { log_id: logId };
    return RemoteBackendClient.request('POST', '/api/admin/audit-logs/delete', body);
  }

  static async adminListAllAuditLogs(): Promise<RemoteBackendResult> {
    return RemoteBackendClient.request('GET', '/api/admin/audit-logs');
  }

  static async listAdminAccounts(): Promise<RemoteBackendResult> {
    return RemoteBackendClient.request('GET', '/api/admin/accounts');
  }

  static async adminCreateAccount(phone: string, password: string, displayName: string, role: string): Promise<RemoteBackendResult> {
    const body: AdminAccountCreateRequestBody = {
      phone: phone,
      password: password,
      display_name: displayName,
      role: role
    };
    return RemoteBackendClient.request('POST', '/api/admin/accounts', body);
  }

  static async adminUpdateAccount(accountId: string, phone: string, displayName: string, role: string, status: string): Promise<RemoteBackendResult> {
    const body: AdminAccountUpdateRequestBody = {
      account_id: accountId,
      phone: phone,
      display_name: displayName,
      role: role,
      status: status
    };
    return RemoteBackendClient.request('POST', '/api/admin/accounts/update', body);
  }

  static async adminSoftDeleteAccount(accountId: string): Promise<RemoteBackendResult> {
    const body: AdminAccountActionRequestBody = {
      account_id: accountId
    };
    return RemoteBackendClient.request('POST', '/api/admin/accounts/soft-delete', body);
  }

  static async adminRestoreAccount(accountId: string): Promise<RemoteBackendResult> {
    const body: AdminAccountActionRequestBody = {
      account_id: accountId
    };
    return RemoteBackendClient.request('POST', '/api/admin/accounts/restore', body);
  }

  static async csListTickets(): Promise<RemoteBackendResult> {
    return RemoteBackendClient.request('GET', '/api/cs/tickets');
  }

  static async csListOrders(): Promise<RemoteBackendResult> {
    return RemoteBackendClient.request('GET', '/api/admin/orders');
  }

  static async csAssignTicket(ticketId: string): Promise<RemoteBackendResult> {
    const body: TicketActionRequestBody = { ticket_id: ticketId };
    return RemoteBackendClient.request('POST', '/api/cs/tickets/assign', body);
  }

  static async csResolveTicket(ticketId: string, resolution: string): Promise<RemoteBackendResult> {
    const body: TicketResolveRequestBody = { ticket_id: ticketId, resolution: resolution };
    return RemoteBackendClient.request('POST', '/api/cs/tickets/resolve', body);
  }

  static async csEscalateTicket(ticketId: string): Promise<RemoteBackendResult> {
    const body: TicketActionRequestBody = { ticket_id: ticketId };
    return RemoteBackendClient.request('POST', '/api/cs/tickets/escalate', body);
  }

  static async listPaymentRecords(): Promise<RemoteBackendResult> {
    return RemoteBackendClient.request('GET', '/api/payment-records');
  }

  static async submitFeedback(title: string, content: string, priority?: string): Promise<RemoteBackendResult> {
    const body: FeedbackRequestBody = {
      title: title,
      content: content,
      priority: priority
    };
    return RemoteBackendClient.request('POST', '/api/feedback', body);
  }

  static async updateProfile(realName?: string, age?: number, emergencyPhone?: string, relation?: string, nickName?: string, displayName?: string): Promise<RemoteBackendResult> {
    const body: ProfileUpdateRequestBody = {
      real_name: realName,
      age: age,
      emergency_phone: emergencyPhone,
      relation: relation,
      nick_name: nickName,
      display_name: displayName
    };
    return RemoteBackendClient.request('POST', '/api/profile/update', body);
  }

  static async request(method: string, path: string, body?: object): Promise<RemoteBackendResult> {
    if (RemoteBackendClient.degraded) {
      return {
        success: false,
        statusCode: 0,
        message: '远程后端已降级，使用本地数据',
        body: ''
      };
    }
    const client = http.createHttp();
    const headers: Record<string, string> = {
      'Content-Type': 'application/json'
    };
    if (RemoteBackendClient.accessToken.length > 0) {
      headers['Authorization'] = `Bearer ${RemoteBackendClient.accessToken}`;
    }
    try {
      const response = await client.request(`${RemoteBackendClient.baseUrl}${path}`, {
        method: method === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET,
        header: headers,
        extraData: body ? JSON.stringify(body) : '',
        readTimeout: AppConfig.requestTimeoutMs,
        connectTimeout: AppConfig.requestTimeoutMs
      });
      const code = Number(response.responseCode);
      const isSuccess = code >= 200 && code < 300;
      const bodyText = '' + response.result;
      const backendMessage = RemoteBackendClient.parseBackendMessage(bodyText);
      if (isSuccess) {
        RemoteBackendClient.consecutiveFailures = 0;
      }
      return {
        success: isSuccess,
        statusCode: code,
        message: isSuccess ? '请求成功' : (backendMessage.length > 0 ? backendMessage : ('请求失败(' + code + ')')),
        body: bodyText
      };
    } catch (error) {
      RemoteBackendClient.consecutiveFailures += 1;
      if (RemoteBackendClient.consecutiveFailures >= RemoteBackendClient.MAX_FAILURES) {
        RemoteBackendClient.degraded = true;
      }
      return {
        success: false,
        statusCode: 0,
        message: '远程后端服务不可用，请确认服务已启动且 AppConfig 地址正确',
        body: ''
      };
    } finally {
      client.destroy();
    }
  }

  private static trySaveToken(body: string): void {
    try {
      const parsed: TokenResponse = JSON.parse(body);
      if (parsed.access_token && parsed.access_token.length > 0) {
        RemoteBackendClient.accessToken = parsed.access_token;
      }
    } catch (error) {
    }
  }

  private static parseBackendMessage(body: string): string {
    try {
      const parsed: ErrorMessagePayload = JSON.parse(body);
      return parsed.message ? parsed.message : '';
    } catch (error) {
      return '';
    }
  }
}
