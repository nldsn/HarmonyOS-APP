import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      // 静默失败
    }
  }

  onDestroy(): void {
    // Ability 销毁
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/MainPage', (err) => {
      if (err.code) {
        return;
      }

      // 沉浸式显示配置 — 适配底部光感导航栏
      const windowClass = windowStage.getMainWindowSync();
      if (windowClass) {
        windowClass.setWindowLayoutFullScreen(true);

        windowClass.setWindowSystemBarProperties({
          navigationBarColor: '#00000000',
          navigationBarContentColor: '#000000'
        });
      }
    });
  }

  onWindowStageDestroy(): void {
    // 窗口销毁
  }

  onForeground(): void {
    // 前台
  }

  onBackground(): void {
    // 后台
  }
}
