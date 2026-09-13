import { http } from '@kit.NetworkKit';
import {
  PlatformCode,
  PlatformDataSourceMode,
  PlatformProduct,
  PlatformSearchRequest,
  PlatformSearchResponse
} from '../models/PlatformModels';

interface DummyJsonProduct {
  id: number;
  title: string;
  description: string;
  category: string;
  price: number;
  discountPercentage?: number;
  rating: number;
  stock: number;
  brand?: string;
  thumbnail?: string;
}

interface DummyJsonProductResponse {
  products: DummyJsonProduct[];
  total: number;
  skip: number;
  limit: number;
}

export class PublicProductApiAdapter {
  static async searchProducts(request: PlatformSearchRequest): Promise<PlatformSearchResponse> {
    const safeKeyword = request.keyword.trim();
    const safeLimit = request.pageSize > 0 ? request.pageSize : 20;
    const apiUrl = safeKeyword.length > 0
      ? `https://dummyjson.com/products/search?q=${encodeURIComponent(safeKeyword)}&limit=${safeLimit}`
      : `https://dummyjson.com/products?limit=${safeLimit}`;
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(apiUrl, {
        method: http.RequestMethod.GET,
        readTimeout: 8000,
        connectTimeout: 8000
      });
      const body = `${response.result}`;
      let parsed: DummyJsonProductResponse = {
        products: [],
        total: 0,
        skip: 0,
        limit: 0
      };
      try {
        parsed = JSON.parse(body);
      } catch (error) {
        return {
          request: request,
          products: [],
          sourceMode: PlatformDataSourceMode.PublicApi,
          message: '公开商品 API 返回解析失败，已准备降级为本地商品。'
        };
      }
      const products = parsed.products.map((item: DummyJsonProduct) => PublicProductApiAdapter.toPlatformProduct(item));
      if (products.length === 0 && safeKeyword.length > 0) {
        const fallbackUrl = `https://dummyjson.com/products?limit=${safeLimit}`;
        const fallbackRequest = http.createHttp();
        try {
          const fallbackResponse = await fallbackRequest.request(fallbackUrl, {
            method: http.RequestMethod.GET,
            readTimeout: 8000,
            connectTimeout: 8000
          });
          const fallbackBody = `${fallbackResponse.result}`;
          let fallbackParsed: DummyJsonProductResponse = JSON.parse(fallbackBody);
          const fallbackProducts = fallbackParsed.products.map((item: DummyJsonProduct) => PublicProductApiAdapter.toPlatformProduct(item));
          return {
            request: request,
            products: fallbackProducts,
            sourceMode: PlatformDataSourceMode.PublicApi,
            message: '搜索关键词无精确匹配，已返回热门商品列表。'
          };
        } catch (fallbackError) {
          return {
            request: request,
            products: [],
            sourceMode: PlatformDataSourceMode.PublicApi,
            message: '公开商品 API 暂无返回数据，已准备降级为本地商品。'
          };
        } finally {
          fallbackRequest.destroy();
        }
      }
      return {
        request: request,
        products: products,
        sourceMode: PlatformDataSourceMode.PublicApi,
        message: '已通过公开商品 API 获取商品数据；淘宝、京东、拼多多官方接口仍保留适配器替换点。'
      };
    } catch (error) {
      return {
        request: request,
        products: [],
        sourceMode: PlatformDataSourceMode.PublicApi,
        message: '公开商品 API 网络请求失败，已准备降级为本地商品。'
      };
    } finally {
      httpRequest.destroy();
    }
  }

  private static toPlatformProduct(item: DummyJsonProduct): PlatformProduct {
    const brand = item.brand && item.brand.length > 0 ? item.brand : 'Public API Store';
    const sales = Math.max(100, item.stock * 120);
    return {
      platform: PlatformCode.PublicApi,
      platformName: '公开API',
      platformProductId: `public-dummy-${item.id}`,
      title: item.title,
      price: item.price,
      originalPrice: item.discountPercentage ? Math.round(item.price * (1 + item.discountPercentage / 100)) : Math.round(item.price * 1.1),
      sales: sales,
      rating: item.rating,
      shopName: brand,
      description: item.description,
      productUrl: `https://dummyjson.com/products/${item.id}`,
      tags: [item.category, brand]
    };
  }
}
