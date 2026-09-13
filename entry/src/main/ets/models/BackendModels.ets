import { Account, AccountRole, CustomerTicket, FamilyBinding } from './AuthModels';
import {
  Address,
  OrderDraft,
  PaymentRecord,
  PaymentResult,
  ProductCandidate,
  RecommendationResult,
  ReminderRecord,
  ShoppingSession
} from './ShoppingModels';

export enum BackendErrorCode {
  Ok = 'ok',
  ValidationError = 'validation_error',
  Unauthorized = 'unauthorized',
  Forbidden = 'forbidden',
  NotFound = 'not_found',
  PaymentFailed = 'payment_failed',
  PaymentCancelled = 'payment_cancelled',
  InternalError = 'internal_error'
}

export interface BackendResult<T> {
  success: boolean;
  code: BackendErrorCode;
  message: string;
  data?: T;
}

export interface AuthBackendData {
  account?: Account;
  role: AccountRole;
  canShop: boolean;
}

export interface CompareBackendData {
  session: ShoppingSession;
  recommendation: RecommendationResult;
}

export interface SelectionCommandBackendData {
  product: ProductCandidate;
  quantity: number;
  session: ShoppingSession;
}

export interface PaymentWorkflowBackendData {
  payment: PaymentResult;
  paymentRecord?: PaymentRecord;
  order?: OrderDraft;
  reminder?: ReminderRecord;
}

export interface ChildDashboardBackendData {
  addressCount: number;
  unreadReminderCount: number;
  bindingCount: number;
  defaultAddressText: string;
  latestReminderText: string;
}

export interface ProfileStatsBackendData {
  account?: Account;
  orderCount: number;
  addressCount: number;
  reminderCount: number;
  bindingCount: number;
  unreadReminderCount: number;
}

export interface BindingListBackendData {
  bindings: FamilyBinding[];
}

export interface AdminDashboardBackendData {
  totalAccounts: number;
  elderlyCount: number;
  childCount: number;
  csCount: number;
  adminCount: number;
  totalOrders: number;
  pendingOrders: number;
  deletedCount: number;
  recentAuditLogs: AuditLogSummary[];
}

export interface AuditLogSummary {
  id: string;
  actorName: string;
  action: string;
  detail: string;
  createdAt: string;
}

export interface CustomerServiceDashboardBackendData {
  openTickets: number;
  resolvedToday: number;
  pendingTickets: CustomerTicket[];
}
