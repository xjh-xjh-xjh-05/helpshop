import { MOCK_ADDRESSES } from '../mock/MockData';
import { Address } from '../models/ShoppingModels';
import { AuthService } from './AuthService';
import { CloneUtils } from '../utils/CloneUtils';

export class AddressService {
  private static addresses: Address[] = MOCK_ADDRESSES.map((item: Address) => AddressService.normalizeAddress(item));

  static listAddresses(): Address[] {
    const elderlyAccountId = AuthService.getCurrentElderlyAccountId();
    return AddressService.addresses.filter((item: Address) => {
      return AddressService.ownerOf(item) === elderlyAccountId;
    }).map((item: Address) => CloneUtils.cloneAddress(item));
  }

  static listAddressesForElderly(elderlyAccountId: string): Address[] {
    return AddressService.addresses.filter((item: Address) => {
      return AddressService.ownerOf(item) === elderlyAccountId;
    }).map((item: Address) => CloneUtils.cloneAddress(item));
  }

  static getDefaultAddress(): Address | undefined {
    const addresses = AddressService.listAddresses();
    const address = addresses.find((item: Address) => item.isDefault);
    if (!address && addresses.length > 0) {
      return CloneUtils.cloneAddress(addresses[0]);
    }
    return address ? CloneUtils.cloneAddress(address) : undefined;
  }

  static addAddress(receiver: string, phone: string, detail: string): Address[] {
    const elderlyAccountId = AuthService.getCurrentElderlyAccountId();
    if (elderlyAccountId.length === 0) {
      return AddressService.listAddresses();
    }
    const address: Address = {
      id: `addr-${Date.now()}`,
      elderlyAccountId: elderlyAccountId,
      managedByChildAccountId: AuthService.getCurrentChildAccountId(),
      receiver: receiver,
      phone: phone,
      detail: detail,
      isDefault: AddressService.listAddresses().length === 0
    };
    AddressService.addresses.push(address);
    return AddressService.listAddresses();
  }

  static deleteAddress(id: string): Address[] {
    const elderlyAccountId = AuthService.getCurrentElderlyAccountId();
    AddressService.addresses = AddressService.addresses.filter((item: Address) => {
      return !(item.id === id && AddressService.ownerOf(item) === elderlyAccountId);
    });
    const currentAddresses = AddressService.addresses.filter((item: Address) => AddressService.ownerOf(item) === elderlyAccountId);
    if (!currentAddresses.some((item: Address) => item.isDefault) && currentAddresses.length > 0) {
      currentAddresses[0].isDefault = true;
    }
    return AddressService.listAddresses();
  }

  static setDefaultAddress(id: string): Address[] {
    const elderlyAccountId = AuthService.getCurrentElderlyAccountId();
    AddressService.addresses.forEach((item: Address) => {
      if (AddressService.ownerOf(item) === elderlyAccountId) {
        item.isDefault = item.id === id;
      }
    });
    return AddressService.listAddresses();
  }

  static countCurrentAddresses(): number {
    return AddressService.listAddresses().length;
  }

  static syncRemoteAddresses(remoteAddresses: Address[]): void {
    for (const remote of remoteAddresses) {
      const existing = AddressService.addresses.find((item: Address) => item.id === remote.id);
      if (existing) {
        existing.elderlyAccountId = remote.elderlyAccountId;
        existing.managedByChildAccountId = remote.managedByChildAccountId;
        existing.receiver = remote.receiver;
        existing.phone = remote.phone;
        existing.detail = remote.detail;
        existing.isDefault = remote.isDefault;
      } else {
        AddressService.addresses.push(CloneUtils.cloneAddress(remote));
      }
    }
  }

  static replaceAllForElderly(elderlyAccountId: string, remoteAddresses: Address[]): void {
    AddressService.addresses = AddressService.addresses.filter((item: Address) => {
      return AddressService.ownerOf(item) !== elderlyAccountId;
    });
    for (const remote of remoteAddresses) {
      AddressService.addresses.push(CloneUtils.cloneAddress(remote));
    }
  }

  private static ownerOf(address: Address): string {
    return address.elderlyAccountId ? address.elderlyAccountId : '';
  }

  private static normalizeAddress(address: Address): Address {
    const cloned = CloneUtils.cloneAddress(address);
    if (!cloned.elderlyAccountId) {
      cloned.elderlyAccountId = 'acct-elderly-001';
    }
    return cloned;
  }

}
