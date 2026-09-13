import { common } from '@kit.AbilityKit';
import { Account, AccountRole, AccountStatus, CustomerTicket } from '../models/AuthModels';
import {
  AuthBackendData,
  BackendResult,
  BindingListBackendData,
  AdminDashboardBackendData,
  CustomerServiceDashboardBackendData,
  ChildDashboardBackendData,
  CompareBackendData,
  PaymentWorkflowBackendData,
  ProfileStatsBackendData,
  SelectionCommandBackendData
} from '../models/BackendModels';
import { ProductGatewayStatus } from '../models/PlatformModels';
import {
  Address,
  BackendAuditRecord,
  OrderDraft,
  PaymentMethod,
  PaymentRecord,
  ParsedIntent,
  ProductCandidate,
  RecommendationResult,
  ReminderRecord,
  ShoppingSession
} from '../models/ShoppingModels';
import { AgentLogEntry, AgentResponse } from '../agent/AgentModels';
import { AuthFacadeService } from './AuthFacadeService';
import { ProductFacadeService } from './ProductFacadeService';
import { OrderFacadeService } from './OrderFacadeService';
import { OrderService } from './OrderService';
import { AuditLogService } from './AuditLogService';
import { ProfileFacadeService } from './ProfileFacadeService';
import { ReminderFacadeService } from './ReminderFacadeService';
import { ShoppingAgentOrchestrator } from '../agent/ShoppingAgentOrchestrator';
import { RemoteAdminUserItem } from '../models/RemoteModels';
import { RemoteBackendClient } from './RemoteBackendClient';
import { BackendErrorCode } from '../models/BackendModels';

export class AppBackendService {
  static isLoggedIn(): boolean {
    return AuthFacadeService.isLoggedIn();
  }

  static getCurrentAccount(): Account | undefined {
    return AuthFacadeService.getCurrentAccount();
  }

  static getCurrentRole(): AccountRole {
    return AuthFacadeService.getCurrentRole();
  }

  static getCurrentAuth(): BackendResult<AuthBackendData> {
    return AuthFacadeService.getCurrentAuth();
  }

  static login(phone: string, password: string): BackendResult<AuthBackendData> {
    return AuthFacadeService.login(phone, password);
  }

  static register(phone: string, password: string, displayName: string): BackendResult<AuthBackendData> {
    return AuthFacadeService.register(phone, password, displayName);
  }

  static certifyCurrentAccount(role: AccountRole): BackendResult<AuthBackendData> {
    return AuthFacadeService.certifyCurrentAccount(role);
  }

  static logout(): void {
    AuthFacadeService.logout();
  }

  static canEnterShopping(): boolean {
    return AuthFacadeService.canEnterShopping();
  }

  static bindCurrentChildToElderly(keyword: string): BackendResult<BindingListBackendData> {
    return AuthFacadeService.bindCurrentChildToElderly(keyword);
  }

  static listCurrentChildBindings(): BackendResult<BindingListBackendData> {
    return AuthFacadeService.listCurrentChildBindings();
  }

  static getAccountName(accountId: string): string {
    return AuthFacadeService.getAccountName(accountId);
  }

  static getAccountPhone(accountId: string): string {
    return AuthFacadeService.getAccountPhone(accountId);
  }

  static roleName(role: AccountRole): string {
    return AuthFacadeService.roleName(role);
  }

  static async loginRemote(phone: string, password: string): Promise<BackendResult<AuthBackendData>> {
    return AuthFacadeService.loginRemote(phone, password);
  }

  static async registerRemote(phone: string, password: string, displayName: string): Promise<BackendResult<AuthBackendData>> {
    return AuthFacadeService.registerRemote(phone, password, displayName);
  }

  static async certifyRoleRemote(role: AccountRole): Promise<BackendResult<AuthBackendData>> {
    return AuthFacadeService.certifyRoleRemote(role);
  }

  static async bindFamilyRemote(keyword: string): Promise<BackendResult<BindingListBackendData>> {
    return AuthFacadeService.bindFamilyRemote(keyword);
  }

  static async listFamilyBindingsRemote(): Promise<BackendResult<BindingListBackendData>> {
    return AuthFacadeService.listFamilyBindingsRemote();
  }

  static async loginWithHuaweiIDRemote(context: common.UIAbilityContext): Promise<BackendResult<AuthBackendData>> {
    return AuthFacadeService.loginWithHuaweiIDRemote(context);
  }

  static async loginWithHuaweiIDByCredential(openID: string, unionID: string, authCode: string, idToken: string): Promise<BackendResult<AuthBackendData>> {
    return AuthFacadeService.loginWithHuaweiIDByCredential(openID, unionID, authCode, idToken);
  }

  static async linkPhoneRemote(phone: string): Promise<BackendResult<AuthBackendData>> {
    return AuthFacadeService.linkPhoneRemote(phone);
  }

  static listProducts(): BackendResult<ProductCandidate[]> {
    return ProductFacadeService.listProducts();
  }

  static searchProducts(keyword: string, pageSize: number): BackendResult<ProductCandidate[]> {
    return ProductFacadeService.searchProducts(keyword, pageSize);
  }

  static async refreshProductsFromPublicApi(keyword: string, pageSize: number): Promise<BackendResult<ProductCandidate[]>> {
    return ProductFacadeService.refreshProductsFromPublicApi(keyword, pageSize);
  }

  static getProductGatewayStatus(): BackendResult<ProductGatewayStatus> {
    return ProductFacadeService.getProductGatewayStatus();
  }

  static getFeaturedProducts(count: number): BackendResult<ProductCandidate[]> {
    return ProductFacadeService.getFeaturedProducts(count);
  }

  static getDefaultProduct(): ProductCandidate {
    return ProductFacadeService.getDefaultProduct();
  }

  static getProductById(productId: string): BackendResult<ProductCandidate> {
    return ProductFacadeService.getProductById(productId);
  }

  static startCompare(query: string): BackendResult<CompareBackendData> {
    return ProductFacadeService.startCompare(query);
  }

  static getDemoRecommendation(): RecommendationResult {
    return ProductFacadeService.getDemoRecommendation();
  }

  static selectProduct(productId: string): BackendResult<ShoppingSession> {
    return ProductFacadeService.selectProduct(productId);
  }

  static confirmSelectionByCommand(command: string, candidates: ProductCandidate[]): BackendResult<SelectionCommandBackendData> {
    return ProductFacadeService.confirmSelectionByCommand(command, candidates);
  }

  static parseIntent(query: string): ParsedIntent {
    return ProductFacadeService.parseIntent(query);
  }

  static async listProductsRemote(): Promise<BackendResult<ProductCandidate[]>> {
    return ProductFacadeService.listProductsRemote();
  }

  static async getFeaturedProductsRemote(count: number): Promise<BackendResult<ProductCandidate[]>> {
    return ProductFacadeService.getFeaturedProductsRemote(count);
  }

  static async getProductByIdRemote(productId: string): Promise<BackendResult<ProductCandidate>> {
    return ProductFacadeService.getProductByIdRemote(productId);
  }

  static async startCompareRemote(query: string): Promise<BackendResult<CompareBackendData>> {
    return ProductFacadeService.startCompareRemote(query);
  }

  static async confirmSelectionByCommandRemote(command: string, candidates: ProductCandidate[]): Promise<BackendResult<SelectionCommandBackendData>> {
    return ProductFacadeService.confirmSelectionByCommandRemote(command, candidates);
  }

  static payAndCreateOrder(product: ProductCandidate, quantity: number, address: Address, method: PaymentMethod): BackendResult<PaymentWorkflowBackendData> {
    return OrderFacadeService.payAndCreateOrder(product, quantity, address, method);
  }

  static async huaWeiPayAndCreateOrder(context: common.UIAbilityContext, product: ProductCandidate, quantity: number, address: Address): Promise<BackendResult<PaymentWorkflowBackendData>> {
    return OrderFacadeService.huaWeiPayAndCreateOrder(context, product, quantity, address);
  }

  static async agentPayAndCreateOrder(context: common.UIAbilityContext): Promise<BackendResult<PaymentWorkflowBackendData>> {
    return OrderFacadeService.agentPayAndCreateOrder(context);
  }

  static simulatePaymentFailed(): BackendResult<PaymentWorkflowBackendData> {
    return OrderFacadeService.simulatePaymentFailed();
  }

  static simulatePaymentCancelled(): BackendResult<PaymentWorkflowBackendData> {
    return OrderFacadeService.simulatePaymentCancelled();
  }

  static listOrders(): BackendResult<OrderDraft[]> {
    return OrderFacadeService.listOrders();
  }

  static listPaymentRecords(): BackendResult<PaymentRecord[]> {
    return OrderFacadeService.listPaymentRecords();
  }

  static paymentMethodName(method: PaymentMethod): string {
    return OrderFacadeService.paymentMethodName(method);
  }

  static listAuditLogs(): BackendResult<BackendAuditRecord[]> {
    return OrderFacadeService.listAuditLogs();
  }

  static async payAndCreateOrderRemote(product: ProductCandidate, quantity: number, address: Address, method: PaymentMethod): Promise<BackendResult<PaymentWorkflowBackendData>> {
    return OrderFacadeService.payAndCreateOrderRemote(product, quantity, address, method);
  }

  static async simulatePaymentFailedRemote(product: ProductCandidate, quantity: number, address: Address): Promise<BackendResult<PaymentWorkflowBackendData>> {
    return OrderFacadeService.simulatePaymentFailedRemote(product, quantity, address);
  }

  static async simulatePaymentCancelledRemote(product: ProductCandidate, quantity: number, address: Address): Promise<BackendResult<PaymentWorkflowBackendData>> {
    return OrderFacadeService.simulatePaymentCancelledRemote(product, quantity, address);
  }

  static async listOrdersRemote(): Promise<BackendResult<OrderDraft[]>> {
    return OrderFacadeService.listOrdersRemote();
  }

  static getProfileStats(): BackendResult<ProfileStatsBackendData> {
    return ProfileFacadeService.getProfileStats();
  }

  static async getProfileStatsRemote(): Promise<BackendResult<ProfileStatsBackendData>> {
    return ProfileFacadeService.getProfileStatsRemote();
  }

  static getChildDashboard(): BackendResult<ChildDashboardBackendData> {
    return ProfileFacadeService.getChildDashboard();
  }

  static async getChildDashboardRemote(): Promise<BackendResult<ChildDashboardBackendData>> {
    return ProfileFacadeService.getChildDashboardRemote();
  }

  static getAdminDashboard(): BackendResult<AdminDashboardBackendData> {
    return ProfileFacadeService.getAdminDashboard();
  }

  static async getAdminDashboardRemote(): Promise<BackendResult<AdminDashboardBackendData>> {
    return ProfileFacadeService.getAdminDashboardRemote();
  }

  static getCsDashboard(): BackendResult<CustomerServiceDashboardBackendData> {
    return ProfileFacadeService.getCsDashboard();
  }

  static async getCsDashboardRemote(): Promise<BackendResult<CustomerServiceDashboardBackendData>> {
    return ProfileFacadeService.getCsDashboardRemote();
  }

  static listAddresses(): BackendResult<Address[]> {
    return ReminderFacadeService.listAddresses();
  }

  static async listAddressesRemote(): Promise<BackendResult<Address[]>> {
    return ReminderFacadeService.listAddressesRemote();
  }

  static getDefaultAddress(): BackendResult<Address> {
    return ReminderFacadeService.getDefaultAddress();
  }

  static addAddress(receiver: string, phone: string, detail: string): BackendResult<Address[]> {
    return ReminderFacadeService.addAddress(receiver, phone, detail);
  }

  static async addAddressRemote(receiver: string, phone: string, detail: string): Promise<BackendResult<Address[]>> {
    return ReminderFacadeService.addAddressRemote(receiver, phone, detail);
  }

  static deleteAddress(id: string): BackendResult<Address[]> {
    return ReminderFacadeService.deleteAddress(id);
  }

  static async deleteAddressRemote(id: string): Promise<BackendResult<Address[]>> {
    return ReminderFacadeService.deleteAddressRemote(id);
  }

  static setDefaultAddress(id: string): BackendResult<Address[]> {
    return ReminderFacadeService.setDefaultAddress(id);
  }

  static async setDefaultAddressRemote(id: string): Promise<BackendResult<Address[]>> {
    return ReminderFacadeService.setDefaultAddressRemote(id);
  }

  static listReminders(): BackendResult<ReminderRecord[]> {
    return ReminderFacadeService.listReminders();
  }

  static async listRemindersRemote(): Promise<BackendResult<ReminderRecord[]>> {
    return ReminderFacadeService.listRemindersRemote();
  }

  static markAllRemindersRead(): BackendResult<ReminderRecord[]> {
    return ReminderFacadeService.markAllRemindersRead();
  }

  static async markAllRemindersReadRemote(): Promise<BackendResult<ReminderRecord[]>> {
    return ReminderFacadeService.markAllRemindersReadRemote();
  }

  static processAgentQuery(input: string): AgentResponse {
    return ShoppingAgentOrchestrator.process(input);
  }

  static getAgentSupplementQuestions(input: string): string[] {
    return ShoppingAgentOrchestrator.getSupplementQuestions(input);
  }

  static listAgentLogs(sessionId: string): AgentLogEntry[] {
    return ShoppingAgentOrchestrator.listLogs(sessionId);
  }

  static resetAgentSession(): void {
    ShoppingAgentOrchestrator.resetSession();
  }

  static listAllAccounts(): Account[] {
    return AuthFacadeService.listAllAccounts();
  }

  static updateAccountStatus(accountId: string, status: AccountStatus): BackendResult<AuthBackendData> {
    return AuthFacadeService.updateAccountStatus(accountId, status);
  }

  static updateAccountRole(accountId: string, role: AccountRole): BackendResult<AuthBackendData> {
    return AuthFacadeService.updateAccountRole(accountId, role);
  }

  static listAllOrders(): OrderDraft[] {
    return OrderFacadeService.listAllOrders();
  }

  static listAllTickets(): CustomerTicket[] {
    return AuthFacadeService.listAllTickets();
  }

  static listOpenTickets(): CustomerTicket[] {
    return AuthFacadeService.listOpenTickets();
  }

  static assignTicket(ticketId: string, csAccountId: string): CustomerTicket | undefined {
    return AuthFacadeService.assignTicket(ticketId, csAccountId);
  }

  static resolveTicket(ticketId: string, resolution: string): CustomerTicket | undefined {
    return AuthFacadeService.resolveTicket(ticketId, resolution);
  }

  static escalateTicket(ticketId: string): CustomerTicket | undefined {
    return AuthFacadeService.escalateTicket(ticketId);
  }

  static countOpenTickets(): number {
    return AuthFacadeService.countOpenTickets();
  }

  static countResolvedToday(): number {
    return AuthFacadeService.countResolvedToday();
  }

  static createAccount(phone: string, password: string, displayName: string, role: AccountRole): BackendResult<AuthBackendData> {
    return AuthFacadeService.createAccount(phone, password, displayName, role);
  }

  static updateAccount(accountId: string, phone: string, displayName: string, role: AccountRole, status: AccountStatus): BackendResult<AuthBackendData> {
    return AuthFacadeService.updateAccount(accountId, phone, displayName, role, status);
  }

  static softDeleteAccount(accountId: string): BackendResult<AuthBackendData> {
    return AuthFacadeService.softDeleteAccount(accountId);
  }

  static restoreAccount(accountId: string): BackendResult<AuthBackendData> {
    return AuthFacadeService.restoreAccount(accountId);
  }

  static listDeletedAccounts(): Account[] {
    return AuthFacadeService.listDeletedAccounts();
  }

  static async listAdminUsersRemote(): Promise<BackendResult<AuthBackendData>> {
    return AuthFacadeService.listAdminUsersRemote();
  }

  static async listAdminAccountsRemote(): Promise<BackendResult<AuthBackendData>> {
    return AuthFacadeService.listAdminAccountsRemote();
  }

  static async createAccountRemote(phone: string, password: string, displayName: string, role: AccountRole): Promise<BackendResult<AuthBackendData>> {
    return AuthFacadeService.createAccountRemote(phone, password, displayName, role);
  }

  static async updateAccountRemote(accountId: string, phone: string, displayName: string, role: AccountRole, status: AccountStatus): Promise<BackendResult<AuthBackendData>> {
    return AuthFacadeService.updateAccountRemote(accountId, phone, displayName, role, status);
  }

  static async softDeleteAccountRemote(accountId: string): Promise<BackendResult<AuthBackendData>> {
    return AuthFacadeService.softDeleteAccountRemote(accountId);
  }

  static async restoreAccountRemote(accountId: string): Promise<BackendResult<AuthBackendData>> {
    return AuthFacadeService.restoreAccountRemote(accountId);
  }

  static async csListTicketsRemote(): Promise<BackendResult<CustomerServiceDashboardBackendData>> {
    return ProfileFacadeService.csListTicketsRemote();
  }

  static async listPaymentRecordsRemote(): Promise<BackendResult<PaymentRecord[]>> {
    return OrderFacadeService.listPaymentRecordsRemote();
  }

  static async listAuditLogsRemote(): Promise<BackendResult<BackendAuditRecord[]>> {
    return OrderFacadeService.listAuditLogsRemote();
  }

  static async listAdminAuditLogsRemote(): Promise<BackendResult<BackendAuditRecord[]>> {
    return OrderFacadeService.listAdminAuditLogsRemote();
  }

  static async listAdminOrdersRemote(): Promise<BackendResult<OrderDraft[]>> {
    return OrderFacadeService.listAdminOrdersRemote();
  }

  static async listCsOrdersRemote(): Promise<BackendResult<OrderDraft[]>> {
    return OrderFacadeService.listAdminOrdersRemote();
  }

  static async adminDeleteOrderRemote(orderId: string): Promise<BackendResult<null>> {
    const result = await RemoteBackendClient.adminDeleteOrder(orderId);
    if (result.success) {
      OrderService.deleteOrder(orderId);
      return { success: true, code: BackendErrorCode.Ok, message: '订单已删除' };
    }
    OrderService.deleteOrder(orderId);
    return { success: true, code: BackendErrorCode.Ok, message: '本地订单已删除' };
  }

  static async adminClearAuditLogsRemote(): Promise<BackendResult<null>> {
    const result = await RemoteBackendClient.adminClearAuditLogs();
    if (result.success) {
      AuditLogService.clearRecords();
      return { success: true, code: BackendErrorCode.Ok, message: '日志已清空' };
    }
    AuditLogService.clearRecords();
    return { success: true, code: BackendErrorCode.Ok, message: '本地日志已清空' };
  }

  static async adminDeleteAuditLogRemote(logId: string): Promise<BackendResult<null>> {
    const result = await RemoteBackendClient.adminDeleteAuditLog(logId);
    if (result.success) {
      AuditLogService.deleteRecord(logId);
      return { success: true, code: BackendErrorCode.Ok, message: '日志已删除' };
    }
    AuditLogService.deleteRecord(logId);
    return { success: true, code: BackendErrorCode.Ok, message: '本地日志已删除' };
  }

  static syncRemoteUsers(users: RemoteAdminUserItem[]): void {
    AuthFacadeService.syncRemoteUsers(users);
  }

  static submitFeedbackLocal(title: string, content: string): CustomerTicket {
    return AuthFacadeService.submitFeedbackLocal(title, content);
  }

  static async submitFeedbackRemote(title: string, content: string): Promise<BackendResult<AuthBackendData>> {
    return AuthFacadeService.submitFeedbackRemote(title, content);
  }

  static async updateElderlyProfileRemote(realName: string, age: number, emergencyPhone: string, nickName: string): Promise<BackendResult<AuthBackendData>> {
    return AuthFacadeService.updateElderlyProfileRemote(realName, age, emergencyPhone, nickName);
  }

  static async updateChildProfileRemote(realName: string, relation: string, nickName: string): Promise<BackendResult<AuthBackendData>> {
    return AuthFacadeService.updateChildProfileRemote(realName, relation, nickName);
  }
}
