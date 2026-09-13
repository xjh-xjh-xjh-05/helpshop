import { CareModeToggle } from '../components/CareModeToggle';
import { ProductCard } from '../components/ProductCard';
import { BackendResult, CompareBackendData } from '../models/BackendModels';
import { ProductGatewayStatus } from '../models/PlatformModels';
import { ProductCandidate, RecommendationResult } from '../models/ShoppingModels';
import { AppBackendService } from '../services/AppBackendService';
import { SpeechService } from '../services/SpeechService';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TTSService } from '../services/TTSService';
import { LLMService } from '../services/LLMService';
import { CopilotConfig } from '../config/AppConfig';
import { AgentSessionManager } from '../agent/AgentSessionManager';
import { PermissionUtils } from '../utils/PermissionUtils';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';

interface CompareParams {
  query?: string;
}

@Entry
@Component
struct CompareResult {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('voicePromptEnabled') voicePromptEnabled: boolean = true;
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @State query: string = '我想买一双不累脚的鞋';
  @State commandText: string = '买第一个';
  @State commandMessage: string = '';
  @State result: RecommendationResult = AppBackendService.getDemoRecommendation();
  @State productSourceText: string = '多平台商品网关';
  @State supplementQuestions: string[] = [];
  @State commandListening: boolean = false;
  @State commandInitializing: boolean = false;
  private pendingCommandStart: boolean = false;
  private speechService: SpeechService = SpeechService.getInstance();

  async aboutToAppear(): Promise<void> {
    TTSService.getInstance().setEnabled(this.voicePromptEnabled);
    const routerParams: CompareParams = this.getUIContext().getRouter().getParams() as CompareParams;
    const queryParam: string = routerParams?.query ?? '';
    if (queryParam.length > 0) {
      this.query = queryParam;
      try {
        const compareResult: BackendResult<CompareBackendData> = await AppBackendService.startCompareRemote(this.query);
        if (compareResult.success && compareResult.data) {
          this.result = compareResult.data.recommendation;
          this.commandText = '买第一个';
          this.speakRecommendation();
        } else {
          const failFallback: string = '未找到"' + this.query + '"的相关商品，请尝试其他关键词。';
          if (CopilotConfig.apiKey.trim().length > 0) {
            this.speakLLM('用户想买"' + this.query + '"但搜索失败，请温柔地告诉老人并建议换个说法。', failFallback);
          } else {
            TTSService.getInstance().speak(failFallback);
          }
          RouteUtils.showToast(this.getUIContext(), compareResult.message);
        }
      } catch (error) {
        const errFallback: string = '比价加载失败，请稍后重试。';
        if (CopilotConfig.apiKey.trim().length > 0) {
          this.speakLLM('用户想买"' + this.query + '"但系统出错，请温柔地告诉老人稍后再试。', errFallback);
        } else {
          TTSService.getInstance().speak(errFallback);
        }
        RouteUtils.showToast(this.getUIContext(), errFallback);
      }
    } else {
      this.speakRecommendation();
    }
    const questions: string[] = AppBackendService.getAgentSupplementQuestions(this.query);
    this.supplementQuestions = questions;
    const statusResult: BackendResult<ProductGatewayStatus> = AppBackendService.getProductGatewayStatus();
    if (statusResult.data) {
      this.productSourceText = statusResult.data.platforms.join(' / ') + ' · 商品接口已对接前端显示';
    }
  }

  private speakRecommendation(): void {
    const best: ProductCandidate = this.result.bestProduct;
    hilog.info(0x0001, 'CompareResult', 'speakRecommendation called, best=%{public}s, candidates=%{public}d',
      best ? best.name : 'null', this.result.candidates.length);
    if (!best || best.name.length === 0 || this.result.candidates.length === 0) {
      const fallbackText: string = '抱歉，未找到"' + this.query + '"的相关商品，请换个说法再试试。';
      if (CopilotConfig.apiKey.trim().length > 0) {
        this.speakLLM('用户想买"' + this.query + '"但未找到匹配商品，请温柔地告诉老人，建议换个说法或换个商品。', fallbackText);
      } else {
        TTSService.getInstance().speak(fallbackText);
      }
      return;
    }
    const productInfo: string = '找到' + this.result.candidates.length.toString() + '款商品，' +
      '推荐' + best.name + '，价格' + best.price.toFixed(0) + '元。';
    const fallbackText: string = '为您找到' + this.result.candidates.length.toString() + '款' +
      this.query + '相关商品，推荐' + best.name + '，价格' + best.price.toFixed(0) + '元。您可以说买第一个、买第二个来选择。';
    if (CopilotConfig.apiKey.trim().length > 0) {
      this.speakLLM('用户想买"' + this.query + '"，' + productInfo + '请生成简短温馨的语音播报，提醒可以说买第一个买第二个来选择。', fallbackText);
    } else {
      RouteUtils.showToast(this.getUIContext(), fallbackText);
      TTSService.getInstance().speak(fallbackText);
    }
  }

  private speakLLM(userContext: string, fallbackText: string): void {
    const systemPrompt: string =
      '你是HelpShop银发购物助手的语音播报模块。根据商品搜索结果，生成一句简洁温馨的语音播报文字。' +
      '要求：1.口语化，适合老人听；2.不超过60字；3.不要加引号或特殊符号；4.直接输出播报内容，不加前缀；' +
      '5.对多音字用拼音标注，格式为：字[=拼音+声调数字]，例如：着[=zhuo2]手、教[=jiao4]育、重[=zhong4]要。';
    LLMService.getInstance().generateVoicePrompt(systemPrompt, userContext, fallbackText)
      .then((llmText: string) => {
        hilog.info(0x0001, 'CompareResult', 'LLM TTS: %{public}s', llmText);
        RouteUtils.showToast(this.getUIContext(), llmText);
        TTSService.getInstance().speak(llmText);
      });
  }

  private get compareColumnsTemplate(): string {
    switch (this.breakpoint) {
      case 'lg': return '1fr 1fr 1fr 1fr 1fr';
      case 'md': return '1fr 1fr 1fr 1fr';
      default: return '1fr 1fr';
    }
  }

  private openDetail(product: ProductCandidate): void {
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

  private selectProduct(product: ProductCandidate, quantity?: number): void {
    try {
      const qty: number = quantity ? quantity : this.result.intent.quantity;
      AgentSessionManager.setSelectedProduct(product, qty);
      AppBackendService.selectProduct(product.id);
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/PaymentConfirm',
        params: {
          productId: product.id,
          quantity: (quantity ? quantity : this.result.intent.quantity).toString()
        }
      });
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '页面跳转失败，请稍后重试');
    }
  }

  private confirmByCommand(): void {
    if (this.result.candidates.length === 0) {
      this.commandMessage = '暂无可选商品';
      RouteUtils.showToast(this.getUIContext(), this.commandMessage);
      return;
    }
    // 本地解析"买第一个/二个/三个"等指令，无需网络
    const commandText: string = this.commandText.trim();
    let index = 0;
    if (commandText.indexOf('第三') >= 0 || commandText.indexOf('第3') >= 0) {
      index = 2;
    } else if (commandText.indexOf('第二') >= 0 || commandText.indexOf('第2') >= 0) {
      index = 1;
    }
    if (index >= this.result.candidates.length) {
      index = 0;
    }
    let quantity = 1;
    // 提取数量：两件/双、三件/双
    if (commandText.indexOf('两') >= 0 || commandText.indexOf('2') >= 0) {
      quantity = 2;
    } else if (commandText.indexOf('三') >= 0 || commandText.indexOf('3') >= 0) {
      quantity = 3;
    }
    const product: ProductCandidate = this.result.candidates[index];
    this.commandMessage = '已选择 ' + product.name + '，数量 ' + quantity.toString();
    TTSService.getInstance().speak(
      '已选择' + product.name + '，' + quantity.toString() + '件。即将进入支付页面。'
    );
    RouteUtils.showToast(this.getUIContext(), this.commandMessage);
    this.selectProduct(product, quantity);
  }

  private initCommandSpeech(): void {
    this.commandInitializing = true;
    this.commandMessage = '';
    this.speechService.init({
      onResult: (text: string, isFinal: boolean) => {
        if (isFinal) {
          this.commandText = text;
          this.commandListening = false;
          // 一键化：语音识别完成后自动执行指令确认
          if (text.length > 0 && (text.indexOf('买第') >= 0 || text.indexOf('第一') >= 0 || text.indexOf('第二') >= 0 || text.indexOf('第三') >= 0)) {
            this.confirmByCommand();
          }
        }
      },
      onError: (errorCode: number, errorMessage: string) => {
        this.commandListening = false;
        this.commandInitializing = false;
        this.pendingCommandStart = false;
        this.commandMessage = '语音识别失败';
      },
      onStart: () => {
        this.commandListening = true;
      },
      onComplete: () => {
        this.commandListening = false;
      },
      onReady: () => {
        this.commandInitializing = false;
        this.commandMessage = '';
        if (this.pendingCommandStart) {
          this.pendingCommandStart = false;
          this.speechService.startListening();
        }
      }
    });
  }

  private async startCommandListening(): Promise<void> {
    const hasPermission = await PermissionUtils.requestMicPermission(this.getUIContext());
    if (!hasPermission) {
      return;
    }
    // 每次都重新 init 以重新绑定 listener（不同页面的回调不同）
    if (!this.commandInitializing) {
      this.pendingCommandStart = true;
      this.initCommandSpeech();
    } else {
      this.pendingCommandStart = true;
    }
  }

  private stopCommandListening(): void {
    this.pendingCommandStart = false;
    if (this.commandListening) {
      this.speechService.stopListening();
    } else if (this.commandInitializing) {
      this.speechService.cancelListening();
      this.commandInitializing = false;
    }
  }

  build() {
    Scroll() {
      Row() {
        Column({ space: 18 }) {
          Row() {
            Button('返回')
              .fontSize(this.careMode ? 18 : 15)
              .fontColor('#2B7068')
              .backgroundColor('#EFFAF8')
              .borderRadius(18)
              .onClick(() => {
                RouteUtils.goBack(this.getUIContext());
              })
            Blank()
            CareModeToggle()
          }
          .width('100%')

          Column({ space: 8 }) {
            Row() {
              Text('比价结果')
                .fontSize(this.careMode ? 32 : 26)
                .fontWeight(FontWeight.Bold)
                .fontColor('#431407')
              Blank()
              Text(this.result.candidates.length.toString() + ' 款候选')
                .fontSize(this.careMode ? 16 : 13)
                .fontColor('#2B7068')
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor('#EFFAF8')
                .borderRadius(8)
            }
            .width('100%')
            Text('需求：' + this.query)
              .fontSize(this.careMode ? 20 : 16)
              .fontColor('#6B4E3D')
              .width('100%')
            Text('识别：' + this.result.intent.product + '，数量 ' + this.result.intent.quantity.toString())
              .fontSize(this.careMode ? 18 : 14)
              .fontColor('#7A5C45')
              .width('100%')
            Text(this.result.reason)
              .fontSize(this.careMode ? 18 : 15)
              .fontColor('#2B7068')
              .lineHeight(this.careMode ? 28 : 22)
              .width('100%')
            Text(this.productSourceText)
              .fontSize(this.careMode ? 16 : 13)
              .fontColor('#7A5C45')
              .lineHeight(this.careMode ? 24 : 19)
              .width('100%')
          }
          .width('100%')
          .padding(18)
          .backgroundColor('#FAF7F2')
          .borderRadius(18)
          .border({ width: 1, color: '#E8DDD2' })

          Column({ space: 10 }) {
            Text('语音说出或输入指令确认')
              .fontSize(this.careMode ? 21 : 17)
              .fontWeight(FontWeight.Bold)
              .fontColor('#431407')
              .width('100%')

            TextInput({ placeholder: '例如：买第一个', text: $$this.commandText })
              .height(this.careMode ? 56 : 46)
              .fontSize(this.careMode ? 19 : 15)
              .backgroundColor(Color.White)
              .borderRadius(8)
              .padding({ left: 12, right: 12 })

            if (this.commandMessage.length > 0) {
              Text(this.commandMessage)
                .fontSize(this.careMode ? 17 : 13)
                .fontColor('#2B7068')
                .lineHeight(this.careMode ? 24 : 20)
                .width('100%')
                .padding(10)
                .backgroundColor('#EFFAF8')
                .borderRadius(8)
            }

            Row({ space: 10 }) {
              Button(this.commandInitializing ? '初始化中...' : (this.commandListening ? '松手确认' : '按住说话'))
                .layoutWeight(1)
                .height(this.careMode ? 52 : 44)
                .fontSize(this.careMode ? 18 : 15)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .backgroundColor(this.commandListening ? '#2B7068' : '#2B7068')
                .borderRadius(10)
                .enabled(!this.commandInitializing)
                .onTouch((event: TouchEvent) => {
                  if (event.type === TouchType.Down) {
                    this.startCommandListening();
                  } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                    this.stopCommandListening();
                  }
                })
              Button('确认')
                .layoutWeight(1)
                .height(this.careMode ? 52 : 44)
                .fontSize(this.careMode ? 18 : 15)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .backgroundColor('#378F85')
                .borderRadius(10)
                .onClick(() => {
                  this.confirmByCommand();
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(8)
          .border({ width: 1, color: '#E8DDD2' })

          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(this.result.candidates, (item: ProductCandidate) => {
              ProductCard({
                product: item,
                isBest: item.id === this.result.bestProduct.id,
                careMode: this.careMode,
                compact: true,
                onSelect: (product: ProductCandidate) => {
                  this.selectProduct(product);
                },
                onDetail: (product: ProductCandidate) => {
                  this.openDetail(product);
                }
              })
              .width(this.breakpoint === 'sm' ? '50%' : (this.breakpoint === 'md' ? '25%' : '20%'))
              .padding({ left: 3, right: 3, top: 3, bottom: 3 })
            }, (item: ProductCandidate) => item.id)
          }
          .width('100%')
        }
        .width('100%')
        .padding(10)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .height('100%')
    .width('100%')
    .backgroundColor('#F3EFE8')
  }
}
