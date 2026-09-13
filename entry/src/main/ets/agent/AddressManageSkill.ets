import {
  AgentIntent,
  ConversationContext,
  emptySkillResultData,
  IntentType,
  Skill,
  SkillResult
} from './AgentModels';
import { Address } from '../models/ShoppingModels';
import { AddressService } from '../services/AddressService';

export class AddressManageSkill implements Skill {
  name: string = 'address_manage';
  description: string = '地址管理：查看、添加、设置默认、删除收货地址';

  canHandle(intent: AgentIntent): boolean {
    return intent.type === IntentType.AddressManage;
  }

  execute(intent: AgentIntent, context: ConversationContext): SkillResult {
    const data = emptySkillResultData();
    try {
      const action: string = AddressManageSkill.detectAction(intent.rawText);
      if (action === 'add') {
        return AddressManageSkill.handleAdd(intent);
      }
      if (action === 'setDefault') {
        return AddressManageSkill.handleSetDefault();
      }
      if (action === 'delete') {
        return AddressManageSkill.handleDelete();
      }
      return AddressManageSkill.handleList();
    } catch (error) {
      return {
        success: false,
        data: emptySkillResultData(),
        message: '地址服务暂时不可用，请稍后再试。',
        fallbackUsed: true
      };
    }
  }

  private static detectAction(text: string): string {
    if (text.indexOf('添加') >= 0 || text.indexOf('新增') >= 0) { return 'add'; }
    if (text.indexOf('默认') >= 0 || text.indexOf('设为默认') >= 0) { return 'setDefault'; }
    if (text.indexOf('删除') >= 0 || text.indexOf('移除') >= 0) { return 'delete'; }
    return 'list';
  }

  private static handleList(): SkillResult {
    const data = emptySkillResultData();
    const addresses: Address[] = AddressService.listAddresses();
    if (addresses.length === 0) {
      return {
        success: true,
        data: data,
        message: '您还没有收货地址。说"添加地址"可以新增一个。',
        fallbackUsed: false
      };
    }
    const msg: string = AddressManageSkill.buildAddressList(addresses);
    return {
      success: true,
      data: data,
      message: msg,
      fallbackUsed: false
    };
  }

  private static handleAdd(intent: AgentIntent): SkillResult {
    const data = emptySkillResultData();
    const parts: string[] = intent.attributes.rawAttributes;
    if (parts.length >= 3) {
      const addresses = AddressService.addAddress(parts[0], parts[1], parts.slice(2).join(''));
      return {
        success: true,
        data: data,
        message: '地址已添加。您现在有 ' + addresses.length.toString() + ' 个收货地址。',
        fallbackUsed: false
      };
    }
    return {
      success: false,
      data: data,
      message: '添加地址需要收货人、电话和详细地址。请去地址管理页面添加，或告诉我收货人、电话和地址信息。',
      fallbackUsed: false
    };
  }

  private static handleSetDefault(): SkillResult {
    const data = emptySkillResultData();
    const addresses: Address[] = AddressService.listAddresses();
    if (addresses.length === 0) {
      return {
        success: false,
        data: data,
        message: '您还没有收货地址，无法设置默认地址。',
        fallbackUsed: false
      };
    }
    const defaultAddr: Address | undefined = AddressService.getDefaultAddress();
    if (defaultAddr) {
      return {
        success: true,
        data: data,
        message: '当前默认地址：' + defaultAddr.receiver + ' ' + defaultAddr.phone + ' ' + defaultAddr.detail,
        fallbackUsed: false
      };
    }
    return {
      success: true,
      data: data,
      message: '请告诉我要把哪个地址设为默认。',
      fallbackUsed: false
    };
  }

  private static handleDelete(): SkillResult {
    return {
      success: false,
      data: emptySkillResultData(),
      message: '删除地址请到地址管理页面操作，确保不会误删。',
      fallbackUsed: false
    };
  }

  private static buildAddressList(addresses: Address[]): string {
    let msg: string = '您有 ' + addresses.length.toString() + ' 个收货地址：\n';
    for (let i = 0; i < addresses.length; i += 1) {
      const addr: Address = addresses[i];
      const defaultTag: string = addr.isDefault ? ' [默认]' : '';
      msg += (i + 1).toString() + '. ' + addr.receiver + ' ' + addr.phone + ' ' + addr.detail + defaultTag + '\n';
    }
    return msg.trimEnd();
  }
}
