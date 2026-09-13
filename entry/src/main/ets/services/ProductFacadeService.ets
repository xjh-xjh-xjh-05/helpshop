import { BackendErrorCode, BackendResult, CompareBackendData, SelectionCommandBackendData } from '../models/BackendModels';
import { PlatformSearchResponse, ProductGatewayStatus } from '../models/PlatformModels';
import {
  RemoteProductItem,
  RemoteCompareResponse,
  RemoteSelectionResponse
} from '../models/RemoteModels';
import { ParsedIntent, ProductCandidate, RecommendationResult, ShoppingSession } from '../models/ShoppingModels';
import { AgentResponse, AgentSession, agentIntentToParsedIntent } from '../agent/AgentModels';
import { AgentSessionManager } from '../agent/AgentSessionManager';
import { ShoppingAgentOrchestrator } from '../agent/ShoppingAgentOrchestrator';
import { IntentEngine } from '../agent/IntentEngine';
import { MockProductService } from './MockProductService';
import { PlatformProductGatewayService } from './PlatformProductGatewayService';
import { RemoteBackendClient, RemoteBackendResult } from './RemoteBackendClient';
import { RemoteDataMapper } from './RemoteDataMapper';

export class ProductFacadeService {
  static listProducts(): BackendResult<ProductCandidate[]> {
    return RemoteDataMapper.ok<ProductCandidate[]>('已获取商品列表', MockProductService.getAllProducts());
  }

  static searchProducts(keyword: string, pageSize: number): BackendResult<ProductCandidate[]> {
    const products: ProductCandidate[] = PlatformProductGatewayService.searchCandidates(keyword, pageSize > 0 ? pageSize : 20);
    return RemoteDataMapper.ok<ProductCandidate[]>('已从平台商品网关获取商品', products);
  }

  static async refreshProductsFromPublicApi(keyword: string, pageSize: number): Promise<BackendResult<ProductCandidate[]>> {
    const response: PlatformSearchResponse = await PlatformProductGatewayService.refreshProductsFromPublicApi(keyword, pageSize);
    const products: ProductCandidate[] = response.products.map((item) => PlatformProductGatewayService.toCandidate(item));
    if (response.sourceMode === undefined) {
      return RemoteDataMapper.fail<ProductCandidate[]>(BackendErrorCode.InternalError, '商品接口返回异常');
    }
    return RemoteDataMapper.ok<ProductCandidate[]>(response.message, products);
  }

  static getProductGatewayStatus(): BackendResult<ProductGatewayStatus> {
    return RemoteDataMapper.ok<ProductGatewayStatus>('已获取商品平台接入状态', PlatformProductGatewayService.getStatus());
  }

  static getFeaturedProducts(count: number): BackendResult<ProductCandidate[]> {
    const safeCount: number = count > 0 ? count : 8;
    return RemoteDataMapper.ok<ProductCandidate[]>('已获取推荐商品', MockProductService.getAllProducts().slice(0, safeCount));
  }

  static getDefaultProduct(): ProductCandidate {
    return MockProductService.getAllProducts()[0];
  }

  static getProductById(productId: string): BackendResult<ProductCandidate> {
    const product: ProductCandidate | undefined = MockProductService.getProductById(productId);
    if (!product) {
      return RemoteDataMapper.fail<ProductCandidate>(BackendErrorCode.NotFound, '商品不存在');
    }
    return RemoteDataMapper.ok<ProductCandidate>('已获取商品', product);
  }

  static startCompare(query: string): BackendResult<CompareBackendData> {
    const normalized: string = query.trim();
    if (normalized.length === 0) {
      return RemoteDataMapper.fail<CompareBackendData>(BackendErrorCode.ValidationError, '请先输入想买的商品');
    }
    const agentResponse: AgentResponse = ShoppingAgentOrchestrator.process(normalized);
    const session: ShoppingSession = ProductFacadeService.agentSessionToShoppingSession(AgentSessionManager.getSession());
    const recommendation: RecommendationResult = agentResponse.result.success && agentResponse.result.data.recommendation
      ? agentResponse.result.data.recommendation
      : ShoppingAgentOrchestrator.compareProducts(agentIntentToParsedIntent(agentResponse.intent));
    return RemoteDataMapper.ok<CompareBackendData>(agentResponse.result.message, {
      session: session,
      recommendation: recommendation
    });
  }

  static getDemoRecommendation(): RecommendationResult {
    const intent: ParsedIntent = ShoppingAgentOrchestrator.parseIntent('我想买一双不累脚的鞋');
    return ShoppingAgentOrchestrator.compareProducts(intent);
  }

  static selectProduct(productId: string): BackendResult<ShoppingSession> {
    const product: ProductCandidate | undefined = MockProductService.getProductById(productId);
    if (!product) {
      return RemoteDataMapper.fail<ShoppingSession>(BackendErrorCode.NotFound, '商品不存在');
    }
    const agentSession: AgentSession = AgentSessionManager.selectProduct(productId);
    const session: ShoppingSession = ProductFacadeService.agentSessionToShoppingSession(agentSession);
    return RemoteDataMapper.ok<ShoppingSession>('商品已选择', session);
  }

  static confirmSelectionByCommand(command: string, candidates: ProductCandidate[]): BackendResult<SelectionCommandBackendData> {
    if (candidates.length === 0) {
      return RemoteDataMapper.fail<SelectionCommandBackendData>(BackendErrorCode.NotFound, '暂无可选择商品');
    }
    const index: number = IntentEngine.extractProductIndex(command);
    if (index < 0 || index >= candidates.length) {
      return RemoteDataMapper.fail<SelectionCommandBackendData>(BackendErrorCode.ValidationError, '没有找到对应商品，请输入"买第一个"或"买第二个"。');
    }
    const quantity: number = IntentEngine.extractQuantity(command);
    const product: ProductCandidate = candidates[index];
    const agentSession: AgentSession = AgentSessionManager.selectProduct(product.id);
    const session: ShoppingSession = ProductFacadeService.agentSessionToShoppingSession(agentSession);
    return RemoteDataMapper.ok<SelectionCommandBackendData>('已识别选择指令', {
      product: product,
      quantity: quantity,
      session: session
    });
  }

  static parseIntent(query: string): ParsedIntent {
    return ShoppingAgentOrchestrator.parseIntent(query);
  }

  static async listProductsRemote(): Promise<BackendResult<ProductCandidate[]>> {
    const result: RemoteBackendResult = await RemoteBackendClient.listProducts();
    if (!result.success) {
      return ProductFacadeService.listProducts();
    }
    const parsed = RemoteDataMapper.parseProductList(result.body);
    if (!parsed || !parsed.products) {
      return ProductFacadeService.listProducts();
    }
    return RemoteDataMapper.ok<ProductCandidate[]>('已从 Spring 后端获取商品列表', parsed.products.map((item: RemoteProductItem) => RemoteDataMapper.mapRemoteProduct(item)));
  }

  static async getFeaturedProductsRemote(count: number): Promise<BackendResult<ProductCandidate[]>> {
    const result: BackendResult<ProductCandidate[]> = await ProductFacadeService.listProductsRemote();
    if (!result.data) {
      return result;
    }
    const safeCount: number = count > 0 ? count : 8;
    return RemoteDataMapper.ok<ProductCandidate[]>('已从 Spring 后端获取推荐商品', result.data.slice(0, safeCount));
  }

  static async getProductByIdRemote(productId: string): Promise<BackendResult<ProductCandidate>> {
    const result: RemoteBackendResult = await RemoteBackendClient.getProduct(productId);
    if (!result.success) {
      return ProductFacadeService.getProductById(productId);
    }
    const parsed = RemoteDataMapper.parseProductDetail(result.body);
    if (!parsed || !parsed.product) {
      return ProductFacadeService.getProductById(productId);
    }
    return RemoteDataMapper.ok<ProductCandidate>('已从 Spring 后端获取商品详情', RemoteDataMapper.mapRemoteProduct(parsed.product));
  }

  static async startCompareRemote(query: string): Promise<BackendResult<CompareBackendData>> {
    const normalized: string = query.trim();
    if (normalized.length === 0) {
      return RemoteDataMapper.fail<CompareBackendData>(BackendErrorCode.ValidationError, '请先输入想买的商品');
    }
    const result: RemoteBackendResult = await RemoteBackendClient.compareProducts(normalized);
    if (!result.success) {
      return ProductFacadeService.startCompare(query);
    }
    const parsed: RemoteCompareResponse | undefined = RemoteDataMapper.parseCompareResponse(result.body);
    if (!parsed || !parsed.recommendation) {
      return ProductFacadeService.startCompare(query);
    }
    const recommendation: RecommendationResult = RemoteDataMapper.mapRemoteRecommendation(parsed.recommendation);
    const agentSession2: AgentSession = AgentSessionManager.startShopping(normalized);
    const session: ShoppingSession = parsed.session ? parsed.session : ProductFacadeService.agentSessionToShoppingSession(agentSession2);
    return RemoteDataMapper.ok<CompareBackendData>(parsed.message ? parsed.message : '已从 Spring 后端生成比价推荐', {
      session: session,
      recommendation: recommendation
    });
  }

  static async confirmSelectionByCommandRemote(command: string, candidates: ProductCandidate[]): Promise<BackendResult<SelectionCommandBackendData>> {
    const result: RemoteBackendResult = await RemoteBackendClient.confirmSelectionCommand(command, candidates);
    if (!result.success) {
      return ProductFacadeService.confirmSelectionByCommand(command, candidates);
    }
    const parsed: RemoteSelectionResponse | undefined = RemoteDataMapper.parseSelectionResponse(result.body);
    if (!parsed || !parsed.product) {
      return ProductFacadeService.confirmSelectionByCommand(command, candidates);
    }
    const product: ProductCandidate = RemoteDataMapper.mapRemoteProduct(parsed.product);
    return RemoteDataMapper.ok<SelectionCommandBackendData>(parsed.message ? parsed.message : '已从 Spring 后端识别选择指令', {
      product: product,
      quantity: parsed.quantity ? parsed.quantity : 1,
      session: parsed.session ? parsed.session : ProductFacadeService.agentSessionToShoppingSession(AgentSessionManager.selectProduct(product.id))
    });
  }

  private static agentSessionToShoppingSession(agentSession: AgentSession): ShoppingSession {
    return {
      id: agentSession.id,
      status: AgentSessionManager.toShoppingSessionStatus(agentSession.status),
      query: agentSession.query,
      selectedProductId: agentSession.selectedProductId
    };
  }
}
