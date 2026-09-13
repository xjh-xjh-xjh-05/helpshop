import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { PermissionRequestResult } from '../models/RemoteModels';

export class PermissionUtils {
  static requestMicPermission(uiContext: UIContext): Promise<boolean> {
    return new Promise<boolean>((resolve: (value: boolean) => void) => {
      const context = uiContext.getHostContext();
      if (context === undefined) {
        resolve(false);
        return;
      }
      const atManager = abilityAccessCtrl.createAtManager();
      const permission: Permissions = 'ohos.permission.MICROPHONE';
      atManager.checkAccessToken(context.applicationInfo.accessTokenId, permission).then((grantStatus: abilityAccessCtrl.GrantStatus) => {
        if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
          resolve(true);
        } else {
          atManager.requestPermissionsFromUser(context, [permission]).then((result: PermissionRequestResult) => {
            if (result.authResults[0] === 0) {
              resolve(true);
            } else {
              resolve(false);
            }
          }).catch(() => {
            resolve(false);
          });
        }
      }).catch(() => {
        resolve(false);
      });
    });
  }
}
