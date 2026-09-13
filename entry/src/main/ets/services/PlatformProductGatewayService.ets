import { MOCK_PRODUCTS } from '../mock/MockData';
import {
  PlatformAdapter,
  PlatformCode,
  PlatformDataSourceMode,
  PlatformProduct,
  PlatformSearchRequest,
  PlatformSearchResponse,
  ProductGatewayStatus
} from '../models/PlatformModels';
import { ProductCandidate } from '../models/ShoppingModels';
import { PublicProductApiAdapter } from './PublicProductApiAdapter';
import { PddApiAdapter } from './PddApiAdapter';
import { WanbangApiAdapter } from './WanbangApiAdapter';
import { PddApiConfig, WanbangApiConfig } from '../config/AppConfig';
import { CloneUtils } from '../utils/CloneUtils';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'PlatformProductGateway';
const DOMAIN: number = 0x0002;

interface ProductKeywordScore {
  product: PlatformProduct;
  score: number;
}

class LocalPlatformAdapter implements PlatformAdapter {
  platform: PlatformCode;
  platformName: string;
  private products: ProductCandidate[];

  constructor(platform: PlatformCode, platformName: string, products: ProductCandidate[]) {
    this.platform = platform;
    this.platformName = platformName;
    this.products = products.map((item: ProductCandidate) => CloneUtils.cloneProduct(item));
  }

  searchProducts(request: PlatformSearchRequest): PlatformProduct[] {
    const keyword = request.keyword.trim();
    const filtered = this.products.filter((item: ProductCandidate) => {
      const keywordMatched = keyword.length === 0 ||
        item.name.indexOf(keyword) >= 0 ||
        item.description.indexOf(keyword) >= 0 ||
        item.tags.some((tag: string) => keyword.indexOf(tag) >= 0 || tag.indexOf(keyword) >= 0);
      const categoryMatched = !request.category || item.tags.indexOf(request.category) >= 0 || item.name.indexOf(request.category) >= 0;
      const minMatched = request.minPrice === undefined || item.price >= request.minPrice;
      const maxMatched = request.maxPrice === undefined || item.price <= request.maxPrice;
      return keywordMatched && categoryMatched && minMatched && maxMatched;
    });
    return filtered.map((item: ProductCandidate) => this.toPlatformProduct(item));
  }

  getProductDetail(platformProductId: string): PlatformProduct | undefined {
    const found = this.products.find((item: ProductCandidate) => item.id === platformProductId);
    return found ? this.toPlatformProduct(found) : undefined;
  }

  buildPurchaseUrl(platformProductId: string): string {
    if (this.platform === PlatformCode.JD) {
      return `https://item.jd.com/${platformProductId}.html`;
    }
    if (this.platform === PlatformCode.PDD) {
      return `https://mobile.yangkeduo.com/goods.html?goods_id=${platformProductId}`;
    }
    return `https://item.taobao.com/item.htm?id=${platformProductId}`;
  }

  private toPlatformProduct(product: ProductCandidate): PlatformProduct {
    return {
      platform: this.platform,
      platformName: this.platformName,
      platformProductId: product.id,
      title: product.name,
      price: product.price,
      originalPrice: Math.round(product.price * 1.12),
      sales: product.sales,
      rating: product.rating,
      shopName: product.shopName,
      description: product.description,
      productUrl: this.buildPurchaseUrl(product.id),
      tags: product.tags.slice(),
      imageKey: product.imageKey,
      imageUrl: product.imageUrl
    };
  }
}

export class PlatformProductGatewayService {
  private static adapters: PlatformAdapter[] = [];
  private static publicProducts: PlatformProduct[] = [];
  private static lastSourceMode: PlatformDataSourceMode = PlatformDataSourceMode.Mock;

  private static pddApiProducts: PlatformProduct[] = [];
  private static wanbangProducts: PlatformProduct[] = [];

  static searchProducts(request: PlatformSearchRequest): PlatformSearchResponse {
    const safeRequest = PlatformProductGatewayService.normalizeRequest(request);
    let products: PlatformProduct[] = PlatformProductGatewayService.filterWanbangProducts(safeRequest);
    products = products.concat(PlatformProductGatewayService.filterPublicProducts(safeRequest));
    products = products.concat(PlatformProductGatewayService.filterPddApiProducts(safeRequest));
    PlatformProductGatewayService.getAdapters().forEach((adapter: PlatformAdapter) => {
      if (safeRequest.platforms.indexOf(adapter.platform) >= 0) {
        products = products.concat(adapter.searchProducts(safeRequest));
      }
    });
    products = PlatformProductGatewayService.sortProducts(products, safeRequest.sortBy);
    const start = Math.max(0, (safeRequest.page - 1) * safeRequest.pageSize);
    const end = start + safeRequest.pageSize;
    return {
      request: safeRequest,
      products: products.slice(start, end),
      sourceMode: PlatformProductGatewayService.lastSourceMode,
      message: PlatformProductGatewayService.lastSourceMode === PlatformDataSourceMode.PublicApi
        ? '已接入公开商品 API，同时保留淘宝、京东、拼多多官方接口适配器替换点。'
        : '当前使用淘宝、京东、拼多多模拟平台适配器；接入真实开放平台后替换适配器内部实现。'
    };
  }

  static async refreshProductsFromPublicApi(keyword: string, pageSize: number): Promise<PlatformSearchResponse> {
    const request = PlatformProductGatewayService.normalizeRequest({
      keyword: keyword,
      platforms: [PlatformCode.WanbangTaobao, PlatformCode.WanbangJD, PlatformCode.WanbangPdd, PlatformCode.PddOfficial, PlatformCode.PublicApi, PlatformCode.Taobao, PlatformCode.JD, PlatformCode.PDD],
      category: keyword.trim() !== '推荐' ? keyword : undefined,
      page: 1,
      pageSize: pageSize >= 10 ? pageSize : 10,
      sortBy: 'default'
    });

    if (WanbangApiConfig.enabled && !WanbangApiAdapter.isQuotaExhausted()) {
      const isCategorySearch: boolean = keyword.trim().length > 0 &&
        keyword.trim() !== '推荐' &&
        (WanbangApiConfig.categoryMap['taobao'][keyword.trim()] !== undefined ||
          PlatformProductGatewayService.categoryKeywordMap[keyword.trim()] !== undefined);

      if (isCategorySearch) {
        try {
          hilog.info(DOMAIN, TAG, `Wanbang category search: ${keyword}`);
          const wanbangResponse = await WanbangApiAdapter.searchByCategory(keyword.trim(), 1, pageSize);
          if (wanbangResponse.products.length > 0) {
            PlatformProductGatewayService.wanbangProducts = wanbangResponse.products;
            PlatformProductGatewayService.lastSourceMode = PlatformDataSourceMode.WanbangApi;
            hilog.info(DOMAIN, TAG, `Wanbang category OK, count=${wanbangResponse.products.length}`);
            return {
              request: request,
              products: wanbangResponse.products,
              sourceMode: PlatformDataSourceMode.WanbangApi,
              message: `已通过万邦 API 按「${keyword}」分类获取淘宝、京东、拼多多多平台商品数据`
            };
          }
        } catch (error) {
          hilog.error(DOMAIN, TAG, 'Wanbang category search failed');
        }
      }

      if (keyword.trim().length > 0 && keyword.trim() !== '推荐') {
        try {
          hilog.info(DOMAIN, TAG, `Wanbang all-platform search: ${keyword}`);
          const wanbangResponse = await WanbangApiAdapter.searchAllPlatforms(request);
          if (wanbangResponse.products.length > 0) {
            PlatformProductGatewayService.wanbangProducts = wanbangResponse.products;
            PlatformProductGatewayService.lastSourceMode = PlatformDataSourceMode.WanbangApi;
            hilog.info(DOMAIN, TAG, `Wanbang search OK, count=${wanbangResponse.products.length}`);
            return {
              request: request,
              products: wanbangResponse.products,
              sourceMode: PlatformDataSourceMode.WanbangApi,
              message: '已通过万邦 API 获取淘宝、京东、拼多多多平台商品数据'
            };
          }
        } catch (error) {
          hilog.error(DOMAIN, TAG, 'Wanbang all-platform search failed');
        }
      }

      const needRefresh: boolean = PlatformProductGatewayService.wanbangProducts.length === 0;
      if (needRefresh && keyword.trim() === '推荐') {
        const recommendKeywords: string[] = ['健康保健', '食品营养', '居家生活', '鞋服出行'];
        let allProducts: PlatformProduct[] = [];
        for (let ri: number = 0; ri < recommendKeywords.length; ri += 1) {
          try {
            const recResponse = await WanbangApiAdapter.searchByCategory(recommendKeywords[ri], 1, 10);
            if (recResponse.products.length > 0) {
              allProducts = allProducts.concat(recResponse.products);
            }
          } catch (error) {
            hilog.error(DOMAIN, TAG, `Wanbang recommend category ${recommendKeywords[ri]} failed`);
          }
        }
        if (allProducts.length > 0) {
          const seen: Set<string> = new Set();
          const unique: PlatformProduct[] = [];
          for (let i: number = 0; i < allProducts.length; i += 1) {
            const id: string = allProducts[i].platformProductId;
            if (!seen.has(id)) {
              seen.add(id);
              unique.push(allProducts[i]);
            }
          }
          PlatformProductGatewayService.wanbangProducts = unique;
          PlatformProductGatewayService.lastSourceMode = PlatformDataSourceMode.WanbangApi;
          hilog.info(DOMAIN, TAG, `Wanbang recommend total cached=${allProducts.length} unique=${unique.length}`);
          return {
            request: request,
            products: unique,
            sourceMode: PlatformDataSourceMode.WanbangApi,
            message: '已通过万邦 API 获取多平台推荐商品数据'
          };
        }
      }

      if (PlatformProductGatewayService.wanbangProducts.length > 0) {
        const filtered: PlatformProduct[] = PlatformProductGatewayService.filterProductsByKeyword(
          PlatformProductGatewayService.wanbangProducts, keyword);
        return {
          request: request,
          products: filtered,
          sourceMode: PlatformDataSourceMode.WanbangApi,
          message: '已通过万邦 API 获取多平台商品数据'
        };
      }
    }

    if (PddApiConfig.enabled) {
      const isCategorySearch: boolean = keyword.trim().length > 0 &&
        keyword.trim() !== '推荐' &&
        (PddApiAdapter.CATEGORY_OPT_ID_MAP[keyword.trim()] !== undefined ||
          PlatformProductGatewayService.categoryKeywordMap[keyword.trim()] !== undefined);

      if (isCategorySearch) {
        let allProducts: PlatformProduct[] = [];
        const expandedKeywords: string[] = PddApiAdapter.CATEGORY_KEYWORD_EXPAND[keyword.trim()] ||
          PlatformProductGatewayService.categoryKeywordMap[keyword.trim()] || [keyword.trim()];

        const needRefresh: boolean = PlatformProductGatewayService.pddApiProducts.length === 0;
        if (needRefresh) {
          hilog.info(DOMAIN, TAG, 'PDD category: loading recommend for filter, category=' + keyword);
          const channelTypes: number[] = [1, 0, 2, 6, 5, 8, 3, 4, 7, 9, 10, 12];
          for (let ci: number = 0; ci < channelTypes.length; ci += 1) {
            try {
              hilog.info(DOMAIN, TAG, 'PDD recommend channelType=' + channelTypes[ci]);
              const pageResp = await PddApiAdapter.getRecommendProducts(channelTypes[ci], 1, 50);
              if (pageResp.products.length > 0) {
                allProducts = allProducts.concat(pageResp.products);
              }
            } catch (error) {
              hilog.error(DOMAIN, TAG, 'PDD recommend channelType=' + channelTypes[ci] + ' failed');
            }
          }
          const seen: Set<string> = new Set();
          const unique: PlatformProduct[] = [];
          for (let i: number = 0; i < allProducts.length; i += 1) {
            const id: string = allProducts[i].platformProductId;
            if (!seen.has(id)) {
              seen.add(id);
              unique.push(allProducts[i]);
            }
          }
          PlatformProductGatewayService.pddApiProducts = unique;
          PlatformProductGatewayService.lastSourceMode = PlatformDataSourceMode.OfficialApiReady;
          hilog.info(DOMAIN, TAG, 'PDD recommend total cached=' + allProducts.length + ' unique=' + unique.length);
        }

        if (PlatformProductGatewayService.pddApiProducts.length > 0) {
          const filtered: PlatformProduct[] = PlatformProductGatewayService.filterProductsByCategory(
            PlatformProductGatewayService.pddApiProducts, keyword.trim(), expandedKeywords);
          hilog.info(DOMAIN, TAG, 'PDD category filter cached=' + PlatformProductGatewayService.pddApiProducts.length +
            ' filtered=' + filtered.length + ' category=' + keyword);
          if (filtered.length > 0) {
            return {
              request: request,
              products: filtered,
              sourceMode: PlatformDataSourceMode.OfficialApiReady,
              message: '已通过多多进宝推荐接口按分类获取拼多多商品数据'
            };
          }
        }
      }

      if (PddApiConfig.pid.length > 0 && keyword.trim().length > 0) {
        try {
          const pddResponse = await PddApiAdapter.searchProducts(request);
          if (pddResponse.products.length > 0) {
            PlatformProductGatewayService.pddApiProducts = pddResponse.products;
            PlatformProductGatewayService.lastSourceMode = PlatformDataSourceMode.OfficialApiReady;
            hilog.info(DOMAIN, TAG, 'PDD search OK, count=' + pddResponse.products.length);
            return {
              request: request,
              products: pddResponse.products,
              sourceMode: PlatformDataSourceMode.OfficialApiReady,
              message: '已通过多多进宝搜索接口获取拼多多商品数据'
            };
          }
        } catch (error) {
          hilog.error(DOMAIN, TAG, 'PDD search failed');
        }
      }

      const needRefresh: boolean = PlatformProductGatewayService.pddApiProducts.length === 0;
      if (needRefresh) {
        let allProducts: PlatformProduct[] = [];
        const channelTypes: number[] = [1, 0, 2, 6, 5, 8];
        for (let ci: number = 0; ci < channelTypes.length; ci += 1) {
          try {
            hilog.info(DOMAIN, TAG, 'PDD recommend channelType=' + channelTypes[ci]);
            const pageResp = await PddApiAdapter.getRecommendProducts(channelTypes[ci], 1, 20);
            if (pageResp.products.length > 0) {
              allProducts = allProducts.concat(pageResp.products);
            }
          } catch (error) {
            hilog.error(DOMAIN, TAG, 'PDD recommend channelType=' + channelTypes[ci] + ' failed');
          }
        }
        const seen: Set<string> = new Set();
        const unique: PlatformProduct[] = [];
        for (let i: number = 0; i < allProducts.length; i += 1) {
          const id: string = allProducts[i].platformProductId;
          if (!seen.has(id)) {
            seen.add(id);
            unique.push(allProducts[i]);
          }
        }
        PlatformProductGatewayService.pddApiProducts = unique;
        PlatformProductGatewayService.lastSourceMode = PlatformDataSourceMode.OfficialApiReady;
        hilog.info(DOMAIN, TAG, 'PDD recommend total cached=' + allProducts.length + ' unique=' + unique.length);
      }

      if (PlatformProductGatewayService.pddApiProducts.length > 0) {
        const filtered: PlatformProduct[] = PlatformProductGatewayService.filterProductsByKeyword(
          PlatformProductGatewayService.pddApiProducts, keyword);
        hilog.info(DOMAIN, TAG, 'PDD filter cached=' + PlatformProductGatewayService.pddApiProducts.length +
          ' filtered=' + filtered.length + ' keyword=' + keyword);
        return {
          request: request,
          products: filtered,
          sourceMode: PlatformDataSourceMode.OfficialApiReady,
          message: '已通过多多进宝推荐接口获取拼多多商品数据'
        };
      }
    }

    if (PlatformProductGatewayService.pddApiProducts.length > 0) {
      return PlatformProductGatewayService.searchProducts(request);
    }

    const apiKeyword = PlatformProductGatewayService.toApiKeyword(keyword);
    const apiRequest = PlatformProductGatewayService.normalizeRequest({
      keyword: apiKeyword,
      platforms: [PlatformCode.PublicApi],
      page: 1,
      pageSize: pageSize >= 10 ? pageSize : 10,
      sortBy: 'default'
    });

    try {
      const response = await PublicProductApiAdapter.searchProducts(apiRequest);
      if (response.products.length > 0) {
        PlatformProductGatewayService.publicProducts = response.products;
        PlatformProductGatewayService.lastSourceMode = PlatformDataSourceMode.PublicApi;
        return PlatformProductGatewayService.searchProducts(request);
      }
    } catch (error) {
      // Public API fails
    }

    return PlatformProductGatewayService.buildFallbackResponse(request, '商品 API 暂不可用，已降级为本地商品。');
  }

  static getAllCandidates(): ProductCandidate[] {
    const response = PlatformProductGatewayService.searchProducts({
      keyword: '',
      platforms: [PlatformCode.WanbangTaobao, PlatformCode.WanbangJD, PlatformCode.WanbangPdd, PlatformCode.PublicApi, PlatformCode.PddOfficial, PlatformCode.Taobao, PlatformCode.JD, PlatformCode.PDD],
      page: 1,
      pageSize: 100,
      sortBy: 'default'
    });
    return response.products.map((item: PlatformProduct) => PlatformProductGatewayService.toCandidate(item));
  }

  static getCandidateById(productId: string): ProductCandidate | undefined {
    const product = PlatformProductGatewayService.getProductDetail(productId);
    return product ? PlatformProductGatewayService.toCandidate(product) : undefined;
  }

  static getProductDetail(productId: string): PlatformProduct | undefined {
    const wanbangProduct = PlatformProductGatewayService.wanbangProducts.find((item: PlatformProduct) => item.platformProductId === productId);
    if (wanbangProduct) {
      return wanbangProduct;
    }
    const publicProduct = PlatformProductGatewayService.publicProducts.find((item: PlatformProduct) => item.platformProductId === productId);
    if (publicProduct) {
      return publicProduct;
    }
    const pddProduct = PlatformProductGatewayService.pddApiProducts.find((item: PlatformProduct) => item.platformProductId === productId);
    if (pddProduct) {
      return pddProduct;
    }
    const adapters = PlatformProductGatewayService.getAdapters();
    for (let index = 0; index < adapters.length; index += 1) {
      const product = adapters[index].getProductDetail(productId);
      if (product) {
        return product;
      }
    }
    return undefined;
  }

  static searchCandidates(keyword: string, pageSize: number): ProductCandidate[] {
    const response = PlatformProductGatewayService.searchProducts({
      keyword: keyword,
      platforms: [PlatformCode.WanbangTaobao, PlatformCode.WanbangJD, PlatformCode.WanbangPdd, PlatformCode.PublicApi, PlatformCode.PddOfficial, PlatformCode.Taobao, PlatformCode.JD, PlatformCode.PDD],
      page: 1,
      pageSize: pageSize,
      sortBy: 'default'
    });
    return response.products.map((item: PlatformProduct) => PlatformProductGatewayService.toCandidate(item));
  }

  static getStatus(): ProductGatewayStatus {
    if (PlatformProductGatewayService.lastSourceMode === PlatformDataSourceMode.WanbangApi) {
      return {
        sourceMode: PlatformDataSourceMode.WanbangApi,
        platforms: ['万邦聚合(淘宝+京东+拼多多)', '多多进宝', '公开API'],
        message: '已通过万邦 API 聚合平台接入淘宝、京东、拼多多多平台真实商品数据。'
      };
    }
    if (PlatformProductGatewayService.lastSourceMode === PlatformDataSourceMode.OfficialApiReady) {
      return {
        sourceMode: PlatformDataSourceMode.OfficialApiReady,
        platforms: ['多多进宝', '公开API', '淘宝', '京东', '拼多多'],
        message: '已接入多多进宝官方 API，拼多多商品数据来自真实接口；其他平台保留适配器替换点。'
      };
    }
    if (PlatformProductGatewayService.lastSourceMode === PlatformDataSourceMode.PublicApi) {
      return {
        sourceMode: PlatformDataSourceMode.PublicApi,
        platforms: ['公开商品API', '淘宝', '京东', '拼多多'],
        message: '商品数据已通过公开商品 API 获取并进入统一平台网关；三大平台官方接口仍保留适配器替换点。'
      };
    }
    return {
      sourceMode: PlatformDataSourceMode.Mock,
      platforms: ['淘宝', '京东', '拼多多'],
      message: '商品数据已通过统一平台网关返回，当前为本地模拟数据，接口已预留真实开放平台适配器。'
    };
  }

  static toCandidate(product: PlatformProduct): ProductCandidate {
    const candidate: ProductCandidate = {
      id: product.platformProductId,
      platform: product.platformName,
      name: product.title,
      price: product.price,
      originalPrice: product.originalPrice,
      rating: product.rating,
      sales: product.sales,
      shopName: product.shopName,
      description: product.description,
      tags: product.tags.slice(),
      recommendScore: 0,
      imageKey: product.imageKey,
      imageUrl: product.imageUrl
    };
    return candidate;
  }

  private static createAdapters(): PlatformAdapter[] {
    return [
      new LocalPlatformAdapter(PlatformCode.JD, '京东', PlatformProductGatewayService.filterByPlatform('京东')),
      new LocalPlatformAdapter(PlatformCode.Taobao, '淘宝', PlatformProductGatewayService.filterByPlatform('淘宝')),
      new LocalPlatformAdapter(PlatformCode.PDD, '拼多多', PlatformProductGatewayService.filterByPlatform('拼多多'))
    ];
  }

  private static getAdapters(): PlatformAdapter[] {
    if (PlatformProductGatewayService.adapters.length === 0) {
      PlatformProductGatewayService.adapters = PlatformProductGatewayService.createAdapters();
    }
    return PlatformProductGatewayService.adapters;
  }

  private static readonly categoryKeywordMap: Record<string, string[]> = {
    '推荐': [],
    '健康保健': ['保健', '血压', '血糖', '按摩', '理疗', '药', '养生', '护腰', '护膝', '体温', '制氧', '健康', '医疗', '艾灸', '拔罐', '加湿', '净化', '护理', '老人', '补钙', '关节', '腰椎', '颈椎', '磁疗', '足浴', '泡脚', '艾贴', '膏药', '眼罩', '护眼', '助听', '轮椅', '拐杖', '吸氧', '雾化', '监测', '血压计', '血糖仪', '体温计', '制氧机', '按摩椅', '按摩器', '足浴盆', '泡脚桶', '护颈', '护腕', '护踝', '理疗仪', '养生壶', '血压表', '测压', '热敷', '冷敷', '碘伏', '消毒', '纱布', '创可贴', '医用', '保健枕', '记忆棉', '乳胶枕', '护脊', '靠垫', '腰靠', '坐垫', '电热毯', '暖宫', '暖宝宝', '足贴', '退热贴', '口罩'],
    '食品营养': ['牛奶', '奶粉', '麦片', '杂粮', '蜂蜜', '核桃', '红枣', '枸杞', '芝麻', '糕点', '豆奶', '营养', '补钙', '维生素', '食品', '零食', '水果', '坚果', '酱', '醋', '米', '面', '油', '茶', '奶', '豆', '粮', '糖', '酥', '饼', '干', '橙', '苹', '橘', '柚', '桂圆', '花生', '瓜子', '肉', '肠', '鱼', '虾', '蛋', '粥', '汤', '饮', '酒', '咖啡', '可可', '参', '茸', '燕窝', '阿胶'],
    '居家生活': ['保温', '暖脚', '收纳', '清洁', '防滑', '坐垫', '被子', '枕头', '风扇', '电热水壶', '居家', '日用', '洗衣', '拖把', '纸巾', '毛巾', '牙刷', '厨', '锅', '碗', '杯', '垫', '毯', '枕', '被', '床', '椅', '凳', '架', '柜', '箱', '盆', '壶', '扫', '擦', '洗', '刷', '皂', '液', '袋', '桶', '盘', '碟', '勺', '筷', '炉', '灶', '灯', '电', '暖', '热', '帘', '窗', '门', '锁', '架', '贴', '胶', '修', '工', '器', '机', '水果', '美妆', '洗护', '个护', '日用', '家居'],
    '鞋服出行': ['鞋', '防滑', '棉服', '外套', '冲锋衣', '遮阳帽', '护膝', '手套', '围巾', '服', '裤', '衣', '帽', '袜', '羽绒', '毛呢', '裙', '衫', '袍', '背心', '凉鞋', '运动鞋', '棉鞋', '靴', '拖', '内衣', '打底', '针织', '毛线', '加绒', '加厚', '保暖', '透气', '宽松', '中老年', '女装']
  };

  private static filterProductsByKeyword(products: PlatformProduct[], keyword: string): PlatformProduct[] {
    const trimmed: string = keyword.trim();
    if (trimmed.length === 0 || trimmed === '推荐') {
      return products;
    }
    const keywords: string[] = PlatformProductGatewayService.categoryKeywordMap[trimmed] || [trimmed];
    const categoryNames: Record<string, string[]> = {
      '健康保健': ['医疗', '保健'],
      '食品营养': ['食品', '水果', '生鲜'],
      '居家生活': ['家居', '日用', '个护', '美妆', '洗护'],
      '鞋服出行': ['女装', '男装', '内衣', '鞋靴', '服饰']
    };
    const nameHits: string[] = categoryNames[trimmed] || [];
    const scored: ProductKeywordScore[] = products.map((item: PlatformProduct): ProductKeywordScore => {
      let score: number = 0;
      const text: string = item.title + ' ' + item.description + ' ' + item.tags.join(' ');
      for (let i: number = 0; i < keywords.length; i += 1) {
        if (text.indexOf(keywords[i]) >= 0) {
          score += 10;
        }
      }
      for (let i: number = 0; i < nameHits.length; i += 1) {
        if (text.indexOf(nameHits[i]) >= 0) {
          score += 8;
        }
      }
      for (let i: number = 0; i < nameHits.length; i += 1) {
        for (let j: number = 0; j < item.tags.length; j += 1) {
          if (item.tags[j].indexOf(nameHits[i]) >= 0) {
            score += 6;
            break;
          }
        }
      }
      if (item.price < 50) {
        score += 3;
      }
      if (item.tags.indexOf('有券') >= 0) {
        score += 2;
      }
      return { product: item, score: score };
    });
    scored.sort((a: ProductKeywordScore, b: ProductKeywordScore) => b.score - a.score);
    const matched: PlatformProduct[] = scored.filter((item: ProductKeywordScore) => item.score > 9)
      .map((item: ProductKeywordScore) => item.product);
    if (matched.length >= 4) {
      return matched;
    }
    return scored.slice(0, Math.max(8, matched.length))
      .map((item: ProductKeywordScore) => item.product);
  }

  private static filterProductsByCategory(products: PlatformProduct[], category: string,
    expandedKeywords: string[]): PlatformProduct[] {
    const scored: ProductKeywordScore[] = products.map((item: PlatformProduct): ProductKeywordScore => {
      let score: number = 0;
      const text: string = item.title + ' ' + item.description + ' ' + item.tags.join(' ');
      for (let i: number = 0; i < expandedKeywords.length; i += 1) {
        if (text.indexOf(expandedKeywords[i]) >= 0) {
          score += 10;
        }
      }
      for (let i: number = 0; i < item.tags.length; i += 1) {
        for (let j: number = 0; j < expandedKeywords.length; j += 1) {
          if (item.tags[i].indexOf(expandedKeywords[j]) >= 0 || expandedKeywords[j].indexOf(item.tags[i]) >= 0) {
            score += 8;
            break;
          }
        }
      }
      if (item.price < 50) {
        score += 3;
      }
      if (item.tags.indexOf('有券') >= 0) {
        score += 2;
      }
      return { product: item, score: score };
    });
    scored.sort((a: ProductKeywordScore, b: ProductKeywordScore) => b.score - a.score);
    const matched: PlatformProduct[] = scored.filter((item: ProductKeywordScore) => item.score > 9)
      .map((item: ProductKeywordScore) => item.product);
    if (matched.length >= 4) {
      return matched;
    }
    return scored.slice(0, Math.max(8, matched.length))
      .map((item: ProductKeywordScore) => item.product);
  }

  private static filterByPlatform(platformName: string): ProductCandidate[] {
    return MOCK_PRODUCTS.filter((item: ProductCandidate) => item.platform === platformName || item.platform.indexOf(platformName) >= 0);
  }

  private static filterPublicProducts(request: PlatformSearchRequest): PlatformProduct[] {
    if (PlatformProductGatewayService.publicProducts.length === 0 || request.platforms.indexOf(PlatformCode.PublicApi) < 0) {
      return [];
    }
    const keyword = request.keyword.trim();
    return PlatformProductGatewayService.publicProducts.filter((item: PlatformProduct) => {
      const keywordMatched = keyword.length === 0 ||
        item.title.indexOf(keyword) >= 0 ||
        item.description.indexOf(keyword) >= 0 ||
        item.tags.some((tag: string) => keyword.indexOf(tag) >= 0 || tag.indexOf(keyword) >= 0);
      const categoryMatched = !request.category || item.tags.indexOf(request.category) >= 0 || item.title.indexOf(request.category) >= 0;
      const minMatched = request.minPrice === undefined || item.price >= request.minPrice;
      const maxMatched = request.maxPrice === undefined || item.price <= request.maxPrice;
      return keywordMatched && categoryMatched && minMatched && maxMatched;
    });
  }

  private static filterWanbangProducts(request: PlatformSearchRequest): PlatformProduct[] {
    if (PlatformProductGatewayService.wanbangProducts.length === 0) {
      return [];
    }
    const wanbangCodes: PlatformCode[] = [PlatformCode.WanbangTaobao, PlatformCode.WanbangJD, PlatformCode.WanbangPdd];
    const hasWanbang: boolean = request.platforms.some((p: PlatformCode) => wanbangCodes.indexOf(p) >= 0);
    if (!hasWanbang) {
      return [];
    }
    const keyword = request.keyword.trim();
    if (keyword.length === 0 || keyword === '推荐') {
      return PlatformProductGatewayService.wanbangProducts;
    }
    return PlatformProductGatewayService.wanbangProducts.filter((item: PlatformProduct) => {
      const keywordMatched = keyword.length === 0 ||
        item.title.indexOf(keyword) >= 0 ||
        item.description.indexOf(keyword) >= 0 ||
        item.tags.some((tag: string) => keyword.indexOf(tag) >= 0 || tag.indexOf(keyword) >= 0);
      const minMatched = request.minPrice === undefined || item.price >= request.minPrice;
      const maxMatched = request.maxPrice === undefined || item.price <= request.maxPrice;
      return keywordMatched && minMatched && maxMatched;
    });
  }

  private static filterPddApiProducts(request: PlatformSearchRequest): PlatformProduct[] {
    if (PlatformProductGatewayService.pddApiProducts.length === 0 || request.platforms.indexOf(PlatformCode.PddOfficial) < 0) {
      return [];
    }
    const keyword = request.keyword.trim();
    if (keyword.length === 0 || keyword === '推荐') {
      return PlatformProductGatewayService.pddApiProducts;
    }
    return PlatformProductGatewayService.pddApiProducts.filter((item: PlatformProduct) => {
      const keywordMatched = keyword.length === 0 ||
        item.title.indexOf(keyword) >= 0 ||
        item.description.indexOf(keyword) >= 0 ||
        item.tags.some((tag: string) => keyword.indexOf(tag) >= 0 || tag.indexOf(keyword) >= 0);
      const minMatched = request.minPrice === undefined || item.price >= request.minPrice;
      const maxMatched = request.maxPrice === undefined || item.price <= request.maxPrice;
      return keywordMatched && minMatched && maxMatched;
    });
  }

  private static buildFallbackResponse(request: PlatformSearchRequest, message: string): PlatformSearchResponse {
    const response = PlatformProductGatewayService.searchProducts(request);
    return {
      request: response.request,
      products: response.products,
      sourceMode: PlatformDataSourceMode.Mock,
      message: message
    };
  }

  private static normalizeRequest(request: PlatformSearchRequest): PlatformSearchRequest {
    return {
      keyword: request.keyword,
      platforms: request.platforms.length > 0 ? request.platforms : [PlatformCode.WanbangTaobao, PlatformCode.WanbangJD, PlatformCode.WanbangPdd, PlatformCode.PublicApi, PlatformCode.PddOfficial, PlatformCode.Taobao, PlatformCode.JD, PlatformCode.PDD],
      category: request.category,
      minPrice: request.minPrice,
      maxPrice: request.maxPrice,
      sortBy: request.sortBy ? request.sortBy : 'default',
      page: request.page > 0 ? request.page : 1,
      pageSize: request.pageSize > 0 ? request.pageSize : 20
    };
  }

  private static sortProducts(products: PlatformProduct[], sortBy?: string): PlatformProduct[] {
    const cloned = products.slice();
    if (sortBy === 'price') {
      return cloned.sort((left: PlatformProduct, right: PlatformProduct) => left.price - right.price);
    }
    if (sortBy === 'sales') {
      return cloned.sort((left: PlatformProduct, right: PlatformProduct) => right.sales - left.sales);
    }
    if (sortBy === 'rating') {
      return cloned.sort((left: PlatformProduct, right: PlatformProduct) => right.rating - left.rating);
    }
    return cloned.sort((left: PlatformProduct, right: PlatformProduct) => {
      const leftScore = PlatformProductGatewayService.calculateDisplayScore(left);
      const rightScore = PlatformProductGatewayService.calculateDisplayScore(right);
      return rightScore - leftScore;
    });
  }

  private static calculateDisplayScore(product: PlatformProduct): number {
    const priceScore = Math.max(0, 100 - product.price / 4);
    const ratingScore = product.rating * 20;
    const salesScore = Math.min(100, product.sales / 800);
    return Math.round(priceScore * 0.5 + ratingScore * 0.3 + salesScore * 0.2);
  }

  private static toApiKeyword(keyword: string): string {
    const chineseToEnglish: Record<string, string> = {
      '推荐': 'top',
      '健康监测': 'health monitor',
      '血压计': 'blood pressure monitor',
      '营养食品': 'nutrition food',
      '无糖奶粉': 'sugar free milk',
      '鞋服出行': 'shoes',
      '不累脚的鞋': 'comfortable shoes',
      '手机数码': 'phone',
      '大按键手机': 'senior phone',
      '家电': 'home appliance',
      '护肤': 'skincare',
      '食品': 'food',
      '服装': 'clothing',
      '运动': 'sport',
      '家居': 'home',
      '数码': 'digital',
      '母婴': 'baby',
      '图书': 'book'
    };
    if (chineseToEnglish[keyword] !== undefined) {
      return chineseToEnglish[keyword];
    }
    if (/^[\u4e00-\u9fa5]+$/.test(keyword)) {
      return '';
    }
    return keyword;
  }
}
