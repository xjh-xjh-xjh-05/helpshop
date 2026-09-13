import { Address, ParsedIntent, PaymentMethod, ProductCandidate, RecommendationResult } from '../models/ShoppingModels';
import { TimeUtils } from '../utils/TimeUtils';
import { CloneUtils } from '../utils/CloneUtils';

export enum IntentType {
  Search = 'search',
  Compare = 'compare',
  OrderConfirm = 'order_confirm',
  Pay = 'pay',
  Supplement = 'supplement',
  VoiceCommand = 'voice_command',
  AdminQuery = 'admin_query',
  CSAsk = 'cs_ask',
  OrderQuery = 'order_query',
  AddressManage = 'address_manage',
  ReminderManage = 'reminder_manage',
  FamilyBind = 'family_bind',
  ProductSelect = 'product_select',
  Unknown = 'unknown'
}

export interface VoiceInputContext {
  isVoiceInput: boolean;
  confidence: number;
  partialText: string;
  language: string;
}

export interface StructuredAttributes {
  color: string;
  size: string;
  material: string;
  features: string[];
  rawAttributes: string[];
}

export interface AgentIntent {
  type: IntentType;
  product: string;
  category: string;
  attributes: StructuredAttributes;
  quantity: number;
  rawText: string;
  confidence: number;
  needsSupplement: boolean;
  supplementQuestions: string[];
  voiceContext: VoiceInputContext;
  selectedIndex: number;
}

export enum AgentActionType {
  CallSkill = 'call_skill',
  AskUser = 'ask_user',
  ReturnResult = 'return_result',
  HandleError = 'handle_error',
  PlanMultiStep = 'plan_multi_step',
  Reflect = 'reflect'
}

export interface AgentAction {
  type: AgentActionType;
  skillName: string;
  intent: AgentIntent;
  message: string;
}

export interface OrderPreview {
  product: ProductCandidate;
  quantity: number;
  address: Address;
  totalPrice: number;
  paymentUrl: string;
}

export interface SkillResultData {
  products: ProductCandidate[];
  recommendation: RecommendationResult;
  orderPreview: OrderPreview;
  paymentPreview: PaymentPreview;
  payload: Record<string, Object>;
}

export interface PaymentPreview {
  product: ProductCandidate;
  quantity: number;
  totalPrice: number;
  availableMethods: PaymentMethod[];
  recommendedMethod: PaymentMethod;
  needsAddress: boolean;
  ready: boolean;
}

export interface SkillResult {
  success: boolean;
  data: SkillResultData;
  message: string;
  fallbackUsed: boolean;
}

export interface ConversationTurn {
  role: string;
  roleType: string;
  content: string;
  intent: AgentIntent;
  timestamp: string;
}

export interface ConversationContext {
  sessionId: string;
  turnIndex: number;
  pendingIntent: AgentIntent;
  history: ConversationTurn[];
}

export interface AgentLogEntry {
  id: string;
  sessionId: string;
  input: string;
  intentType: IntentType;
  actionType: AgentActionType;
  skillName: string;
  output: string;
  durationMs: number;
  fallbackUsed: boolean;
  timestamp: string;
}

export enum AgentSessionStatus {
  Idle = 'idle',
  Shopping = 'shopping',
  Comparing = 'comparing',
  WaitingConfirm = 'waitingConfirm',
  WaitingPayment = 'waitingPayment',
  Completed = 'completed'
}

export interface AgentSession {
  id: string;
  status: AgentSessionStatus;
  role: string;
  query: string;
  selectedProductId: string;
  selectedProduct: ProductCandidate;
  quantity: number;
  addressId: string;
  paymentMethod: PaymentMethod;
  conversationContext: ConversationContext;
  createdAt: string;
  updatedAt: string;
}

export interface AgentActionResult {
  action: AgentActionType;
  skillResult: SkillResult;
  supplementQuestions: string[];
  errorMessage: string;
}

export interface AgentResponse {
  intent: AgentIntent;
  action: AgentActionType;
  result: SkillResult;
  session: AgentSession;
  supplementQuestions: string[];
  logEntry: AgentLogEntry;
  thinkingChain: ThinkingChain;
  fallbackUsed: boolean;
}

export interface ThinkingStep {
  stepId: string;
  type: string;
  content: string;
  toolName: string;
  toolArgs: Record<string, string>;
  result: ToolResult;
  isFinal: boolean;
  timestamp: string;
}

export interface ThinkingChain {
  steps: ThinkingStep[];
  finalResponse: string;
  toolsUsed: string[];
  totalSteps: number;
  llmCallsUsed: number;
}

export interface ToolParameter {
  name: string;
  type: string;
  description: string;
  required: boolean;
}

export interface ToolResult {
  success: boolean;
  data: string;
  message: string;
}

export interface ExecutionStep {
  stepIndex: number;
  toolName: string;
  input: string;
  output: string;
  success: boolean;
  timestamp: string;
}

export interface Tool {
  name: string;
  description: string;
  parameters: ToolParameter[];
  canHandle(intent: AgentIntent): boolean;
  execute(intent: AgentIntent, context: ConversationContext): SkillResult;
  executeWithArgs(args: Record<string, string>, context: ConversationContext): ToolResult;
}

export interface Skill {
  name: string;
  description: string;
  canHandle(intent: AgentIntent): boolean;
  execute(intent: AgentIntent, context: ConversationContext): SkillResult;
}

export function emptyStructuredAttributes(): StructuredAttributes {
  return {
    color: '',
    size: '',
    material: '',
    features: [],
    rawAttributes: []
  };
}

export function emptySkillResultData(): SkillResultData {
  return {
    products: [],
    recommendation: {
      intent: { product: '', attributes: [], quantity: 1, rawText: '' },
      bestProduct: {
        id: '', platform: '', name: '', price: 0, rating: 0, sales: 0,
        shopName: '', description: '', tags: [], recommendScore: 0
      },
      candidates: [],
      reason: '',
      fallbackUsed: false
    },
    orderPreview: {
      product: {
        id: '', platform: '', name: '', price: 0, rating: 0, sales: 0,
        shopName: '', description: '', tags: [], recommendScore: 0
      },
      quantity: 0,
      address: { id: '', receiver: '', phone: '', detail: '', isDefault: false },
      totalPrice: 0,
      paymentUrl: ''
    },
    paymentPreview: {
      product: {
        id: '', platform: '', name: '', price: 0, rating: 0, sales: 0,
        shopName: '', description: '', tags: [], recommendScore: 0
      },
      quantity: 1,
      totalPrice: 0,
      availableMethods: [],
      recommendedMethod: PaymentMethod.HuaWeiPay,
      needsAddress: true,
      ready: false
    },
    payload: {}
  };
}

export function agentIntentToParsedIntent(intent: AgentIntent): ParsedIntent {
  const allAttributes: string[] = [];
  if (intent.attributes.color.length > 0) {
    allAttributes.push(intent.attributes.color);
  }
  if (intent.attributes.size.length > 0) {
    allAttributes.push(intent.attributes.size);
  }
  if (intent.attributes.material.length > 0) {
    allAttributes.push(intent.attributes.material);
  }
  for (let i = 0; i < intent.attributes.features.length; i += 1) {
    allAttributes.push(intent.attributes.features[i]);
  }
  for (let i = 0; i < intent.attributes.rawAttributes.length; i += 1) {
    allAttributes.push(intent.attributes.rawAttributes[i]);
  }
  return {
    product: intent.product,
    attributes: allAttributes,
    quantity: intent.quantity,
    rawText: intent.rawText
  };
}

export function cloneAgentIntent(intent: AgentIntent): AgentIntent {
  return CloneUtils.cloneAgentIntent(intent);
}

export function cloneConversationContext(context: ConversationContext): ConversationContext {
  return CloneUtils.cloneConversationContext(context);
}

export function emptyAgentIntent(): AgentIntent {
  return {
    type: IntentType.Unknown,
    product: '',
    category: '',
    attributes: emptyStructuredAttributes(),
    quantity: 1,
    rawText: '',
    confidence: 0,
    needsSupplement: false,
    supplementQuestions: [],
    voiceContext: { isVoiceInput: false, confidence: 0, partialText: '', language: 'zh-CN' },
    selectedIndex: -1
  };
}

export function emptyProductCandidate(): ProductCandidate {
  return {
    id: '', platform: '', name: '', price: 0, rating: 0, sales: 0,
    shopName: '', description: '', tags: [], recommendScore: 0
  };
}

export function emptyAgentSession(): AgentSession {
  const now: string = formatAgentTime(new Date());
  return {
    id: '',
    status: AgentSessionStatus.Idle,
    role: 'elderly',
    query: '',
    selectedProductId: '',
    selectedProduct: emptyProductCandidate(),
    quantity: 1,
    addressId: '',
    paymentMethod: PaymentMethod.HuaWeiPay,
    conversationContext: emptyConversationContext(),
    createdAt: now,
    updatedAt: now
  };
}

export function cloneAgentSession(session: AgentSession): AgentSession {
  return CloneUtils.cloneAgentSession(session);
}

export function formatAgentTime(date: Date): string {
  return TimeUtils.formatDate(date);
}

export function emptyConversationContext(): ConversationContext {
  return {
    sessionId: '',
    turnIndex: 0,
    pendingIntent: emptyAgentIntent(),
    history: []
  };
}

export function emptyThinkingChain(): ThinkingChain {
  return {
    steps: [],
    finalResponse: '',
    toolsUsed: [],
    totalSteps: 0,
    llmCallsUsed: 0
  };
}

export function emptyThinkingStep(): ThinkingStep {
  return {
    stepId: '',
    type: 'observe',
    content: '',
    toolName: '',
    toolArgs: {},
    result: emptyToolResult(),
    isFinal: false,
    timestamp: ''
  };
}

export function emptyToolResult(): ToolResult {
  return {
    success: false,
    data: '',
    message: ''
  };
}

export function emptyExecutionStep(): ExecutionStep {
  return {
    stepIndex: 0,
    toolName: '',
    input: '',
    output: '',
    success: false,
    timestamp: ''
  };
}
