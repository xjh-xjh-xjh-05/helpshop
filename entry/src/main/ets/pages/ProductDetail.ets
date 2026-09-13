import { CareModeToggle } from '../components/CareModeToggle';
import { BackendResult } from '../models/BackendModels';
import { ProductCandidate } from '../models/ShoppingModels';
import { AppBackendService } from '../services/AppBackendService';
import { ProductImageService } from '../services/ProductImageService';
import { TTSService } from '../services/TTSService';
import { LLMService } from '../services/LLMService';
import { CopilotConfig } from '../config/AppConfig';
import { AgentSessionManager } from '../agent/AgentSessionManager';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';
import { hilog } from '@kit.PerformanceAnalysisKit';

interface ProductDetailParams {
  productId?: string;
  productData?: string;
}

@Entry
@Component
struct ProductDetail {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('voicePromptEnabled') voicePromptEnabled: boolean = true;
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @State product: ProductCandidate = AppBackendService.getDefaultProduct();
  @State llmReview: string = '';
  @State llmLoading: boolean = false;
  @State quantity: number = 1;

  aboutToDisappear(): void {
    TTSService.getInstance().stop();
  }

  async aboutToAppear(): Promise<void> {
    TTSService.getInstance().setEnabled(this.voicePromptEnabled);
    const routerParams: ProductDetailParams = this.getUIContext().getRouter().getParams() as ProductDetailParams;
    if (routerParams?.productData && routerParams.productData.length > 0) {
      try {
        const parsed: ProductCandidate = JSON.parse(routerParams.productData) as ProductCandidate;
        if (parsed && parsed.id.length > 0) {
          this.product = parsed;
          this.loadLLMReview();
          this.speakProductIntro();
          return;
        }
      } catch (e) {
        hilog.error(0x0001, 'ProductDetail', 'Failed to parse productData from params');
      }
    }
    const productId: string = routerParams?.productId ?? '';
    if (productId.length > 0) {
      try {
        const result: BackendResult<ProductCandidate> = await AppBackendService.getProductByIdRemote(productId);
        if (result.success && result.data) {
          this.product = result.data;
          this.loadLLMReview();
          this.speakProductIntro();
        } else {
          RouteUtils.showToast(this.getUIContext(), result.message);
        }
      } catch (error) {
        RouteUtils.showToast(this.getUIContext(), '加载商品失败，请稍后重试');
      }
    }
  }

  private speakProductIntro(): void {
    if (!this.voicePromptEnabled) {
      return;
    }
    const fallback: string = '这是' + this.product.name + '，价格' + this.product.price.toFixed(0) + '元。';
    if (CopilotConfig.apiKey.trim().length > 0) {
      const systemPrompt: string =
        '你是HelpShop银发购物助手的语音播报模块。用一句简短温馨的话介绍当前商品，提醒老人可以查看详情或直接购买。' +
        '要求：1.口语化；2.不超过40字；3.不加引号或特殊符号；4.不要加拼音标注。';
      const userContext: string =
        '商品：' + this.product.name + '，价格：' + this.product.price.toFixed(0) + '元，评分：' +
        this.product.rating.toString() + '，平台：' + this.product.platform + '。';
      LLMService.getInstance().generateVoicePrompt(systemPrompt, userContext, fallback)
        .then((text: string) => {
          TTSService.getInstance().speak(text);
        })
        .catch(() => {
          TTSService.getInstance().speak(fallback);
        });
    } else {
      TTSService.getInstance().speak(fallback);
    }
  }

  private loadLLMReview(): void {
    if (CopilotConfig.apiKey.trim().length === 0) {
      this.llmReview = '配置大模型后可查看智能适老评价。';
      return;
    }
    this.llmLoading = true;
    const systemPrompt: string =
      '你是HelpShop银发购物助手的商品评价模块。根据商品信息，生成2-3条适合老人了解的商品亮点和注意事项。' +
      '要求：1.用通俗语言；2.重点标注适老友好点；3.如有不足也温和提醒；4.不加引号或编号符号；5.不超过80字。';
    const userContext: string =
      '商品名：' + this.product.name + '，价格：' + this.product.price.toFixed(0) + '元，评分：' +
      this.product.rating.toString() + '，销量：' + this.product.sales.toString() + '，标签：' +
      this.product.tags.join('、') + '，描述：' + this.product.description;
    LLMService.getInstance().generateVoicePrompt(systemPrompt, userContext, '暂无智能评价')
      .then((text: string) => {
        this.llmReview = text;
        this.llmLoading = false;
      })
      .catch(() => {
        this.llmReview = '暂无智能评价';
        this.llmLoading = false;
      });
  }

  private startCompare(): void {
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/CompareResult',
        params: {
          query: this.product.name
        }
      });
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '页面跳转失败，请稍后重试');
    }
  }

  private buyNow(): void {
    try {
      AgentSessionManager.setSelectedProduct(this.product, this.quantity);
      AppBackendService.selectProduct(this.product.id);
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/PaymentConfirm',
        params: {
          productId: this.product.id,
          quantity: this.quantity.toString()
        }
      });
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '页面跳转失败，请稍后重试');
    }
  }

  private addQuantity(): void {
    if (this.quantity < 99) {
      this.quantity += 1;
    }
  }

  private subQuantity(): void {
    if (this.quantity > 1) {
      this.quantity -= 1;
    }
  }

  private speakReview(): void {
    if (!this.voicePromptEnabled) {
      return;
    }
    if (this.llmReview.length > 0) {
      TTSService.getInstance().speak(this.llmReview);
    }
  }

  @Builder
  private ProductInfoColumn() {
    Column({ space: 10 }) {
      Row() {
        Text(this.product.platform)
          .fontSize(this.careMode ? 17 : 13)
          .fontColor('#2B7068')
          .fontWeight(FontWeight.Bold)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor('#EFFAF8')
          .borderRadius(8)
        if (this.product.tags.length > 0) {
          Text(this.product.tags[0])
            .fontSize(this.careMode ? 15 : 12)
            .fontColor('#6F5B4B')
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('#FAF7F2')
            .borderRadius(8)
            .margin({ left: 6 })
        }
        Blank()
        Text('销量 ' + this.product.sales.toString())
          .fontSize(this.careMode ? 16 : 13)
          .fontColor('#6D6258')
      }
      .width('100%')

      Text(this.product.name)
        .fontSize(this.careMode ? 30 : 24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#431407')
        .lineHeight(this.careMode ? 40 : 32)
        .width('100%')

      Text(this.product.shopName)
        .fontSize(this.careMode ? 18 : 14)
        .fontColor('#6D6258')
        .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(8)
  }

  @Builder
  private PriceQuantityColumn() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text('\u00A5' + this.product.price.toFixed(2))
          .fontSize(this.careMode ? 40 : 32)
          .fontWeight(FontWeight.Bold)
          .fontColor('#378F85')
        if (this.product.originalPrice && this.product.originalPrice > this.product.price) {
          Text('\u00A5' + this.product.originalPrice.toFixed(2))
            .fontSize(this.careMode ? 18 : 15)
            .fontColor('#9B8E82')
            .decoration({ type: TextDecorationType.LineThrough })
            .margin({ left: 4 })
        }
        Blank()
        Text('评分 ' + this.product.rating.toString())
          .fontSize(this.careMode ? 18 : 15)
          .fontColor('#5C5048')
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor('#FAF7F2')
          .borderRadius(8)
      }
      .width('100%')

      Row() {
        Text('推荐指数')
          .fontSize(this.careMode ? 18 : 14)
          .fontColor('#5C5048')
        Text(this.product.recommendScore.toString() + '/100')
          .fontSize(this.careMode ? 18 : 14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2B7068')
          .margin({ left: 6 })
        Blank()
        Row() {
          Button('-')
            .width(this.careMode ? 40 : 34)
            .height(this.careMode ? 40 : 34)
            .fontSize(this.careMode ? 20 : 17)
            .fontColor('#2B7068')
            .backgroundColor('#EFFAF8')
            .borderRadius(8)
            .onClick(() => {
              this.subQuantity();
            })
          Text(this.quantity.toString())
            .width(this.careMode ? 48 : 40)
            .textAlign(TextAlign.Center)
            .fontSize(this.careMode ? 20 : 17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#431407')
          Button('+')
            .width(this.careMode ? 40 : 34)
            .height(this.careMode ? 40 : 34)
            .fontSize(this.careMode ? 20 : 17)
            .fontColor('#2B7068')
            .backgroundColor('#EFFAF8')
            .borderRadius(8)
            .onClick(() => {
              this.addQuantity();
            })
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(8)
  }

  @Builder
  private DetailSections() {
    Column({ space: 14 }) {
      Column({ space: 10 }) {
        Text('适老标签')
          .fontSize(this.careMode ? 22 : 18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#431407')
          .width('100%')
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach(this.product.tags, (tag: string) => {
            Text(tag)
              .fontSize(this.careMode ? 16 : 13)
              .fontColor('#2B7068')
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .backgroundColor('#EFFAF8')
              .borderRadius(8)
              .margin({ right: 8, bottom: 8 })
          }, (tag: string) => tag)
        }
        .width('100%')
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Color.White)
      .borderRadius(8)

      Column({ space: 10 }) {
        Text('商品详情')
          .fontSize(this.careMode ? 22 : 18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#431407')
          .width('100%')
        if (this.product.specs && this.product.specs.length > 0) {
          Text('规格：' + this.product.specs)
            .fontSize(this.careMode ? 18 : 14)
            .fontColor('#5C5048')
            .lineHeight(this.careMode ? 28 : 22)
            .width('100%')
        }
        Text(this.product.description)
          .fontSize(this.careMode ? 20 : 16)
          .fontColor('#333333')
          .lineHeight(this.careMode ? 32 : 26)
          .width('100%')
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Color.White)
      .borderRadius(8)

      Column({ space: 10 }) {
        Row() {
          Text('AI 适老评价')
            .fontSize(this.careMode ? 22 : 18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#431407')
          Blank()
          if (this.llmReview.length > 0) {
            Button('播报')
              .height(this.careMode ? 36 : 30)
              .fontSize(this.careMode ? 15 : 12)
              .fontColor('#2B7068')
              .backgroundColor('#EFFAF8')
              .borderRadius(8)
              .onClick(() => {
                this.speakReview();
              })
          }
        }
        .width('100%')

        if (this.llmLoading) {
          Row({ space: 8 }) {
            LoadingProgress()
              .width(this.careMode ? 24 : 20)
              .height(this.careMode ? 24 : 20)
              .color('#2B7068')
            Text('AI 正在分析商品适老情况...')
              .fontSize(this.careMode ? 18 : 14)
              .fontColor('#6D6258')
          }
          .width('100%')
        } else {
          Text(this.llmReview.length > 0 ? this.llmReview : '暂无智能评价')
            .fontSize(this.careMode ? 18 : 14)
            .fontColor('#5C5048')
            .lineHeight(this.careMode ? 28 : 22)
            .width('100%')
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FAF7F2')
      .borderRadius(8)
      .border({ width: 1, color: '#E8DDD2' })
    }
    .width('100%')
  }

  build() {
    Column() {
      Row() {
        Button('返回')
          .height(38)
          .fontSize(this.careMode ? 18 : 15)
          .fontColor('#2B7068')
          .backgroundColor('#EFFAF8')
          .borderRadius(8)
          .onClick(() => {
            RouteUtils.goBack(this.getUIContext());
          })
        Blank()
        Text('商品详情')
          .fontSize(this.careMode ? 22 : 18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#431407')
        Blank()
        Row({ space: 12 }) {
          Row({ space: 6 }) {
            Text('语音')
              .fontSize(this.careMode ? 14 : 12)
              .fontColor(this.voicePromptEnabled ? '#2B7068' : '#6D6258')
            Toggle({ type: ToggleType.Switch, isOn: this.voicePromptEnabled })
              .width(this.careMode ? 48 : 40)
              .height(this.careMode ? 28 : 24)
              .selectedColor('#378F85')
              .onChange((isOn: boolean) => {
                this.voicePromptEnabled = isOn;
                TTSService.getInstance().setEnabled(isOn);
              })
          }
          CareModeToggle()
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 10 })
      .backgroundColor('#F3EFE8')

      Scroll() {
        if (this.breakpoint === 'sm') {
          Column({ space: 14 }) {
            Image(ProductImageService.getImage(this.product))
              .width('100%')
              .height(this.careMode ? 320 : 260)
              .objectFit(ImageFit.Contain)
              .backgroundColor(Color.White)
              .borderRadius(8)
            this.ProductInfoColumn()
            this.PriceQuantityColumn()
            this.DetailSections()
          }
          .width('100%')
          .padding({ left: 14, right: 14, bottom: 90 })
        } else {
          Column({ space: 14 }) {
            Row({ space: 14 }) {
              Image(ProductImageService.getImage(this.product))
                .width('40%')
                .height(this.careMode ? 360 : 300)
                .objectFit(ImageFit.Contain)
                .backgroundColor(Color.White)
                .borderRadius(8)
              Column({ space: 14 }) {
                this.ProductInfoColumn()
                this.PriceQuantityColumn()
              }
              .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
            this.DetailSections()
          }
          .width('100%')
          .constraintSize({ maxWidth: 840 })
          .padding({ left: 14, right: 14, bottom: 90 })
        }
      }
      .layoutWeight(1)

      Row({ space: 10 }) {
        Button('智能比价')
          .layoutWeight(1)
          .height(this.careMode ? 56 : 48)
          .fontSize(this.careMode ? 19 : 16)
          .fontColor('#2B7068')
          .backgroundColor('#EFFAF8')
          .borderRadius(8)
          .onClick(() => {
            this.startCompare();
          })
        Button('立即购买')
          .layoutWeight(1)
          .height(this.careMode ? 56 : 48)
          .fontSize(this.careMode ? 19 : 16)
          .fontColor(Color.White)
          .backgroundColor('#378F85')
          .borderRadius(8)
          .onClick(() => {
            this.buyNow();
          })
      }
      .width('100%')
      .constraintSize({ maxWidth: this.breakpoint === 'sm' ? 10000 : 840 })
      .padding({ left: 14, right: 14, top: 10, bottom: 12 })
      .backgroundColor(Color.White)
      .border({ width: { top: 1 }, color: '#E8DDD2' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3EFE8')
  }
}
