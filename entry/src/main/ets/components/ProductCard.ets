import { ProductCandidate } from '../models/ShoppingModels';
import { ProductImageService } from '../services/ProductImageService';
import { BreakpointType } from '../utils/BreakpointSystem';

@Component
export struct ProductCard {
  product: ProductCandidate = {
    id: '', platform: '', name: '', price: 0, rating: 0, sales: 0,
    shopName: '', description: '', tags: [], recommendScore: 0
  };
  isBest: boolean = false;
  careMode: boolean = false;
  compact: boolean = false;
  onSelect: (product: ProductCandidate) => void = () => {};
  onDetail: (product: ProductCandidate) => void = () => {};

  private get imageHeight(): number {
    if (this.compact) {
      return this.careMode ? 80 : 70;
    }
    return this.careMode ? 140 : 120;
  }

  private get nameFontSize(): number {
    return this.careMode ? (this.compact ? 12 : 16) : (this.compact ? 10 : 14);
  }

  private get priceFontSize(): number {
    return this.careMode ? (this.compact ? 14 : 22) : (this.compact ? 13 : 18);
  }

  private get tagFontSize(): number {
    return this.compact ? 8 : 10;
  }

  private get btnHeight(): number {
    return this.compact ? 28 : (this.careMode ? 40 : 36);
  }

  private get btnFontSize(): number {
    return this.compact ? 10 : (this.careMode ? 14 : 13);
  }

  build() {
    Column({ space: 0 }) {
      Stack({ alignContent: Alignment.BottomStart }) {
        Image(ProductImageService.getImage(this.product))
          .width('100%')
          .height(this.imageHeight)
          .objectFit(ImageFit.Cover)
          .backgroundColor('#F2EFEB')
          .borderRadius({ topLeft: 16, topRight: 16 })
        Column()
          .width('100%')
          .height(40)
          .borderRadius({ topLeft: 16, topRight: 16 })
          .linearGradient({
            angle: 180,
            colors: [['#00000000', 0], ['#00000030', 1]]
          })
          .position({ x: 0, y: this.imageHeight - 40 })

        Row({ space: 6 }) {
          Text(this.product.platform)
            .fontSize(this.careMode ? 13 : 10)
            .fontColor('#FFFFFF')
            .opacity(0.9)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('#FFFFFF30')
            .borderRadius(6)
          if (this.product.rating > 0) {
            Text('★ ' + this.product.rating.toFixed(1))
              .fontSize(this.careMode ? 13 : 10)
              .fontColor('#D4A853')
              .fontWeight(FontWeight.Bold)
          }
        }
        .padding({ left: 10, bottom: 8 })

        if (this.isBest) {
          Text('推荐')
            .fontSize(this.careMode ? 14 : 11)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Bold)
            .padding({ left: 12, right: 12, top: 5, bottom: 5 })
            .backgroundColor('#2B7068')
            .borderRadius({ bottomLeft: 10 })
            .position({ x: '88%', y: 0 })
        }
      }
      .width('100%')

      Column({ space: 6 }) {
        Text(this.product.name)
          .fontSize(this.nameFontSize)
          .fontColor('#2C1810')
          .fontWeight(FontWeight.Bold)
          .maxLines(2)
          .lineHeight(this.compact ? (this.careMode ? 20 : 16) : (this.careMode ? 26 : 22))
          .width('100%')

        Row({ space: 0 }) {
          Text('¥')
            .fontSize(this.careMode ? 15 : 12)
            .fontColor('#2B7068')
            .fontWeight(FontWeight.Bold)
          Text(this.product.price.toFixed(0))
            .fontSize(this.priceFontSize)
            .fontColor('#2B7068')
            .fontWeight(FontWeight.Bold)
          Blank()
          if (this.product.sales > 0) {
            Text(this.formatSales(this.product.sales))
              .fontSize(this.careMode ? 11 : 9)
              .fontColor('#A09080')
          }
        }
        .width('100%')

        if (this.product.tags.length > 0) {
          Row({ space: 4 }) {
            ForEach(this.product.tags.slice(0, this.compact ? 2 : 3), (tag: string) => {
              Text(tag)
                .fontSize(this.tagFontSize)
                .fontColor('#8A7A70')
                .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                .backgroundColor('#F5F0EB')
                .borderRadius(4)
            }, (tag: string) => tag)
          }
          .width('100%')
        }

        if (!this.compact) {
          Row({ space: 8 }) {
            Button('查看')
              .layoutWeight(1)
              .height(this.btnHeight)
              .fontSize(this.btnFontSize)
              .fontColor('#2B7068')
              .fontWeight(FontWeight.Medium)
              .backgroundColor('#EFFAF8')
              .borderRadius(10)
              .onClick(() => { this.onDetail(this.product); })
            Button('选择')
              .layoutWeight(1)
              .height(this.btnHeight)
              .fontSize(this.btnFontSize)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .backgroundColor('#2B7068')
              .borderRadius(10)
              .shadow({ radius: 6, color: '#2B706840', offsetX: 0, offsetY: 2 })
              .onClick(() => { this.onSelect(this.product); })
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding(this.compact ? 6 : 8)
    }
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(this.compact ? 10 : 16)
    .shadow({
      radius: this.isBest ? 14 : 10,
      color: this.isBest ? '#2B706820' : '#3D1E0A10',
      offsetX: 0,
      offsetY: this.isBest ? 4 : 2
    })
    .onClick(() => { this.onDetail(this.product); })
  }

  private formatSales(sales: number): string {
    if (sales >= 10000) {
      return '已售' + (sales / 10000).toFixed(1) + '万';
    }
    return '已售' + sales.toString();
  }
}
