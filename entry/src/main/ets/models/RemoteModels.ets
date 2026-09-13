import { ShoppingSession } from './ShoppingModels';

export interface RemoteAddressItem {
  id: string;
  elderly_account_id?: string;
  managed_by_child_account_id?: string;
  receiver: string;
  phone: string;
  detail: string;
  is_default: number;
}

export interface RemoteAddressListResponse {
  success: boolean;
  addresses?: RemoteAddressItem[];
}

export interface RemoteOrderItem {
  id: string;
  elderly_account_id?: string;
  managed_by_child_account_id?: string;
  product_id: string;
  product_name: string;
  platform: string;
  quantity: number;
  address_id: string;
  total_price: number;
  payment_method: string;
  payment_status: string;
  created_at: string;
  shop_name?: string;
  product_price?: number;
  rating?: number;
  sales?: number;
  description?: string;
  tags?: string;
  address_receiver?: string;
  address_phone?: string;
  address_detail?: string;
}

export interface RemoteOrderListResponse {
  success: boolean;
  orders?: RemoteOrderItem[];
}

export interface RemoteReminderItem {
  id: string;
  order_id: string;
  elderly_account_id?: string;
  child_account_id?: string;
  title: string;
  content: string;
  created_at: string;
  read: number;
}

export interface RemoteReminderListResponse {
  success: boolean;
  message?: string;
  reminders?: RemoteReminderItem[];
}

export interface RemotePaymentResponse {
  success: boolean;
  payment_id?: string;
  order_id?: string;
  status: string;
  message: string;
}

export interface RemoteProductItem {
  id: string;
  platform: string;
  name: string;
  price: number;
  rating: number;
  sales: number;
  shop_name?: string;
  shopName?: string;
  description: string;
  tags?: string;
  tag_list?: string[];
  recommend_score?: number;
  recommendScore?: number;
  image_key?: string;
  imageKey?: string;
  image_url?: string;
  imageUrl?: string;
}

export interface RemoteProductListResponse {
  success: boolean;
  products?: RemoteProductItem[];
}

export interface RemoteProductDetailResponse {
  success: boolean;
  product?: RemoteProductItem;
}

export interface RemoteIntentItem {
  product: string;
  attributes: string[];
  quantity: number;
  rawText?: string;
  raw_text?: string;
}

export interface RemoteRecommendationItem {
  intent: RemoteIntentItem;
  bestProduct?: RemoteProductItem;
  best_product?: RemoteProductItem;
  candidates: RemoteProductItem[];
  reason: string;
  fallbackUsed?: boolean;
  fallback_used?: boolean;
}

export interface RemoteCompareResponse {
  success: boolean;
  message?: string;
  session?: ShoppingSession;
  recommendation?: RemoteRecommendationItem;
}

export interface RemoteSelectionResponse {
  success: boolean;
  message?: string;
  product?: RemoteProductItem;
  quantity?: number;
  session?: ShoppingSession;
}

export interface RemoteAccountItem {
  id: string;
  id_user?: number;
  phone: string;
  password_hash?: string;
  display_name?: string;
  default_role?: string;
  status?: string;
  huawei_open_id?: string;
  huawei_union_id?: string;
  created_at?: string;
  updated_at?: string;
}

export interface RemoteProfileStatsResponse {
  success: boolean;
  account?: RemoteAccountItem;
  orderCount?: number;
  order_count?: number;
  addressCount?: number;
  address_count?: number;
  reminderCount?: number;
  reminder_count?: number;
  bindingCount?: number;
  binding_count?: number;
  unreadReminderCount?: number;
  unread_reminder_count?: number;
}

export interface RemoteChildDashboardResponse {
  success: boolean;
  addressCount?: number;
  address_count?: number;
  unreadReminderCount?: number;
  unread_reminder_count?: number;
  bindingCount?: number;
  binding_count?: number;
  defaultAddressText?: string;
  default_address_text?: string;
  latestReminderText?: string;
  latest_reminder_text?: string;
}

export interface RemoteAuthResponse {
  success: boolean;
  access_token?: string;
  message?: string;
  account?: RemoteAccountItem;
}

export interface RemoteBindingData {
  id: string;
  elderly_account_id: string;
  child_account_id: string;
  binding_code: string;
  status: string;
  created_at: string;
  updated_at: string;
}

export interface RemoteElderlyData {
  id: string;
  display_name: string;
  phone: string;
  binding_code: string;
}

export interface RemoteBindResponse {
  success: boolean;
  message?: string;
  binding?: RemoteBindingData;
  elderly?: RemoteElderlyData;
}

export interface PermissionRequestResult {
  permissions: string[];
  authResults: number[];
}

export interface RemoteHuaweiLoginResponse {
  success: boolean;
  access_token?: string;
  message?: string;
  account?: RemoteAccountItem;
  phone_missing?: boolean;
}

export interface RemoteAdminUserItem {
  id: string;
  phone: string;
  display_name?: string;
  default_role?: string;
  status?: string;
  orderCount?: number;
  order_count?: number;
  id_user?: number;
  created_at?: string;
  updated_at?: string;
}

export interface RemoteAdminUserListResponse {
  success: boolean;
  users?: RemoteAdminUserItem[];
  total?: number;
}

export interface RemoteAdminOrderListResponse {
  success: boolean;
  orders?: RemoteOrderItem[];
  total?: number;
}

export interface RemoteAdminAccountCrudResponse {
  success: boolean;
  message?: string;
  account?: RemoteAccountItem;
}

export interface RemoteCsTicketItem {
  id: string;
  user: string;
  title: string;
  priority: string;
  status: string;
  time: string;
  elderly_account_id?: string;
  cs_account_id?: string;
  content?: string;
  created_at?: string;
  updated_at?: string;
}

export interface RemoteCsTicketListResponse {
  success: boolean;
  tickets?: RemoteCsTicketItem[];
}

export interface RemotePaymentRecordItem {
  id: string;
  order_id?: string;
  elderly_account_id?: string;
  product_id?: string;
  amount: number;
  method: string;
  status: string;
  message: string;
  created_at: string;
}

export interface RemotePaymentRecordListResponse {
  success: boolean;
  payment_records?: RemotePaymentRecordItem[];
}

export interface RemoteAuditLogItem {
  id: string;
  actor_account_id?: string;
  elderly_account_id?: string;
  action: string;
  detail: string;
  created_at: string;
}

export interface RemoteAuditLogListResponse {
  success: boolean;
  logs?: RemoteAuditLogItem[];
}

export interface RemoteAdminDashboardResponse {
  success: boolean;
  totalAccounts?: number;
  total_accounts?: number;
  elderlyCount?: number;
  elderly_count?: number;
  childCount?: number;
  child_count?: number;
  csCount?: number;
  cs_count?: number;
  adminCount?: number;
  admin_count?: number;
  totalOrders?: number;
  total_orders?: number;
  pendingOrders?: number;
  pending_orders?: number;
  message?: string;
}
