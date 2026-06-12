import { router, Prompt } from '@kit.ArkUI'
import { HdsNavigation, HdsNavigationTitleMode, HdsNavigationMenuContentOptions,
  ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit'
import { common } from '@kit.AbilityKit'
import { PanCookieProfile, PanPlayRequest } from '../common/model/PanModels'
import {
  ResolverDefaults,
  ResolverEpisode,
  ResolverPlaySource,
  ResolverVodDetail
} from '../common/model/ResolverModels'
import { HttpClient } from '../data/http/HttpClient'
import { ResolverRepository } from '../data/repository/ResolverRepository'
import { CacheStore } from '../data/storage/CacheStore'
import { PanCookieStore } from '../data/storage/PanCookieStore'

/**
 * 详情页 — 沉浸海报式影视详情
 *
 * 主视觉参考竖屏影视详情页，保留爱马仕橙与原有小 tag 样式。
 */

interface PlaySrc {
  name: string
  flag: string
  eps: PlayEp[]
}

interface PlayEp {
  title: string
  url: string
  flag: string
  size: number
  pic: string
  fileName: string
  fileExt: string
  panType: string
  shareId: string
  fileId: string
  fileToken: string
  stoken: string
}

interface MenuItem {
  value: string
  action: () => void
}

interface DetailRouteParams {
  vod_id?: string
  vod_name?: string
  vod_pic?: string
  resolver_base_url?: string
  resolver_source_id?: string
  site_key?: string
  site_name?: string
}

const EMPTY_VOD_NAME: string = '影视详情'
const EMPTY_VOD_PIC: string = 'https://via.placeholder.com/300x420/333333/F37021?text=Poster'

@Entry
@Component
struct DetailPage {
  @State vodId: string = ''
  @State vodName: string = EMPTY_VOD_NAME
  @State vodPic: string = EMPTY_VOD_PIC
  @State typeName: string = ''
  @State vodYear: string = ''
  @State vodArea: string = ''
  @State vodDirector: string = ''
  @State vodActor: string = ''
  @State vodContent: string = ''
  @State sources: PlaySrc[] = []
  @State isLoading: boolean = false
  @State isResolvingPlay: boolean = false
  @State errorMsg: string = ''
  @State playMessage: string = ''
  @State showFullIntro: boolean = false
  @State activeSourceIndex: number = 0
  @State activeEpisodeIndex: number = 0
  @StorageLink('resolverBaseUrl') resolverBaseUrl: string = ResolverDefaults.BASE_URL
  @StorageLink('resolverSourceId') resolverSourceId: string = ''
  @StorageProp('statusBarTop') statusBarTop: number = 44
  @State siteKey: string = ''
  // 沉浸光感材质等级：默认自适应(ADAPTIVE)，设备不支持 IMMERSIVE 时降级为 SMOOTH
  @State private materialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.ADAPTIVE

  private resolverRepository: ResolverRepository = new ResolverRepository(new HttpClient())
  private scrollerForScroll: Scroller = new Scroller()
  private menus: HdsNavigationMenuContentOptions = {
    value: [{
      content: {
        label: '搜索',
        icon: $r('sys.symbol.magnifyingglass'),
        action: () => {
          router.pushUrl({ url: 'pages/SearchPage' })
        }
      }
    }, {
      content: {
        label: '喜欢',
        icon: $r('sys.symbol.heart'),
        action: () => {
          Prompt.showToast({ message: '暂无收藏功能', duration: 1500 })
        }
      }
    }, {
      content: {
        label: '更多',
        icon: $r('sys.symbol.ellipsis_circle'),
        action: () => {
          Prompt.showToast({ message: '更多选项开发中', duration: 1500 })
        }
      }
    }]
  }

  aboutToAppear(): void {
    // 查询当前设备支持的材质能力，按官方建议选择沉浸光感等级
    let materialTypes: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes()
    if (materialTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) < 0) {
      this.materialLevel = hdsMaterial.MaterialLevel.SMOOTH
    }

    let params = router.getParams()
    if (params !== null && params !== undefined) {
      let p: DetailRouteParams = params as DetailRouteParams
      let id: string = p.vod_id ?? ''
      if (id.length > 0) {
        this.vodId = id
      }
      let name: string = p.vod_name ?? ''
      if (name.length > 0) {
        this.vodName = name
      }
      let pic: string = p.vod_pic ?? ''
      if (pic.length > 0) {
        this.vodPic = this.posterUrl(pic)
      }
      let baseUrl: string = p.resolver_base_url ?? ''
      if (baseUrl.length > 0) {
        this.resolverBaseUrl = baseUrl
      }
      let sourceId: string = p.resolver_source_id ?? ''
      if (sourceId.length > 0) {
        this.resolverSourceId = sourceId
      }
      let key: string = p.site_key ?? ''
      if (key.length > 0) {
        this.siteKey = key
      }
    }
    this.loadDetail()
  }

  build() {
    Column() {
      HdsNavigation() {
        Scroll(this.scrollerForScroll) {
          if (this.isErrorState()) {
            this.buildError()
          } else {
            Column() {
              this.buildPosterHero()
              this.buildIntroBlock()
              if (this.isLoading) {
                LoadingProgress()
                  .width(40)
                  .height(40)
                  .color($r('app.color.hermes_orange'))
                  .margin({ top: 40 })
              } else {
                this.buildSourceSection()
              }
              this.buildPlayStatus()
              Column().height(48)
            }
            .width('100%')
            .constraintSize({ minHeight: '100%' })
          }
        }
        .scrollBar(BarState.Auto)
        .height('100%')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      }
      .mode(NavigationMode.Stack)
      .titleBar({
        content: {
          title: {
            mainTitle: '',
          },
          menu: this.menus,
        },
        style: {
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          },
          originalStyle: {
            backgroundStyle: {
              backgroundColor: '#00000000',
              maskExtraHeight: 0
            },
            contentStyle: {
              menuStyle: {
                iconColor: Color.White,
                textColor: Color.White
              },
              backIconStyle: {
                iconColor: Color.White
              },
              dividerStyle: {
                dividerColor: '#00000000'
              }
            }
          },
          scrollEffectStyle: {
            backgroundStyle: {
              backgroundColor: '#00000000',
              maskExtraHeight: 0
            },
            contentStyle: {
              menuStyle: {
                iconColor: Color.White,
                textColor: Color.White
              },
              backIconStyle: {
                iconColor: Color.White
              },
              dividerStyle: {
                dividerColor: '#00000000'
              }
            }
          },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: this.materialLevel
          },
        },
        avoidLayoutSafeArea: true,
        enableComponentSafeArea: false
      })
      .bindToScrollable([this.scrollerForScroll])
      .hideBackButton(false)
      .titleMode(HdsNavigationTitleMode.MINI)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.detail_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  buildPosterHero() {
    Stack({ alignContent: Alignment.Bottom }) {
      Image(this.vodPic)
        .width('100%')
        .height(600)
        .objectFit(ImageFit.Cover)
        .syncLoad(false)
        .backgroundColor($r('app.color.detail_poster_placeholder'))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      Column()
        .width('100%')
        .height(600)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [
            ['#00000000', 0.0],
            ['#335A524A', 0.35],
            ['#CC5A524A', 0.76],
            ['#FF5A524A', 1.0]
          ]
        })

      Column({ space: 13 }) {
        this.buildTitleLockup()
        this.buildContinueButton()
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 22 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height(600)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  @Builder
  buildTitleLockup() {
    Column({ space: 12 }) {
      Text(this.vodName)
        .fontSize(28)
        .fontWeight(FontWeight.Bolder)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .textShadow({ radius: 8, color: '#40000000', offsetX: 0, offsetY: 4 })
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Text(this.metaLine())
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.detail_text_light'))
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  buildContinueButton() {
    Column({ space: 3 }) {
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.play_fill'))
          .fontSize(20)
          .fontColor([Color.Black])
        Text('继续播放')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.Black)
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')

      Text(this.continueSubTitle())
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.detail_button_text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('86%')
    .height(58)
    .alignSelf(ItemAlign.Center)
    .justifyContent(FlexAlign.Center)
    .borderRadius(14)
    .backgroundColor($r('app.color.detail_button_bg'))
    .shadow({ radius: 12, color: '#42000000', offsetY: 5 })
    .enabled(!this.isResolvingPlay)
    .onClick(async () => {
      await this.resolveActiveEpisode()
    })
  }

  @Builder
  buildIntroBlock() {
    Column({ space: 10 }) {
      Text(this.vodContent)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.detail_text_intro'))
        .lineHeight(24)
        .maxLines(this.showFullIntro ? 12 : 3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (this.vodDirector.length > 0 || this.vodActor.length > 0) {
        Text(this.creditLine())
          .fontSize(12)
          .fontColor($r('app.color.detail_text_medium'))
          .lineHeight(18)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 4, bottom: 24 })
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      this.showFullIntro = !this.showFullIntro
    })
  }

  @Builder
  buildSourceSection() {
    if (this.sources.length > 0) {
      Column({ space: 14 }) {
        Row() {
          Button() {
            Row({ space: 8 }) {
              Text(this.currentSourceName())
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .maxLines(1)
              SymbolGlyph($r('sys.symbol.chevron_down'))
                .fontSize(16)
                .fontColor([$r('app.color.detail_text_medium')])
            }
          }
          .height(34)
          .padding({ left: 0, right: 8 })
          .backgroundColor(Color.Transparent)
          .bindMenu(this.sourceMenuItems())

          Blank()

          this.buildSourceTool($r('sys.symbol.magnifyingglass'), true, () => {
            Prompt.showToast({ message: '当前源搜索开发中', duration: 1500 })
          })
          this.buildSourceTool($r('sys.symbol.backward_fill'), false, () => {
            this.switchSource(-1)
          })
          this.buildSourceTool($r('sys.symbol.forward_end_fill'), false, () => {
            this.switchSource(1)
          })

          Text('更多')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.detail_text_medium'))
            .margin({ left: 4 })
        }
        .width('100%')
        .padding({ left: 22, right: 22 })

        this.buildEpisodeRow()
      }
      .width('100%')
      .padding({ bottom: 8 })
      .backgroundColor(Color.Transparent)
    }
  }

  @Builder
  buildSourceTool(icon: Resource, active: boolean, onClickAction: () => void) {
    Button() {
      if (active) {
        SymbolGlyph(icon)
          .fontSize(18)
          .fontColor([Color.White])
      } else {
        SymbolGlyph(icon)
          .fontSize(18)
          .fontColor([$r('app.color.detail_text_muted')])
      }
    }
    .width(34)
    .height(34)
    .borderRadius(17)
    .backgroundColor(Color.Transparent)
    .onClick(onClickAction)
  }

  @Builder
  buildEpisodeRow() {
    if (this.activeSourceIndex < this.sources.length) {
      List({ space: 14 }) {
        ForEach(this.activeSourceEps(), (ep: PlayEp, epIdx: number) => {
          this.buildEpisodeListItem(ep, epIdx)
        })
      }
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(170)
      .padding({ left: 22, right: 22 })
    }
  }

  @Builder
  buildEpisodeListItem(ep: PlayEp, epIdx: number) {
    ListItem() {
      this.buildEpisodeCard(ep, epIdx)
    }
  }

  @Builder
  buildEpisodeCard(ep: PlayEp, epIdx: number) {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.BottomStart }) {
        this.buildEpisodeThumb(ep)

        Column()
          .width(188)
          .height(106)
          .borderRadius(18)
          .backgroundColor(this.episodeOverlayColor(epIdx))

        if (this.isActiveEpisode(epIdx)) {
          Column()
            .width(188)
            .height(106)
            .borderRadius(18)
            .border({ width: 3, color: $r('app.color.detail_button_bg') })
        }

        Text(this.episodeBadgeText(epIdx))
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(8)
          .backgroundColor('#A6F37021')
          .margin({ left: 10, bottom: 10 })
      }
      .width(188)
      .height(106)

      Text(ep.title)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(188)
        
      if (ep.fileName && ep.fileName !== ep.title) {
        Text(ep.fileName)
          .fontSize(12)
          .fontColor($r('app.color.detail_text_medium'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width(188)
      }
    }
    .width(188)
    .onClick(async () => {
      this.activeEpisodeIndex = epIdx
      await this.resolveEpisode(ep)
    })
  }

  @Builder
  buildEpisodeThumb(ep: PlayEp) {
    if (ep.pic.length > 0) {
      Image(ep.pic)
        .width(188)
        .height(106)
        .objectFit(ImageFit.Cover)
        .syncLoad(false)
        .borderRadius(18)
        .backgroundColor($r('app.color.detail_episode_placeholder'))
    } else {
      Column() {
        Text(this.fileCardTitle(ep))
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .maxLines(3)
          .lineHeight(17)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .width('100%')
      .height('100%')
      .padding(14)
      .justifyContent(FlexAlign.Center)
      .borderRadius(18)
      .backgroundColor($r('app.color.detail_episode_placeholder'))
      .linearGradient({
        direction: GradientDirection.Bottom,
        colors: [
          ['#3B3028', 0.0],
          ['#211D19', 0.68],
          ['#452514', 1.0]
        ]
      })
      .border({ width: 1, color: '#33F37021' })
    }
  }

  @Builder
  buildPlayStatus() {
    if (this.playMessage.length > 0 || this.isResolvingPlay) {
      Row({ space: 8 }) {
        if (this.isResolvingPlay) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color($r('app.color.hermes_orange'))
        }
        Text(this.playMessage)
          .fontSize(12)
          .fontColor($r('app.color.detail_status_text'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 22, right: 22, top: 8, bottom: 4 })
      .backgroundColor(Color.Transparent)
    }
  }

  @Builder
  buildError() {
    Column({ space: 16 }) {
      Text('!')
        .fontSize(36)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.hermes_orange'))
        .width(48)
        .height(48)
        .textAlign(TextAlign.Center)
        .borderRadius(24)
        .border({ width: 2, color: $r('app.color.hermes_orange') })
      Text(this.errorMsg)
        .fontSize(15)
        .fontColor($r('app.color.detail_text_medium'))
        .textAlign(TextAlign.Center)
        .padding({ left: 40, right: 40 })
      Button('重试')
        .fontSize(14)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.hermes_orange'))
        .borderRadius(20)
        .height(40)
        .padding({ left: 24, right: 24 })
        .onClick(async () => {
          await this.loadDetail()
        })
    }
    .width('100%')
    .height('100%')
    .constraintSize({ minHeight: '100%' })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('app.color.detail_error_bg'))
  }

  private isErrorState(): boolean {
    return this.errorMsg.length > 0 && this.sources.length === 0 && !this.isLoading
  }

  private switchSource(direction: number): void {
    if (this.sources.length === 0) {
      return
    }
    let newIndex: number = this.activeSourceIndex + direction
    if (newIndex < 0) {
      newIndex = this.sources.length - 1
    } else if (newIndex >= this.sources.length) {
      newIndex = 0
    }
    this.activeSourceIndex = newIndex
    this.activeEpisodeIndex = 0
    this.playMessage = ''
  }

  private sourceMenuItems(): MenuItem[] {
    let items: MenuItem[] = []
    for (let i = 0; i < this.sources.length; i++) {
      let index: number = i
      let src: PlaySrc = this.sources[i]
      items.push({
        value: src.name,
        action: () => {
          this.activeSourceIndex = index
          this.activeEpisodeIndex = 0
          this.playMessage = ''
        }
      })
    }
    return items
  }

  private async loadDetail(): Promise<void> {
    if (this.vodId.length === 0) {
      this.errorMsg = '缺少影片 ID'
      return
    }
    if (this.resolverBaseUrl.trim().length === 0 || this.resolverSourceId.length === 0 ||
      this.siteKey.length === 0) {
      this.errorMsg = '缺少远端解析上下文'
      return
    }

    let currentVodId: string = this.vodId
    this.isLoading = true
    this.isResolvingPlay = false
    this.errorMsg = ''
    this.playMessage = ''

    try {
      let detail: ResolverVodDetail = await this.resolverRepository.getDetail(
        this.resolverBaseUrl,
        this.resolverSourceId,
        this.siteKey,
        currentVodId
      )
      if (currentVodId !== this.vodId) {
        return
      }
      this.applyDetail(detail)
    } catch (err) {
      this.errorMsg = this.errorText(err)
    } finally {
      this.isLoading = false
    }
  }

  private applyDetail(detail: ResolverVodDetail): void {
    if (detail.vodId.length > 0) {
      this.vodId = detail.vodId
    }
    if (detail.vodName.length > 0) {
      this.vodName = detail.vodName
    }
    if (detail.vodPic.length > 0) {
      this.vodPic = this.posterUrl(detail.vodPic)
    }
    this.typeName = detail.typeName
    this.vodYear = detail.vodYear
    this.vodArea = detail.vodArea
    this.vodDirector = detail.vodDirector
    this.vodActor = detail.vodActor
    this.vodContent = this.nonEmptyText(detail.vodContent, '暂无简介')
    this.sources = this.mapPlaySources(detail.playSources)
    this.activeSourceIndex = 0
    this.activeEpisodeIndex = 0
    if (this.sources.length === 0) {
      this.playMessage = '当前详情未返回可播放剧集'
    }
  }

  private mapPlaySources(items: ResolverPlaySource[]): PlaySrc[] {
    let result: PlaySrc[] = []
    for (let i = 0; i < items.length; i++) {
      let item: ResolverPlaySource = items[i]
      let episodes: PlayEp[] = this.mapEpisodes(item.episodes, item.flag)
      if (episodes.length > 0) {
        result.push({
          name: this.nonEmptyText(item.name, '线路' + (i + 1).toString()),
          flag: this.nonEmptyText(item.flag, item.name),
          eps: episodes
        })
      }
    }
    return result
  }

  private mapEpisodes(items: ResolverEpisode[], fallbackFlag: string): PlayEp[] {
    let result: PlayEp[] = []
    for (let i = 0; i < items.length; i++) {
      let item: ResolverEpisode = items[i]
      if (item.url.length > 0) {
        result.push({
          title: this.nonEmptyText(item.title, '第' + (i + 1).toString() + '集'),
          url: item.url,
          flag: this.nonEmptyText(item.flag, fallbackFlag),
          size: item.size,
          pic: this.optionalPosterUrl(item.pic ?? ''),
          fileName: this.nonEmptyText(item.fileName ?? '', item.title),
          fileExt: item.fileExt ?? '',
          panType: item.panType ?? '',
          shareId: item.shareId ?? '',
          fileId: item.fileId ?? '',
          fileToken: item.fileToken ?? '',
          stoken: item.stoken ?? ''
        })
      }
    }
    return result
  }

  private async resolveActiveEpisode(): Promise<void> {
    let ep: PlayEp | null = this.activeEpisode()
    if (ep === null) {
      this.playMessage = '请先选择剧集'
      return
    }
    await this.resolveEpisode(ep)
  }

  private async resolveEpisode(ep: PlayEp): Promise<void> {
    if (this.isResolvingPlay) {
      return
    }

    this.isResolvingPlay = true
    this.errorMsg = ''
    try {
      if (this.isDirectMediaUrl(ep.url)) {
        this.openPlayer(ep.url, ep.title, ep.pic, 'direct', '直链播放', '')
      } else if (this.isQuarkEpisode(ep)) {
        let cookie: string = await this.localQuarkCookie()
        if (cookie.length === 0) {
          this.playMessage = '未同步夸克账号，请先到配置中心扫码登录'
          this.isResolvingPlay = false
          return
        }
        let req = this.panPlayRequest(ep)
        router.pushUrl({
          url: 'pages/PlayerPage',
          params: {
            title: ep.title,
            cover: this.nonEmptyText(ep.pic, this.vodPic),
            quark_request_json: JSON.stringify(req),
            quark_cookie: cookie
          }
        })
      } else {
        this.playMessage = '当前剧集不是直链或夸克网盘资源，暂未接入 App 本地播放'
      }
    } catch (err) {
      this.playMessage = this.errorText(err)
    } finally {
      this.isResolvingPlay = false
    }
  }

  private panPlayRequest(ep: PlayEp): PanPlayRequest {
    return {
      panType: ep.panType,
      shareUrl: ep.url,
      shareId: ep.shareId,
      fileId: ep.fileId,
      fileToken: ep.fileToken,
      stoken: ep.stoken,
      fileName: ep.fileName,
      title: ep.title,
      cover: this.nonEmptyText(ep.pic, this.vodPic)
    }
  }

  private async localQuarkCookie(): Promise<string> {
    let context = getContext(this) as common.UIAbilityContext
    let store = new PanCookieStore(new CacheStore(context))
    let cookie: string = store.getQuarkCookie()
    if (cookie.length > 0) {
      return cookie
    }
    return await this.syncQuarkCookieFromResolver(store)
  }

  private async syncQuarkCookieFromResolver(store: PanCookieStore): Promise<string> {
    if (this.resolverBaseUrl.trim().length === 0) {
      return ''
    }
    try {
      this.playMessage = '正在同步夸克账号...'
      let profile: PanCookieProfile = await this.resolverRepository.getProfile(this.resolverBaseUrl)
      if (profile.hasQuark && profile.quarkCookie.length > 0) {
        store.saveProfile(profile)
        return profile.quarkCookie
      }
    } catch (err) {
      this.playMessage = this.errorText(err)
    }
    return ''
  }

  private isQuarkEpisode(ep: PlayEp): boolean {
    let panType: string = ep.panType.toLowerCase()
    if (panType.indexOf('quark') >= 0 || panType.indexOf('夸克') >= 0) {
      return true
    }
    let flag: string = ep.flag.toLowerCase()
    if (flag.indexOf('quark') >= 0 || flag.indexOf('夸克') >= 0) {
      return true
    }
    if (ep.url.indexOf('pan.quark.cn/s/') >= 0 || ep.url.indexOf('drive.uc.cn/s/') >= 0) {
      return true
    }
    return ep.shareId.length > 0 && (ep.stoken.length > 0 || ep.fileToken.length > 0 || ep.fileId.length > 0)
  }

  private openPlayer(playUrl: string, title: string, cover: string, source: string, message: string,
    headersJson: string): void {
    router.pushUrl({
      url: 'pages/PlayerPage',
      params: {
        play_url: playUrl,
        title: title,
        cover: this.nonEmptyText(cover, this.vodPic),
        source: source,
        message: message,
        headers_json: headersJson
      }
    })
  }

  private activeSourceEps(): PlayEp[] {
    if (this.activeSourceIndex < this.sources.length) {
      return this.sources[this.activeSourceIndex].eps
    }
    return []
  }

  private isDirectMediaUrl(url: string): boolean {
    let lower: string = url.trim().toLowerCase()
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return false
    }
    if (lower.indexOf('pan.quark.cn/s/') >= 0 || lower.indexOf('drive.uc.cn/s/') >= 0 ||
      lower.indexOf('pan.baidu.com/s/') >= 0 || lower.indexOf('aliyundrive.com/s/') >= 0 ||
      lower.indexOf('alipan.com/s/') >= 0) {
      return false
    }
    return lower.indexOf('.m3u8') >= 0 || lower.indexOf('.mp4') >= 0 ||
      lower.indexOf('.mkv') >= 0 || lower.indexOf('.ts') >= 0 ||
      lower.indexOf('.flv') >= 0 || lower.indexOf('.mov') >= 0 ||
      lower.indexOf('.webm') >= 0
  }

  private currentSourceName(): string {
    if (this.activeSourceIndex < this.sources.length) {
      return this.sources[this.activeSourceIndex].name
    }
    return '线路'
  }

  private metaLine(): string {
    let result: string = ''
    if (this.vodYear.length > 0) {
      result = this.vodYear
    }
    if (this.typeName.length > 0) {
      result = this.appendMeta(result, this.typeName)
    }
    if (this.vodArea.length > 0) {
      result = this.appendMeta(result, this.vodArea)
    }
    return result
  }

  private appendMeta(current: string, value: string): string {
    if (current.length === 0) {
      return value
    }
    return current + ' · ' + value
  }

  private creditLine(): string {
    let result: string = ''
    if (this.vodDirector.length > 0) {
      result = '导演：' + this.vodDirector
    }
    if (this.vodActor.length > 0) {
      if (result.length > 0) {
        result = result + '  '
      }
      result = result + '主演：' + this.vodActor
    }
    return result
  }

  private continueSubTitle(): string {
    let ep: PlayEp | null = this.activeEpisode()
    if (ep === null) {
      return '选择剧集开始播放'
    }
    let text: string = ep.title
    let size: string = this.epSizeText(ep)
    if (size.length > 0) {
      text = text + '  [' + size + ']'
    }
    return text
  }

  private activeEpisode(): PlayEp | null {
    let eps: PlayEp[] = this.activeSourceEps()
    if (this.activeEpisodeIndex >= 0 && this.activeEpisodeIndex < eps.length) {
      return eps[this.activeEpisodeIndex]
    }
    return null
  }

  private isActiveEpisode(index: number): boolean {
    return this.activeEpisodeIndex === index
  }

  private episodeOverlayColor(index: number): string {
    if (this.isActiveEpisode(index)) {
      return '#12000000'
    }
    return '#66000000'
  }

  private episodeBadgeText(index: number): string {
    let num: number = index + 1
    if (num < 10) {
      return 'E0' + num.toString()
    }
    return 'E' + num.toString()
  }

  private epSizeText(ep: PlayEp): string {
    let s: number | undefined = ep.size
    if (s === undefined || s === null || s <= 0) {
      return ''
    }
    let units: string[] = ['B', 'KB', 'MB', 'GB', 'TB']
    let idx: number = 0
    let size: number = s
    while (size >= 1024 && idx < units.length - 1) {
      size = size / 1024
      idx++
    }
    return size.toFixed(2) + units[idx]
  }

  private fileCardTitle(ep: PlayEp): string {
    if (ep.fileName.length > 0) {
      return ep.fileName
    }
    return ep.title
  }

  private posterUrl(url: string): string {
    let trimmed: string = url.trim()
    if (trimmed.length > 0) {
      return this.upgradeImageUrl(trimmed)
    }
    return EMPTY_VOD_PIC
  }

  private optionalPosterUrl(url: string): string {
    let trimmed: string = url.trim()
    if (trimmed.length > 0) {
      return this.upgradeImageUrl(trimmed)
    }
    return ''
  }

  private upgradeImageUrl(url: string): string {
    return url.replace('/t/p/w185/', '/t/p/w780/')
      .replace('/t/p/w220/', '/t/p/w780/')
      .replace('/t/p/w300/', '/t/p/w780/')
      .replace('/t/p/w342/', '/t/p/w780/')
      .replace('/t/p/w500/', '/t/p/w780/')
      .replace('/view/photo/s_ratio_poster/public/', '/view/photo/l_ratio_poster/public/')
      .replace('/view/photo/m_ratio_poster/public/', '/view/photo/l_ratio_poster/public/')
  }

  private nonEmptyText(value: string, fallback: string): string {
    let trimmed: string = value.trim()
    if (trimmed.length > 0) {
      return trimmed
    }
    return fallback
  }

  private errorText(err: Object): string {
    if (err instanceof Error && err.message.length > 0) {
      return err.message
    }
    return '详情加载失败'
  }
}
