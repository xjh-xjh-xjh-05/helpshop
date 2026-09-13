import { Address, ReminderRecord } from '../models/ShoppingModels';
import { BackendResult, BackendErrorCode } from '../models/BackendModels';
import { AuthService } from './AuthService';
import { AddressService } from './AddressService';
import { ReminderService } from './ReminderService';
import { AuditLogService } from './AuditLogService';
import { RemoteBackendClient, RemoteBackendResult } from './RemoteBackendClient';
import { RemoteDataMapper } from './RemoteDataMapper';
import { RemoteAddressItem, RemoteReminderItem } from '../models/RemoteModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class ReminderFacadeService {
  static listAddresses(): BackendResult<Address[]> {
    return RemoteDataMapper.ok<Address[]>('已获取收货地址', AddressService.listAddresses());
  }

  static async listAddressesRemote(): Promise<BackendResult<Address[]>> {
    const result: RemoteBackendResult = await RemoteBackendClient.listAddresses();
    if (!result.success) {
      hilog.warn(0x0001, 'ReminderFacade', 'listAddressesRemote failed, fallback to local');
      return RemoteDataMapper.ok<Address[]>('远程地址不可用，已使用本地地址', AddressService.listAddresses());
    }
    const parsed = RemoteDataMapper.parseAddressList(result.body);
    if (!parsed || !parsed.addresses) {
      hilog.warn(0x0001, 'ReminderFacade', 'listAddressesRemote parse failed, fallback to local');
      return RemoteDataMapper.ok<Address[]>('远程地址数据异常，已使用本地地址', AddressService.listAddresses());
    }
    const remoteAddresses: Address[] = parsed.addresses.map((item: RemoteAddressItem) => RemoteDataMapper.mapRemoteAddress(item));
    const elderlyAccountId = AuthService.getCurrentElderlyAccountId();
    if (elderlyAccountId.length > 0) {
      AddressService.replaceAllForElderly(elderlyAccountId, remoteAddresses);
    } else {
      AddressService.syncRemoteAddresses(remoteAddresses);
    }
    hilog.info(0x0001, 'ReminderFacade', 'listAddressesRemote synced %{public}d addresses from remote', remoteAddresses.length);
    return RemoteDataMapper.ok<Address[]>('已从远程后端获取收货地址', AddressService.listAddresses());
  }

  static getDefaultAddress(): BackendResult<Address> {
    const address = AddressService.getDefaultAddress();
    if (!address) {
      return RemoteDataMapper.fail<Address>(BackendErrorCode.NotFound, '暂无可用收货地址');
    }
    return RemoteDataMapper.ok<Address>('已获取默认地址', address);
  }

  static addAddress(receiver: string, phone: string, detail: string): BackendResult<Address[]> {
    if (!AuthService.hasActiveElderlyContext()) {
      return RemoteDataMapper.fail<Address[]>(BackendErrorCode.Forbidden, '请先完成身份认证；子女需要先绑定老人账号');
    }
    if (receiver.trim().length === 0 || phone.trim().length === 0 || detail.trim().length === 0) {
      return RemoteDataMapper.fail<Address[]>(BackendErrorCode.ValidationError, '请填写收货人、电话和详细地址');
    }
    const addresses = AddressService.addAddress(receiver.trim(), phone.trim(), detail.trim());
    AuditLogService.record('address.create', '新增收货地址（本地）：' + receiver.trim());
    return RemoteDataMapper.ok<Address[]>('地址已添加（离线模式）', addresses);
  }

  static async addAddressRemote(receiver: string, phone: string, detail: string): Promise<BackendResult<Address[]>> {
    if (receiver.trim().length === 0 || phone.trim().length === 0 || detail.trim().length === 0) {
      return RemoteDataMapper.fail<Address[]>(BackendErrorCode.ValidationError, '请填写收货人、电话和详细地址');
    }
    const result: RemoteBackendResult = await RemoteBackendClient.createAddress(receiver.trim(), phone.trim(), detail.trim());
    if (!result.success) {
      hilog.warn(0x0001, 'ReminderFacade', 'addAddressRemote failed, fallback to local');
      return ReminderFacadeService.addAddress(receiver, phone, detail);
    }
    AuditLogService.record('address.create', '新增收货地址（远程）：' + receiver.trim());
    return ReminderFacadeService.listAddressesRemote();
  }

  static deleteAddress(id: string): BackendResult<Address[]> {
    if (!AuthService.hasActiveElderlyContext()) {
      return RemoteDataMapper.fail<Address[]>(BackendErrorCode.Forbidden, '请先完成身份认证；子女需要先绑定老人账号');
    }
    if (id.length === 0) {
      return RemoteDataMapper.fail<Address[]>(BackendErrorCode.ValidationError, '地址参数无效');
    }
    const addresses = AddressService.deleteAddress(id);
    AuditLogService.record('address.delete', '删除收货地址（本地）：' + id);
    return RemoteDataMapper.ok<Address[]>('地址已删除（离线模式）', addresses);
  }

  static async deleteAddressRemote(id: string): Promise<BackendResult<Address[]>> {
    if (id.length === 0) {
      return RemoteDataMapper.fail<Address[]>(BackendErrorCode.ValidationError, '地址参数无效');
    }
    const result: RemoteBackendResult = await RemoteBackendClient.deleteAddress(id);
    if (!result.success) {
      hilog.warn(0x0001, 'ReminderFacade', 'deleteAddressRemote failed, fallback to local');
      return ReminderFacadeService.deleteAddress(id);
    }
    AuditLogService.record('address.delete', '删除收货地址（远程）：' + id);
    return ReminderFacadeService.listAddressesRemote();
  }

  static setDefaultAddress(id: string): BackendResult<Address[]> {
    if (!AuthService.hasActiveElderlyContext()) {
      return RemoteDataMapper.fail<Address[]>(BackendErrorCode.Forbidden, '请先完成身份认证；子女需要先绑定老人账号');
    }
    if (id.length === 0) {
      return RemoteDataMapper.fail<Address[]>(BackendErrorCode.ValidationError, '地址参数无效');
    }
    const addresses = AddressService.setDefaultAddress(id);
    AuditLogService.record('address.default', '设置默认收货地址（本地）：' + id);
    return RemoteDataMapper.ok<Address[]>('默认地址已更新（离线模式）', addresses);
  }

  static async setDefaultAddressRemote(id: string): Promise<BackendResult<Address[]>> {
    if (id.length === 0) {
      return RemoteDataMapper.fail<Address[]>(BackendErrorCode.ValidationError, '地址参数无效');
    }
    const result: RemoteBackendResult = await RemoteBackendClient.setDefaultAddress(id);
    if (!result.success) {
      hilog.warn(0x0001, 'ReminderFacade', 'setDefaultAddressRemote failed, fallback to local');
      return ReminderFacadeService.setDefaultAddress(id);
    }
    AuditLogService.record('address.default', '设置默认收货地址（远程）：' + id);
    return ReminderFacadeService.listAddressesRemote();
  }

  static listReminders(): BackendResult<ReminderRecord[]> {
    return RemoteDataMapper.ok<ReminderRecord[]>('已获取提醒列表', ReminderService.listReminders());
  }

  static async listRemindersRemote(): Promise<BackendResult<ReminderRecord[]>> {
    const result: RemoteBackendResult = await RemoteBackendClient.listReminders();
    if (!result.success) {
      return ReminderFacadeService.listReminders();
    }
    const parsed = RemoteDataMapper.parseReminderList(result.body);
    if (!parsed || !parsed.reminders) {
      return ReminderFacadeService.listReminders();
    }
    return RemoteDataMapper.ok<ReminderRecord[]>('已从远程后端获取提醒列表', parsed.reminders.map((item: RemoteReminderItem) => RemoteDataMapper.mapRemoteReminder(item)));
  }

  static markAllRemindersRead(): BackendResult<ReminderRecord[]> {
    return RemoteDataMapper.ok<ReminderRecord[]>('提醒已全部标记为已读', ReminderService.markAllRead());
  }

  static async markAllRemindersReadRemote(): Promise<BackendResult<ReminderRecord[]>> {
    const result: RemoteBackendResult = await RemoteBackendClient.markAllRemindersRead();
    if (!result.success) {
      return ReminderFacadeService.markAllRemindersRead();
    }
    const parsed = RemoteDataMapper.parseReminderList(result.body);
    if (!parsed || !parsed.reminders) {
      return ReminderFacadeService.markAllRemindersRead();
    }
    return RemoteDataMapper.ok<ReminderRecord[]>(parsed.message ? parsed.message : '提醒已全部标记为已读', parsed.reminders.map((item: RemoteReminderItem) => RemoteDataMapper.mapRemoteReminder(item)));
  }
}
