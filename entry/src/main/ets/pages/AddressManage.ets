import { AddressCard } from '../components/AddressCard';
import { AppHeader } from '../components/AppHeader';
import { BottomNav } from '../components/BottomNav';
import { BackendResult } from '../models/BackendModels';
import { Address } from '../models/ShoppingModels';
import { AppBackendService } from '../services/AppBackendService';
import { RouteUtils } from '../utils/RouteUtils';
import { BreakpointType } from '../utils/BreakpointSystem';

@Entry
@Component
struct AddressManage {
  @StorageLink('careMode') careMode: boolean = false;
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @State addresses: Address[] = [];
  @State receiver: string = '';
  @State phone: string = '';
  @State detail: string = '';

  private async refresh(): Promise<void> {
    try {
      const result: BackendResult<Address[]> = await AppBackendService.listAddressesRemote();
      this.addresses = result.data ? result.data : [];
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '加载地址失败，请稍后重试');
    }
  }

  private async addAddress(): Promise<void> {
    if (this.receiver.trim().length === 0 || this.phone.trim().length === 0 || this.detail.trim().length === 0) {
      RouteUtils.showToast(this.getUIContext(), '请填写收货人、电话和详细地址');
      return;
    }
    try {
      const result: BackendResult<Address[]> = await AppBackendService.addAddressRemote(this.receiver, this.phone, this.detail);
      RouteUtils.showToast(this.getUIContext(), result.message);
      if (!result.success || !result.data) {
        return;
      }
      this.addresses = result.data;
      this.receiver = '';
      this.phone = '';
      this.detail = '';
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '添加地址异常，请稍后重试');
    }
  }

  private async setDefaultAddress(id: string): Promise<void> {
    try {
      const result: BackendResult<Address[]> = await AppBackendService.setDefaultAddressRemote(id);
      if (result.data) {
        this.addresses = result.data;
      }
      RouteUtils.showToast(this.getUIContext(), result.message);
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '设置默认地址异常，请稍后重试');
    }
  }

  private async deleteAddress(id: string): Promise<void> {
    try {
      const result: BackendResult<Address[]> = await AppBackendService.deleteAddressRemote(id);
      if (result.data) {
        this.addresses = result.data;
      }
      RouteUtils.showToast(this.getUIContext(), result.message);
    } catch (error) {
      RouteUtils.showToast(this.getUIContext(), '删除地址异常，请稍后重试');
    }
  }

  private switchRole(): void {
    RouteUtils.replacePage(this.getUIContext(), 'pages/Index');
  }

  build() {
    Column() {
      AppHeader({
        title: '收货地址',
        subtitle: '子女端维护地址，老人端支付时可直接选择',
        roleText: '子女端',
        careMode: this.careMode,
        onSwitchRole: () => {
          this.switchRole();
        }
      })

      Scroll() {
        Row() {
          Column({ space: 14 }) {
          Column({ space: 12 }) {
            Row() {
              Text('新增收货地址')
                .fontSize(this.careMode ? 24 : 20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#431407')
              Blank()
            }
            .width('100%')

            TextInput({ placeholder: '收货人', text: $$this.receiver })
              .height(this.careMode ? 58 : 48)
              .fontSize(this.careMode ? 20 : 16)
              .backgroundColor(Color.White)
              .borderRadius(8)
              .padding({ left: 12, right: 12 })

            TextInput({ placeholder: '联系电话', text: $$this.phone })
              .type(InputType.PhoneNumber)
              .height(this.careMode ? 58 : 48)
              .fontSize(this.careMode ? 20 : 16)
              .backgroundColor(Color.White)
              .borderRadius(8)
              .padding({ left: 12, right: 12 })

            TextInput({ placeholder: '详细地址', text: $$this.detail })
              .height(this.careMode ? 70 : 56)
              .fontSize(this.careMode ? 20 : 16)
              .backgroundColor(Color.White)
              .borderRadius(8)
              .padding({ left: 12, right: 12 })

            Button('添加地址')
              .width('100%')
              .height(this.careMode ? 56 : 48)
              .fontSize(this.careMode ? 19 : 16)
              .fontColor(Color.White)
              .backgroundColor('#378F85')
              .borderRadius(8)
              .onClick(() => {
                this.addAddress();
              })
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FAF7F2')
          .borderRadius(8)
          .border({ width: 1, color: '#E8DDD2' })

          Column({ space: 12 }) {
            Row() {
              Text('已保存地址')
                .fontSize(this.careMode ? 24 : 20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#431407')
              Blank()
              Text(this.addresses.length.toString() + ' 个')
                .fontSize(this.careMode ? 16 : 13)
                .fontColor('#2B7068')
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor('#EFFAF8')
                .borderRadius(8)
            }
            .width('100%')

            ForEach(this.addresses, (item: Address) => {
              AddressCard({
                address: item,
                careMode: this.careMode,
                onSetDefault: (id: string) => {
                  this.setDefaultAddress(id);
                },
                onDelete: (id: string) => {
                  this.deleteAddress(id);
                }
              })
            }, (item: Address) => item.id)
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .constraintSize({ maxWidth: this.breakpoint === 'sm' ? 10000 : 720 })
        .onAppear(() => {
          this.refresh();
        })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .layoutWeight(1)

      BottomNav({
        role: 'child',
        active: 'address',
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
