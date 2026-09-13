import { ProductCandidate } from './ShoppingModels';

export enum PlatformCode {
  Taobao = 'taobao',
  JD = 'jd',
  PDD = 'pdd',
  PddOfficial = 'pdd_official',
  PublicApi = 'public_api',
  WanbangTaobao = 'wanbang_taobao',
  WanbangJD = 'wanbang_jd',
  WanbangPdd = 'wanbang_pdd'
}

export enum PlatformDataSourceMode {
  Mock = 'mock',
  PublicApi = 'public_api',
  OfficialApiReady = 'official_api_ready',
  WanbangApi = 'wanbang_api'
}

export interface PlatformSearchRequest {
  keyword: string;
  platforms: PlatformCode[];
  category?: string;
  minPrice?: number;
  maxPrice?: number;
  sortBy?: string;
  page: number;
  pageSize: number;
}

export interface PlatformProduct {
  platform: PlatformCode;
  platformName: string;
  platformProductId: string;
  title: string;
  price: number;
  originalPrice?: number;
  sales: number;
  rating: number;
  shopName: string;
  description: string;
  productUrl: string;
  tags: string[];
  imageKey?: string;
  imageUrl?: string;
}

export interface PlatformSearchResponse {
  request: PlatformSearchRequest;
  products: PlatformProduct[];
  sourceMode: PlatformDataSourceMode;
  message: string;
}

export interface PlatformAdapter {
  platform: PlatformCode;
  platformName: string;
  searchProducts(request: PlatformSearchRequest): PlatformProduct[];
  getProductDetail(platformProductId: string): PlatformProduct | undefined;
  buildPurchaseUrl(platformProductId: string): string;
}

export interface ProductGatewayStatus {
  sourceMode: PlatformDataSourceMode;
  platforms: string[];
  message: string;
}

export interface ProductCandidateMapping {
  platformProduct: PlatformProduct;
  candidate: ProductCandidate;
}
