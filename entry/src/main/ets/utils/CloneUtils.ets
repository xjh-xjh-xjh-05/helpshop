import { Account, AdminProfile, ChildProfile, CustomerServiceProfile, ElderlyProfile, FamilyBinding } from '../models/AuthModels';
import { ProductCandidate, Address, OrderDraft, PaymentRecord, ReminderRecord, BackendAuditRecord } from '../models/ShoppingModels';
import { AgentIntent, ConversationContext, ConversationTurn, AgentSession, AgentLogEntry } from '../agent/AgentModels';

export class CloneUtils {
  static cloneAccount(account: Account): Account {
    return {
      id: account.id,
      idUser: account.idUser,
      phone: account.phone,
      passwordHash: account.passwordHash,
      displayName: account.displayName,
      defaultRole: account.defaultRole,
      status: account.status,
      huaweiOpenId: account.huaweiOpenId,
      huaweiUnionId: account.huaweiUnionId,
      avatarUri: account.avatarUri,
      nickName: account.nickName,
      createdAt: account.createdAt,
      updatedAt: account.updatedAt
    };
  }

  static cloneElderlyProfile(profile: ElderlyProfile): ElderlyProfile {
    return {
      id: profile.id,
      accountId: profile.accountId,
      realName: profile.realName,
      age: profile.age,
      careModeEnabled: profile.careModeEnabled,
      emergencyPhone: profile.emergencyPhone,
      bindingCode: profile.bindingCode,
      createdAt: profile.createdAt,
      updatedAt: profile.updatedAt
    };
  }

  static cloneChildProfile(profile: ChildProfile): ChildProfile {
    return {
      id: profile.id,
      accountId: profile.accountId,
      realName: profile.realName,
      relation: profile.relation,
      notificationEnabled: profile.notificationEnabled,
      createdAt: profile.createdAt,
      updatedAt: profile.updatedAt
    };
  }

  static cloneAdminProfile(profile: AdminProfile): AdminProfile {
    return {
      id: profile.id,
      accountId: profile.accountId,
      realName: profile.realName,
      department: profile.department,
      permissions: profile.permissions.slice(),
      createdAt: profile.createdAt,
      updatedAt: profile.updatedAt
    };
  }

  static cloneCustomerServiceProfile(profile: CustomerServiceProfile): CustomerServiceProfile {
    return {
      id: profile.id,
      accountId: profile.accountId,
      realName: profile.realName,
      serviceGroup: profile.serviceGroup,
      maxConcurrent: profile.maxConcurrent,
      status: profile.status,
      createdAt: profile.createdAt,
      updatedAt: profile.updatedAt
    };
  }

  static cloneBinding(binding: FamilyBinding): FamilyBinding {
    return {
      id: binding.id,
      elderlyAccountId: binding.elderlyAccountId,
      childAccountId: binding.childAccountId,
      bindingCode: binding.bindingCode,
      status: binding.status,
      createdAt: binding.createdAt,
      updatedAt: binding.updatedAt
    };
  }

  static cloneProduct(product: ProductCandidate): ProductCandidate {
    return {
      id: product.id,
      platform: product.platform,
      name: product.name,
      price: product.price,
      rating: product.rating,
      sales: product.sales,
      shopName: product.shopName,
      description: product.description,
      tags: product.tags.slice(),
      recommendScore: product.recommendScore,
      imageKey: product.imageKey,
      imageUrl: product.imageUrl
    };
  }

  static cloneAddress(address: Address): Address {
    return {
      id: address.id,
      elderlyAccountId: address.elderlyAccountId,
      managedByChildAccountId: address.managedByChildAccountId,
      receiver: address.receiver,
      phone: address.phone,
      detail: address.detail,
      isDefault: address.isDefault
    };
  }

  static cloneOrder(order: OrderDraft): OrderDraft {
    return {
      id: order.id,
      elderlyAccountId: order.elderlyAccountId,
      managedByChildAccountId: order.managedByChildAccountId,
      createdAt: order.createdAt,
      product: CloneUtils.cloneProduct(order.product),
      quantity: order.quantity,
      address: CloneUtils.cloneAddress(order.address),
      totalPrice: order.totalPrice,
      paymentMethod: order.paymentMethod,
      paymentStatus: order.paymentStatus
    };
  }

  static clonePaymentRecord(record: PaymentRecord): PaymentRecord {
    return {
      id: record.id,
      orderId: record.orderId,
      elderlyAccountId: record.elderlyAccountId,
      productId: record.productId,
      amount: record.amount,
      method: record.method,
      status: record.status,
      message: record.message,
      createdAt: record.createdAt
    };
  }

  static cloneReminder(reminder: ReminderRecord): ReminderRecord {
    return {
      id: reminder.id,
      orderId: reminder.orderId,
      elderlyAccountId: reminder.elderlyAccountId,
      childAccountId: reminder.childAccountId,
      title: reminder.title,
      content: reminder.content,
      createdAt: reminder.createdAt,
      read: reminder.read
    };
  }

  static cloneAuditRecord(record: BackendAuditRecord): BackendAuditRecord {
    return {
      id: record.id,
      actorAccountId: record.actorAccountId,
      elderlyAccountId: record.elderlyAccountId,
      action: record.action,
      detail: record.detail,
      createdAt: record.createdAt
    };
  }

  static cloneAgentLogEntry(entry: AgentLogEntry): AgentLogEntry {
    return {
      id: entry.id,
      sessionId: entry.sessionId,
      input: entry.input,
      intentType: entry.intentType,
      actionType: entry.actionType,
      skillName: entry.skillName,
      output: entry.output,
      durationMs: entry.durationMs,
      fallbackUsed: entry.fallbackUsed,
      timestamp: entry.timestamp
    };
  }

  static cloneAgentIntent(intent: AgentIntent): AgentIntent {
    return {
      type: intent.type,
      product: intent.product,
      category: intent.category,
      attributes: {
        color: intent.attributes.color,
        size: intent.attributes.size,
        material: intent.attributes.material,
        features: intent.attributes.features.slice(),
        rawAttributes: intent.attributes.rawAttributes.slice()
      },
      quantity: intent.quantity,
      rawText: intent.rawText,
      confidence: intent.confidence,
      needsSupplement: intent.needsSupplement,
      supplementQuestions: intent.supplementQuestions.slice(),
      voiceContext: {
        isVoiceInput: intent.voiceContext.isVoiceInput,
        confidence: intent.voiceContext.confidence,
        partialText: intent.voiceContext.partialText,
        language: intent.voiceContext.language
      },
      selectedIndex: intent.selectedIndex
    };
  }

  static cloneConversationContext(context: ConversationContext): ConversationContext {
    const clonedHistory: ConversationTurn[] = context.history.map((turn: ConversationTurn): ConversationTurn => {
      const cloned: ConversationTurn = {
        role: turn.role,
        roleType: turn.roleType,
        content: turn.content,
        intent: CloneUtils.cloneAgentIntent(turn.intent),
        timestamp: turn.timestamp
      };
      return cloned;
    });
    return {
      sessionId: context.sessionId,
      turnIndex: context.turnIndex,
      pendingIntent: CloneUtils.cloneAgentIntent(context.pendingIntent),
      history: clonedHistory
    };
  }

  static cloneAgentSession(session: AgentSession): AgentSession {
    return {
      id: session.id,
      status: session.status,
      role: session.role,
      query: session.query,
      selectedProductId: session.selectedProductId,
      selectedProduct: CloneUtils.cloneProduct(session.selectedProduct),
      quantity: session.quantity,
      addressId: session.addressId,
      paymentMethod: session.paymentMethod,
      conversationContext: CloneUtils.cloneConversationContext(session.conversationContext),
      createdAt: session.createdAt,
      updatedAt: session.updatedAt
    };
  }
}
