import { BottomNav } from './BottomNav';
import { BreakpointType } from '../utils/BreakpointSystem';

@Component
export struct ResponsiveScaffold {
  @StorageLink('currentBreakpoint') breakpoint: BreakpointType = 'sm';
  @BuilderParam content: () => void = this.emptyContent;
  role: string = 'user';
  active: string = 'home';
  careMode: boolean = false;
  onNavigate: (url: string) => void = () => {};

  @Builder
  private emptyContent() {}

  private get isTablet(): boolean {
    return this.breakpoint === 'md' || this.breakpoint === 'lg';
  }

  @Builder
  private PhoneLayout() {
    Column() {
      Column() {
        this.content()
      }
      .layoutWeight(1)
      BottomNav({
        role: this.role, active: this.active, careMode: this.careMode,
        onNavigate: this.onNavigate
      })
    }
  }

  @Builder
  private TabletLayout() {
    Row() {
      BottomNav({
        role: this.role, active: this.active, careMode: this.careMode,
        onNavigate: this.onNavigate
      })
      Column() {
        this.content()
      }
      .layoutWeight(1)
    }
    .width('100%').height('100%')
  }

  build() {
    if (this.isTablet) {
      this.TabletLayout()
    } else {
      this.PhoneLayout()
    }
  }
}
