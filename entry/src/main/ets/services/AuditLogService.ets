import { Account } from '../models/AuthModels';
import { BackendAuditRecord } from '../models/ShoppingModels';
import { AuthService } from './AuthService';
import { TimeUtils } from '../utils/TimeUtils';
import { CloneUtils } from '../utils/CloneUtils';

export class AuditLogService {
  private static records: BackendAuditRecord[] = [];

  static record(action: string, detail: string): BackendAuditRecord {
    const account: Account | undefined = AuthService.getCurrentAccount();
    const audit: BackendAuditRecord = {
      id: `audit-${Date.now()}`,
      actorAccountId: account ? account.id : undefined,
      elderlyAccountId: AuthService.getCurrentElderlyAccountId(),
      action: action,
      detail: detail,
      createdAt: TimeUtils.formatDate(new Date())
    };
    AuditLogService.records.unshift(audit);
    return CloneUtils.cloneAuditRecord(audit);
  }

  static listRecords(): BackendAuditRecord[] {
    const elderlyAccountId = AuthService.getCurrentElderlyAccountId();
    const account: Account | undefined = AuthService.getCurrentAccount();
    const actorAccountId = account ? account.id : '';
    return AuditLogService.records.filter((item: BackendAuditRecord) => {
      return item.elderlyAccountId === elderlyAccountId || item.actorAccountId === actorAccountId;
    }).map((item: BackendAuditRecord) => CloneUtils.cloneAuditRecord(item));
  }

  static deleteRecord(logId: string): boolean {
    const index: number = AuditLogService.records.findIndex((item: BackendAuditRecord) => item.id === logId);
    if (index >= 0) {
      AuditLogService.records.splice(index, 1);
      return true;
    }
    return false;
  }

  static clearRecords(): void {
    AuditLogService.records = [];
  }

}
