/**
 * HelpShop Agent Extension — 端A2A智能体
 * 将自研的 IntentEngine + Skill 能力注册为 HarmonyOS AgentAbility，
 * 可被小艺、元服务、以及其他 A2A 协议的应用发现和调用。
 */
import { AgentExtensionAbility, common, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ShoppingAgentOrchestrator } from './ShoppingAgentOrchestrator';
import { AgentResponse } from './AgentModels';

const TAG: string = 'HelpShopAgent';
const DOMAIN: number = 0x0003;

export default class HelpShopAgentExtension extends AgentExtensionAbility {
  private comProxy: common.AgentHostProxy | null = null;

  onCreate(want: Want): void {
    hilog.info(DOMAIN, TAG, 'HelpShopAgentExtension onCreate');
  }

  onConnect(want: Want, proxy: common.AgentHostProxy): void {
    hilog.info(DOMAIN, TAG, 'HelpShopAgentExtension onConnect');
    this.comProxy = proxy;
  }

  onDisconnect(want: Want, proxy: common.AgentHostProxy): void {
    hilog.info(DOMAIN, TAG, 'HelpShopAgentExtension onDisconnect');
    this.comProxy = null;
  }

  onData(proxy: common.AgentHostProxy, data: string): void {
    hilog.info(DOMAIN, TAG, 'onData received: %{public}s', data);
    try {
      const response: AgentResponse = ShoppingAgentOrchestrator.process(data);
      const reply: string = JSON.stringify({
        success: response.result.success,
        message: response.result.message,
        intent: response.intent.type,
        action: response.action,
        supplementQuestions: response.supplementQuestions
      });
      proxy.sendData(reply);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'onData error');
      try {
        proxy.sendData(JSON.stringify({
          success: false,
          message: '抱歉，处理您的请求时出现了问题，请换个说法再试试。'
        }));
      } catch (e2) {
        hilog.error(DOMAIN, TAG, 'sendData fallback error');
      }
    }
  }

  onAuth(proxy: common.AgentHostProxy, handshakeData: string): void {
    hilog.info(DOMAIN, TAG, 'HelpShopAgentExtension onAuth');
    try {
      proxy.authorize('auth success');
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'authorize error');
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'HelpShopAgentExtension onDestroy');
  }
}
