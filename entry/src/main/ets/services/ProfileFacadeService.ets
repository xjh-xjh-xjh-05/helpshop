import { Account, AccountRole, CustomerTicket, FamilyBinding } from '../models/AuthModels';
import { BackendResult, AdminDashboardBackendData, CustomerServiceDashboardBackendData, ProfileStatsBackendData, ChildDashboardBackendData } from '../models/BackendModels';
import { Address, ReminderRecord } from '../models/ShoppingModels';
import { RemoteCsTicketItem } from '../models/RemoteModels';
import { AuthService } from './AuthService';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AddressService } from './AddressService';
import { OrderService } from './OrderService';
import { ReminderService } from './ReminderService';
import { RemoteBackendClient, RemoteBackendResult } from './RemoteBackendClient';
import { RemoteDataMapper } from './RemoteDataMapper';
import { TimeUtils } from '../utils/TimeUtils';
import { AppBackendService } from './AppBackendService';

export class ProfileFacadeService {
  static getProfileStats(): BackendResult<ProfileStatsBackendData> {
    const bindings: FamilyBinding[] = AuthService.listCurrentChildBindings();
    return RemoteDataMapper.ok<ProfileStatsBackendData>('已获取个人页统计', {
      account: AuthService.getCurrentAccount(),
      orderCount: OrderService.countCurrentOrders(),
      addressCount: AddressService.countCurrentAddresses(),
      reminderCount: ReminderService.countCurrentReminders(),
      bindingCount: bindings.length,
      unreadReminderCount: ReminderService.countCurrentUnreadReminders()
    });
  }

  static async getProfileStatsRemote(): Promise<BackendResult<ProfileStatsBackendData>> {
    const result: RemoteBackendResult = await RemoteBackendClient.profileStats();
    if (!result.success) {
      return ProfileFacadeService.getProfileStats();
    }
    const parsed = RemoteDataMapper.parseProfileStats(result.body);
    if (!parsed) {
      return ProfileFacadeService.getProfileStats();
    }
    return RemoteDataMapper.ok<ProfileStatsBackendData>('已从 Spring 后端获取个人页统计', {
      account: parsed.account ? RemoteDataMapper.mapRemoteAccount(parsed.account) : AuthService.getCurrentAccount(),
      orderCount: parsed.orderCount !== undefined ? parsed.orderCount : (parsed.order_count ? parsed.order_count : 0),
      addressCount: parsed.addressCount !== undefined ? parsed.addressCount : (parsed.address_count ? parsed.address_count : 0),
      reminderCount: parsed.reminderCount !== undefined ? parsed.reminderCount : (parsed.reminder_count ? parsed.reminder_count : 0),
      bindingCount: parsed.bindingCount !== undefined ? parsed.bindingCount : (parsed.binding_count ? parsed.binding_count : 0),
      unreadReminderCount: parsed.unreadReminderCount !== undefined ? parsed.unreadReminderCount : (parsed.unread_reminder_count ? parsed.unread_reminder_count : 0)
    });
  }

  static getChildDashboard(): BackendResult<ChildDashboardBackendData> {
    const currentAccount = AuthService.getCurrentAccount();
    const currentRole = AuthService.getCurrentRole();
    const canShop = AuthService.canEnterShopping();
    const bindings = AuthService.listCurrentChildBindings();
    const elderlyId = AuthService.getCurrentElderlyAccountId();
    if (currentRole === AccountRole.Child && !canShop) {
      return RemoteDataMapper.ok<ChildDashboardBackendData>('请先绑定老人账号', {
        addressCount: 0,
        unreadReminderCount: 0,
        bindingCount: 0,
        defaultAddressText: '请先绑定老人账号，绑定后可维护老人收货地址',
        latestReminderText: '暂无提醒，绑定老人并完成购物后会显示在这里'
      });
    }
    const addresses: Address[] = AddressService.listAddresses();
    const defaultAddress = AddressService.getDefaultAddress();
    const reminders: ReminderRecord[] = ReminderService.listReminders();
    return RemoteDataMapper.ok<ChildDashboardBackendData>('已获取子女端概览', {
      addressCount: addresses.length,
      unreadReminderCount: reminders.filter((item: ReminderRecord) => !item.read).length,
      bindingCount: AuthService.listCurrentChildBindings().length,
      defaultAddressText: defaultAddress ? (defaultAddress.receiver + '，' + defaultAddress.detail) : '暂无默认地址',
      latestReminderText: reminders.length > 0 ? reminders[0].content : '暂无提醒'
    });
  }

  static async getChildDashboardRemote(): Promise<BackendResult<ChildDashboardBackendData>> {
    const result: RemoteBackendResult = await RemoteBackendClient.childDashboard();
    if (!result.success) {
      return ProfileFacadeService.getChildDashboard();
    }
    const parsed = RemoteDataMapper.parseChildDashboard(result.body);
    if (!parsed) {
      return ProfileFacadeService.getChildDashboard();
    }
    return RemoteDataMapper.ok<ChildDashboardBackendData>('已从 Spring 后端获取子女端概览', {
      addressCount: parsed.addressCount !== undefined ? parsed.addressCount : (parsed.address_count ? parsed.address_count : 0),
      unreadReminderCount: parsed.unreadReminderCount !== undefined ? parsed.unreadReminderCount : (parsed.unread_reminder_count ? parsed.unread_reminder_count : 0),
      bindingCount: parsed.bindingCount !== undefined ? parsed.bindingCount : (parsed.binding_count ? parsed.binding_count : 0),
      defaultAddressText: parsed.defaultAddressText ? parsed.defaultAddressText : (parsed.default_address_text ? parsed.default_address_text : ''),
      latestReminderText: parsed.latestReminderText ? parsed.latestReminderText : (parsed.latest_reminder_text ? parsed.latest_reminder_text : '')
    });
  }

  static getAdminDashboard(): BackendResult<AdminDashboardBackendData> {
    if (AuthService.getCurrentRole() !== AccountRole.Admin) {
      return RemoteDataMapper.ok<AdminDashboardBackendData>('当前不是管理员', {
        totalAccounts: 0, elderlyCount: 0, childCount: 0, csCount: 0, adminCount: 0, totalOrders: 0, pendingOrders: 0, deletedCount: 0, recentAuditLogs: []
      });
    }
    const accounts = AppBackendService.listAllAccounts();
    const deletedAccounts = AppBackendService.listDeletedAccounts();
    const allOrders = OrderService.listAllOrders();
    return RemoteDataMapper.ok<AdminDashboardBackendData>('已获取管理端概览', {
      totalAccounts: accounts.length,
      elderlyCount: accounts.filter((item: Account) => item.defaultRole === AccountRole.Elderly).length,
      childCount: accounts.filter((item: Account) => item.defaultRole === AccountRole.Child).length,
      csCount: accounts.filter((item: Account) => item.defaultRole === AccountRole.CustomerService).length,
      adminCount: accounts.filter((item: Account) => item.defaultRole === AccountRole.Admin).length,
      totalOrders: allOrders.length,
      pendingOrders: allOrders.filter((o) => o.paymentStatus === 'pending').length,
      deletedCount: deletedAccounts.length,
      recentAuditLogs: []
    });
  }

  static async getAdminDashboardRemote(): Promise<BackendResult<AdminDashboardBackendData>> {
    const result: RemoteBackendResult = await RemoteBackendClient.adminDashboard();
    if (!result.success) {
      return ProfileFacadeService.getAdminDashboard();
    }
    const parsed = RemoteDataMapper.parseAdminDashboard(result.body);
    if (!parsed) {
      return ProfileFacadeService.getAdminDashboard();
    }
    return RemoteDataMapper.ok<AdminDashboardBackendData>('已从后端获取管理端概览', {
      totalAccounts: parsed.totalAccounts !== undefined ? parsed.totalAccounts : (parsed.total_accounts ? parsed.total_accounts : 0),
      elderlyCount: parsed.elderlyCount !== undefined ? parsed.elderlyCount : (parsed.elderly_count ? parsed.elderly_count : 0),
      childCount: parsed.childCount !== undefined ? parsed.childCount : (parsed.child_count ? parsed.child_count : 0),
      csCount: parsed.csCount !== undefined ? parsed.csCount : (parsed.cs_count ? parsed.cs_count : 0),
      adminCount: parsed.adminCount !== undefined ? parsed.adminCount : (parsed.admin_count ? parsed.admin_count : 0),
      totalOrders: parsed.totalOrders !== undefined ? parsed.totalOrders : (parsed.total_orders ? parsed.total_orders : 0),
      pendingOrders: parsed.pendingOrders !== undefined ? parsed.pendingOrders : (parsed.pending_orders ? parsed.pending_orders : 0),
      deletedCount: 0,
      recentAuditLogs: []
    });
  }

  static getCsDashboard(): BackendResult<CustomerServiceDashboardBackendData> {
    if (AuthService.getCurrentRole() !== AccountRole.CustomerService) {
      return RemoteDataMapper.ok<CustomerServiceDashboardBackendData>('当前不是客服', {
        openTickets: 0, resolvedToday: 0, pendingTickets: []
      });
    }
    const allTickets: CustomerTicket[] = AuthService.listAllTickets();
    const openCount: number = allTickets.filter((t: CustomerTicket) => t.status === 'open' || t.status === 'processing').length;
    const today: string = TimeUtils.formatDate(new Date()).substring(0, 10);
    const resolvedCount: number = allTickets.filter((t: CustomerTicket) =>
      t.status === 'resolved' && t.updatedAt.substring(0, 10) === today
    ).length;
    return RemoteDataMapper.ok<CustomerServiceDashboardBackendData>('已获取客服端概览', {
      openTickets: openCount, resolvedToday: resolvedCount, pendingTickets: []
    });
  }

  static async getCsDashboardRemote(): Promise<BackendResult<CustomerServiceDashboardBackendData>> {
    const result: RemoteBackendResult = await RemoteBackendClient.csDashboard();
    if (!result.success) {
      return ProfileFacadeService.getCsDashboard();
    }
    try {
      const parsed: Record<string, Object> = JSON.parse(result.body) as Record<string, Object>;
      const openTickets: number = typeof parsed['openTickets'] === 'number' ? parsed['openTickets'] as number : 0;
      const resolvedToday: number = typeof parsed['resolvedToday'] === 'number' ? parsed['resolvedToday'] as number : 0;
      return RemoteDataMapper.ok<CustomerServiceDashboardBackendData>('已从后端获取客服端概览', {
        openTickets: openTickets,
        resolvedToday: resolvedToday,
        pendingTickets: []
      });
    } catch (error) {
      return ProfileFacadeService.getCsDashboard();
    }
  }

  static async csListTicketsRemote(): Promise<BackendResult<CustomerServiceDashboardBackendData>> {
    const result: RemoteBackendResult = await RemoteBackendClient.csListTickets();
    if (!result.success) {
      return ProfileFacadeService.getCsDashboard();
    }
    const parsed = RemoteDataMapper.parseCsTicketList(result.body);
    if (!parsed || !parsed.tickets) {
      return ProfileFacadeService.getCsDashboard();
    }
    const tickets: CustomerTicket[] = parsed.tickets.map((item: RemoteCsTicketItem) => RemoteDataMapper.mapRemoteCsTicket(item));
    AuthService.syncRemoteTickets(tickets);
    return RemoteDataMapper.ok<CustomerServiceDashboardBackendData>('已从远程获取工单列表', {
      openTickets: tickets.filter((t: CustomerTicket) => t.status === 'open' || t.status === 'processing').length,
      resolvedToday: 0,
      pendingTickets: tickets
    });
  }
}
