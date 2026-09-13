import {
  AgentIntent,
  ConversationContext,
  emptySkillResultData,
  IntentType,
  Skill,
  SkillResult
} from './AgentModels';
import { AppBackendService } from '../services/AppBackendService';
import { BackendResult } from '../models/BackendModels';
import { BindingListBackendData } from '../models/BackendModels';
import { FamilyBinding } from '../models/AuthModels';

export class FamilyBindSkill implements Skill {
  name: string = 'family_bind';
  description: string = '家庭绑定：查看绑定关系或通过绑定码绑定老人账号';

  canHandle(intent: AgentIntent): boolean {
    return intent.type === IntentType.FamilyBind;
  }

  execute(intent: AgentIntent, context: ConversationContext): SkillResult {
    const data = emptySkillResultData();
    try {
      const action: string = FamilyBindSkill.detectAction(intent.rawText);
      if (action === 'bind') {
        return FamilyBindSkill.handleBind(intent);
      }
      return FamilyBindSkill.handleList();
    } catch (error) {
      return {
        success: false,
        data: emptySkillResultData(),
        message: '家庭绑定服务暂时不可用，请稍后再试。',
        fallbackUsed: true
      };
    }
  }

  private static detectAction(text: string): string {
    if (text.indexOf('绑定码') >= 0) { return 'bind'; }
    if (text.indexOf('绑定') >= 0 && text.indexOf('我的绑定') < 0 && text.indexOf('查看') < 0 && text.indexOf('已绑定') < 0) {
      return 'bind';
    }
    return 'list';
  }

  private static handleList(): SkillResult {
    const data = emptySkillResultData();
    const result: BackendResult<BindingListBackendData> = AppBackendService.listCurrentChildBindings();
    if (!result.success || !result.data) {
      return {
        success: true,
        data: data,
        message: '您还没有绑定老人账号。说"绑定码 XXXX"可以绑定老人。',
        fallbackUsed: false
      };
    }
    const bindings: FamilyBinding[] = result.data.bindings;
    if (bindings.length === 0) {
      return {
        success: true,
        data: data,
        message: '您还没有绑定老人账号。获取老人的绑定码后，说"绑定码 XXXX"即可绑定。',
        fallbackUsed: false
      };
    }
    let msg: string = '您已绑定 ' + bindings.length.toString() + ' 位老人：\n';
    for (let i = 0; i < bindings.length; i += 1) {
      const binding: FamilyBinding = bindings[i];
      msg += (i + 1).toString() + '. 账号' + binding.elderlyAccountId + '（绑定码：' + binding.bindingCode + '）\n';
    }
    return {
      success: true,
      data: data,
      message: msg.trimEnd(),
      fallbackUsed: false
    };
  }

  private static handleBind(intent: AgentIntent): SkillResult {
    const data = emptySkillResultData();
    const keyword: string = FamilyBindSkill.extractKeyword(intent.rawText);
    if (keyword.length === 0) {
      return {
        success: false,
        data: data,
        message: '绑定老人需要绑定码。请获取老人账号的绑定码后，说"绑定码 XXXX"。',
        fallbackUsed: false
      };
    }
    const result: BackendResult<BindingListBackendData> = AppBackendService.bindCurrentChildToElderly(keyword);
    if (result.success && result.data) {
      return {
        success: true,
        data: data,
        message: '绑定成功！已绑定 ' + result.data.bindings.length.toString() + ' 位老人。',
        fallbackUsed: false
      };
    }
    return {
      success: false,
      data: data,
      message: result.message.length > 0 ? result.message : '绑定码无效或已过期，请确认后重试。',
      fallbackUsed: false
    };
  }

  private static extractKeyword(text: string): string {
    const patterns: string[] = ['绑定码', '绑定码是', '绑定码为', '码'];
    for (let i = 0; i < patterns.length; i += 1) {
      const idx: number = text.indexOf(patterns[i]);
      if (idx >= 0) {
        const after: string = text.substring(idx + patterns[i].length).trim();
        const parts: string[] = after.split(/[\s,，、]+/);
        if (parts.length > 0 && parts[0].length >= 3) {
          return parts[0];
        }
        if (after.length >= 3 && after.length <= 20) {
          return after;
        }
      }
    }
    const attrs: string[] = text.split(/[\s,，、]+/);
    for (let i = 0; i < attrs.length; i += 1) {
      if (attrs[i].length >= 4 && attrs[i].length <= 10) {
        return attrs[i];
      }
    }
    return '';
  }
}
