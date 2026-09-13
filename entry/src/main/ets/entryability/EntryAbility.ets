import { AbilityConstant, ConfigurationConstant, UIAbility, Want, common, abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { SpeechService } from '../services/SpeechService';
import { TTSService } from '../services/TTSService';
import { BreakpointSystem } from '../utils/BreakpointSystem';
import { OrderStore } from '../services/OrderStore';
import { ReminderStore } from '../services/ReminderStore';
import { DistributedDataSync } from '../agent/DistributedDataSync';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  static abilityContext: common.UIAbilityContext;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    EntryAbility.abilityContext = this.context;
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    this.requestDistributedPermission();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  private requestDistributedPermission(): void {
    const permissions: Array<Permissions> = ['ohos.permission.DISTRIBUTED_DATASYNC'];
    const atManager = abilityAccessCtrl.createAtManager();
    atManager.requestPermissionsFromUser(this.context, permissions).then((data) => {
      const grantStatus: Array<number> = data.authResults;
      for (let i = 0; i < grantStatus.length; i += 1) {
        if (grantStatus[i] === 0) {
          hilog.info(DOMAIN, 'testTag', 'DISTRIBUTED_DATASYNC permission granted');
        } else {
          hilog.warn(DOMAIN, 'testTag', 'DISTRIBUTED_DATASYNC permission denied');
        }
      }
    }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, 'testTag', 'Request DISTRIBUTED_DATASYNC failed: %{public}s', err.code.toString());
    });
  }

  onDestroy(): void {
    SpeechService.getInstance().shutdown();
    TTSService.getInstance().shutdown();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    BreakpointSystem.init(this.context);
    OrderStore.init(this.context);
    ReminderStore.init(this.context);
    DistributedDataSync.getInstance().init(this.context);

    setTimeout(() => {
      windowStage.loadContent('pages/Index', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      });
    }, 2000);
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    SpeechService.getInstance().cancelListening();
    TTSService.getInstance().stop();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}