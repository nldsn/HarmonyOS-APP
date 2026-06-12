import { HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit'
import { ResolverDefaults } from '../common/model/ResolverModels'
import { SiteSimple } from '../common/model/SourceModels'
import { HomePage } from '../tabs/HomePage'
import { LivePage } from '../tabs/LivePage'
import { SettingsPage } from '../tabs/SettingsPage'
import { AppConfigStore } from '../data/storage/AppConfigStore'
import { common } from '@kit.AbilityKit'

/**
 * 沉浸光感底部导航栏 — HdsTabs + barFloatingStyle
 *
 * 品牌色：爱马仕橙 #F37021
 */

@Component
struct MainPage {
  @StorageLink('siteList') siteList: SiteSimple[] = []
  @StorageLink('homeSelectedSiteKey') homeSelectedSiteKey: string = ''

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
      .barBackgroundColor('#00000000')
      .barFloatingStyle({
        barWidth: {
          smallWidth: 200,
          mediumWidth: 300,
          largeWidth: 400
        },
        barBottomMargin: 28,
        gradientMask: {
          maskColor: this.isDoubanHomeActive() ? '#00000000' : '#66F5F0EB',
          maskHeight: 92
        },
        systemMaterialEffect: {
          materialType: this.isDoubanHomeActive() ? hdsMaterial.MaterialType.IMMERSIVE : hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
        barOpacity: this.isDoubanHomeActive() ? 0.82 : 1
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
    .backgroundColor(this.isDoubanHomeActive() ? '#111214' : $r('app.color.background'))
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
            : $r('app.color.text_primary')
        ])

      Text($r('app.string.tab_home'))
        .fontSize(10)
        .fontWeight(this.activeTab === 0 ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(
          this.activeTab === 0
            ? $r('app.color.hermes_orange')
            : $r('app.color.text_primary')
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
            : $r('app.color.text_primary')
        ])

      Text($r('app.string.tab_live'))
        .fontSize(10)
        .fontWeight(this.activeTab === 1 ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(
          this.activeTab === 1
            ? $r('app.color.hermes_orange')
            : $r('app.color.text_primary')
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
            : $r('app.color.text_primary')
        ])

      Text($r('app.string.tab_settings'))
        .fontSize(10)
        .fontWeight(this.activeTab === 2 ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(
          this.activeTab === 2
            ? $r('app.color.hermes_orange')
            : $r('app.color.text_primary')
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

  private isDoubanHomeActive(): boolean {
    if (this.activeTab !== 0) {
      return false
    }
    let site = this.currentHomeSite()
    if (site === null) {
      return false
    }
    let key: string = site.key.toLowerCase()
    let name: string = site.name.toLowerCase()
    return key.indexOf('douban') >= 0 || name.indexOf('豆瓣') >= 0
  }

  private currentHomeSite(): SiteSimple | null {
    if (this.siteList.length === 0) {
      return null
    }
    for (let i = 0; i < this.siteList.length; i++) {
      let site: SiteSimple = this.siteList[i]
      if (site.key === this.homeSelectedSiteKey) {
        return site
      }
    }
    return this.siteList[0]
  }
}

// ── Entry 入口 ────────────────────────────────────
@Entry
@Component
struct Index {
  aboutToAppear(): void {
    // 标准 HarmonyOS 状态栏高度 44vp
    AppStorage.setOrCreate<number>('statusBarTop', 44)
    AppStorage.setOrCreate<SiteSimple[]>('siteList', [])
    AppStorage.setOrCreate<string>('resolverBaseUrl', ResolverDefaults.BASE_URL)
    AppStorage.setOrCreate<string>('resolverSourceId', '')
    AppStorage.setOrCreate<string>('homeSelectedSiteKey', '')
    AppStorage.setOrCreate<string>('sourceUrl', 'https://9280.kstore.vip/cat/index.js.md5')

    try {
      let context = getContext(this) as common.UIAbilityContext
      let configStore = new AppConfigStore(context)
      let config = configStore.getConfig()
      if (config !== null) {
        if (config.resolverBaseUrl) AppStorage.setOrCreate('resolverBaseUrl', config.resolverBaseUrl)
        if (config.sourceUrl) AppStorage.setOrCreate('sourceUrl', config.sourceUrl)
        if (config.resolverSourceId) AppStorage.setOrCreate('resolverSourceId', config.resolverSourceId)
        if (config.siteList && config.siteList.length > 0) AppStorage.setOrCreate('siteList', config.siteList)
      }
    } catch (e) {
      // 忽略
    }
  }

  build() {
    Column() {
      MainPage()
    }
    .width('100%')
    .height('100%')
  }
}
