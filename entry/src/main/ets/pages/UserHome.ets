import { BottomNav } from '../components/BottomNav';
import { CareModeToggle } from '../components/CareModeToggle';
import { HandwriteGuideDialog } from '../components/HandwriteGuideDialog';
import { AccountRole } from '../models/AuthModels';
import { BackendResult } from '../models/BackendModels';
import { ProductCandidate } from '../models/ShoppingModels';
import { AppBackendService } from '../services/AppBackendService';
import { ProductImageService } from '../services/ProductImageService';
import { SpeechService } from '../services/SpeechService';
import { TTSService } from '../services/TTSService';
import { PermissionUtils } from '../utils/PermissionUtils';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';
import { ProductCard } from '../components/ProductCard';
import { hilog } from '@kit.PerformanceAnalysisKit';

interface ScoredProduct {
  product: ProductCandidate;
  score: number;
}

@Entry
@Component
struct UserHome {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('hasShownHandwriteGuide') hasShownHandwriteGuide: boolean = false;
  @StorageLink('voicePromptEnabled') voicePromptEnabled: boolean = true;
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @State query: string = '';
  @State voicePanelVisible: boolean = false;
  @State voiceRecognizing: boolean = false;
  @State voiceTranscript: string = '';
  @State voicePartialText: string = '';
  @State speechReady: boolean = false;
  @State speechInitializing: boolean = false;
  @State speechError: string = '';
  private pendingVoiceStart: boolean = false;
  @State featuredProducts: ProductCandidate[] = [];
  @State productSourceText: string = '拼多多商品加载中...';
  @State activeCategory: string = '推荐';
  private guideOpened: boolean = false;
  private lastBackTime: number = 0;
  private readonly categories: string[] = ['推荐', '健康保健', '食品营养', '居家生活', '鞋服出行'];
  private readonly categoryKeywords: Record<string, string[]> = {
    '推荐': ['保健', '食品', '居家', '鞋', '老人', '血压', '营养', '养生'],
    '健康保健': ['保健', '血压', '血糖', '按摩', '理疗', '药', '养生', '护腰', '护膝', '体温', '制氧'],
    '食品营养': ['牛奶', '奶粉', '麦片', '杂粮', '蜂蜜', '核桃', '红枣', '枸杞', '芝麻', '糕点', '豆奶'],
    '居家生活': ['保温', '暖脚', '收纳', '清洁', '防滑', '坐垫', '被子', '枕头', '风扇', '电热水壶'],
    '鞋服出行': ['鞋', '防滑', '棉服', '外套', '冲锋衣', '遮阳帽', '护膝', '手套', '围巾']
  };
  private speechService: SpeechService = SpeechService.getInstance();
  private guideController: CustomDialogController = new CustomDialogController({
    builder: HandwriteGuideDialog({
      onConfirm: () => {
        this.hasShownHandwriteGuide = true;
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: false
  });

  aboutToAppear(): void {
    TTSService.getInstance().setEnabled(this.voicePromptEnabled);
    const role = AppBackendService.getCurrentRole();
    if (role === AccountRole.Unverified) {
      RouteUtils.pushPage(this.getUIContext(), 'pages/IdentityAuth');
      return;
    }
    if (!AppBackendService.canEnterShopping()) {
      RouteUtils.showToast(this.getUIContext(), '请先绑定老人账号，再帮助老人购物');
      RouteUtils.pushPage(this.getUIContext(), 'pages/BindFamily');
      return;
    }
    this.loadFeaturedProducts();
  }

  onPageHide(): void {
    TTSService.getInstance().stop();
  }

  onPageShow(): void {
    TTSService.getInstance().setEnabled(this.voicePromptEnabled);
    if (this.voicePromptEnabled && this.featuredProducts.length > 0) {
      TTSService.getInstance().speak('首页已加载，您可以浏览商品或点击麦克风说出想买的东西。');
    }
  }

  onBackPress(): boolean {
    const context = this.getUIContext();
    try {
      context.getPromptAction().showToast({ message: '再按一次退出应用' });
    } catch (e) {
    }
    if (this.lastBackTime > 0 && Date.now() - this.lastBackTime < 2000) {
      return false;
    }
    this.lastBackTime = Date.now();
    return true;
  }

  private filterForElderly(products: ProductCandidate[]): ProductCandidate[] {
    const elderlyKeywords: string[] = [
      '保健', '养生', '老人', '老年', '血压', '血糖', '按摩', '理疗',
      '牛奶', '奶粉', '麦片', '杂粮', '蜂蜜', '核桃', '红枣', '枸杞',
      '芝麻', '糕点', '豆奶', '营养', '补钙', '维生素',
      '保温', '暖脚', '防滑', '坐垫', '被子', '枕头', '收纳',
      '鞋', '棉服', '外套', '冲锋衣', '遮阳', '护膝', '手套',
      '药', '制氧', '体温', '护腰', '电热水壶', '风扇',
      '酱', '醋', '米', '面', '油', '茶', '水果', '零食',
      '洗衣', '清洁', '拖把', '纸巾', '毛巾', '牙刷',
      '手机', '收音机', '放大镜', '手电筒'
    ];
    const scored: ScoredProduct[] = products.map((item: ProductCandidate): ScoredProduct => {
      let score: number = 0;
      const text: string = item.name + ' ' + item.description + ' ' + item.tags.join(' ');
      for (let i: number = 0; i < elderlyKeywords.length; i += 1) {
        if (text.indexOf(elderlyKeywords[i]) >= 0) {
          score += 10;
        }
      }
      if (item.price < 50) {
        score += 5;
      } else if (item.price < 100) {
        score += 3;
      }
      if (item.sales > 10000) {
        score += 5;
      } else if (item.sales > 1000) {
        score += 2;
      }
      if (item.tags.indexOf('有券') >= 0) {
        score += 3;
      }
      const result: ScoredProduct = { product: item, score: score };
      return result;
    });
    scored.sort((a: ScoredProduct, b: ScoredProduct) => b.score - a.score);
    return scored.map((item: ScoredProduct) => item.product);
  }

  private formatSales(sales: number): string {
    if (sales >= 10000) {
      return (sales / 10000).toFixed(1) + '万';
    }
    return sales.toString() + '件';
  }

  private filterByCategory(category: string): ProductCandidate[] {
    return this.featuredProducts;
  }

  private async loadCategoryProducts(category: string): Promise<void> {
    if (category === '推荐') {
      this.loadFeaturedProducts();
      return;
    }
    this.query = '';
    this.productSourceText = '加载中...';
    try {
      hilog.info(0x0001, 'UserHome', 'loadCategoryProducts: ' + category);
      const pddResult: BackendResult<ProductCandidate[]> = await AppBackendService.refreshProductsFromPublicApi(category, 10);
      hilog.info(0x0001, 'UserHome', 'loadCategoryProducts result: success=' + pddResult.success + ' count=' + (pddResult.data ? pddResult.data.length : 0) + ' msg=' + pddResult.message);
      if (pddResult.data && pddResult.data.length > 0) {
        const filtered: ProductCandidate[] = this.filterForElderly(pddResult.data);
        if (filtered.length > 0) {
          this.featuredProducts = filtered;
        } else {
          this.featuredProducts = pddResult.data;
        }
        this.productSourceText = pddResult.message || ('多平台·' + category);
        if (this.voicePromptEnabled) {
          TTSService.getInstance().speak(category + '分类已加载' + this.featuredProducts.length.toString() + '款商品。');
        }
        return;
      }
      this.productSourceText = pddResult.message || '暂无商品数据';
      return;
    } catch (error) {
      hilog.error(0x0001, 'UserHome', 'loadCategoryProducts error: ' + JSON.stringify(error));
      this.productSourceText = '加载出错';
    }
  }

  private async loadFeaturedProducts(): Promise<void> {
    try {
      hilog.info(0x0001, 'UserHome', 'loadFeaturedProducts start');
      const pddResult: BackendResult<ProductCandidate[]> = await AppBackendService.refreshProductsFromPublicApi('推荐', 10);
      hilog.info(0x0001, 'UserHome', 'loadFeaturedProducts result: success=' + pddResult.success + ' count=' + (pddResult.data ? pddResult.data.length : 0) + ' msg=' + pddResult.message);
      if (pddResult.data && pddResult.data.length > 0) {
        this.featuredProducts = this.filterForElderly(pddResult.data);
        this.productSourceText = pddResult.message || '多平台推荐商品数据';
        if (this.voicePromptEnabled) {
          TTSService.getInstance().speak('为您推荐了' + this.featuredProducts.length.toString() + '款商品，点击可查看详情。');
        }
        return;
      }
    } catch (error) {
      hilog.error(0x0001, 'UserHome', 'loadFeaturedProducts error');
    }
    if (this.featuredProducts.length === 0) {
      const localResult: BackendResult<ProductCandidate[]> = AppBackendService.getFeaturedProducts(8);
      if (localResult.data) {
        this.featuredProducts = localResult.data;
        this.productSourceText = '本地模拟商品数据';
        hilog.info(0x0001, 'UserHome', 'loadFeaturedProducts fallback to mock, count=' + localResult.data.length);
      }
    }
  }

  private openGuide(): void {
    if (!this.hasShownHandwriteGuide) {
      this.guideController.open();
    }
  }

  private async startCompare(): Promise<void> {
    const value = this.query.trim();
    if (value.length === 0) {
      RouteUtils.showToast(this.getUIContext(), '请先输入想买的商品');
      return;
    }
    try {
      const pddResult: BackendResult<ProductCandidate[]> = await AppBackendService.refreshProductsFromPublicApi(value, 10);
      if (pddResult.data && pddResult.data.length > 0) {
        this.featuredProducts = pddResult.data;
        this.productSourceText = '多平台搜索结果';
      }
    } catch (error) {
      // Search fails, continue
    }
    try {
      const result = await AppBackendService.startCompareRemote(value);
      if (!result.success) {
        RouteUtils.showToast(this.getUIContext(), result.message);
        return;
      }
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/CompareResult',
        params: {
          query: value
        }
      });
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '页面跳转失败，请稍后重试');
    }
  }

  private toggleVoicePanel(): void {
    this.voicePanelVisible = !this.voicePanelVisible;
  }

  private initSpeech(): void {
    this.speechInitializing = true;
    this.speechError = '';
    this.speechService.init({
      onResult: (text: string, isFinal: boolean) => {
        if (isFinal) {
          this.voiceTranscript = text;
          this.voicePartialText = '';
          this.voiceRecognizing = false;
          this.query = text;
        } else {
          this.voicePartialText = text;
        }
      },
      onError: (errorCode: number, errorMessage: string) => {
        this.voiceRecognizing = false;
        this.speechInitializing = false;
        this.pendingVoiceStart = false;
        this.speechError = '识别失败(' + errorCode.toString() + ')';
      },
      onStart: () => {
        this.voiceRecognizing = true;
        this.voicePartialText = '';
        this.voiceTranscript = '';
      },
      onComplete: () => {
        this.voiceRecognizing = false;
      },
      onReady: () => {
        this.speechReady = true;
        this.speechInitializing = false;
        this.speechError = '';
        if (this.pendingVoiceStart) {
          this.pendingVoiceStart = false;
          this.speechService.startListening();
        }
      }
    });
  }

  private async startVoiceRecognition(): Promise<void> {
    try {
      const hasPermission = await PermissionUtils.requestMicPermission(this.getUIContext());
      if (!hasPermission) {
        return;
      }
      if (this.speechService.isReady()) {
        this.speechService.startListening();
      } else if (!this.speechInitializing && this.speechError.length === 0) {
        this.pendingVoiceStart = true;
        this.initSpeech();
      } else if (this.speechInitializing) {
        this.pendingVoiceStart = true;
      }
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '语音识别启动异常，请稍后重试');
    }
  }

  private stopVoiceRecognition(): void {
    this.pendingVoiceStart = false;
    if (this.voiceRecognizing) {
      this.speechService.stopListening();
    } else if (this.speechInitializing) {
      this.speechService.cancelListening();
      this.speechInitializing = false;
    }
  }

  private useVoiceTranscript(): void {
    const text: string = this.voiceTranscript.length > 0 ? this.voiceTranscript : this.voicePartialText;
    if (text.length === 0) {
      RouteUtils.showToast(this.getUIContext(), '请先进行语音识别');
      return;
    }
    this.query = text;
    this.startCompare();
  }

  private buyProduct(product: ProductCandidate): void {
    try {
      AppBackendService.selectProduct(product.id);
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/PaymentConfirm',
        params: {
          productId: product.id,
          quantity: '1'
        }
      });
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '页面跳转失败，请稍后重试');
    }
  }

  private openProductDetail(product: ProductCandidate): void {
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/ProductDetail',
        params: {
          productId: product.id,
          productData: JSON.stringify(product)
        }
      });
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '页面跳转失败，请稍后重试');
    }
  }

  @Builder
  private VoicePanel() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 4 }) {
          Text('语音购物')
            .fontSize(this.careMode ? 22 : 18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#431407')
          Text('按住说话，松开结束识别')
            .fontSize(this.careMode ? 16 : 13)
            .fontColor('#6D6258')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text(this.voiceRecognizing ? '识别中...' : (this.voiceTranscript.length > 0 ? '已识别' : '待识别'))
          .fontSize(this.careMode ? 15 : 12)
          .fontColor('#2B7068')
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor('#EFFAF8')
          .borderRadius(8)
      }
      .width('100%')

      Text(this.voiceRecognizing && this.voicePartialText.length > 0 ? this.voicePartialText : (this.voiceTranscript.length > 0 ? this.voiceTranscript : '语音内容将显示在这里'))
        .fontSize(this.careMode ? 20 : 16)
        .fontColor(this.voiceTranscript.length > 0 || this.voicePartialText.length > 0 ? '#431407' : '#B0A898')
        .lineHeight(this.careMode ? 30 : 24)
        .width('100%')
        .padding(12)
        .backgroundColor(Color.White)
        .borderRadius(8)
        .border({ width: 1, color: '#E8DDD2' })

      if (this.speechError.length > 0) {
        Text(this.speechError)
          .fontSize(this.careMode ? 16 : 13)
          .fontColor('#378F85')
          .width('100%')
      }

      Row({ space: 10 }) {
        Button(this.speechInitializing ? '初始化中...' : (this.voiceRecognizing ? '松开结束' : '按住说话'))
          .layoutWeight(1)
          .height(this.careMode ? 48 : 40)
          .fontSize(this.careMode ? 17 : 14)
          .fontColor(Color.White)
          .backgroundColor(this.voiceRecognizing ? '#2B7068' : '#378F85')
          .borderRadius(8)
          .enabled(!this.speechInitializing)
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.startVoiceRecognition();
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.stopVoiceRecognition();
            }
          })
        Button('使用转写比价')
          .layoutWeight(1)
          .height(this.careMode ? 48 : 40)
          .fontSize(this.careMode ? 17 : 14)
          .fontColor(Color.White)
          .backgroundColor('#378F85')
          .borderRadius(8)
          .enabled(this.voiceTranscript.length > 0 || this.voicePartialText.length > 0)
          .onClick(() => {
            this.useVoiceTranscript();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FAF7F2')
    .borderRadius(8)
    .border({ width: 1, color: '#E8DDD2' })
  }

  private get columnsTemplate(): string {
    switch (this.breakpoint) {
      case 'lg': return '1fr 1fr 1fr 1fr 1fr 1fr';
      case 'md': return '1fr 1fr 1fr 1fr';
      default: return '1fr 1fr';
    }
  }

  private get isCompact(): boolean {
    return true;
  }

  build() {
    Column() {
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Row({ space: 4 }) {
            Text('银发智购')
              .fontSize(this.careMode ? 20 : 16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F5E6D3')
            Text('语音购物更省心')
              .fontSize(this.careMode ? 16 : 12)
              .fontColor('#FFFFFF')
              .opacity(0.85)
          }
          Blank()
          CareModeToggle()
        }
        .width('100%')

        Row({ space: 6 }) {
          TextInput({ placeholder: '搜索商品或输入需求', text: $$this.query })
            .layoutWeight(1)
            .height(this.careMode ? 52 : 44)
            .fontSize(this.careMode ? 18 : 15)
            .backgroundColor('#FFFFFF')
            .borderRadius(20)
            .padding({ left: 16, right: 16 })
            .onClick(() => {
              this.openGuide();
            })
          Button('搜索')
            .width(this.careMode ? 72 : 60)
            .height(this.careMode ? 52 : 44)
            .fontSize(this.careMode ? 16 : 14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#2B7068')
            .backgroundColor('#F5E6D3')
            .borderRadius(20)
            .onClick(() => {
              this.startCompare();
            })
        }
        .width('100%')

        Row({ space: 12 }) {
          Row({ space: 6 }) {
            Text('语音')
              .fontSize(this.careMode ? 14 : 12)
              .fontColor(this.voicePromptEnabled ? '#FFFFFF' : '#FFFFFF99')
            Toggle({ type: ToggleType.Switch, isOn: this.voicePromptEnabled })
              .width(this.careMode ? 48 : 40)
              .height(this.careMode ? 28 : 24)
              .selectedColor('#F5E6D3')
              .onChange((isOn: boolean) => {
                this.voicePromptEnabled = isOn;
                TTSService.getInstance().setEnabled(isOn);
              })
          }
          Button('🎤 语音')
            .height(this.careMode ? 38 : 32)
            .fontSize(this.careMode ? 14 : 12)
            .fontColor('#FFFFFF')
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: '#FFFFFF', radius: 16 })
            .onClick(() => {
              this.toggleVoicePanel();
            })
          Text(this.productSourceText)
            .fontSize(this.careMode ? 13 : 11)
            .fontColor('#FFFFFF')
            .opacity(0.8)
            .layoutWeight(1)
        }
        .width('100%')

        if (this.voicePanelVisible) {
          this.VoicePanel()
        }
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 10 })
      .linearGradient({
        direction: GradientDirection.Right,
        colors: [['#2B7068', 0], ['#378F85', 1]]
      })

      Scroll() {
        Column({ space: 0 }) {
          Scroll() {
            Row({ space: this.breakpoint === 'sm' ? 0 : 8 }) {
              ForEach(this.categories, (cat: string) => {
                if (this.breakpoint === 'sm') {
                  // 手机：文字+下划线
                  Column() {
                    Text(cat)
                      .fontSize(this.careMode ? 17 : 14)
                      .fontWeight(this.activeCategory === cat ? FontWeight.Bold : FontWeight.Normal)
                      .fontColor(this.activeCategory === cat ? '#378F85' : '#6B4E3D')
                    if (this.activeCategory === cat) {
                      Row().width(20).height(3).backgroundColor('#378F85').borderRadius(2).margin({ top: 4 })
                    }
                  }
                  .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                  .onClick(() => { this.activeCategory = cat; this.loadCategoryProducts(cat); })
                } else {
                  // 平板：胶囊按钮
                  Button(cat)
                    .height(this.careMode ? 44 : 36)
                    .fontSize(this.careMode ? 18 : 15)
                    .fontWeight(this.activeCategory === cat ? FontWeight.Bold : FontWeight.Medium)
                    .fontColor(this.activeCategory === cat ? '#FFFFFF' : '#5C5048')
                    .backgroundColor(this.activeCategory === cat ? '#2B7068' : '#FAF7F2')
                    .borderRadius(8)
                    .padding({ left: 16, right: 16 })
                    .onClick(() => { this.activeCategory = cat; this.loadCategoryProducts(cat); })
                }
              }, (cat: string) => cat)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          .backgroundColor(this.breakpoint === 'sm' ? Color.White : '#FFFFFF')
          .padding(this.breakpoint === 'sm' ? { top: 4, bottom: 4 } : { left: 12, right: 12, top: 8, bottom: 8 })

          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(this.filterByCategory(this.activeCategory), (item: ProductCandidate) => {
              ProductCard({
                product: item,
                isBest: false,
                careMode: this.careMode,
                compact: true,
                onSelect: (product: ProductCandidate) => {
                  this.openProductDetail(product);
                },
                onDetail: (product: ProductCandidate) => {
                  this.openProductDetail(product);
                }
              })
              .width(this.breakpoint === 'sm' ? '50%' : (this.breakpoint === 'md' ? '25%' : '16.66%'))
              .padding({ left: 3, right: 3, top: 3, bottom: 3 })
            }, (item: ProductCandidate) => item.id)
          }
          .width('100%')
          .padding({ left: 5, right: 5, top: 8 })
        }
        .width('100%')
        .onAppear(() => {
          if (!this.hasShownHandwriteGuide && !this.guideOpened) {
            this.guideOpened = true;
            this.openGuide();
          }
        })
      }
      .layoutWeight(1)

      BottomNav({
        role: 'user',
        active: 'home',
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
