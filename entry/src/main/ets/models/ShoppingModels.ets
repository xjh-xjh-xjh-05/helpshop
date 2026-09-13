export interface ParsedIntent {
  product: string;
  attributes: string[];
  quantity: number;
  rawText: string;
}

export interface ProductCandidate {
  id: string;
  platform: string;
  name: string;
  price: number;
  originalPrice?: number;
  rating: number;
  sales: number;
  shopName: string;
  description: string;
  specs?: string;
  tags: string[];
  recommendScore: number;
  imageKey?: string;
  imageUrl?: string;
}

export interface RecommendationResult {
  intent: ParsedIntent;
  bestProduct: ProductCandidate;
  candidates: ProductCandidate[];
  reason: string;
  fallbackUsed: boolean;
}

export interface Address {
  id: string;
  elderlyAccountId?: string;
  managedByChildAccountId?: string;
  receiver: string;
  phone: string;
  detail: string;
  isDefault: boolean;
}

export interface OrderDraft {
  id: string;
  elderlyAccountId?: string;
  managedByChildAccountId?: string;
  createdAt: string;
  product: ProductCandidate;
  quantity: number;
  address: Address;
  totalPrice: number;
  paymentMethod: PaymentMethod;
  paymentStatus: PaymentStatus;
}

export interface ReminderRecord {
  id: string;
  orderId: string;
  elderlyAccountId?: string;
  childAccountId?: string;
  title: string;
  content: string;
  createdAt: string;
  read: boolean;
}

export interface ShoppingSession {
  id: string;
  status: ShoppingSessionStatus;
  query: string;
  selectedProductId?: string;
}

export enum ShoppingSessionStatus {
  Idle = 'idle',
  Comparing = 'comparing',
  WaitingConfirm = 'waitingConfirm',
  WaitingPayment = 'waitingPayment',
  Completed = 'completed'
}

export enum PaymentStatus {
  Pending = 'pending',
  Success = 'success',
  Failed = 'failed',
  Cancelled = 'cancelled'
}

export enum PaymentMethod {
  Face = 'face',
  Fingerprint = 'fingerprint',
  Password = 'password',
  HuaWeiPay = 'huawei_pay'
}

export interface PaymentResult {
  status: PaymentStatus;
  message: string;
  method: PaymentMethod;
  paidAt: string;
}

export interface PaymentRecord {
  id: string;
  orderId?: string;
  elderlyAccountId?: string;
  productId?: string;
  amount: number;
  method: PaymentMethod;
  status: PaymentStatus;
  message: string;
  createdAt: string;
}

export interface BackendAuditRecord {
  id: string;
  actorAccountId?: string;
  elderlyAccountId?: string;
  action: string;
  detail: string;
  createdAt: string;
}
