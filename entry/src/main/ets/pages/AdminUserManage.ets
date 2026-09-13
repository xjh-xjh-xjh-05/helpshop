import { BottomNav } from '../components/BottomNav';
import { AccountRole, Account, AccountStatus } from '../models/AuthModels';
import { AppBackendService } from '../services/AppBackendService';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';
import { RemoteBackendClient } from '../services/RemoteBackendClient';
import { RemoteDataMapper } from '../services/RemoteDataMapper';
import { RemoteAdminUserItem } from '../models/RemoteModels';

interface UserItem { id: string; name: string; phone: string; role: string; orderCount: number; status: string; }

@Entry
@Component
struct AdminUserManage {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @State users: UserItem[] = [];
  @State allUsers: UserItem[] = [];
  @State filterRole: string = 'all';
  @State loading: boolean = false;

  async aboutToAppear(): Promise<void> {
    if (AppBackendService.getCurrentRole() !== AccountRole.Admin) {
      RouteUtils.replacePage(this.getUIContext(), 'pages/Index'); return;
    }
    await this.loadUsersFromBackend();
  }

  private async loadUsersFromBackend(): Promise<void> {
    this.loading = true;
    const result = await RemoteBackendClient.listAdminUsers();
    if (result.success) {
      const parsed = RemoteDataMapper.parseAdminUserList(result.body);
      if (parsed && parsed.users) {
        this.allUsers = parsed.users
          .filter((item: RemoteAdminUserItem) => item.id_user === 0 || item.id_user === undefined)
          .map((item: RemoteAdminUserItem): UserItem => {
            return {
              id: item.id,
              name: item.display_name ? item.display_name : '',
              phone: item.phone,
              role: this.roleLabel(item.default_role ? item.default_role : 'unverified'),
              orderCount: item.orderCount !== undefined ? item.orderCount : (item.order_count ? item.order_count : 0),
              status: (item.status === 'disabled' || item.status === AccountStatus.Disabled) ? '停用' : '正常'
            } as UserItem;
          });
        AppBackendService.syncRemoteUsers(parsed.users);
        this.applyFilter();
        this.loading = false;
        return;
      }
    }
    const localAccounts: Account[] = AppBackendService.listAllAccounts();
    this.allUsers = localAccounts.map((account: Account): UserItem => {
      return {
        id: account.id,
        name: account.displayName,
        phone: account.phone,
        role: this.roleLabel(account.defaultRole),
        orderCount: 0,
        status: account.status === AccountStatus.Disabled ? '停用' : '正常'
      } as UserItem;
    });
    this.applyFilter();
    this.loading = false;
  }

  private roleLabel(role: string): string {
    if (role === 'elderly') return '老人';
    if (role === 'child') return '子女';
    if (role === 'admin') return '管理员';
    if (role === 'customer_service') return '客服';
    if (role === 'unverified') return '未认证';
    return role;
  }

  private roleKeyFromLabel(label: string): string {
    if (label === '老人') return 'elderly';
    if (label === '子女') return 'child';
    if (label === '管理员') return 'admin';
    if (label === '客服') return 'customer_service';
    return 'unverified';
  }

  private applyFilter(): void {
    if (this.filterRole === 'all') {
      this.users = [...this.allUsers];
    } else if (this.filterRole === 'elderly') {
      this.users = this.allUsers.filter((u: UserItem) => u.role === '老人');
    } else if (this.filterRole === 'child') {
      this.users = this.allUsers.filter((u: UserItem) => u.role === '子女');
    } else if (this.filterRole === 'admin') {
      this.users = this.allUsers.filter((u: UserItem) => u.role === '管理员');
    } else if (this.filterRole === 'cs') {
      this.users = this.allUsers.filter((u: UserItem) => u.role === '客服');
    }
  }

  private selectFilter(role: string): void {
    this.filterRole = role;
    this.applyFilter();
  }

  private getRoleLabel(role: string): string {
    if (role === 'all') return '全部';
    if (role === 'elderly') return '老人';
    if (role === 'child') return '子女';
    if (role === 'admin') return '管理员';
    if (role === 'cs') return '客服';
    return role;
  }

  private updateUserInList(userId: string, updater: (u: UserItem) => UserItem): void {
    this.allUsers = this.allUsers.map((u: UserItem): UserItem => {
      if (u.id === userId) {
        return updater(u);
      }
      return u;
    });
    this.applyFilter();
  }

  private toggleUserStatus(user: UserItem): void {
    const newStatus = user.status === '正常' ? AccountStatus.Disabled : AccountStatus.Active;
    const label = newStatus === AccountStatus.Disabled ? '停用' : '启用';
    this.getUIContext().showAlertDialog({
      title: '确认' + label,
      message: '确认将用户 ' + user.name + '（' + user.phone + '）设置为' + label + '状态？',
      primaryButton: {
        value: '确认',
        action: async () => {
          const remoteResult = await AppBackendService.updateAccountRemote(user.id, user.phone, user.name, this.roleKeyFromLabel(user.role) as AccountRole, newStatus);
          if (!remoteResult.success) {
            AppBackendService.updateAccountStatus(user.id, newStatus);
          }
          this.updateUserInList(user.id, (u: UserItem): UserItem => {
            return {
              id: u.id, name: u.name, phone: u.phone, role: u.role, orderCount: u.orderCount,
              status: newStatus === AccountStatus.Disabled ? '停用' : '正常'
            } as UserItem;
          });
          this.getUIContext().getPromptAction().showToast({ message: '用户已' + label });
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    });
  }

  private changeUserRole(user: UserItem): void {
    const currentRoleKey = this.roleKeyFromLabel(user.role);
    this.getUIContext().showAlertDialog({
      title: '修改用户角色',
      message: '当前角色：' + user.role + '\n用户：' + user.name + '（' + user.phone + '）',
      primaryButton: {
        value: '设为子女',
        action: async () => {
          if (currentRoleKey !== 'child') {
            const userStatus = user.status === '停用' ? AccountStatus.Disabled : AccountStatus.Active;
            const remoteResult = await AppBackendService.updateAccountRemote(user.id, user.phone, user.name, AccountRole.Child, userStatus);
            if (!remoteResult.success) {
              AppBackendService.updateAccountRole(user.id, AccountRole.Child);
            }
            this.updateUserInList(user.id, (u: UserItem): UserItem => {
              return { id: u.id, name: u.name, phone: u.phone, role: '子女', orderCount: u.orderCount, status: u.status } as UserItem;
            });
            this.getUIContext().getPromptAction().showToast({ message: '角色已更新为子女' });
          }
        }
      },
      secondaryButton: {
        value: '设为老人',
        action: async () => {
          if (currentRoleKey !== 'elderly') {
            const userStatus = user.status === '停用' ? AccountStatus.Disabled : AccountStatus.Active;
            const remoteResult = await AppBackendService.updateAccountRemote(user.id, user.phone, user.name, AccountRole.Elderly, userStatus);
            if (!remoteResult.success) {
              AppBackendService.updateAccountRole(user.id, AccountRole.Elderly);
            }
            this.updateUserInList(user.id, (u: UserItem): UserItem => {
              return { id: u.id, name: u.name, phone: u.phone, role: '老人', orderCount: u.orderCount, status: u.status } as UserItem;
            });
            this.getUIContext().getPromptAction().showToast({ message: '角色已更新为老人' });
          }
        }
      }
    });
  }

  private showAddUserDialog(): void {
    this.getUIContext().showAlertDialog({
      title: '新增用户',
      message: '将创建一个默认角色为老人、密码为123456的新用户',
      primaryButton: {
        value: '确认添加',
        action: async () => {
          const phone = '138' + Date.now().toString().substring(5);
          const name = '新用户';
          const remoteResult = await AppBackendService.createAccountRemote(phone, '123456', name, AccountRole.Elderly);
          if (remoteResult.success) {
            await this.loadUsersFromBackend();
            this.getUIContext().getPromptAction().showToast({ message: '用户创建成功' });
          } else {
            const result = AppBackendService.createAccount(phone, '123456', name, AccountRole.Elderly);
            if (result.success && result.data && result.data.account) {
              const newAccount = result.data.account;
              this.allUsers = [{
                id: newAccount.id,
                name: newAccount.displayName,
                phone: newAccount.phone,
                role: this.roleLabel(newAccount.defaultRole),
                orderCount: 0,
                status: '正常'
              } as UserItem, ...this.allUsers];
              this.applyFilter();
              this.getUIContext().getPromptAction().showToast({ message: '用户创建成功（本地模式）' });
            } else {
              this.getUIContext().getPromptAction().showToast({ message: result.message });
            }
          }
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    });
  }

  private deleteUser(user: UserItem): void {
    this.getUIContext().showAlertDialog({
      title: '删除用户',
      message: '确认软删除用户 ' + user.name + '（' + user.phone + '）？该操作可恢复。',
      primaryButton: {
        value: '确认删除',
        action: async () => {
          const remoteResult = await AppBackendService.softDeleteAccountRemote(user.id);
          if (!remoteResult.success) {
            AppBackendService.softDeleteAccount(user.id);
          }
          this.allUsers = this.allUsers.filter((u: UserItem) => u.id !== user.id);
          this.applyFilter();
          this.getUIContext().getPromptAction().showToast({ message: '用户已删除' });
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    });
  }

  @Builder
  private UserRow(user: UserItem) {
    Column({ space: 8 }) {
      Row({ space: 14 }) {
        Column({ space: 2 }) {
          Text(user.name).fontSize(this.careMode ? 19 : 16).fontWeight(FontWeight.Bold).fontColor('#1A237E')
          Text(user.phone).fontSize(this.careMode ? 16 : 13).fontColor('#7986CB')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)

        Text(user.role).fontSize(this.careMode ? 15 : 12).fontColor('#1A237E')
          .padding({ left: 10, right: 10, top: 4, bottom: 4 }).backgroundColor('#E8EAF6').borderRadius(6)

        Text(user.orderCount.toString() + ' 单').fontSize(this.careMode ? 16 : 13).fontColor('#5C6BC0')

        Text(user.status).fontSize(this.careMode ? 15 : 12).fontColor(user.status === '停用' ? '#C62828' : '#2E7D32')
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(user.status === '停用' ? '#FFEBEE' : '#E8F5E9').borderRadius(6)
      }.width('100%')

      Row({ space: 8 }) {
        Button(user.status === '正常' ? '停用' : '启用')
          .height(this.careMode ? 34 : 28).fontSize(this.careMode ? 13 : 11)
          .fontColor(user.status === '正常' ? '#C62828' : '#2E7D32')
          .backgroundColor(user.status === '正常' ? '#FFEBEE' : '#E8F5E9').borderRadius(6)
          .onClick(() => { this.toggleUserStatus(user); })
        Button('改角色')
          .height(this.careMode ? 34 : 28).fontSize(this.careMode ? 13 : 11)
          .fontColor('#1A237E').backgroundColor('#E8EAF6').borderRadius(6)
          .onClick(() => { this.changeUserRole(user); })
        Button('删除')
          .height(this.careMode ? 34 : 28).fontSize(this.careMode ? 13 : 11)
          .fontColor('#C62828').backgroundColor('#FFEBEE').borderRadius(6)
          .onClick(() => { this.deleteUser(user); })
      }.width('100%').justifyContent(FlexAlign.End)
    }
    .width('100%').padding(14).backgroundColor(Color.White).borderRadius(12)
    .shadow({ radius: 6, color: '#1A237E08', offsetX: 0, offsetY: 2 })
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Text('用户管理').fontSize(this.careMode ? 28 : 22).fontWeight(FontWeight.Bold).fontColor('#1A237E')
        Blank()
        Text('共 ' + this.users.length.toString() + ' 人').fontSize(this.careMode ? 15 : 12).fontColor('#7986CB')
      }.width('100%').padding({ left: 18, right: 18, top: 16, bottom: 12 })

      Row({ space: 8 }) {
        ForEach(['all', 'elderly', 'child', 'admin', 'cs'], (role: string) => {
          Text(this.getRoleLabel(role))
            .fontSize(this.careMode ? 16 : 13)
            .fontColor(this.filterRole === role ? '#FFFFFF' : '#7986CB')
            .fontWeight(this.filterRole === role ? FontWeight.Bold : FontWeight.Normal)
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .backgroundColor(this.filterRole === role ? '#1A237E' : '#E8EAF6').borderRadius(8)
            .onClick(() => { this.selectFilter(role); })
        }, (role: string) => role)
      }.width('100%').padding({ left: 18, right: 18, bottom: 10 })

      Row() {
        Button('+ 新增用户')
          .height(this.careMode ? 40 : 34).fontSize(this.careMode ? 15 : 13)
          .fontColor('#FFFFFF').backgroundColor('#1A237E').borderRadius(8)
          .onClick(() => { this.showAddUserDialog(); })
      }.width('100%').padding({ left: 18, right: 18, bottom: 8 })

      if (this.loading) {
        Column() {
          Text('加载中...').fontSize(this.careMode ? 18 : 15).fontColor('#7986CB').margin({ top: 40 })
        }.layoutWeight(1)
      } else {
        Scroll() {
          Column({ space: 10 }) {
            ForEach(this.users, (user: UserItem) => { this.UserRow(user) }, (user: UserItem) => user.id)
          }.width('100%').padding({ left: 18, right: 18, top: 6, bottom: 100 })
        }.layoutWeight(1).backgroundColor('#F5F7FF')
      }

      BottomNav({ role: 'admin', active: 'users', careMode: this.careMode,
        onNavigate: (url: string) => { RouteUtils.replacePage(this.getUIContext(), url); } })
    }.width('100%').height('100%')
    .constraintSize({ maxWidth: this.breakpoint === 'sm' ? 10000 : 900 }).backgroundColor('#F5F7FF')
  }
}
