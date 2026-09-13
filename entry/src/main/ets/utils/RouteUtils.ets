export class RouteUtils {
  static showToast(uiContext: UIContext, message: string): void {
    try {
      uiContext.getPromptAction().showToast({ message: message });
    } catch (error) {
    }
  }

  static pushPage(uiContext: UIContext, url: string): void {
    try {
      uiContext.getRouter().pushUrl({ url: url });
    } catch (error) {
      RouteUtils.showToast(uiContext, '页面跳转失败，请稍后重试');
    }
  }

  static replacePage(uiContext: UIContext, url: string): void {
    try {
      uiContext.getRouter().replaceUrl({ url: url });
    } catch (error) {
      RouteUtils.showToast(uiContext, '页面跳转失败，请稍后重试');
    }
  }

  static clearAndPush(uiContext: UIContext, url: string): void {
    try {
      uiContext.getRouter().replaceUrl({ url: url });
      uiContext.getRouter().clear();
    } catch (error) {
      RouteUtils.showToast(uiContext, '页面跳转失败，请稍后重试');
    }
  }

  static navigate(uiContext: UIContext, url: string): void {
    try {
      uiContext.getRouter().pushUrl({ url: url });
    } catch (error) {
      RouteUtils.showToast(uiContext, '页面跳转失败，请稍后重试');
    }
  }

  static goBack(uiContext: UIContext): void {
    try {
      uiContext.getRouter().back();
    } catch (error) {
      RouteUtils.showToast(uiContext, '无法返回上一页');
    }
  }
}
