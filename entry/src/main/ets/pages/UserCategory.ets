import { BottomNav } from '../components/BottomNav';
import { AccountRole } from '../models/AuthModels';
import { BackendResult } from '../models/BackendModels';
import { ProductGatewayStatus } from '../models/PlatformModels';
import { ProductCandidate } from '../models/ShoppingModels';
import { AppBackendService } from '../services/AppBackendService';
import { ProductImageService } from '../services/ProductImageService';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';
import { ProductCard } from '../components/ProductCard';

@Entry
@Component
struct UserCategory {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @State activeCategory: string = '鞋服出行';
  @State products: ProductCandidate[] = [];
  @State productSourceText: string = '淘宝 / 京东 / 拼多多';
  private categories: string[] = ['鞋服出行', '健康监测', '营养食品', '手机数码', '居家生活'];

  aboutToAppear(): void {
    const role = AppBackendService.getCurrentRole();
    if (role === AccountRole.Unverified) {
      RouteUtils.navigate(this.getUIContext(), 'pages/IdentityAuth');
      return;
    }
    if (!AppBackendService.canEnterShopping()) {
      RouteUtils.showToast(this.getUIContext(), '请先绑定老人账号，再帮助老人购物');
      RouteUtils.navigate(this.getUIContext(), 'pages/BindFamily');
      return;
    }
    this.refreshProducts();
  }

  private async refreshProducts(): Promise<void> {
    try {
      const result: BackendResult<ProductCandidate[]> = await AppBackendService.listProductsRemote();
      const allProducts: ProductCandidate[] = result.data ? result.data : [];
      const statusResult: BackendResult<ProductGatewayStatus> = AppBackendService.getProductGatewayStatus();
      if (statusResult.data) {
        this.productSourceText = statusResult.data.platforms.join(' / ') + ' · 平台商品网关';
      }
      this.products = allProducts.filter((item: ProductCandidate) => {
        if (item.platform === '公开API') {
          return true;
        }
        if (this.activeCategory === '鞋服出行') {
          return item.tags.indexOf('鞋') >= 0 || item.tags.indexOf('推车') >= 0;
        }
        if (this.activeCategory === '健康监测') {
          return item.tags.indexOf('血压计') >= 0 || item.tags.indexOf('药盒') >= 0;
        }
        if (this.activeCategory === '营养食品') {
          return item.tags.indexOf('奶粉') >= 0 || item.tags.indexOf('大米') >= 0;
        }
        if (this.activeCategory === '手机数码') {
          return item.tags.indexOf('手机') >= 0 || item.tags.indexOf('台灯') >= 0;
        }
        return item.tags.indexOf('暖脚器') >= 0 || item.tags.indexOf('毛毯') >= 0 || item.tags.indexOf('台灯') >= 0;
      });
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '加载商品失败，请稍后重试');
    }
  }

  private openProductDetail(product: ProductCandidate): void {
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/ProductDetail',
        params: {
          productId: product.id
        }
      });
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '页面跳转失败，请稍后重试');
    }
  }

  private get categoryColumnsTemplate(): string {
    switch (this.breakpoint) {
      case 'lg': return '1fr 1fr 1fr 1fr';
      case 'md': return '1fr 1fr 1fr';
      default: return '1fr 1fr';
    }
  }

  private get isCompact(): boolean {
    return true;
  }

  private formatCategorySales(sales: number): string {
    if (sales >= 10000) {
      return (sales / 10000).toFixed(1) + '万';
    }
    return sales.toString() + '件';
  }

  build() {
    Column() {
      Column({ space: 8 }) {
        Row() {
          Text('商品分类')
            .fontSize(this.careMode ? 28 : 22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#431407')
          Blank()
          Button('账号')
            .height(34)
            .fontSize(this.careMode ? 16 : 13)
            .fontColor('#2B7068')
            .backgroundColor('#EFFAF8')
            .borderRadius(8)
            .onClick(() => {
              RouteUtils.replacePage(this.getUIContext(), 'pages/Index');
            })
        }
        .width('100%')

        Text('按常用场景浏览商品。')
          .fontSize(this.careMode ? 17 : 13)
          .fontColor('#6F5B4B')
          .width('100%')
        Text(this.productSourceText)
          .fontSize(this.careMode ? 15 : 12)
          .fontColor('#6D6258')
          .width('100%')
      }
      .width('100%')
      .padding(14)
      .backgroundColor('#F3EFE8')

      // 平板端：顶部标签导航；手机端：左侧竖排导航
      if (this.breakpoint !== 'sm') {
        // 平板：顶部横排分类标签
        Scroll() {
          Row({ space: 6 }) {
            ForEach(this.categories, (item: string) => {
              Button(item)
                .height(this.careMode ? 44 : 36)
                .fontSize(this.careMode ? 18 : 15)
                .fontWeight(this.activeCategory === item ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(this.activeCategory === item ? '#FFFFFF' : '#5C5048')
                .backgroundColor(this.activeCategory === item ? '#2B7068' : '#FAF7F2')
                .borderRadius(8)
                .padding({ left: 16, right: 16 })
                .onClick(() => { this.activeCategory = item; this.refreshProducts(); })
            }, (item: string) => item)
          }
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        }
        .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
        .width('100%').backgroundColor('#FFFFFF')
      }

      Row() {
        if (this.breakpoint === 'sm') {
          // 手机：左侧竖排分类
          Column({ space: 6 }) {
            ForEach(this.categories, (item: string) => {
              Button(item)
                .width('100%')
                .height(this.careMode ? 58 : 48)
                .fontSize(this.careMode ? 18 : 14)
                .fontWeight(this.activeCategory === item ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(this.activeCategory === item ? '#2B7068' : '#5C5048')
                .backgroundColor(this.activeCategory === item ? Color.White : '#EEE8E0')
                .borderRadius(8)
                .onClick(() => { this.activeCategory = item; this.refreshProducts(); })
            }, (item: string) => item)
          }
          .width(108).height('100%').padding({ left: 8, right: 8, top: 10 })
          .backgroundColor('#EEE8E0')
        }

        Scroll() {
          Column({ space: 10 }) {
            Row() {
              Text(this.activeCategory)
                .fontSize(this.careMode ? 25 : 20).fontWeight(FontWeight.Bold).fontColor('#431407')
              Blank()
              Text(this.products.length.toString() + ' 件')
                .fontSize(this.careMode ? 16 : 13).fontColor('#2B7068')
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor('#EFFAF8').borderRadius(8)
            }.width('100%')

            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              ForEach(this.products, (item: ProductCandidate) => {
                ProductCard({
                  product: item, isBest: false, careMode: this.careMode, compact: true,
                  onSelect: (p: ProductCandidate) => { this.openProductDetail(p); },
                  onDetail: (p: ProductCandidate) => { this.openProductDetail(p); }
                })
                .width(this.breakpoint === 'sm' ? '50%' : (this.breakpoint === 'md' ? '25%' : '16.66%'))
                .padding({ left: 3, right: 3, top: 3, bottom: 3 })
              }, (item: ProductCandidate) => item.id)
            }.width('100%')
          }.width('100%').padding(12)
        }
        .layoutWeight(1).height('100%')
      }
      .width('100%').constraintSize({ maxWidth: 1200 }).layoutWeight(1)

      BottomNav({
        role: 'user',
        active: 'category',
        careMode: this.careMode,
        onNavigate: (url: string) => {
          RouteUtils.replacePage(this.getUIContext(), url);
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3EFE8')
  }
}
