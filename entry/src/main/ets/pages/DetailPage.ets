import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { PanCookieProfile, PanPlayRequest, PanPlayResult } from '../common/model/PanModels'
import {
  ResolverDefaults,
  ResolverEpisode,
  ResolverPlaySource,
  ResolverVodDetail
} from '../common/model/ResolverModels'
import { HttpClient } from '../data/http/HttpClient'
import { QuarkPanRepository } from '../data/repository/QuarkPanRepository'
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
  @State vodRemarks: string = ''
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
  @State resolverBaseUrl: string = ResolverDefaults.BASE_URL
  @State resolverSourceId: string = ''
  @State siteKey: string = ''
  @State siteName: string = ''

  private resolverRepository: ResolverRepository = new ResolverRepository(new HttpClient())
  private quarkPanRepository: QuarkPanRepository = new QuarkPanRepository()

  aboutToAppear(): void {
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
      let siteDisplayName: string = p.site_name ?? ''
      if (siteDisplayName.length > 0) {
        this.siteName = siteDisplayName
      }
    }
    this.loadDetail()
  }

  build() {
    Column() {
      if (this.errorMsg.length > 0 && this.sources.length === 0 && !this.isLoading) {
        this.buildError()
      } else {
        Stack({ alignContent: Alignment.TopStart }) {
          Scroll() {
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
          }
          .scrollBar(BarState.Auto)
          .layoutWeight(1)

          this.buildTopBar()
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#5A524A')
  }

  @Builder
  buildPosterHero() {
    Stack({ alignContent: Alignment.Bottom }) {
      Image(this.vodPic)
        .width('100%')
        .height(600)
        .objectFit(ImageFit.Cover)
        .syncLoad(false)
        .backgroundColor('#241F1A')

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
        this.buildActionRow()
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 22 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height(600)
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
        .fontColor('#F4EFE8')
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
        .fontColor('#5D5A56')
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
    .backgroundColor('#F8F6F2')
    .shadow({ radius: 12, color: '#42000000', offsetY: 5 })
    .enabled(!this.isResolvingPlay)
    .onClick(async () => {
      await this.resolveActiveEpisode()
    })
  }

  @Builder
  buildActionRow() {
    Row({ space: 24 }) {
      this.buildActionIcon($r('sys.symbol.magnifyingglass'))
      this.buildActionIcon($r('sys.symbol.heart_fill'))
      this.buildActionIcon($r('sys.symbol.ellipsis_circle'))
    }
    .width('100%')
    .height(44)
    .justifyContent(FlexAlign.Center)
    .alignSelf(ItemAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  buildActionIcon(icon: Resource) {
    Button() {
      SymbolGlyph(icon)
        .fontSize(20)
        .fontColor([Color.White])
    }
    .width(40)
    .height(40)
    .borderRadius(20)
    .backgroundColor('#18FFFFFF')
  }

  @Builder
  buildTopBar() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20)
          .fontColor([Color.White])
      }
      .width(38)
      .height(38)
      .backgroundColor(Color.Transparent)
      .border({ width: 1.5, color: '#66FFFFFF' })
      .onClick(() => {
        router.back()
      })

      Blank()
    }
    .width('100%')
    .padding({ left: 10, top: 48, right: 18 })
  }

  @Builder
  buildIntroBlock() {
    Column({ space: 10 }) {
      Text(this.vodContent)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#F2ECE4')
        .lineHeight(24)
        .maxLines(this.showFullIntro ? 12 : 3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (this.vodDirector.length > 0 || this.vodActor.length > 0) {
        Text(this.creditLine())
          .fontSize(12)
          .fontColor('#BEB6AA')
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
                .fontColor(['#BEB6AA'])
            }
          }
          .height(34)
          .padding({ left: 0, right: 8 })
          .backgroundColor(Color.Transparent)
          .bindMenu(this.sourceMenuItems())

          Blank()

          this.buildSourceTool($r('sys.symbol.magnifyingglass'), true)
          this.buildSourceTool($r('sys.symbol.backward_fill'), false)
          this.buildSourceTool($r('sys.symbol.forward_end_fill'), false)

          Text('更多')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#BEB6AA')
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
  buildSourceTool(icon: Resource, active: boolean) {
    Button() {
      if (active) {
        SymbolGlyph(icon)
          .fontSize(18)
          .fontColor([Color.White])
      } else {
        SymbolGlyph(icon)
          .fontSize(18)
          .fontColor(['#928C84'])
      }
    }
    .width(34)
    .height(34)
    .borderRadius(17)
    .backgroundColor(Color.Transparent)
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
            .border({ width: 3, color: '#F8F6F2' })
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
          .fontColor('#BEB6AA')
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
        .backgroundColor('#2B2722')
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
      .backgroundColor('#2B2722')
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
          .fontColor('#D8CEC2')
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
  buildTag(text: string) {
    Text(text)
      .fontSize(11)
      .fontColor('#FFE0C0')
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .margin({ right: 6, bottom: 6 })
      .borderRadius(4)
      .backgroundColor('#33FFFFFF')
      .border({ width: 1, color: '#44FFFFFF' })
  }



  @Builder
  buildError() {
    Column({ space: 16 }) {
      Blank()
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
        .fontColor('#BEB6AA')
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
      Blank()
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor('#201D19')
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
    this.vodRemarks = detail.vodRemarks
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

  private heroTitleSize(): number {
    if (this.vodName.length > 10) {
      return 34
    }
    return 44
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

  private panBadgeText(ep: PlayEp): string {
    let text: string = ep.panType.toUpperCase()
    if (text.length > 0) {
      return text
    }
    if (ep.flag.length > 0) {
      return ep.flag
    }
    return 'PAN'
  }

  private fileExtText(ep: PlayEp): string {
    let ext: string = ep.fileExt.toUpperCase()
    if (ext.length > 0 && ext.length <= 8) {
      return ext
    }
    return 'FILE'
  }

  private fileCardTitle(ep: PlayEp): string {
    if (ep.fileName.length > 0) {
      return ep.fileName
    }
    return ep.title
  }

  private fileCardSubTitle(ep: PlayEp): string {
    let id: string = ep.fileId
    if (id.length > 10) {
      id = id.substring(0, 10)
    }
    if (id.length > 0) {
      return '文件 ID ' + id
    }
    if (ep.shareId.length > 0) {
      return '网盘分享 ' + ep.shareId
    }
    return '等待网盘缩略图'
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
