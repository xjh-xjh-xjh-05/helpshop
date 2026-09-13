import { CopilotController, FrontendAction } from '@hw-agconnect/copilot';
import { AppConfig, AgentMode, CopilotConfig } from '../config/AppConfig';
import { AgentResponse, IntentType, VoiceInputContext } from '../agent/AgentModels';
import { ShoppingAgentOrchestrator } from '../agent/ShoppingAgentOrchestrator';
import { ProductFacadeService } from './ProductFacadeService';
import { AddressService } from './AddressService';
import { ProductCandidate, RecommendationResult } from '../models/ShoppingModels';

export interface AgentProviderStatus {
  activeMode: AgentMode;
  localReady: boolean;
  copilotInstalled: boolean;
  copilotReady: boolean;
  title: string;
  message: string;
}

export interface AgentQuickPrompt {
  id: string;
  title: string;
  content: string;
}

export class AgentNextAction {
  route: string = '';
  params?: AgentRouteParams;
}

export class AgentRouteParams {
  query: string = '';
  productId: string = '';
  quantity: string = '';
}

class CopilotProductPayload {
  id: string = '';
  platform: string = '';
  name: string = '';
  price: number = 0;
  rating: number = 0;
  sales: number = 0;
}

class CopilotSearchPayload {
  success: boolean = false;
  keyword: string = '';
  products: CopilotProductPayload[] = [];
}

class CopilotComparePayload {
  success: boolean = false;
  query: string = '';
  message: string = '';
  recommendation?: RecommendationResult;
}

class CopilotAddressPayload {
  id: string = '';
  receiver: string = '';
  phone: string = '';
  detail: string = '';
  isDefault: boolean = false;
}

class CopilotAddressListPayload {
  success: boolean = false;
  addresses: CopilotAddressPayload[] = [];
}

export class AgentProviderService {
  static readonly QUICK_PROMPTS: AgentQuickPrompt[] = [
    {
      id: 'agent-001',
      title: '先比价',
      content: '我想买一双不累脚的鞋'
    },
    {
      id: 'agent-002',
      title: '营养品',
      content: '买两罐无糖奶粉'
    },
    {
      id: 'agent-003',
      title: '老人手机',
      content: '老人用的大按键手机'
    },
    {
      id: 'agent-004',
      title: '直接支付',
      content: '帮我准备支付'
    }
  ];

  static getStatus(): AgentProviderStatus {
    if (AgentProviderService.canUseCopilot()) {
      return {
        activeMode: AgentMode.Copilot,
        localReady: true,
        copilotInstalled: true,
        copilotReady: true,
        title: 'Copilot 已启用',
        message: '当前使用官方 Copilot 聊天组件，可继续接入服务端代理的大模型能力。'
      };
    }
    return {
      activeMode: AgentMode.Native,
      localReady: true,
      copilotInstalled: true,
      copilotReady: false,
      title: '原生 Agent 已启用',
      message: '当前使用混合架构 Agent（规则引擎 + LLM ReAct 推理）。LLM 不可用时自动降级到规则引擎。'
    };
  }

  static getQuickPrompts(): AgentQuickPrompt[] {
    return AgentProviderService.QUICK_PROMPTS.slice();
  }

  static canUseCopilot(): boolean {
    return AppConfig.agentMode === AgentMode.Copilot &&
      CopilotConfig.baseUrl.trim().length > 0 &&
      CopilotConfig.apiKey.trim().length > 0 &&
      CopilotConfig.model.trim().length > 0;
  }

  static processNative(input: string): AgentResponse {
    return ShoppingAgentOrchestrator.process(input);
  }

  static async processNativeWithThinking(input: string): Promise<AgentResponse> {
    return ShoppingAgentOrchestrator.processWithThinking(input);
  }

  static processVoiceInput(text: string, confidence: number, partialText: string, language: string): AgentResponse {
    return ShoppingAgentOrchestrator.processVoiceInput(text, confidence, partialText, language);
  }

  static createCopilotController(): CopilotController | undefined {
    if (!AgentProviderService.canUseCopilot()) {
      return undefined;
    }
    const controller: CopilotController = new CopilotController({
      llm: {
        baseUrl: CopilotConfig.baseUrl,
        apiKey: CopilotConfig.apiKey,
        model: CopilotConfig.model
      },
      systemPrompt: CopilotConfig.systemPrompt
    });
    AgentProviderService.registerActions(controller);
    return controller;
  }

  static resolveNextAction(response: AgentResponse): AgentNextAction | undefined {
    if (response.intent.type === IntentType.Compare &&
      response.result.data.recommendation &&
      response.result.data.recommendation.bestProduct.id.length > 0) {
      const params: AgentRouteParams = new AgentRouteParams();
      params.query = response.intent.rawText;
      const action: AgentNextAction = new AgentNextAction();
      action.route = 'pages/CompareResult';
      action.params = params;
      return action;
    }

    if (response.intent.type === IntentType.OrderConfirm &&
      response.result.data.orderPreview &&
      response.result.data.orderPreview.product.id.length > 0) {
      const params: AgentRouteParams = new AgentRouteParams();
      params.productId = response.result.data.orderPreview.product.id;
      params.quantity = response.result.data.orderPreview.quantity.toString();
      const action: AgentNextAction = new AgentNextAction();
      action.route = 'pages/PaymentConfirm';
      action.params = params;
      return action;
    }

    if (response.intent.type === IntentType.Pay &&
      response.result.data.paymentPreview &&
      response.result.data.paymentPreview.product.id.length > 0) {
      const params: AgentRouteParams = new AgentRouteParams();
      params.productId = response.result.data.paymentPreview.product.id;
      params.quantity = response.result.data.paymentPreview.quantity.toString();
      const action: AgentNextAction = new AgentNextAction();
      action.route = 'pages/PaymentConfirm';
      action.params = params;
      return action;
    }
    return undefined;
  }

  private static registerActions(controller: CopilotController): void {
    const actions: FrontendAction[] = [
      {
        name: 'search_product',
        description: '搜索适合老年用户购买的商品列表',
        available: 'enabled',
        parameters: [
          {
            name: 'keyword',
            type: 'string',
            description: '商品关键词',
            required: true
          }
        ],
        handler: async (args: Record<string, ESObject>): Promise<ESObject> => {
          const keyword: string = `${args.keyword ? args.keyword : ''}`.trim();
          const result = ProductFacadeService.searchProducts(keyword, 6);
          const products: ProductCandidate[] = result.data ? result.data : [];
          const payload: CopilotSearchPayload = new CopilotSearchPayload();
          payload.success = result.success;
          payload.keyword = keyword;
          payload.products = products.map((item: ProductCandidate) => {
            const next: CopilotProductPayload = new CopilotProductPayload();
            next.id = item.id;
            next.platform = item.platform;
            next.name = item.name;
            next.price = item.price;
            next.rating = item.rating;
            next.sales = item.sales;
            return next;
          });
          return payload;
        }
      },
      {
        name: 'compare_product',
        description: '按老人需求进行商品比价和推荐',
        available: 'enabled',
        parameters: [
          {
            name: 'query',
            type: 'string',
            description: '老人购物需求',
            required: true
          }
        ],
        handler: async (args: Record<string, ESObject>): Promise<ESObject> => {
          const query: string = `${args.query ? args.query : ''}`.trim();
          const result = ProductFacadeService.startCompare(query);
          const payload: CopilotComparePayload = new CopilotComparePayload();
          payload.success = result.success;
          payload.query = query;
          payload.message = result.message;
          payload.recommendation = result.data ? result.data.recommendation : undefined;
          return payload;
        }
      },
      {
        name: 'list_address',
        description: '查看当前老人账号的收货地址',
        available: 'enabled',
        handler: async (): Promise<ESObject> => {
          const addresses = AddressService.listAddresses();
          const payload: CopilotAddressListPayload = new CopilotAddressListPayload();
          payload.success = true;
          payload.addresses = addresses.map((item) => {
            const next: CopilotAddressPayload = new CopilotAddressPayload();
            next.id = item.id;
            next.receiver = item.receiver;
            next.phone = item.phone;
            next.detail = item.detail;
            next.isDefault = item.isDefault;
            return next;
          });
          return payload;
        }
      }
    ];

    for (let i = 0; i < actions.length; i += 1) {
      controller.registerAction(actions[i]);
    }
  }
}
