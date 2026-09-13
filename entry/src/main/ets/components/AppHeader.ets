import { CareModeToggle } from './CareModeToggle';

@Component
export struct AppHeader {
  title: string = '';
  subtitle: string = '';
  roleText: string = '';
  actionText: string = '账号';
  careMode: boolean = false;
  showBack: boolean = false;
  onBack: () => void = () => {};
  onSwitchRole: () => void = () => {};

  build() {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        if (this.showBack) {
          Button('‹')
            .width(44)
            .height(44)
            .fontSize(28)
            .fontColor('#2B7068')
            .fontWeight(FontWeight.Lighter)
            .backgroundColor('#FFFFFF')
            .borderRadius(14)
            .shadow({ radius: 6, color: '#00000010', offsetX: 0, offsetY: 2 })
            .onClick(() => { this.onBack(); })
        }
        Column({ space: 4 }) {
          Row({ space: 10 }) {
            if (this.roleText.length > 0) {
              Text(this.roleText)
                .fontSize(this.careMode ? 15 : 12)
                .fontColor('#2B7068')
                .fontWeight(FontWeight.Medium)
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .backgroundColor('#EFFAF8')
                .borderRadius(6)
            }
            Text('银发智购')
              .fontSize(this.careMode ? 16 : 13)
              .fontColor('#A09080')
              .fontWeight(FontWeight.Lighter)
              .opacity(0.7)
          }
          .width('100%')
          Text(this.title)
            .fontSize(this.careMode ? 32 : 26)
            .fontWeight(FontWeight.Bold)
            .fontColor('#3D1E0A')
            .letterSpacing(-0.5)
            .width('100%')
          if (this.subtitle.length > 0) {
            Text(this.subtitle)
              .fontSize(this.careMode ? 18 : 14)
              .fontColor('#8A7A70')
              .opacity(0.85)
              .width('100%')
              .maxLines(1)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Button(this.actionText)
          .height(40)
          .fontSize(this.careMode ? 15 : 13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#2B7068')
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .shadow({ radius: 4, color: '#0000000A', offsetX: 0, offsetY: 1 })
          .onClick(() => { this.onSwitchRole(); })
        CareModeToggle()
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: 14 })
  }
}
