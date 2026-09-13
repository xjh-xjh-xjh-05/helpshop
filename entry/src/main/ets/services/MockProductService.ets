import { ParsedIntent, ProductCandidate } from '../models/ShoppingModels';
import { PlatformProductGatewayService } from './PlatformProductGatewayService';
import { CloneUtils } from '../utils/CloneUtils';

export class MockProductService {
  static getAllProducts(): ProductCandidate[] {
    return PlatformProductGatewayService.getAllCandidates().map((item: ProductCandidate) => {
      return CloneUtils.cloneProduct(item);
    });
  }

  static getProductById(id: string): ProductCandidate | undefined {
    const found = PlatformProductGatewayService.getCandidateById(id);
    if (!found) {
      return undefined;
    }
    return CloneUtils.cloneProduct(found);
  }

  static searchProducts(intent: ParsedIntent): ProductCandidate[] {
    return MockProductService.searchProductsWithFallback(intent).products;
  }

  static searchProductsWithFallback(intent: ParsedIntent): ProductSearchResult {
    const allProducts = MockProductService.getAllProducts();
    const keyword = intent.product;
    const matched = allProducts.filter((item: ProductCandidate) => {
      return item.name.indexOf(keyword) >= 0 || item.tags.some((tag: string) => keyword.indexOf(tag) >= 0 || tag.indexOf(keyword) >= 0);
    });
    const source = matched.length > 0 ? matched : allProducts.filter((item: ProductCandidate) => item.tags.some((tag: string) => intent.rawText.indexOf(tag) >= 0));
    const fallbackUsed = source.length === 0;
    const candidates = (source.length > 0 ? source : allProducts.slice(0, 5)).slice(0, 5);
    const products = candidates.map((item: ProductCandidate) => {
      const product = CloneUtils.cloneProduct(item);
      product.recommendScore = MockProductService.calculateScore(product);
      return product;
    }).sort((left: ProductCandidate, right: ProductCandidate) => right.recommendScore - left.recommendScore);
    return {
      products: products,
      fallbackUsed: fallbackUsed
    };
  }

  private static calculateScore(product: ProductCandidate): number {
    const priceScore = Math.max(0, 100 - product.price / 4);
    const ratingScore = product.rating * 20;
    const salesScore = Math.min(100, product.sales / 800);
    return Math.round(priceScore * 0.5 + ratingScore * 0.3 + salesScore * 0.2);
  }

}

export interface ProductSearchResult {
  products: ProductCandidate[];
  fallbackUsed: boolean;
}
