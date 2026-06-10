import { router } from '@kit.ArkUI'
import { webview } from '@kit.ArkWeb'
import { common } from '@kit.AbilityKit'
import { PanCookieProfile } from '../common/model/PanModels'
import { ResolverDefaults } from '../common/model/ResolverModels'
import { HttpClient } from '../data/http/HttpClient'
import { ResolverRepository } from '../data/repository/ResolverRepository'
import { CacheStore } from '../data/storage/CacheStore'
import { PanCookieStore } from '../data/storage/PanCookieStore'

interface ConfigCenterRouteParams {
  page_url?: string
  title?: string
  resolver_base_url?: string
  resolver_source_id?: string
}

@Entry
@Component
struct ConfigCenterPage {
  @State private pageUrl: string = ''
  @State private title: string = '配置中心'
  @State private loadProgress: number = 0
  @State private errorMsg: string = ''
  @State private resolverBaseUrl: string = ResolverDefaults.BASE_URL
  @State private resolverSourceId: string = ''
  @State private isSyncingProfile: boolean = false
  @State private profileMessage: string = ''
  @StorageProp('statusBarTop') statusBarTop: number = 44

  private controller: webview.WebviewController = new webview.WebviewController()
  private resolverRepository: ResolverRepository = new ResolverRepository(new HttpClient())

  aboutToAppear(): void {
    let params = router.getParams()
    if (params !== null && params !== undefined) {
      let p: ConfigCenterRouteParams = params as ConfigCenterRouteParams
      let displayTitle: string = p.title ?? ''
      if (displayTitle.length > 0) {
        this.title = displayTitle
      }
      let baseUrl: string = p.resolver_base_url ?? ResolverDefaults.BASE_URL
      if (baseUrl.length > 0) {
        this.resolverBaseUrl = baseUrl
      }
      let sourceId: string = p.resolver_source_id ?? ''
      if (sourceId.length > 0) {
        this.resolverSourceId = sourceId
      }
      let routeUrl: string = p.page_url ?? ''
      if (routeUrl.length > 0) {
        this.pageUrl = routeUrl
        return
      }
      if (sourceId.length > 0) {
        this.pageUrl = this.resolverRepository.runtimeWebsiteUrl(baseUrl, sourceId)
      }
    }
  }

  aboutToDisappear(): void {
    this.syncProfileSilently()
  }

  build() {
    Column() {
      this.buildTopBar()
      if (this.loadProgress > 0 && this.loadProgress < 100) {
        Progress({ value: this.loadProgress, total: 100, type: ProgressType.Linear })
          .width('100%')
          .height(2)
          .color($r('app.color.hermes_orange'))
          .backgroundColor($r('app.color.background'))
      } else {
        Divider().color($r('app.color.background'))
      }

      if (this.pageUrl.length > 0) {
        Column() {
          Web({ src: this.pageUrl, controller: this.controller })
            .width('100%')
            .layoutWeight(1)
            .backgroundColor($r('app.color.card_background'))
            .onPageBegin(() => {
              this.errorMsg = ''
            })
            .onProgressChange((event) => {
              if (event !== undefined && event.newProgress !== undefined) {
                this.loadProgress = event.newProgress
              }
            })
            .onPageEnd(() => {
              this.loadProgress = 100
            })
            .onErrorReceive((event) => {
              if (event !== undefined && event.error !== undefined) {
                this.errorMsg = event.error.getErrorInfo()
              } else {
                this.errorMsg = '配置页加载失败'
              }
            })
          this.buildProfileStatus()
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        this.buildEmpty()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }

  @Builder
  buildTopBar() {
    Row({ space: 10 }) {
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20)
          .fontColor([$r('app.color.text_primary')])
      }
      .width(38)
      .height(38)
      .borderRadius(19)
      .backgroundColor($r('app.color.card_background'))
      .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
      .onClick(() => {
        router.back()
      })

      Text(this.title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      Button(this.isSyncingProfile ? '同步中' : '同步账号')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .width(74)
        .height(38)
        .borderRadius(19)
        .backgroundColor($r('app.color.hermes_orange'))
        .enabled(!this.isSyncingProfile)
        .onClick(async () => {
          await this.syncProfile()
        })

      Button('刷新')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.hermes_orange'))
      .width(48)
      .height(38)
      .borderRadius(19)
      .backgroundColor($r('app.color.card_background'))
      .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
      .onClick(() => {
        this.errorMsg = ''
        this.controller.refresh()
      })
    }
    .width('100%')
    .height(56 + this.statusBarTop)
    .padding({ left: 14, top: this.statusBarTop, right: 14 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('app.color.card_background'))
  }

  @Builder
  buildProfileStatus() {
    if (this.profileMessage.length > 0 || this.isSyncingProfile) {
      Row({ space: 8 }) {
        if (this.isSyncingProfile) {
          LoadingProgress()
            .width(16)
            .height(16)
            .color($r('app.color.hermes_orange'))
        }
        Text(this.profileStatusText())
          .fontSize(12)
          .fontColor(this.errorMsg.length > 0 ? '#FF3B30' : $r('app.color.text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 10 })
      .backgroundColor($r('app.color.card_background'))
    }
  }

  @Builder
  buildEmpty() {
    Column({ space: 10 }) {
      Blank()
      SymbolGlyph($r('sys.symbol.gearshape_fill'))
        .fontSize(44)
        .fontColor([$r('app.color.hermes_orange')])
      Text(this.emptyText())
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
      Blank()
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 32, right: 32 })
  }

  private emptyText(): string {
    if (this.errorMsg.length > 0) {
      return this.errorMsg
    }
    return '配置页地址为空'
  }

  private async syncProfile(): Promise<void> {
    if (this.resolverBaseUrl.trim().length === 0) {
      this.profileMessage = '缺少 Resolver 服务地址'
      return
    }
    this.isSyncingProfile = true
    this.errorMsg = ''
    this.profileMessage = '正在同步本地网盘账号...'
    try {
      let profile: PanCookieProfile = await this.resolverRepository.getProfile(this.resolverBaseUrl)
      if (!profile.hasQuark || profile.quarkCookie.length === 0) {
        this.profileMessage = '未检测到夸克 Cookie，请先完成扫码登录'
        return
      }
      let context = getContext(this) as common.UIAbilityContext
      let store = new PanCookieStore(new CacheStore(context))
      store.saveProfile(profile)
      this.profileMessage = '夸克账号已同步到 App 本地'
    } catch (err) {
      this.profileMessage = this.errorText(err)
      this.errorMsg = this.profileMessage
    } finally {
      this.isSyncingProfile = false
    }
  }

  private syncProfileSilently(): void {
    if (this.isSyncingProfile || this.resolverBaseUrl.trim().length === 0) {
      return
    }
    this.resolverRepository.getProfile(this.resolverBaseUrl)
      .then((profile: PanCookieProfile) => {
        if (profile.hasQuark && profile.quarkCookie.length > 0) {
          let context = getContext(this) as common.UIAbilityContext
          let store = new PanCookieStore(new CacheStore(context))
          store.saveProfile(profile)
        }
      })
      .catch((err: Error) => {
      })
  }

  private profileStatusText(): string {
    if (this.isSyncingProfile) {
      return '正在同步本地网盘账号...'
    }
    return this.profileMessage
  }

  private errorText(err: Object): string {
    if (err instanceof Error && err.message.length > 0) {
      return err.message
    }
    return '账号配置同步失败'
  }
}
