import { http } from '@kit.NetworkKit';
import {
  PlatformCode,
  PlatformDataSourceMode,
  PlatformProduct,
  PlatformSearchRequest,
  PlatformSearchResponse
} from '../models/PlatformModels';
import { WanbangApiConfig } from '../config/AppConfig';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'WanbangApiAdapter';
const DOMAIN: number = 0x0002;

interface WanbangSearchItem {
  title: string;
  pic_url: string;
  price: string | number;
  orginal_price?: string | number;
  promotion_price?: string | number;
  sales?: number;
  num_iid: string | number;
  detail_url: string;
  shop_id?: number | string;
  reviews?: string;
  nick?: string;
  shop_name?: string;
}

interface WanbangSearchItems {
  page: string;
  real_total_results: number;
  total_results: number;
  page_size: number;
  pagecount: number;
  item: WanbangSearchItem[];
}

interface WanbangSearchResponse {
  items?: WanbangSearchItems;
  error_code: string;
  reason: string;
  error: string;
  api_type: string;
}

export class WanbangApiAdapter {
  static readonly PLATFORM_NAMES: Record<string, string> = {
    'taobao': '淘宝',
    'jd': '京东',
    'pdd': '拼多多'
  };

  static readonly PLATFORM_CODES: Record<string, PlatformCode> = {
    'taobao': PlatformCode.WanbangTaobao,
    'jd': PlatformCode.WanbangJD,
    'pdd': PlatformCode.WanbangPdd
  };

  private static quotaExhausted: boolean = false;

  static isQuotaExhausted(): boolean {
    return WanbangApiAdapter.quotaExhausted;
  }

  static async searchProducts(
    request: PlatformSearchRequest,
    apiPlatform: string
  ): Promise<PlatformSearchResponse> {
    if (!WanbangApiConfig.enabled || WanbangApiAdapter.quotaExhausted) {
      return {
        request: request,
        products: [],
        sourceMode: PlatformDataSourceMode.Mock,
        message: '万邦 API 未启用'
      };
    }

    const safeKeyword: string = request.keyword.trim();
    if (safeKeyword.length === 0) {
      return {
        request: request,
        products: [],
        sourceMode: PlatformDataSourceMode.WanbangApi,
        message: '搜索关键词不能为空'
      };
    }

    const safePageSize: number = request.pageSize >= 10 ? request.pageSize : 20;
    const platformName: string = WanbangApiAdapter.PLATFORM_NAMES[apiPlatform] || apiPlatform;
    const platformCode: PlatformCode = WanbangApiAdapter.PLATFORM_CODES[apiPlatform] || PlatformCode.WanbangTaobao;

    const params: Record<string, string> = {
      'key': WanbangApiConfig.apiKey,
      'secret': WanbangApiConfig.apiSecret,
      'q': safeKeyword,
      'page': request.page.toString(),
      'page_size': safePageSize.toString(),
      'cat': '0',
      'start_price': request.minPrice !== undefined ? request.minPrice.toString() : '0',
      'end_price': request.maxPrice !== undefined ? request.maxPrice.toString() : '0',
      'cache': 'yes',
      'result_type': 'json',
      'lang': 'cn'
    };

    if (request.sortBy && request.sortBy !== 'default') {
      if (request.sortBy === 'price') {
        params['sort'] = '_bid2';
      } else if (request.sortBy === 'sales') {
        params['sort'] = '_sale';
      }
    }

    const queryString: string = WanbangApiAdapter.buildQueryString(params);
    const apiUrl: string = `${WanbangApiConfig.baseUrl}/${apiPlatform}/item_search/?${queryString}`;

    hilog.info(DOMAIN, TAG, `Searching ${apiPlatform}: keyword=${safeKeyword} page=${request.page}`);

    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(apiUrl, {
        method: http.RequestMethod.GET,
        readTimeout: 15000,
        connectTimeout: 15000,
        header: {
          'Content-Type': 'application/json',
          'Accept-Encoding': 'gzip',
          'Connection': 'keep-alive'
        }
      });
      const body: string = `${response.result}`;
      let parsed: WanbangSearchResponse;
      try {
        parsed = JSON.parse(body) as WanbangSearchResponse;
      } catch (error) {
        hilog.error(DOMAIN, TAG, `JSON parse failed for ${apiPlatform}`);
        return {
          request: request,
          products: [],
          sourceMode: PlatformDataSourceMode.WanbangApi,
          message: `万邦 ${platformName} API 返回解析失败`
        };
      }

      if (parsed.error_code !== '0000' && parsed.error_code !== '2000') {
        hilog.error(DOMAIN, TAG, `Wanbang ${apiPlatform} error: ${parsed.error} code=${parsed.error_code}`);
        if (parsed.error_code === '4013' || parsed.error_code === '4016') {
          WanbangApiAdapter.quotaExhausted = true;
          hilog.error(DOMAIN, TAG, 'Wanbang API quota exhausted, will skip further calls');
        }
        return {
          request: request,
          products: [],
          sourceMode: PlatformDataSourceMode.WanbangApi,
          message: `万邦 ${platformName} API 报错: ${parsed.error}`
        };
      }

      if (!parsed.items || !parsed.items.item || parsed.items.item.length === 0) {
        hilog.info(DOMAIN, TAG, `Wanbang ${apiPlatform} no results for: ${safeKeyword}`);
        return {
          request: request,
          products: [],
          sourceMode: PlatformDataSourceMode.WanbangApi,
          message: `万邦 ${platformName} 暂无商品数据`
        };
      }

      const products: PlatformProduct[] = parsed.items.item.map(
        (item: WanbangSearchItem) => WanbangApiAdapter.toPlatformProduct(item, apiPlatform, platformCode, platformName)
      );

      hilog.info(DOMAIN, TAG, `Wanbang ${apiPlatform} search OK, count=${products.length}`);
      return {
        request: request,
        products: products,
        sourceMode: PlatformDataSourceMode.WanbangApi,
        message: `已通过万邦 API 获取${platformName}商品数据`
      };
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Wanbang ${apiPlatform} request failed`);
      return {
        request: request,
        products: [],
        sourceMode: PlatformDataSourceMode.WanbangApi,
        message: `万邦 ${platformName} API 网络请求失败`
      };
    } finally {
      httpRequest.destroy();
    }
  }

  static async searchAllPlatforms(
    request: PlatformSearchRequest
  ): Promise<PlatformSearchResponse> {
    if (!WanbangApiConfig.enabled || WanbangApiAdapter.quotaExhausted) {
      return {
        request: request,
        products: [],
        sourceMode: PlatformDataSourceMode.Mock,
        message: '万邦 API 未启用'
      };
    }

    const safeKeyword: string = request.keyword.trim();
    if (safeKeyword.length === 0) {
      return {
        request: request,
        products: [],
        sourceMode: PlatformDataSourceMode.WanbangApi,
        message: '搜索关键词不能为空'
      };
    }

    let allProducts: PlatformProduct[] = [];
    const platforms: string[] = WanbangApiConfig.platforms;
    const errors: string[] = [];

    for (let i: number = 0; i < platforms.length; i += 1) {
      const apiPlatform: string = platforms[i];
      try {
        const result: PlatformSearchResponse = await WanbangApiAdapter.searchProducts(request, apiPlatform);
        if (result.products.length > 0) {
          allProducts = allProducts.concat(result.products);
        }
      } catch (error) {
        errors.push(apiPlatform);
      }
    }

    if (allProducts.length === 0) {
      return {
        request: request,
        products: [],
        sourceMode: PlatformDataSourceMode.WanbangApi,
        message: errors.length > 0
          ? `万邦 API 全平台搜索失败: ${errors.join(',')}`
          : '万邦 API 全平台暂无商品数据'
      };
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

    hilog.info(DOMAIN, TAG, `Wanbang all platforms total=${allProducts.length} unique=${unique.length}`);
    return {
      request: request,
      products: unique,
      sourceMode: PlatformDataSourceMode.WanbangApi,
      message: `已通过万邦 API 获取淘宝、京东、拼多多多平台商品数据，共${unique.length}件`
    };
  }

  static async searchByCategory(
    category: string,
    page: number,
    pageSize: number
  ): Promise<PlatformSearchResponse> {
    if (!WanbangApiConfig.enabled || WanbangApiAdapter.quotaExhausted) {
      return {
        request: { keyword: category, platforms: [], page: page, pageSize: pageSize },
        products: [],
        sourceMode: PlatformDataSourceMode.Mock,
        message: '万邦 API 未启用'
      };
    }

    let allProducts: PlatformProduct[] = [];
    const platforms: string[] = WanbangApiConfig.platforms;

    for (let i: number = 0; i < platforms.length; i += 1) {
      const apiPlatform: string = platforms[i];
      const categoryKeywords: Record<string, string> = WanbangApiConfig.categoryMap[apiPlatform];
      if (!categoryKeywords) {
        continue;
      }
      const keywords: string = categoryKeywords[category];
      if (!keywords || keywords.length === 0) {
        continue;
      }

      const keywordList: string[] = keywords.split(' ');
      const searchKeyword: string = keywordList[0];

      const request: PlatformSearchRequest = {
        keyword: searchKeyword,
        platforms: [WanbangApiAdapter.PLATFORM_CODES[apiPlatform]],
        category: category,
        page: page,
        pageSize: pageSize >= 10 ? pageSize : 20,
        sortBy: 'default'
      };

      try {
        const result: PlatformSearchResponse = await WanbangApiAdapter.searchProducts(request, apiPlatform);
        if (result.products.length > 0) {
          allProducts = allProducts.concat(result.products);
        }
      } catch (error) {
        hilog.error(DOMAIN, TAG, `Wanbang category search failed for ${apiPlatform}`);
      }
    }

    if (allProducts.length === 0) {
      const fallbackRequest: PlatformSearchRequest = {
        keyword: category,
        platforms: [],
        page: page,
        pageSize: pageSize
      };
      return WanbangApiAdapter.searchAllPlatforms(fallbackRequest);
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

    return {
      request: { keyword: category, platforms: [], page: page, pageSize: pageSize },
      products: unique,
      sourceMode: PlatformDataSourceMode.WanbangApi,
      message: `已通过万邦 API 按「${category}」分类获取多平台商品数据，共${unique.length}件`
    };
  }

  private static toPlatformProduct(
    item: WanbangSearchItem,
    apiPlatform: string,
    platformCode: PlatformCode,
    platformName: string
  ): PlatformProduct {
    const price: number = typeof item.price === 'number'
      ? item.price
      : parseFloat(item.price) || 0;
    const originalPrice: number = WanbangApiAdapter.parseOriginalPrice(item);
    const sales: number = item.sales || 0;
    const picUrl: string = item.pic_url || '';
    const fullPicUrl: string = picUrl.startsWith('//')
      ? `https:${picUrl}`
      : picUrl;
    const numIid: string = typeof item.num_iid === 'number'
      ? item.num_iid.toString()
      : item.num_iid;
    const shopName: string = item.nick || item.shop_name || `${platformName}店铺`;

    return {
      platform: platformCode,
      platformName: platformName,
      platformProductId: `wb-${apiPlatform}-${numIid}`,
      title: item.title || '',
      price: Math.round(price * 100) / 100,
      originalPrice: originalPrice > 0 ? Math.round(originalPrice * 100) / 100 : undefined,
      sales: sales,
      rating: 4.5,
      shopName: shopName,
      description: item.title || '',
      productUrl: item.detail_url || '',
      tags: [platformName],
      imageUrl: fullPicUrl.length > 0 ? fullPicUrl : undefined
    };
  }

  private static parseOriginalPrice(item: WanbangSearchItem): number {
    if (item.orginal_price !== undefined && item.orginal_price !== null) {
      const val: number = typeof item.orginal_price === 'number'
        ? item.orginal_price
        : parseFloat(item.orginal_price);
      if (!isNaN(val) && val > 0) {
        return val;
      }
    }
    if (item.promotion_price !== undefined && item.promotion_price !== null) {
      const val: number = typeof item.promotion_price === 'number'
        ? item.promotion_price
        : parseFloat(item.promotion_price);
      if (!isNaN(val) && val > 0) {
        return val;
      }
    }
    return 0;
  }

  private static buildQueryString(params: Record<string, string>): string {
    const parts: string[] = [];
    const keys: string[] = Object.keys(params);
    for (let i: number = 0; i < keys.length; i += 1) {
      const key: string = keys[i];
      parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(params[key]));
    }
    return parts.join('&');
  }
}
