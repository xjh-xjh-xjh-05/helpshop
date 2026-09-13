import { BottomNav } from '../components/BottomNav';
import { CareModeToggle } from '../components/CareModeToggle';
import { AgentActionType, AgentIntent, AgentResponse, ThinkingStep, IntentType } from '../agent/AgentModels';
import { Address, OrderDraft, PaymentMethod, ProductCandidate } from '../models/ShoppingModels';
import {
  AgentProviderService,
  AgentQuickPrompt
} from '../services/AgentProviderService';
import { SpeechService } from '../services/SpeechService';
import { TTSService } from '../services/TTSService';
import { PermissionUtils } from '../utils/PermissionUtils';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';
import { ShoppingAgentOrchestrator } from '../agent/ShoppingAgentOrchestrator';
import { AgentThinkingEngine } from '../agent/AgentThinkingEngine';
import { IntentEngine } from '../agent/IntentEngine';
import { ConversationManager } from '../agent/ConversationManager';
import { AgentSessionManager } from '../agent/AgentSessionManager';
import { DistributedEventEmitter } from '../agent/DistributedEventEmitter';
import { ReminderService } from '../services/ReminderService';
import { AddressService } from '../services/AddressService';
import { OrderService } from '../services/OrderService';

interface LocalAgentMessage {
  id: string;
  role: 'assistant' | 'user';
  content: string;
  subtext: string;
  thinkingSteps: ThinkingStep[];
  showThinking: boolean;
  products: ProductCandidate[];
  order: OrderDraft | null;
}

@Entry
@Component
struct AgentAssistant {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('voicePromptEnabled') voicePromptEnabled: boolean = true;
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @State inputText: string = '';
  @State messages: LocalAgentMessage[] = [];
  @State speechReady: boolean = false;
  @State speechInitializing: boolean = false;
  @State listening: boolean = false;
  @State speechError: string = '';
  @State voiceText: string = '';
  @State actionHint: string = '';
  @State lastActionText: string = '';
  @State lastProductName: string = '';
  @State lastProductId: string = '';
  @State lastQuantity: number = 1;
  @State lastQuery: string = '';
  @State isThinking: boolean = false;
  private lastRecommendedProducts: ProductCandidate[] = [];
  private pendingSelectProduct: ProductCandidate | null = null;
  private waitingQuantity: boolean = false;
  private pendingVoiceStart: boolean = false;
  private speechService: SpeechService = SpeechService.getInstance();

  aboutToAppear(): void {
    TTSService.getInstance().setEnabled(this.voicePromptEnabled);
    if (this.messages.length === 0) {
      this.messages = [
        {
          id: 'assistant-welcome',
          role: 'assistant',
          content: '您好，我是银发智购智能购物助手。您可以直接说想买什么，我会帮您搜索、比价并准备下单。',
          subtext: '',
          thinkingSteps: [],
          showThinking: false,
          products: [],
          order: null
        }
      ];
    }
  }

  aboutToDisappear(): void {
    this.pendingVoiceStart = false;
    this.speechService.cancelListening();
    TTSService.getInstance().stop();
  }

  private appendMessage(role: 'assistant' | 'user', content: string, subtext: string = '', thinkingSteps: ThinkingStep[] = [], showThinking: boolean = false, products: ProductCandidate[] = [], order: OrderDraft | null = null): void {
    const next: LocalAgentMessage = {
      id: role + '-' + Date.now().toString(),
      role: role,
      content: content,
      subtext: subtext,
      thinkingSteps: thinkingSteps,
      showThinking: showThinking,
      products: products,
      order: order
    };
    const copied: LocalAgentMessage[] = this.messages.slice();
    copied.push(next);
    this.messages = copied;
  }

  private isVoiceInput: boolean = false;

  private processAndNavigate(text: string): void {
    const trimmed: string = text.trim();
    if (trimmed.length === 0) {
      return;
    }
    if (this.isVoiceInput && trimmed.length <= 1) {
      this.isVoiceInput = false;
      return;
    }
    const noiseWords: string[] = ['嗯', '啊', '哦', '呃', '哈', '唉', '哎', '喂', '嘿', '噢', '唔'];
    if (this.isVoiceInput && noiseWords.includes(trimmed)) {
      this.isVoiceInput = false;
      return;
    }

    if (this.waitingQuantity) {
      this.appendMessage('user', trimmed);
      this.handleQuantityInput(trimmed);
      return;
    }

    const displayText: string = this.isVoiceInput ? '[语音] ' + trimmed : trimmed;
    this.isVoiceInput = false;
    this.appendMessage('user', displayText);
    this.isThinking = true;

    const preIntent: AgentIntent = IntentEngine.parse(text, ConversationManager.getContext());
    if (preIntent.type === IntentType.ProductSelect && this.lastRecommendedProducts.length > 0) {
      this.handleProductSelect(preIntent);
      return;
    }

    const useLLM: boolean = AgentThinkingEngine.isLLMAvailable();

    if (useLLM) {
      ShoppingAgentOrchestrator.processWithThinking(text).then((response: AgentResponse) => {
        this.handleCompareResult(text, response);
      }).catch(() => {
        const voiceResponse: AgentResponse = AgentProviderService.processNative(text);
        this.handleCompareResult(text, voiceResponse);
      });
    } else {
      const voiceResponse: AgentResponse = AgentProviderService.processNative(text);
      this.handleCompareResult(text, voiceResponse);
    }
  }

  private handleProductSelect(intent: AgentIntent): void {
    this.isThinking = false;
    const idx: number = intent.selectedIndex > 0 ? intent.selectedIndex : 1;
    const selectIdx: number = Math.min(idx, this.lastRecommendedProducts.length) - 1;
    const selected: ProductCandidate = this.lastRecommendedProducts[selectIdx];

    this.pendingSelectProduct = selected;
    this.lastProductId = selected.id;
    this.lastProductName = selected.name;

    AgentSessionManager.setProduct(selected);

    const voiceText: string = '已为您选择第' + idx.toString() + '款：' + selected.name +
      '，' + selected.platform + '，' + selected.price.toString() + '元。请问您要买多少？';
    this.appendMessage('assistant', voiceText, '请说数量');
    this.speakSimple(voiceText);
    this.waitingQuantity = true;
  }

  private handleQuantityInput(text: string): void {
    const qty: number = IntentEngine.extractQuantity(text);
    if (qty <= 0) {
      const voiceText: string = '没听清数量，请再说一次要买多少。';
      this.appendMessage('assistant', voiceText);
      this.speakSimple(voiceText);
      return;
    }

    this.waitingQuantity = false;
    const selected: ProductCandidate = this.pendingSelectProduct!;
    this.lastQuantity = qty;

    AgentSessionManager.setQuantity(qty);
    const address: Address | undefined = AddressService.getDefaultAddress();
    if (address) {
      AgentSessionManager.setAddress(address.id);
    }

    const order: OrderDraft = OrderService.createOrder(
      selected, qty,
      address ? address : { id: '', receiver: '', phone: '', detail: '', isDefault: false },
      PaymentMethod.HuaWeiPay
    );

    ReminderService.createShoppingReminder(order);
    DistributedEventEmitter.emitOrderCreated(order.id, selected.name, address ? address.receiver : '');
    DistributedEventEmitter.emitPaymentSuccess(order.id, selected.name, address ? address.receiver : '', order.totalPrice, PaymentMethod.HuaWeiPay.toString());

    const voiceText: string = '好的，' + qty.toString() + '件' + selected.name +
      '，共' + (selected.price * qty).toString() + '元，订单已生成。';
    this.appendMessage('assistant', voiceText, '', [], false, [], order);
    this.speakSimple(voiceText);
    this.pendingSelectProduct = null;
  }

  private handleCompareResult(text: string, compareResponse: AgentResponse): void {
    this.isThinking = false;
    this.applyResponse(compareResponse);

    const thinkingSteps: ThinkingStep[] = compareResponse.thinkingChain.steps;
    const products: ProductCandidate[] = compareResponse.result.data.products;

    if (products.length > 0) {
      this.lastRecommendedProducts = products.slice();
    }

    const voiceSummary: string = products.length > 0
      ? this.buildProductVoiceText(products)
      : compareResponse.result.message;

    if (products.length > 0) {
      this.appendMessage('assistant',
        products.length.toString() + '款商品已找到，请说要买第几款',
        '', [], false, products);
      this.speakSimple(voiceSummary);
    } else {
      this.appendMessage('assistant', compareResponse.result.message, '', [], false);
      this.speakSimple(voiceSummary);
    }
  }

  private submitNativeInput(): void {
    const text: string = this.inputText.trim();
    if (text.length === 0) {
      RouteUtils.showToast(this.getUIContext(), '请先输入购物需求');
      return;
    }
    this.inputText = '';
    this.processAndNavigate(text.trim());
  }

  private speakSimple(text: string): void {
    if (text.length > 0 && this.voicePromptEnabled) {
      TTSService.getInstance().speak(text);
    }
  }

  private buildProductVoiceText(products: ProductCandidate[]): string {
    const top3: ProductCandidate[] = products.slice(0, 3);
    if (top3.length === 0) {
      return '';
    }
    let parts: string[] = [];
    for (let i = 0; i < top3.length; i++) {
      const p: ProductCandidate = top3[i];
      parts.push((i + 1).toString() + '.' + p.name + '，' + p.platform + '，' + p.price.toString() + '元');
    }
    return '为您推荐' + top3.length.toString() + '款商品：' + parts.join('；') + '。请说要买第几款，要买多少。';
  }

  private applyResponse(response: AgentResponse): void {
    this.lastActionText = this.describeAction(response);
    this.lastQuery = response.intent.rawText;

    if (response.supplementQuestions.length > 0) {
      this.actionHint = response.supplementQuestions[0];
    } else {
      this.actionHint = '';
    }

    if (response.result.data.recommendation &&
      response.result.data.recommendation.bestProduct &&
      response.result.data.recommendation.bestProduct.id.length > 0) {
      const best: ProductCandidate = response.result.data.recommendation.bestProduct;
      this.lastProductId = best.id;
      this.lastProductName = best.name;
      this.lastQuantity = response.result.data.recommendation.intent.quantity > 0
        ? response.result.data.recommendation.intent.quantity
        : 1;
    } else if (response.result.data.products.length > 0 && this.lastProductId.length === 0) {
      const first: ProductCandidate = response.result.data.products[0];
      this.lastProductId = first.id;
      this.lastProductName = first.name;
      this.lastQuantity = 1;
    }

    if (response.result.data.orderPreview && response.result.data.orderPreview.product.id.length > 0) {
      this.lastProductId = response.result.data.orderPreview.product.id;
      this.lastProductName = response.result.data.orderPreview.product.name;
      this.lastQuantity = response.result.data.orderPreview.quantity;
    }

    if (response.result.data.paymentPreview && response.result.data.paymentPreview.product.id.length > 0) {
      this.lastProductId = response.result.data.paymentPreview.product.id;
      this.lastProductName = response.result.data.paymentPreview.product.name;
      this.lastQuantity = response.result.data.paymentPreview.quantity;
    }
  }

  private describeAction(response: AgentResponse): string {
    if (response.action === AgentActionType.AskUser) {
      return '需要补充信息';
    }
    if (response.action === AgentActionType.CallSkill) {
      return '已调用本地技能';
    }
    if (response.action === AgentActionType.HandleError) {
      return '已走降级处理';
    }
    return '已返回结果';
  }

  private goToCompare(): void {
    if (this.lastQuery.length === 0) {
      RouteUtils.showToast(this.getUIContext(), '请先输入购物需求');
      return;
    }
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/CompareResult',
        params: {
          query: this.lastQuery
        }
      });
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '页面跳转失败，请稍后重试');
    }
  }

  private goToPayment(): void {
    if (this.lastProductId.length === 0) {
      RouteUtils.showToast(this.getUIContext(), '请先确认商品');
      return;
    }
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/PaymentConfirm',
        params: {
          productId: this.lastProductId,
          quantity: this.lastQuantity.toString()
        }
      });
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '页面跳转失败，请稍后重试');
    }
  }

  private fillPrompt(prompt: AgentQuickPrompt): void {
    this.inputText = prompt.content;
  }

  private initSpeech(): void {
    this.speechInitializing = true;
    this.speechError = '';
    this.speechService.init({
      onResult: (text: string, isFinal: boolean) => {
        if (isFinal) {
          this.voiceText = text;
          this.listening = false;
          this.inputText = '';
          this.isVoiceInput = true;
          this.processAndNavigate(text);
        }
      },
      onError: (errorCode: number, errorMessage: string) => {
        this.listening = false;
        this.speechInitializing = false;
        this.pendingVoiceStart = false;
        this.speechError = '语音识别失败(' + errorCode.toString() + ')';
      },
      onStart: () => {
        this.listening = true;
        this.voiceText = '';
      },
      onComplete: () => {
        this.listening = false;
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

  private async startVoiceInput(): Promise<void> {
    try {
      const granted: boolean = await PermissionUtils.requestMicPermission(this.getUIContext());
      if (!granted) {
        return;
      }
      if (this.speechService.isReady()) {
        this.speechService.startListening();
      } else if (!this.speechInitializing) {
        this.pendingVoiceStart = true;
        this.initSpeech();
      } else {
        this.pendingVoiceStart = true;
      }
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '语音输入启动异常，请稍后重试');
    }
  }

  private stopVoiceInput(): void {
    this.pendingVoiceStart = false;
    if (this.listening) {
      this.speechService.stopListening();
    } else if (this.speechInitializing) {
      this.speechService.cancelListening();
      this.speechInitializing = false;
    }
  }

  @Builder
  private LocalMessageItem(item: LocalAgentMessage) {
    Column({ space: 6 }) {
      Row() {
        Text(item.role === 'assistant' ? '助手' : '我')
          .fontSize(this.careMode ? 14 : 12)
          .fontWeight(FontWeight.Bold)
          .fontColor(item.role === 'assistant' ? '#2B7068' : '#6D6258')
        Blank()
        if (item.subtext.length > 0) {
          Text(item.subtext)
            .fontSize(this.careMode ? 13 : 11)
            .fontColor('#2B7068')
        }
      }
      .width('100%')

      Text(item.content)
        .fontSize(this.careMode ? 20 : 16)
        .lineHeight(this.careMode ? 30 : 24)
        .fontColor('#431407')
        .width('100%')

      if (item.role === 'assistant' && item.products.length > 0) {
        Column({ space: 8 }) {
          ForEach(item.products.slice(0, 3), (product: ProductCandidate) => {
            Row({ space: 10 }) {
              if (product.imageUrl && product.imageUrl.length > 0) {
                Image(product.imageUrl)
                  .width(this.careMode ? 72 : 60)
                  .height(this.careMode ? 72 : 60)
                  .borderRadius(8)
                  .objectFit(ImageFit.Cover)
              }
              Column({ space: 4 }) {
                Text(product.name)
                  .fontSize(this.careMode ? 16 : 14)
                  .fontColor('#431407')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                Row({ space: 8 }) {
                  Text('¥' + product.price.toFixed(2))
                    .fontSize(this.careMode ? 18 : 15)
                    .fontColor('#C4342D')
                    .fontWeight(FontWeight.Bold)
                  Text(product.platform)
                    .fontSize(this.careMode ? 12 : 11)
                    .fontColor('#2B7068')
                    .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                    .backgroundColor('#EFFAF8')
                    .borderRadius(4)
                }
                if (product.rating > 0) {
                  Text('评分 ' + product.rating.toFixed(1) + '  销量 ' + this.formatSales(product.sales))
                    .fontSize(this.careMode ? 12 : 11)
                    .fontColor('#6D6258')
                }
              }
              .layoutWeight(1)
            }
            .width('100%')
            .padding(10)
            .backgroundColor(Color.White)
            .borderRadius(8)
            .border({ width: 1, color: '#E8DDD2' })
            .onClick(() => {
            })
          }, (product: ProductCandidate) => product.id)

          if (item.products.length > 3) {
            Text('还有' + (item.products.length - 3).toString() + '款商品，点击"查看比价"查看全部')
              .fontSize(this.careMode ? 14 : 12)
              .fontColor('#2B7068')
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 4, bottom: 4 })
          }
        }
        .width('100%')
      }

      if (item.order !== null) {
        Column({ space: 8 }) {
          Row({ space: 10 }) {
            if (item.order.product.imageUrl && item.order.product.imageUrl.length > 0) {
              Image(item.order.product.imageUrl)
                .width(this.careMode ? 72 : 60)
                .height(this.careMode ? 72 : 60)
                .borderRadius(8)
                .objectFit(ImageFit.Cover)
            }
            Column({ space: 4 }) {
              Text(item.order.product.name)
                .fontSize(this.careMode ? 16 : 14)
                .fontColor('#431407')
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
              Row({ space: 8 }) {
                Text('¥' + item.order.totalPrice.toFixed(2))
                  .fontSize(this.careMode ? 18 : 15)
                  .fontColor('#C4342D')
                  .fontWeight(FontWeight.Bold)
                Text('x' + item.order.quantity.toString())
                  .fontSize(this.careMode ? 14 : 12)
                  .fontColor('#6D6258')
              }
              if (item.order.address.receiver.length > 0) {
                Text(item.order.address.receiver + ' ' + item.order.address.detail)
                  .fontSize(this.careMode ? 12 : 11)
                  .fontColor('#6D6258')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
              }
            }
            .layoutWeight(1)
          }
          .width('100%')
          Row() {
            Text('订单号：' + item.order.id)
              .fontSize(this.careMode ? 12 : 11)
              .fontColor('#6D6258')
            Blank()
            Text(OrderService.paymentMethodName(item.order.paymentMethod))
              .fontSize(this.careMode ? 12 : 11)
              .fontColor('#2B7068')
            Text('已支付')
              .fontSize(this.careMode ? 12 : 11)
              .fontColor('#378F85')
              .fontWeight(FontWeight.Bold)
              .margin({ left: 6 })
          }
          .width('100%')
        }
        .width('100%')
        .padding(12)
        .backgroundColor(Color.White)
        .borderRadius(8)
        .border({ width: 1, color: '#378F85' })
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(item.role === 'assistant' ? '#FAF7F2' : Color.White)
    .borderRadius(8)
    .border({ width: 1, color: '#E8DDD2' })
  }

  private formatSales(sales: number): string {
    if (sales >= 10000) {
      return (sales / 10000).toFixed(1) + '万';
    }
    return sales.toString();
  }

  @Builder
  private LocalAssistantView() {
    Column({ space: 12 }) {
      if (this.actionHint.length > 0 || this.lastProductName.length > 0) {
        Column({ space: 8 }) {
          if (this.actionHint.length > 0) {
            Text('下一步建议：' + this.actionHint)
              .fontSize(this.careMode ? 16 : 13)
              .fontColor('#2B7068')
              .width('100%')
          }
          if (this.lastProductName.length > 0) {
            Text('最近推荐：' + this.lastProductName + ' x ' + this.lastQuantity.toString())
              .fontSize(this.careMode ? 16 : 13)
              .fontColor('#6D6258')
              .width('100%')
          }
          Row({ space: 8 }) {
            Button('查看比价')
              .layoutWeight(1)
              .height(this.careMode ? 44 : 38)
              .fontSize(this.careMode ? 16 : 13)
              .fontColor('#2B7068')
              .backgroundColor('#EFFAF8')
              .borderRadius(8)
              .onClick(() => {
                this.goToCompare();
              })
            Button('去支付')
              .layoutWeight(1)
              .height(this.careMode ? 44 : 38)
              .fontSize(this.careMode ? 16 : 13)
              .fontColor(Color.White)
              .backgroundColor('#378F85')
              .borderRadius(8)
              .onClick(() => {
                this.goToPayment();
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding(14)
        .backgroundColor(Color.White)
        .borderRadius(8)
        .border({ width: 1, color: '#E8DDD2' })
      }

      Text('常用指令')
        .fontSize(this.careMode ? 22 : 18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#431407')
        .width('100%')

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(AgentProviderService.getQuickPrompts(), (item: AgentQuickPrompt) => {
          Button(item.title)
            .width(this.breakpoint === 'sm' ? '48%' : '31%')
            .height(this.careMode ? 46 : 38)
            .fontSize(this.careMode ? 16 : 13)
            .fontColor('#5C5048')
            .backgroundColor('#FAF7F2')
            .borderRadius(8)
            .margin({ bottom: 10 })
            .onClick(() => {
              this.fillPrompt(item);
            })
        }, (item: AgentQuickPrompt) => item.id)
      }
      .width('100%')

      Scroll() {
        Column({ space: 10 }) {
          if (this.isThinking) {
            Column({ space: 6 }) {
              Row({ space: 8 }) {
                LoadingProgress()
                  .width(this.careMode ? 20 : 16)
                  .height(this.careMode ? 20 : 16)
                  .color('#2B7068')
                Text('正在思考...')
                  .fontSize(this.careMode ? 16 : 13)
                  .fontColor('#2B7068')
              }
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#FAF7F2')
            .borderRadius(8)
            .border({ width: 1, color: '#E8DDD2' })
          }
          ForEach(this.messages, (item: LocalAgentMessage) => {
            this.LocalMessageItem(item)
          }, (item: LocalAgentMessage) => item.id)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')

      if (this.speechError.length > 0) {
        Text(this.speechError)
          .fontSize(this.careMode ? 16 : 13)
          .fontColor('#378F85')
          .width('100%')
      }

      Row({ space: 8 }) {
        TextInput({ placeholder: '直接说出想买什么，我来帮您', text: $$this.inputText })
          .layoutWeight(1)
          .height(this.careMode ? 54 : 46)
          .fontSize(this.careMode ? 18 : 15)
          .backgroundColor(Color.White)
          .borderRadius(8)
          .padding({ left: 14, right: 14 })
        Button(this.speechInitializing ? '初始化' : (this.listening ? '结束' : '语音'))
          .width(this.careMode ? 76 : 64)
          .height(this.careMode ? 54 : 46)
          .fontSize(this.careMode ? 16 : 13)
          .fontColor('#2B7068')
          .backgroundColor('#EFFAF8')
          .borderRadius(8)
          .enabled(!this.speechInitializing)
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.startVoiceInput();
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.stopVoiceInput();
            }
          })
        Button('发送')
          .width(this.careMode ? 76 : 64)
          .height(this.careMode ? 54 : 46)
          .fontSize(this.careMode ? 17 : 14)
          .fontColor(Color.White)
          .backgroundColor('#378F85')
          .borderRadius(8)
          .onClick(() => {
            this.submitNativeInput();
          })
      }
      .width('100%')
    }
    .width('100%')
    .layoutWeight(1)
  }

  build() {
    Column() {
      Column({ space: 12 }) {
        Row() {
          Text('智能助手')
            .fontSize(this.careMode ? 28 : 22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#378F85')
          Blank()
          Row({ space: 12 }) {
            Row({ space: 6 }) {
              Text('语音提示')
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
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 12 })
      .backgroundColor('#F3EFE8')

      Column() {
        this.LocalAssistantView()
      }
      .layoutWeight(1)
      .width('100%')
      .constraintSize({ maxWidth: this.breakpoint === 'sm' ? 10000 : 720 })
      .padding(12)

      BottomNav({
        role: 'user',
        active: 'assistant',
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
