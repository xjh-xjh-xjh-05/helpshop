import { BreakpointType } from '../utils/BreakpointSystem';

@Component
export struct ResponsiveContainer {
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @Prop smMaxWidth: number = 10000;
  @Prop mdMaxWidth: number = 600;
  @Prop lgMaxWidth: number = 840;
  @BuilderParam content: () => void = this.defaultContent;

  @Builder
  defaultContent() {
  }

  build() {
    Row() {
      Column() {
        this.content();
      }
      .width('100%')
      .constraintSize({ maxWidth: this.currentMaxWidth })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  private get currentMaxWidth(): number {
    switch (this.breakpoint) {
      case 'sm':
        return this.smMaxWidth;
      case 'md':
        return this.mdMaxWidth;
      case 'lg':
        return this.lgMaxWidth;
      default:
        return this.smMaxWidth;
    }
  }
}
