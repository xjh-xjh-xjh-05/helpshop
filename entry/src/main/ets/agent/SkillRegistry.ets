import { AgentIntent, Skill } from './AgentModels';
import { ShoppingCompareSkill } from './ShoppingCompareSkill';
import { ProductSearchSkill } from './ProductSearchSkill';
import { OrderConfirmSkill } from './OrderConfirmSkill';
import { PaymentSkill } from './PaymentSkill';
import { VoiceInputSkill } from './VoiceInputSkill';
import { AdminDashboardSkill } from './AdminDashboardSkill';
import { CustomerServiceSkill } from './CustomerServiceSkill';
import { OrderQuerySkill } from './OrderQuerySkill';
import { AddressManageSkill } from './AddressManageSkill';
import { ReminderManageSkill } from './ReminderManageSkill';
import { FamilyBindSkill } from './FamilyBindSkill';
import { ProductSelectSkill } from './ProductSelectSkill';

export class SkillRegistry {
  private static skills: Skill[] = [];
  private static initialized: boolean = false;

  static ensureInitialized(): void {
    if (SkillRegistry.initialized) {
      return;
    }
    SkillRegistry.initialized = true;
    SkillRegistry.skills.push(new AdminDashboardSkill());
    SkillRegistry.skills.push(new CustomerServiceSkill());
    SkillRegistry.skills.push(new VoiceInputSkill());
    SkillRegistry.skills.push(new ShoppingCompareSkill());
    SkillRegistry.skills.push(new ProductSearchSkill());
    SkillRegistry.skills.push(new OrderConfirmSkill());
    SkillRegistry.skills.push(new PaymentSkill());
    SkillRegistry.skills.push(new OrderQuerySkill());
    SkillRegistry.skills.push(new AddressManageSkill());
    SkillRegistry.skills.push(new ReminderManageSkill());
    SkillRegistry.skills.push(new FamilyBindSkill());
    SkillRegistry.skills.push(new ProductSelectSkill());
  }

  static register(skill: Skill): void {
    SkillRegistry.skills.push(skill);
  }

  static findSkill(intent: AgentIntent): Skill | undefined {
    SkillRegistry.ensureInitialized();
    for (let i = 0; i < SkillRegistry.skills.length; i += 1) {
      if (SkillRegistry.skills[i].canHandle(intent)) {
        return SkillRegistry.skills[i];
      }
    }
    return undefined;
  }

  static listSkills(): Skill[] {
    SkillRegistry.ensureInitialized();
    return SkillRegistry.skills.slice();
  }

  static reset(): void {
    SkillRegistry.skills = [];
    SkillRegistry.initialized = false;
  }
}
