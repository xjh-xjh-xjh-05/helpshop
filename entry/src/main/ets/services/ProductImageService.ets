import { ProductCandidate } from '../models/ShoppingModels';

export class ProductImageService {
  static getImage(product: ProductCandidate): ResourceStr {
    if (product.imageUrl && product.imageUrl.length > 0) {
      return product.imageUrl;
    }
    const imageKey = ProductImageService.getImageKey(product);
    if (imageKey === 'shoe') {
      return $r('app.media.product_shoe');
    }
    if (imageKey === 'bp') {
      return $r('app.media.product_bp');
    }
    if (imageKey === 'milk') {
      return $r('app.media.product_milk');
    }
    if (imageKey === 'phone') {
      return $r('app.media.product_phone');
    }
    if (imageKey === 'lamp') {
      return $r('app.media.product_lamp');
    }
    if (imageKey === 'rice') {
      return $r('app.media.product_rice');
    }
    if (imageKey === 'medicine') {
      return $r('app.media.product_medicine');
    }
    if (imageKey === 'cart') {
      return $r('app.media.product_cart');
    }
    if (imageKey === 'heater') {
      return $r('app.media.product_heater');
    }
    if (imageKey === 'blanket') {
      return $r('app.media.product_blanket');
    }
    return $r('app.media.product_shoe');
  }

  static getImageKey(product: ProductCandidate): string {
    if (product.imageKey && product.imageKey.length > 0) {
      return product.imageKey;
    }
    if (product.id.indexOf('shoe') >= 0 || ProductImageService.hasTag(product, '鞋')) {
      return 'shoe';
    }
    if (product.id.indexOf('bp') >= 0 || ProductImageService.hasTag(product, '血压计')) {
      return 'bp';
    }
    if (product.id.indexOf('milk') >= 0 || ProductImageService.hasTag(product, '奶粉')) {
      return 'milk';
    }
    if (product.id.indexOf('phone') >= 0 || ProductImageService.hasTag(product, '手机')) {
      return 'phone';
    }
    if (product.id.indexOf('lamp') >= 0 || ProductImageService.hasTag(product, '台灯')) {
      return 'lamp';
    }
    if (product.id.indexOf('rice') >= 0 || ProductImageService.hasTag(product, '大米')) {
      return 'rice';
    }
    if (product.id.indexOf('medicine') >= 0 || ProductImageService.hasTag(product, '药盒')) {
      return 'medicine';
    }
    if (product.id.indexOf('cart') >= 0 || ProductImageService.hasTag(product, '推车')) {
      return 'cart';
    }
    if (product.id.indexOf('heater') >= 0 || ProductImageService.hasTag(product, '暖脚器')) {
      return 'heater';
    }
    if (product.id.indexOf('blanket') >= 0 || ProductImageService.hasTag(product, '毛毯')) {
      return 'blanket';
    }
    return 'shoe';
  }

  private static hasTag(product: ProductCandidate, tag: string): boolean {
    return product.tags.indexOf(tag) >= 0 || product.name.indexOf(tag) >= 0 || product.description.indexOf(tag) >= 0;
  }
}
