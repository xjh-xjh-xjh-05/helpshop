@CustomDialog
export struct HandwriteGuideDialog {
  controller?: CustomDialogController;
  onConfirm: () => void = () => {};

  build() {
    Column({ space: 16 }) {
      Text('手写输入设置')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#431407')

      Text('第一次使用时，请把系统输入法切换到手写模式。后续输入商品需求时，可以直接手写。')
        .fontSize(18)
        .fontColor('#5C5048')
        .lineHeight(28)

      Column({ space: 10 }) {
        Text('1. 点击输入框，调出系统键盘')
        Text('2. 点击键盘左上角设置或输入方式按钮')
        Text('3. 选择“手写”模式')
        Text('4. 写下想买的商品，例如“不累脚的鞋”')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(14)
      .backgroundColor('#FAF7F2')
      .borderRadius(12)

      Button('我知道了，开始使用')
        .width('100%')
        .height(48)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor('#378F85')
        .borderRadius(24)
        .onClick(() => {
          this.onConfirm();
          this.controller?.close();
        })
    }
    .width('86%')
    .padding(24)
    .backgroundColor(Color.White)
    .borderRadius(18)
  }
}
