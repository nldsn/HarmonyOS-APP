import { HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit'
import { HomePage } from '../tabs/HomePage'
import { LivePage } from '../tabs/LivePage'
import { SettingsPage } from '../tabs/SettingsPage'

/**
 * 沉浸光感底部导航栏 — HdsTabs + barFloatingStyle
 *
 * 品牌色：爱马仕橙 #F37021
 */

@Component
struct MainPage {
  @State private activeTab: number = 0
  private controller: HdsTabsController = new HdsTabsController()

  build() {
    Column() {
      HdsTabs({ controller: this.controller }) {
        TabContent() {
          HomePage()
        }
        .tabBar(this.buildHomeTab())

        TabContent() {
          LivePage()
        }
        .tabBar(this.buildLiveTab())

        TabContent() {
          SettingsPage()
        }
        .tabBar(this.buildSettingsTab())
      }
      .barPosition(BarPosition.End)
      .vertical(false)
      .barOverlap(true)
      .barFloatingStyle({
        barWidth: {
          smallWidth: 200,
          mediumWidth: 300,
          largeWidth: 400
        },
        barBottomMargin: 28,
        gradientMask: {
          maskColor: '#66F5F0EB',
          maskHeight: 92
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      .animationDuration(200)
      .scrollable(false)
      .onChange((index: number) => {
        this.activeTab = index
      })
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  // ── Tab 0: 首页 ──────────────────────────────────
  @Builder
  buildHomeTab() {
    Column({ space: 2 }) {
      SymbolGlyph($r('sys.symbol.house_fill'))
        .fontSize(24)
        .fontColor([
          this.activeTab === 0
            ? $r('app.color.hermes_orange')
            : $r('app.color.text_secondary')
        ])

      Text($r('app.string.tab_home'))
        .fontSize(10)
        .fontWeight(this.activeTab === 0 ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(
          this.activeTab === 0
            ? $r('app.color.hermes_orange')
            : $r('app.color.text_secondary')
        )
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 4 })
    .onClick(() => {
      this.activeTab = 0
    })
  }

  // ── Tab 1: 直播 ──────────────────────────────────
  @Builder
  buildLiveTab() {
    Column({ space: 2 }) {
      SymbolGlyph($r('sys.symbol.play_fill'))
        .fontSize(24)
        .fontColor([
          this.activeTab === 1
            ? $r('app.color.hermes_orange')
            : $r('app.color.text_secondary')
        ])

      Text($r('app.string.tab_live'))
        .fontSize(10)
        .fontWeight(this.activeTab === 1 ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(
          this.activeTab === 1
            ? $r('app.color.hermes_orange')
            : $r('app.color.text_secondary')
        )
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 4 })
    .onClick(() => {
      this.activeTab = 1
    })
  }

  // ── Tab 2: 设置 ──────────────────────────────────
  @Builder
  buildSettingsTab() {
    Column({ space: 2 }) {
      SymbolGlyph($r('sys.symbol.gearshape_fill'))
        .fontSize(24)
        .fontColor([
          this.activeTab === 2
            ? $r('app.color.hermes_orange')
            : $r('app.color.text_secondary')
        ])

      Text($r('app.string.tab_settings'))
        .fontSize(10)
        .fontWeight(this.activeTab === 2 ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(
          this.activeTab === 2
            ? $r('app.color.hermes_orange')
            : $r('app.color.text_secondary')
        )
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 4 })
    .onClick(() => {
      this.activeTab = 2
    })
  }
}

// ── Entry 入口 ────────────────────────────────────
@Entry
@Component
struct Index {
  aboutToAppear(): void {
    // 标准 HarmonyOS 状态栏高度 44vp
    AppStorage.setOrCreate<number>('statusBarTop', 44)
    AppStorage.setOrCreate<string>('jsSandboxScript', '')
    AppStorage.setOrCreate<string>('jsSandboxCommand', '')
    AppStorage.setOrCreate<string>('jsSandboxResult', '')
    AppStorage.setOrCreate<string>('jsSandboxState', 'idle')
  }

  build() {
    Column() {
      MainPage()
    }
    .width('100%')
    .height('100%')
  }
}
