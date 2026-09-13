import { Address } from '../models/ShoppingModels';

@Component
export struct AddressCard {
  address: Address = {
    id: '',
    receiver: '',
    phone: '',
    detail: '',
    isDefault: false
  };
  careMode: boolean = false;
  onSetDefault: (id: string) => void = () => {};
  onDelete: (id: string) => void = () => {};

  build() {
    Column({ space: 10 }) {
      Row() {
        Text(this.address.receiver)
          .fontSize(this.careMode ? 22 : 18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#431407')

        Text(this.address.phone)
          .fontSize(this.careMode ? 18 : 15)
          .fontColor('#6B4E3D')
          .margin({ left: 12 })

        Blank()

        if (this.address.isDefault) {
          Text('默认')
            .fontSize(this.careMode ? 17 : 14)
            .fontColor('#9C5A2C')
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor('#FEF5F0')
            .borderRadius(12)
        }
      }
      .width('100%')

      Text(this.address.detail)
        .fontSize(this.careMode ? 18 : 15)
        .fontColor('#5C5048')
        .lineHeight(this.careMode ? 28 : 22)
        .width('100%')

      Row({ space: 12 }) {
        Button('设为默认')
          .enabled(!this.address.isDefault)
          .fontSize(this.careMode ? 17 : 14)
          .fontColor(Color.White)
          .backgroundColor(this.address.isDefault ? '#B9A691' : '#378F85')
          .borderRadius(18)
          .onClick(() => {
            this.onSetDefault(this.address.id);
          })

        Button('删除')
          .fontSize(this.careMode ? 17 : 14)
          .fontColor('#B91C1C')
          .backgroundColor('#FEE2E2')
          .borderRadius(18)
          .onClick(() => {
            this.onDelete(this.address.id);
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(14)
    .border({ width: 1, color: '#E8DDD2' })
  }
}
