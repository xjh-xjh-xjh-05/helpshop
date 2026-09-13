import { http } from '@kit.NetworkKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import {
  PlatformCode,
  PlatformDataSourceMode,
  PlatformProduct,
  PlatformSearchRequest,
  PlatformSearchResponse
} from '../models/PlatformModels';
import { PddApiConfig } from '../config/AppConfig';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'PddApiAdapter';
const DOMAIN: number = 0x0002;

interface PddGoodsItem {
  goods_id: number;
  goods_name: string;
  goods_desc: string;
  min_group_price: number;
  min_normal_price: number;
  mall_name: string;
  sales_tip: string;
  cnt: number;
  category_id: number;
  category_name: string;
  goods_thumbnail_url: string;
  goods_image_url: string;
  goods_gallery_urls: string[];
  coupon_discount: number;
  coupon_min_order_amount: number;
  coupon_total_quantity: number;
  coupon_remain_quantity: number;
  opt_id: number;
  opt_name: string;
  search_id: string;
  list_id: string;
  mall_id: number;
}

interface PddSearchResponse {
  goods_list: PddGoodsItem[];
  total_count: number;
  search_id: string;
  list_id: string;
}

interface PddApiError {
  error_code: number;
  error_msg: string;
  sub_msg: string;
  request_id: string;
}

interface PddSearchApiResult {
  goods_search_response: PddSearchResponse;
  request_id: string;
}

interface PddApiSearchResponse {
  error_response?: PddApiError;
  pdd_ddk_goods_search_response?: PddSearchApiResult;
}

interface PddDetailApiResult {
  goods_details: PddGoodsItem[];
  request_id: string;
}

interface PddDetailApiResponse {
  goods_detail_response: PddDetailApiResult;
  request_id: string;
}

interface PddApiDetailResponse {
  error_response?: PddApiError;
  pdd_ddk_goods_detail_response?: PddDetailApiResponse;
}

interface PddTokenResult {
  access_token: string;
  token_type: string;
  expires_in: number;
  refresh_token: string;
  owner_name: string;
  owner_id: string;
  request_id: string;
}

interface PddTokenResponse {
  error_response?: PddApiError;
  pdd_pop_auth_token_create_response?: PddTokenResult;
}

interface PddGoodsListItem {
  goods_id: number;
  goods_name: string;
  goods_desc: string;
  cat_id: number;
  thumb_url: string;
  goods_img_url: string;
  gallery_urls: string[];
  min_normal_price: number;
  min_group_price: number;
  market_price: number;
  sales_tip: string;
  mall_name: string;
  mall_id: number;
  coupon_discount: number;
  coupon_min_order_amount: number;
  coupon_total_quantity: number;
  coupon_remain_quantity: number;
}

interface PddGoodsListResponse {
  goods_list: PddGoodsListItem[];
  total_count: number;
  has_next: boolean;
  request_id: string;
}

interface PddApiGoodsListResponse {
  error_response?: PddApiError;
  pdd_goods_list_get_response?: PddGoodsListResponse;
}

interface PddSkuPriceItem {
  sku_id: number;
  price: number;
  normal_price: number;
  group_price: number;
  spec: string;
  quantity: number;
}

interface PddGoodsDetailItem {
  goods_id: number;
  goods_name: string;
  goods_desc: string;
  cat_id: number;
  thumb_url: string;
  goods_img_url: string;
  gallery_urls: string[];
  sku_price_list: PddSkuPriceItem[];
  min_normal_price: number;
  min_group_price: number;
  market_price: number;
  sales_tip: string;
  mall_name: string;
  mall_id: number;
  coupon_discount: number;
  coupon_min_order_amount: number;
  has_coupon: boolean;
}

interface PddGoodsDetailResponse {
  goods_detail: PddGoodsDetailItem;
  request_id: string;
}

interface PddApiGoodsDetailResponse {
  error_response?: PddApiError;
  pdd_goods_detail_get_response?: PddGoodsDetailResponse;
}

interface PddCatItem {
  cat_id: number;
  cat_name: string;
  level: number;
  parent_cat_id: number;
  children?: PddCatItem[];
}

interface PddCatListResponse {
  cat_list: PddCatItem[];
  request_id: string;
}

interface PddApiCatListResponse {
  error_response?: PddApiError;
  pdd_goods_cat_list_get_response?: PddCatListResponse;
}

interface PddImageItem {
  goods_id: number;
  goods_img_url: string;
  gallery_urls: string[];
  thumb_url: string;
}

interface PddImageResponse {
  image_list: PddImageItem[];
  request_id: string;
}

interface PddApiImageResponse {
  error_response?: PddApiError;
  pdd_goods_image_get_response?: PddImageResponse;
}

interface PddRecommendItem {
  goods_id: number;
  goods_name: string;
  goods_desc: string;
  category_id: string;
  category_name: string;
  opt_id: string;
  opt_name: string;
  goods_image_url: string;
  goods_thumbnail_url: string;
  min_normal_price: number;
  min_group_price: number;
  coupon_discount: number;
  coupon_min_order_amount: number;
  coupon_total_quantity: number;
  coupon_remain_quantity: number;
  sales_tip: string;
  mall_name: string;
  has_coupon: boolean;
  goods_sign: string;
}

interface PddRecommendListResponse {
  total: number;
  list: PddRecommendItem[];
  search_id: string;
  request_id: string;
}

interface PddApiRecommendResponse {
  error_response?: PddApiError;
  goods_basic_detail_response?: PddRecommendListResponse;
}

export class PddApiAdapter {
  private static accessToken: string = '';
  private static tokenExpireTime: number = 0;
  private static cachedCatList: PddCatItem[] = [];
  private static catListLoaded: boolean = false;

  static readonly CATEGORY_OPT_ID_MAP: Record<string, string> = {
    '健康保健': '1342',
    '食品营养': '4',
    '居家生活': '15',
    '鞋服出行': '1',
    '母婴': '16',
    '数码家电': '18',
    '美妆个护': '8',
    '图书文具': '30',
    '运动户外': '10',
    '汽车用品': '23',
    '家装建材': '14',
    '珠宝配饰': '25',
    '宠物': '588',
    '农资园艺': '29'
  };

  static async ensureAccessToken(): Promise<string> {
    if (PddApiAdapter.accessToken.length > 0 && Date.now() < PddApiAdapter.tokenExpireTime) {
      return PddApiAdapter.accessToken;
    }
    const timestamp: number = Math.floor(Date.now() / 1000);
    const params: Record<string, string> = {
      'type': 'pdd.pop.auth.token.create',
      'client_id': PddApiConfig.clientId,
      'timestamp': timestamp.toString(),
      'grant_type': 'authorization_code',
      'code': PddApiConfig.clientSecret
    };
    const sign: string = PddApiAdapter.generateSign(params);
    params['sign'] = sign;
    const queryString: string = PddApiAdapter.buildQueryString(params);
    const apiUrl: string = PddApiConfig.baseUrl + '?' + queryString;
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(apiUrl, {
        method: http.RequestMethod.GET,
        readTimeout: 10000,
        connectTimeout: 10000,
        header: { 'Content-Type': 'application/json' }
      });
      const body: string = `${response.result}`;
      hilog.info(DOMAIN, TAG, 'token response: ' + body.substring(0, 300));
      const parsed: PddTokenResponse = JSON.parse(body) as PddTokenResponse;
      if (parsed.error_response) {
        hilog.error(DOMAIN, TAG, 'token error: ' + parsed.error_response.error_msg);
        return '';
      }
      const tokenResult: PddTokenResult | undefined = parsed.pdd_pop_auth_token_create_response;
      if (tokenResult && tokenResult.access_token && tokenResult.access_token.length > 0) {
        PddApiAdapter.accessToken = tokenResult.access_token;
        PddApiAdapter.tokenExpireTime = Date.now() + (tokenResult.expires_in > 0 ? (tokenResult.expires_in - 60) * 1000 : 3600000);
        hilog.info(DOMAIN, TAG, 'Access token obtained');
        return PddApiAdapter.accessToken;
      }
      hilog.error(DOMAIN, TAG, 'Access token empty in response');
      return '';
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Access token request failed');
      return '';
    } finally {
      httpRequest.destroy();
    }
  }

  static async searchProducts(request: PlatformSearchRequest): Promise<PlatformSearchResponse> {
    const optId: string | undefined = request.category
      ? PddApiAdapter.resolveOptId(request.category)
      : undefined;
    return PddApiAdapter.doSearch(request, optId);
  }

  static readonly CATEGORY_KEYWORD_EXPAND: Record<string, string[]> = {
    '健康保健': ['血压计', '按摩器', '足浴盆', '血糖仪', '制氧机', '理疗仪', '护膝', '护腰', '养生壶', '体温计', '艾灸', '拔罐', '助听器', '轮椅', '拐杖', '雾化器', '健康', '保健'],
    '食品营养': ['牛奶', '奶粉', '麦片', '蜂蜜', '红枣', '枸杞', '核桃', '杂粮', '糕点', '豆奶', '营养', '维生素', '零食', '水果'],
    '居家生活': ['保温杯', '收纳', '清洁', '防滑垫', '坐垫', '被子', '枕头', '电热水壶', '风扇', '暖脚', '拖把', '纸巾', '厨具', '锅', '灯'],
    '鞋服出行': ['老人鞋', '防滑鞋', '棉服', '外套', '冲锋衣', '围巾', '手套', '棉鞋', '运动鞋', '加绒', '保暖', '中老年', '女装'],
    '母婴': ['奶粉', '纸尿裤', '辅食', '童装', '玩具'],
    '数码家电': ['手机', '平板', '电视', '洗衣机', '冰箱', '空调', '耳机'],
    '美妆个护': ['面膜', '洗面奶', '防晒', '洗发水', '沐浴露', '牙膏'],
    '图书文具': ['书', '笔', '笔记本', '文具'],
    '运动户外': ['跑步鞋', '瑜伽垫', '哑铃', '帐篷', '登山杖'],
    '汽车用品': ['车载', '行车记录仪', '坐垫', '脚垫'],
    '家装建材': ['灯', '开关', '水龙头', '瓷砖', '地板'],
    '珠宝配饰': ['项链', '手镯', '耳环', '戒指', '玉'],
    '宠物': ['猫粮', '狗粮', '猫砂', '宠物玩具'],
    '农资园艺': ['种子', '花盆', '肥料', '工具']
  };

  static async searchProductsByCategory(category: string, page: number, pageSize: number): Promise<PlatformSearchResponse> {
    const optId: string | undefined = PddApiAdapter.resolveOptId(category);
    const expandedKeywords: string[] = PddApiAdapter.CATEGORY_KEYWORD_EXPAND[category] || [category];
    const request: PlatformSearchRequest = {
      keyword: expandedKeywords[0],
      platforms: [PlatformCode.PddOfficial],
      category: category,
      page: page,
      pageSize: pageSize >= 10 ? pageSize : 10,
      sortBy: 'default'
    };
    hilog.info(DOMAIN, TAG, 'CatSearch: ' + category + ' opt=' + (optId || '-') + ' kw=' + expandedKeywords[0]);

    if (optId && optId.length > 0) {
      const result: PlatformSearchResponse = await PddApiAdapter.doSearch(request, optId);
      hilog.info(DOMAIN, TAG, 'opt_id res: count=' + result.products.length);
      if (result.products.length > 0) {
        return result;
      }
      hilog.info(DOMAIN, TAG, 'Category search with opt_id returned 0, trying keyword-only');
    }

    for (let ki: number = 1; ki < Math.min(expandedKeywords.length, 4); ki += 1) {
      const fallbackRequest: PlatformSearchRequest = {
        keyword: expandedKeywords[ki],
        platforms: [PlatformCode.PddOfficial],
        category: category,
        page: page,
        pageSize: pageSize >= 10 ? pageSize : 10,
        sortBy: 'default'
      };
      hilog.info(DOMAIN, TAG, 'fb kw=' + expandedKeywords[ki]);
      const fallbackResult: PlatformSearchResponse = await PddApiAdapter.doSearch(fallbackRequest, undefined);
      hilog.info(DOMAIN, TAG, 'fb res: count=' + fallbackResult.products.length);
      if (fallbackResult.products.length > 0) {
        return fallbackResult;
      }
    }

    hilog.warn(DOMAIN, TAG, 'CatSearch empty: ' + category);
    return {
      request: request,
      products: [],
      sourceMode: PlatformDataSourceMode.OfficialApiReady,
      message: '分类搜索暂无商品数据'
    };
  }

  private static resolveOptId(category: string): string | undefined {
    if (PddApiAdapter.CATEGORY_OPT_ID_MAP[category] !== undefined) {
      return PddApiAdapter.CATEGORY_OPT_ID_MAP[category];
    }
    if (PddApiAdapter.cachedCatList.length > 0) {
      const found: PddCatItem | undefined = PddApiAdapter.findCatByName(PddApiAdapter.cachedCatList, category);
      if (found) {
        return found.cat_id.toString();
      }
    }
    return undefined;
  }

  private static findCatByName(cats: PddCatItem[], name: string): PddCatItem | undefined {
    for (let i: number = 0; i < cats.length; i += 1) {
      if (cats[i].cat_name === name || cats[i].cat_name.indexOf(name) >= 0 || name.indexOf(cats[i].cat_name) >= 0) {
        return cats[i];
      }
      if (cats[i].children && cats[i].children!.length > 0) {
        const found: PddCatItem | undefined = PddApiAdapter.findCatByName(cats[i].children!, name);
        if (found) {
          return found;
        }
      }
    }
    return undefined;
  }

  static async ensureCatList(): Promise<void> {
    if (PddApiAdapter.catListLoaded) {
      return;
    }
    try {
      const cats: PddCatItem[] = await PddApiAdapter.getCatList();
      if (cats.length > 0) {
        PddApiAdapter.cachedCatList = cats;
        PddApiAdapter.catListLoaded = true;
        hilog.info(DOMAIN, TAG, 'Cat list loaded, count=' + cats.length);
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to load cat list');
    }
  }

  private static async doSearch(request: PlatformSearchRequest, optId?: string): Promise<PlatformSearchResponse> {
    if (!PddApiConfig.enabled) {
      return {
        request: request,
        products: [],
        sourceMode: PlatformDataSourceMode.Mock,
        message: '多多进宝 API 未启用'
      };
    }
    const safeKeyword: string = request.keyword.trim();
    if (safeKeyword.length === 0) {
      return {
        request: request,
        products: [],
        sourceMode: PlatformDataSourceMode.OfficialApiReady,
        message: '搜索关键词不能为空'
      };
    }
    const safePageSize: number = request.pageSize >= 10 ? request.pageSize : 10;
    const timestamp: number = Math.floor(Date.now() / 1000);
    const params: Record<string, string> = {
      'type': 'pdd.ddk.goods.search',
      'client_id': PddApiConfig.clientId,
      'timestamp': timestamp.toString(),
      'keyword': safeKeyword,
      'page': request.page.toString(),
      'page_size': safePageSize.toString(),
      'with_coupon': 'true',
      'sort_type': '0'
    };
    if (optId && optId.length > 0) {
      params['opt_id'] = optId;
      hilog.info(DOMAIN, TAG, 'Search with opt_id=' + optId + ' category=' + (request.category || ''));
    }
    if (PddApiConfig.pid.length > 0) {
      params['pid'] = PddApiConfig.pid;
    }
    const sign: string = PddApiAdapter.generateSign(params);
    params['sign'] = sign;
    const queryString: string = PddApiAdapter.buildQueryString(params);
    const apiUrl: string = PddApiConfig.baseUrl + '?' + queryString;
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(apiUrl, {
        method: http.RequestMethod.GET,
        readTimeout: 10000,
        connectTimeout: 10000,
        header: { 'Content-Type': 'application/json' }
      });
      const body: string = `${response.result}`;
      hilog.info(DOMAIN, TAG, 'doSearch rsp: ' + body.substring(0, 200));
      let parsed: PddApiSearchResponse;
      try {
        parsed = JSON.parse(body) as PddApiSearchResponse;
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'JSON parse failed');
        return {
          request: request,
          products: [],
          sourceMode: PlatformDataSourceMode.OfficialApiReady,
          message: '多多进宝 API 返回解析失败'
        };
      }
      if (parsed.error_response) {
        hilog.error(DOMAIN, TAG, 'PDD API error: ' + parsed.error_response.error_msg);
        return {
          request: request,
          products: [],
          sourceMode: PlatformDataSourceMode.OfficialApiReady,
          message: '多多进宝 API 报错: ' + parsed.error_response.error_msg
        };
      }
      const searchResponse: PddSearchResponse | undefined =
        parsed.pdd_ddk_goods_search_response?.goods_search_response;
      if (!searchResponse || !searchResponse.goods_list) {
        return {
          request: request,
          products: [],
          sourceMode: PlatformDataSourceMode.OfficialApiReady,
          message: '多多进宝 API 暂无商品数据'
        };
      }
      const products: PlatformProduct[] = searchResponse.goods_list.map(
        (item: PddGoodsItem) => PddApiAdapter.toPlatformProduct(item)
      );
      return {
        request: request,
        products: products,
        sourceMode: PlatformDataSourceMode.OfficialApiReady,
        message: optId && optId.length > 0
          ? '已通过多多进宝 API 按分类获取拼多多商品数据'
          : '已通过多多进宝 API 获取拼多多商品数据'
      };
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'PDD API request failed');
      return {
        request: request,
        products: [],
        sourceMode: PlatformDataSourceMode.OfficialApiReady,
        message: '多多进宝 API 网络请求失败'
      };
    } finally {
      httpRequest.destroy();
    }
  }

  static async getProductDetail(goodsId: string): Promise<PlatformProduct | undefined> {
    if (!PddApiConfig.enabled) {
      return undefined;
    }
    const timestamp: number = Math.floor(Date.now() / 1000);
    const params: Record<string, string> = {
      'type': 'pdd.ddk.goods.detail',
      'client_id': PddApiConfig.clientId,
      'timestamp': timestamp.toString(),
      'goods_id_list': JSON.stringify([parseInt(goodsId)])
    };
    if (PddApiConfig.pid.length > 0) {
      params['pid'] = PddApiConfig.pid;
    }
    const sign: string = PddApiAdapter.generateSign(params);
    params['sign'] = sign;
    const queryString: string = PddApiAdapter.buildQueryString(params);
    const apiUrl: string = PddApiConfig.baseUrl + '?' + queryString;
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(apiUrl, {
        method: http.RequestMethod.GET,
        readTimeout: 10000,
        connectTimeout: 10000,
        header: { 'Content-Type': 'application/json' }
      });
      const body: string = `${response.result}`;
      let parsed: PddApiDetailResponse;
      try {
        parsed = JSON.parse(body) as PddApiDetailResponse;
      } catch (error) {
        return undefined;
      }
      if (parsed.error_response) {
        return undefined;
      }
      const details: PddGoodsItem[] | undefined =
        parsed.pdd_ddk_goods_detail_response?.goods_detail_response?.goods_details;
      if (!details || details.length === 0) {
        return undefined;
      }
      return PddApiAdapter.toPlatformProduct(details[0]);
    } catch (error) {
      return undefined;
    } finally {
      httpRequest.destroy();
    }
  }

  static async searchGoodsList(keyword: string, page: number, pageSize: number): Promise<PlatformSearchResponse> {
    if (!PddApiConfig.enabled) {
      return {
        request: { keyword: keyword, platforms: [], page: page, pageSize: pageSize },
        products: [],
        sourceMode: PlatformDataSourceMode.Mock,
        message: '拼多多 API 未启用'
      };
    }
    const token: string = await PddApiAdapter.ensureAccessToken();
    const safeKeyword: string = keyword.trim();
    if (safeKeyword.length === 0) {
      return {
        request: { keyword: keyword, platforms: [], page: page, pageSize: pageSize },
        products: [],
        sourceMode: PlatformDataSourceMode.OfficialApiReady,
        message: '搜索关键词不能为空'
      };
    }
    const timestamp: number = Math.floor(Date.now() / 1000);
    const params: Record<string, string> = {
      'type': 'pdd.goods.list.get',
      'client_id': PddApiConfig.clientId,
      'timestamp': timestamp.toString(),
      'keyword': safeKeyword,
      'page': page.toString(),
      'page_size': pageSize.toString()
    };
    if (token.length > 0) {
      params['access_token'] = token;
    }
    const sign: string = PddApiAdapter.generateSign(params);
    params['sign'] = sign;
    const queryString: string = PddApiAdapter.buildQueryString(params);
    const apiUrl: string = PddApiConfig.baseUrl + '?' + queryString;
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(apiUrl, {
        method: http.RequestMethod.GET,
        readTimeout: 10000,
        connectTimeout: 10000,
        header: { 'Content-Type': 'application/json' }
      });
      const body: string = `${response.result}`;
      hilog.info(DOMAIN, TAG, 'goods.list response: ' + body.substring(0, 300));
      let parsed: PddApiGoodsListResponse;
      try {
        parsed = JSON.parse(body) as PddApiGoodsListResponse;
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'goods.list JSON parse failed');
        return {
          request: { keyword: keyword, platforms: [], page: page, pageSize: pageSize },
          products: [],
          sourceMode: PlatformDataSourceMode.OfficialApiReady,
          message: 'pdd.goods.list.get 返回解析失败'
        };
      }
      if (parsed.error_response) {
        hilog.error(DOMAIN, TAG, 'PDD goods.list error: ' + parsed.error_response.error_msg);
        return {
          request: { keyword: keyword, platforms: [], page: page, pageSize: pageSize },
          products: [],
          sourceMode: PlatformDataSourceMode.OfficialApiReady,
          message: 'pdd.goods.list.get 报错: ' + parsed.error_response.error_msg
        };
      }
      const listResponse: PddGoodsListResponse | undefined = parsed.pdd_goods_list_get_response;
      if (!listResponse || !listResponse.goods_list) {
        return {
          request: { keyword: keyword, platforms: [], page: page, pageSize: pageSize },
          products: [],
          sourceMode: PlatformDataSourceMode.OfficialApiReady,
          message: 'pdd.goods.list.get 暂无商品数据'
        };
      }
      const products: PlatformProduct[] = listResponse.goods_list.map(
        (item: PddGoodsListItem) => PddApiAdapter.goodsListItemToPlatformProduct(item)
      );
      return {
        request: { keyword: keyword, platforms: [], page: page, pageSize: pageSize },
        products: products,
        sourceMode: PlatformDataSourceMode.OfficialApiReady,
        message: '已通过 pdd.goods.list.get 获取拼多多商品数据'
      };
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'PDD goods.list request failed');
      return {
        request: { keyword: keyword, platforms: [], page: page, pageSize: pageSize },
        products: [],
        sourceMode: PlatformDataSourceMode.OfficialApiReady,
        message: 'pdd.goods.list.get 网络请求失败'
      };
    } finally {
      httpRequest.destroy();
    }
  }

  static async getRecommendProducts(channelType: number, page: number, pageSize: number): Promise<PlatformSearchResponse> {
    if (!PddApiConfig.enabled) {
      return {
        request: { keyword: '', platforms: [], page: page, pageSize: pageSize },
        products: [],
        sourceMode: PlatformDataSourceMode.Mock,
        message: '多多进宝 API 未启用'
      };
    }
    const safePageSize = pageSize >= 10 ? pageSize : 10;
    const timestamp: number = Math.floor(Date.now() / 1000);
    const params: Record<string, string> = {
      'type': 'pdd.ddk.goods.recommend.get',
      'client_id': PddApiConfig.clientId,
      'timestamp': timestamp.toString(),
      'channel_type': channelType.toString(),
      'page': page.toString(),
      'page_size': safePageSize.toString()
    };
    const sign: string = PddApiAdapter.generateSign(params);
    params['sign'] = sign;
    const queryString: string = PddApiAdapter.buildQueryString(params);
    const apiUrl: string = PddApiConfig.baseUrl + '?' + queryString;
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(apiUrl, {
        method: http.RequestMethod.GET,
        readTimeout: 10000,
        connectTimeout: 10000,
        header: { 'Content-Type': 'application/json' }
      });
      const body: string = `${response.result}`;
      hilog.info(DOMAIN, TAG, 'recommend response: ' + body.substring(0, 200));
      let parsed: PddApiRecommendResponse;
      try {
        parsed = JSON.parse(body) as PddApiRecommendResponse;
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'recommend JSON parse failed');
        return {
          request: { keyword: '', platforms: [], page: page, pageSize: pageSize },
          products: [],
          sourceMode: PlatformDataSourceMode.OfficialApiReady,
          message: '多多进宝推荐接口返回解析失败'
        };
      }
      if (parsed.error_response) {
        hilog.error(DOMAIN, TAG, 'PDD recommend error: ' + parsed.error_response.error_msg);
        return {
          request: { keyword: '', platforms: [], page: page, pageSize: pageSize },
          products: [],
          sourceMode: PlatformDataSourceMode.OfficialApiReady,
          message: '多多进宝推荐接口报错: ' + parsed.error_response.error_msg
        };
      }
      const listResponse: PddRecommendListResponse | undefined = parsed.goods_basic_detail_response;
      if (!listResponse || !listResponse.list || listResponse.list.length === 0) {
        return {
          request: { keyword: '', platforms: [], page: page, pageSize: pageSize },
          products: [],
          sourceMode: PlatformDataSourceMode.OfficialApiReady,
          message: '多多进宝推荐接口暂无商品数据'
        };
      }
      const products: PlatformProduct[] = listResponse.list.map(
        (item: PddRecommendItem) => PddApiAdapter.recommendItemToPlatformProduct(item)
      );
      return {
        request: { keyword: '', platforms: [], page: page, pageSize: pageSize },
        products: products,
        sourceMode: PlatformDataSourceMode.OfficialApiReady,
        message: '已通过多多进宝推荐接口获取拼多多商品数据'
      };
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'PDD recommend request failed');
      return {
        request: { keyword: '', platforms: [], page: page, pageSize: pageSize },
        products: [],
        sourceMode: PlatformDataSourceMode.OfficialApiReady,
        message: '多多进宝推荐接口网络请求失败'
      };
    } finally {
      httpRequest.destroy();
    }
  }

  static async getGoodsDetail(goodsId: string): Promise<PlatformProduct | undefined> {
    if (!PddApiConfig.enabled) {
      return undefined;
    }
    const token: string = await PddApiAdapter.ensureAccessToken();
    const timestamp: number = Math.floor(Date.now() / 1000);
    const params: Record<string, string> = {
      'type': 'pdd.goods.detail.get',
      'client_id': PddApiConfig.clientId,
      'timestamp': timestamp.toString(),
      'goods_id': goodsId
    };
    if (token.length > 0) {
      params['access_token'] = token;
    }
    const sign: string = PddApiAdapter.generateSign(params);
    params['sign'] = sign;
    const queryString: string = PddApiAdapter.buildQueryString(params);
    const apiUrl: string = PddApiConfig.baseUrl + '?' + queryString;
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(apiUrl, {
        method: http.RequestMethod.GET,
        readTimeout: 10000,
        connectTimeout: 10000,
        header: { 'Content-Type': 'application/json' }
      });
      const body: string = `${response.result}`;
      let parsed: PddApiGoodsDetailResponse;
      try {
        parsed = JSON.parse(body) as PddApiGoodsDetailResponse;
      } catch (error) {
        return undefined;
      }
      if (parsed.error_response) {
        return undefined;
      }
      const detail: PddGoodsDetailItem | undefined = parsed.pdd_goods_detail_get_response?.goods_detail;
      if (!detail) {
        return undefined;
      }
      return PddApiAdapter.goodsDetailToPlatformProduct(detail);
    } catch (error) {
      return undefined;
    } finally {
      httpRequest.destroy();
    }
  }

  static async getGoodsImages(goodsId: string): Promise<string[]> {
    if (!PddApiConfig.enabled) {
      return [];
    }
    const token: string = await PddApiAdapter.ensureAccessToken();
    const timestamp: number = Math.floor(Date.now() / 1000);
    const params: Record<string, string> = {
      'type': 'pdd.goods.image.get',
      'client_id': PddApiConfig.clientId,
      'timestamp': timestamp.toString(),
      'goods_id': goodsId
    };
    if (token.length > 0) {
      params['access_token'] = token;
    }
    const sign: string = PddApiAdapter.generateSign(params);
    params['sign'] = sign;
    const queryString: string = PddApiAdapter.buildQueryString(params);
    const apiUrl: string = PddApiConfig.baseUrl + '?' + queryString;
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(apiUrl, {
        method: http.RequestMethod.GET,
        readTimeout: 10000,
        connectTimeout: 10000,
        header: { 'Content-Type': 'application/json' }
      });
      const body: string = `${response.result}`;
      const parsed: PddApiImageResponse = JSON.parse(body) as PddApiImageResponse;
      if (parsed.error_response || !parsed.pdd_goods_image_get_response) {
        return [];
      }
      const images = parsed.pdd_goods_image_get_response.image_list;
      if (!images || images.length === 0) {
        return [];
      }
      const urls: string[] = [];
      if (images[0].goods_img_url && images[0].goods_img_url.length > 0) {
        urls.push(images[0].goods_img_url);
      }
      if (images[0].gallery_urls && images[0].gallery_urls.length > 0) {
        urls.push(...images[0].gallery_urls);
      }
      return urls;
    } catch (error) {
      return [];
    } finally {
      httpRequest.destroy();
    }
  }

  static async getCatList(parentCatId?: number): Promise<PddCatItem[]> {
    if (!PddApiConfig.enabled) {
      return [];
    }
    const token: string = await PddApiAdapter.ensureAccessToken();
    const timestamp: number = Math.floor(Date.now() / 1000);
    const params: Record<string, string> = {
      'type': 'pdd.goods.cat.list.get',
      'client_id': PddApiConfig.clientId,
      'timestamp': timestamp.toString()
    };
    if (token.length > 0) {
      params['access_token'] = token;
    }
    if (parentCatId !== undefined) {
      params['parent_cat_id'] = parentCatId.toString();
    }
    const sign: string = PddApiAdapter.generateSign(params);
    params['sign'] = sign;
    const queryString: string = PddApiAdapter.buildQueryString(params);
    const apiUrl: string = PddApiConfig.baseUrl + '?' + queryString;
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(apiUrl, {
        method: http.RequestMethod.GET,
        readTimeout: 10000,
        connectTimeout: 10000,
        header: { 'Content-Type': 'application/json' }
      });
      const body: string = `${response.result}`;
      const parsed: PddApiCatListResponse = JSON.parse(body) as PddApiCatListResponse;
      if (parsed.error_response || !parsed.pdd_goods_cat_list_get_response) {
        return [];
      }
      return parsed.pdd_goods_cat_list_get_response.cat_list;
    } catch (error) {
      return [];
    } finally {
      httpRequest.destroy();
    }
  }

  static buildPromotionUrl(goodsId: string): string {
    return `https://mobile.yangkeduo.com/goods.html?goods_id=${goodsId}`;
  }

  private static toPlatformProduct(item: PddGoodsItem): PlatformProduct {
    const priceInYuan: number = item.min_group_price / 100;
    const normalPriceInYuan: number = item.min_normal_price / 100;
    const couponDiscountYuan: number = item.coupon_discount / 100;
    const salesNum: number = PddApiAdapter.parseSalesTip(item.sales_tip);
    const effectivePrice: number = couponDiscountYuan > 0
      ? Math.max(0, priceInYuan - couponDiscountYuan)
      : priceInYuan;
    const tags: string[] = [];
    if (item.category_name && item.category_name.length > 0) {
      tags.push(item.category_name);
    }
    if (item.opt_name && item.opt_name.length > 0) {
      tags.push(item.opt_name);
    }
    if (couponDiscountYuan > 0) {
      tags.push('有券');
    }
    return {
      platform: PlatformCode.PddOfficial,
      platformName: '拼多多',
      platformProductId: item.goods_id.toString(),
      title: item.goods_name,
      price: Math.round(effectivePrice * 100) / 100,
      originalPrice: Math.round(normalPriceInYuan * 100) / 100,
      sales: salesNum,
      rating: 4.5,
      shopName: item.mall_name && item.mall_name.length > 0 ? item.mall_name : '拼多多店铺',
      description: item.goods_desc && item.goods_desc.length > 0 ? item.goods_desc : item.goods_name,
      productUrl: PddApiAdapter.buildPromotionUrl(item.goods_id.toString()),
      tags: tags,
      imageUrl: item.goods_image_url && item.goods_image_url.length > 0
        ? item.goods_image_url
        : item.goods_thumbnail_url
    };
  }

  private static goodsListItemToPlatformProduct(item: PddGoodsListItem): PlatformProduct {
    const priceInYuan: number = item.min_group_price / 100;
    const normalPriceInYuan: number = item.min_normal_price / 100;
    const couponDiscountYuan: number = item.coupon_discount / 100;
    const effectivePrice: number = couponDiscountYuan > 0
      ? Math.max(0, priceInYuan - couponDiscountYuan)
      : priceInYuan;
    const tags: string[] = [];
    if (couponDiscountYuan > 0) {
      tags.push('有券');
    }
    return {
      platform: PlatformCode.PddOfficial,
      platformName: '拼多多',
      platformProductId: item.goods_id.toString(),
      title: item.goods_name,
      price: Math.round(effectivePrice * 100) / 100,
      originalPrice: Math.round(normalPriceInYuan * 100) / 100,
      sales: PddApiAdapter.parseSalesTip(item.sales_tip),
      rating: 4.5,
      shopName: item.mall_name && item.mall_name.length > 0 ? item.mall_name : '拼多多店铺',
      description: item.goods_desc && item.goods_desc.length > 0 ? item.goods_desc : item.goods_name,
      productUrl: PddApiAdapter.buildPromotionUrl(item.goods_id.toString()),
      tags: tags,
      imageUrl: item.goods_img_url && item.goods_img_url.length > 0
        ? item.goods_img_url
        : item.thumb_url
    };
  }

  private static goodsDetailToPlatformProduct(detail: PddGoodsDetailItem): PlatformProduct {
    const priceInYuan: number = detail.min_group_price / 100;
    const normalPriceInYuan: number = detail.min_normal_price / 100;
    const couponDiscountYuan: number = detail.coupon_discount / 100;
    const effectivePrice: number = couponDiscountYuan > 0
      ? Math.max(0, priceInYuan - couponDiscountYuan)
      : priceInYuan;
    const tags: string[] = [];
    if (detail.has_coupon) {
      tags.push('有券');
    }
    return {
      platform: PlatformCode.PddOfficial,
      platformName: '拼多多',
      platformProductId: detail.goods_id.toString(),
      title: detail.goods_name,
      price: Math.round(effectivePrice * 100) / 100,
      originalPrice: Math.round(normalPriceInYuan * 100) / 100,
      sales: PddApiAdapter.parseSalesTip(detail.sales_tip),
      rating: 4.5,
      shopName: detail.mall_name && detail.mall_name.length > 0 ? detail.mall_name : '拼多多店铺',
      description: detail.goods_desc && detail.goods_desc.length > 0 ? detail.goods_desc : detail.goods_name,
      productUrl: PddApiAdapter.buildPromotionUrl(detail.goods_id.toString()),
      tags: tags,
      imageUrl: detail.goods_img_url && detail.goods_img_url.length > 0
        ? detail.goods_img_url
        : detail.thumb_url
    };
  }

  private static recommendItemToPlatformProduct(item: PddRecommendItem): PlatformProduct {
    const priceInYuan: number = item.min_group_price / 100;
    const normalPriceInYuan: number = item.min_normal_price / 100;
    const couponDiscountYuan: number = item.coupon_discount / 100;
    const effectivePrice: number = couponDiscountYuan > 0
      ? Math.max(0, priceInYuan - couponDiscountYuan)
      : priceInYuan;
    const tags: string[] = [];
    if (item.category_name && item.category_name.length > 0) {
      tags.push(item.category_name);
    }
    if (item.opt_name && item.opt_name.length > 0) {
      tags.push(item.opt_name);
    }
    if (item.has_coupon) {
      tags.push('有券');
    }
    return {
      platform: PlatformCode.PddOfficial,
      platformName: '拼多多',
      platformProductId: item.goods_id.toString(),
      title: item.goods_name,
      price: Math.round(effectivePrice * 100) / 100,
      originalPrice: Math.round(normalPriceInYuan * 100) / 100,
      sales: PddApiAdapter.parseSalesTip(item.sales_tip),
      rating: 4.5,
      shopName: item.mall_name && item.mall_name.length > 0 ? item.mall_name : '拼多多店铺',
      description: item.goods_desc && item.goods_desc.length > 0 ? item.goods_desc : item.goods_name,
      productUrl: PddApiAdapter.buildPromotionUrl(item.goods_id.toString()),
      tags: tags,
      imageUrl: item.goods_image_url && item.goods_image_url.length > 0
        ? item.goods_image_url
        : item.goods_thumbnail_url
    };
  }

  private static parseSalesTip(salesTip: string): number {
    if (!salesTip || salesTip.length === 0) {
      return 0;
    }
    if (salesTip.indexOf('10万+') >= 0) {
      return 100000;
    }
    if (salesTip.indexOf('万') >= 0) {
      const num: number = parseFloat(salesTip.replace('万', ''));
      return Math.round(num * 10000);
    }
    const parsed: number = parseInt(salesTip);
    return isNaN(parsed) ? 0 : parsed;
  }

  private static generateSign(params: Record<string, string>): string {
    const keys: string[] = Object.keys(params).sort();
    let signStr: string = PddApiConfig.clientSecret;
    for (let i: number = 0; i < keys.length; i += 1) {
      const key: string = keys[i];
      if (key === 'sign') {
        continue;
      }
      signStr += key + params[key];
    }
    signStr += PddApiConfig.clientSecret;
    return PddApiAdapter.md5Sync(signStr).toUpperCase();
  }

  private static md5Sync(input: string): string {
    try {
      const md5 = cryptoFramework.createMd('MD5');
      const textEncoder = new util.TextEncoder();
      const data = textEncoder.encodeInto(input);
      const blob: cryptoFramework.DataBlob = { data: data };
      md5.updateSync(blob);
      const result = md5.digestSync();
      const arr = result.data;
      let hex: string = '';
      for (let i: number = 0; i < arr.length; i += 1) {
        const byte: number = arr[i];
        const hexByte: string = byte.toString(16).padStart(2, '0');
        hex += hexByte;
      }
      return hex;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'MD5 failed');
      return '';
    }
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
