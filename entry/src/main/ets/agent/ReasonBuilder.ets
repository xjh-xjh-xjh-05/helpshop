import { AgentIntent } from './AgentModels';
import { ProductCandidate } from '../models/ShoppingModels';

export class ReasonBuilder {
  static buildReason(
    best: ProductCandidate,
    candidates: ProductCandidate[],
    intent: AgentIntent,
    fallbackUsed: boolean
  ): string {
    const parts: string[] = [];

    if (fallbackUsed) {
      parts.push('未找到完全匹配商品，已按相近需求推荐。');
    }

    const priceAdv: string = ReasonBuilder.findPriceAdvantage(best, candidates);
    if (priceAdv.length > 0) {
      parts.push(priceAdv);
    }

    const ratingAdv: string = ReasonBuilder.findRatingAdvantage(best, candidates);
    if (ratingAdv.length > 0) {
      parts.push(ratingAdv);
    }

    const attributeText: string = ReasonBuilder.findAttributeMatchText(best, intent);
    if (attributeText.length > 0) {
      parts.push(attributeText);
    }

    parts.push(best.name + ' 综合推荐分 ' + best.recommendScore.toString() +
      '，价格 ¥' + best.price.toString() +
      '，评分 ' + best.rating.toString() +
      '，销量 ' + best.sales.toString());

    return parts.join('；') + '，适合作为本次优先推荐。';
  }

  private static findPriceAdvantage(best: ProductCandidate, candidates: ProductCandidate[]): string {
    if (candidates.length <= 1) {
      return '';
    }
    let minPrice: number = best.price;
    for (let i = 0; i < candidates.length; i += 1) {
      if (candidates[i].price < minPrice) {
        minPrice = candidates[i].price;
      }
    }
    if (best.price === minPrice && candidates.length > 1) {
      return '这款价格最低';
    }
    const avgPrice: number = candidates.reduce((sum: number, item: ProductCandidate) => sum + item.price, 0) / candidates.length;
    if (best.price < avgPrice * 0.85) {
      return '这款价格低于均价';
    }
    return '';
  }

  private static findRatingAdvantage(best: ProductCandidate, candidates: ProductCandidate[]): string {
    if (candidates.length <= 1) {
      return '';
    }
    let maxRating: number = best.rating;
    for (let i = 0; i < candidates.length; i += 1) {
      if (candidates[i].rating > maxRating) {
        maxRating = candidates[i].rating;
      }
    }
    if (best.rating === maxRating && best.rating >= 4.8) {
      return '好评率超过90%';
    }
    if (best.rating >= 4.7) {
      return '评分较高';
    }
    return '';
  }

  private static findAttributeMatchText(best: ProductCandidate, intent: AgentIntent): string {
    const matchedAttributes: string[] = [];
    const features: string[] = intent.attributes.features;
    for (let i = 0; i < features.length; i += 1) {
      const feature: string = features[i];
      const isMatched: boolean = best.tags.some((tag: string) => {
        return tag.indexOf(feature) >= 0 || feature.indexOf(tag) >= 0;
      });
      if (isMatched) {
        matchedAttributes.push(feature);
      }
    }
    if (intent.attributes.color.length > 0) {
      const colorMatched: boolean = best.tags.some((tag: string) => {
        return tag.indexOf(intent.attributes.color) >= 0;
      });
      if (colorMatched) {
        matchedAttributes.push(intent.attributes.color);
      }
    }
    if (intent.attributes.material.length > 0) {
      const materialMatched: boolean = best.tags.some((tag: string) => {
        return tag.indexOf(intent.attributes.material) >= 0;
      });
      if (materialMatched) {
        matchedAttributes.push(intent.attributes.material);
      }
    }
    if (matchedAttributes.length > 0) {
      return '命中"' + matchedAttributes.join('、') + '"等需求';
    }
    return '';
  }
}
