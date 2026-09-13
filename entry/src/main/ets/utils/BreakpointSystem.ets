import { display } from '@kit.ArkUI';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

export type BreakpointType = 'sm' | 'md' | 'lg';

export class BreakpointSystem {
  private static readonly SM_MAX: number = 520;
  private static readonly MD_MAX: number = 840;
  private static readonly STORAGE_KEY: string = 'currentBreakpoint';
  private static listenerId: number = -1;

  static calculateBreakpoint(widthPx: number, densityPixels: number): BreakpointType {
    const widthVp: number = widthPx / densityPixels;
    if (widthVp < BreakpointSystem.SM_MAX) {
      return 'sm';
    } else if (widthVp < BreakpointSystem.MD_MAX) {
      return 'md';
    } else {
      return 'lg';
    }
  }

  static init(context: common.UIAbilityContext): void {
    try {
      const disp: display.Display = display.getDefaultDisplaySync();
      const bp: BreakpointType = BreakpointSystem.calculateBreakpoint(disp.width, disp.densityPixels);
      AppStorage.setOrCreate<BreakpointType>(BreakpointSystem.STORAGE_KEY, bp);
    } catch (e) {
      AppStorage.setOrCreate<BreakpointType>(BreakpointSystem.STORAGE_KEY, 'sm');
    }

    try {
      window.getLastWindow(context).then((win: window.Window) => {
        win.on('windowSizeChange', (size: window.Size) => {
          try {
            const disp2: display.Display = display.getDefaultDisplaySync();
            const newBp: BreakpointType = BreakpointSystem.calculateBreakpoint(size.width, disp2.densityPixels);
            AppStorage.setOrCreate<BreakpointType>(BreakpointSystem.STORAGE_KEY, newBp);
          } catch (_e) {
            const fallbackBp: BreakpointType = size.width >= 840 ? 'lg' : (size.width >= 600 ? 'md' : 'sm');
            AppStorage.setOrCreate<BreakpointType>(BreakpointSystem.STORAGE_KEY, fallbackBp);
          }
        });
      }).catch((_err: Error) => {});
    } catch (_e) {}
  }

  static getCurrent(): BreakpointType {
    const val: BreakpointType | undefined = AppStorage.get<BreakpointType>(BreakpointSystem.STORAGE_KEY);
    return val ?? 'sm';
  }

  static isTablet(): boolean {
    return BreakpointSystem.getCurrent() !== 'sm';
  }
}
