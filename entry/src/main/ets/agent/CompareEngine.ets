import { AgentIntent, emptySkillResultData } from './AgentModels';
import { ProductCandidate, RecommendationResult } from '../models/ShoppingModels';

export class CompareEngine {
  static compare(candidates: ProductCandidate[], intent: AgentIntent): RecommendationResult {
    const scored: ProductCandidate[] = candidates.map((item: ProductCandidate) => {
      const product: ProductCandidate = CompareEngine.cloneProduct(item);
      product.recommendScore = CompareEngine.calculateScore(product, intent);
      return product;
    }).sort((left: ProductCandidate, right: ProductCandidate) => right.recommendScore - left.recommendScore);

    const bestProduct: ProductCandidate = scored.length > 0 ? scored[0] : CompareEngine.emptyProduct();
    return {
      intent: {
        product: intent.product,
        attributes: intent.attributes.features.concat(intent.attributes.rawAttributes),
        quantity: intent.quantity,
        rawText: intent.rawText
      },
      bestProduct: bestProduct,
      candidates: scored,
      reason: '',
      fallbackUsed: false
    };
  }

  private static calculateScore(product: ProductCandidate, intent: AgentIntent): number {
    const priceScore: number = Math.max(0, 100 - product.price / 4);
    const ratingScore: number = product.rating * 20;
    const salesScore: number = Math.min(100, product.sales / 800);
    const attributeScore: number = CompareEngine.attributeMatchScore(product, intent);
    return Math.round(priceScore * 0.3 + ratingScore * 0.25 + salesScore * 0.2 + attributeScore * 0.25);
  }

  private static attributeMatchScore(product: ProductCandidate, intent: AgentIntent): number {
    let matchCount: number = 0;
    const productTags: string[] = product.tags;
    for (let i = 0; i < intent.attributes.features.length; i += 1) {
      const feature: string = intent.attributes.features[i];
      for (let j = 0; j < productTags.length; j += 1) {
        if (productTags[j].indexOf(feature) >= 0 || feature.indexOf(productTags[j]) >= 0) {
          matchCount += 1;
          break;
        }
      }
    }
    if (intent.attributes.color.length > 0) {
      for (let j = 0; j < productTags.length; j += 1) {
        if (productTags[j].indexOf(intent.attributes.color) >= 0) {
          matchCount += 1;
          break;
        }
      }
    }
    if (intent.attributes.material.length > 0) {
      for (let j = 0; j < productTags.length; j += 1) {
        if (productTags[j].indexOf(intent.attributes.material) >= 0) {
          matchCount += 1;
          break;
        }
      }
    }
    const rawAttrs: string[] = intent.attributes.rawAttributes;
    for (let i = 0; i < rawAttrs.length; i += 1) {
      for (let j = 0; j < productTags.length; j += 1) {
        if (productTags[j].indexOf(rawAttrs[i]) >= 0 || rawAttrs[i].indexOf(productTags[j]) >= 0) {
          matchCount += 1;
          break;
        }
      }
    }
    return Math.min(100, matchCount * 5);
  }

  private static cloneProduct(product: ProductCandidate): ProductCandidate {
    return {
      id: product.id,
      platform: product.platform,
      name: product.name,
      price: product.price,
      rating: product.rating,
      sales: product.sales,
      shopName: product.shopName,
      description: product.description,
      tags: product.tags.slice(),
      recommendScore: product.recommendScore,
      imageKey: product.imageKey,
      imageUrl: product.imageUrl
    };
  }

  private static emptyProduct(): ProductCandidate {
    return {
      id: '',
      platform: '',
      name: '',
      price: 0,
      rating: 0,
      sales: 0,
      shopName: '',
      description: '',
      tags: [],
      recommendScore: 0
    };
  }
}
