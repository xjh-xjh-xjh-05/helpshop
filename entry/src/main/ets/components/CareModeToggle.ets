@Component
export struct CareModeToggle {
  @StorageLink('careMode') careMode: boolean = false;

  build() {
    Button(this.careMode ? '退出关怀模式' : '关怀模式')
      .fontSize(this.careMode ? 20 : 16)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.careMode ? Color.White : '#2B7068')
      .backgroundColor(this.careMode ? '#378F85' : '#EFFAF8')
      .borderRadius(18)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .onClick(() => {
        this.careMode = !this.careMode;
      })
  }
}
