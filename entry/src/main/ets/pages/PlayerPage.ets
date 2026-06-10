import { router } from '@kit.ArkUI'
import { media } from '@kit.MediaKit'
import { BusinessError } from '@kit.BasicServicesKit'

interface PlayerRouteParams {
  play_url?: string
  title?: string
  cover?: string
  source?: string
  message?: string
  headers_json?: string
}

interface PlayerHeaderPayload {
  Cookie?: string
  UserAgent?: string
  Referer?: string
  Origin?: string
}

class PlayerNormalizedHeaders {
  enabled: boolean = false
  cookie: string = ''
  userAgent: string = ''
  referer: string = ''
  origin: string = ''
}

const EMPTY_COVER: string = 'https://via.placeholder.com/640x360/201D19/F37021?text=CobranderTV'
const DEFAULT_USER_AGENT: string =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
const DEFAULT_REFERER: string = 'https://pan.quark.cn'
const DEFAULT_ORIGIN: string = 'https://pan.quark.cn'

@Entry
@Component
struct PlayerPage {
  @State private playUrl: string = ''
  @State private title: string = '正在播放'
  @State private cover: string = EMPTY_COVER
  @State private source: string = ''
  @State private message: string = ''
  @State private headersJson: string = ''
  @State private playerReady: boolean = false
  @State private isPreparing: boolean = false
  @State private isPlaying: boolean = false

  private player: media.AVPlayer | null = null
  private xComponentController: XComponentController = new XComponentController()
  private surfaceId: string = ''
  private hasStarted: boolean = false
  private preparingRequested: boolean = false
  private playRequested: boolean = false

  aboutToAppear(): void {
    let params = router.getParams()
    if (params !== null && params !== undefined) {
      let p: PlayerRouteParams = params as PlayerRouteParams
      let url: string = p.play_url ?? ''
      if (url.length > 0) {
        this.playUrl = url
      }
      let name: string = p.title ?? ''
      if (name.length > 0) {
        this.title = name
      }
      let poster: string = p.cover ?? ''
      if (poster.length > 0) {
        this.cover = poster
      }
      this.source = p.source ?? ''
      this.message = p.message ?? ''
      this.headersJson = p.headers_json ?? ''
    }
  }

  aboutToDisappear(): void {
    this.releasePlayer()
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
          if (this.playUrl.length > 0) {
            this.buildAvPlayerSurface()
          } else {
            this.buildEmptyPlayer()
          }

          this.buildBottomInfo()
        }
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)

        this.buildTopBar()
        this.buildCenterStatus()
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }

  @Builder
  buildAvPlayerSurface() {
    Stack() {
      Image(this.cover)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Contain)
        .opacity(this.playerReady ? 0 : 0.42)
        .backgroundColor(Color.Black)

      XComponent({
        id: 'cobranderPlayerSurface',
        type: XComponentType.SURFACE,
        controller: this.xComponentController
      })
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)
        .onLoad(() => {
          this.surfaceId = this.xComponentController.getXComponentSurfaceId()
          this.startPlayback()
        })
        .onDestroy(() => {
          this.releasePlayer()
        })
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  buildTopBar() {
    Row() {
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20)
          .fontColor([Color.White])
      }
      .width(38)
      .height(38)
      .borderRadius(19)
      .backgroundColor('#33000000')
      .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
      .onClick(() => {
        router.back()
      })

      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ left: 10, right: 10 })
    }
    .width('100%')
    .padding({ left: 16, top: 48, right: 16 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  buildCenterStatus() {
    if (this.isPreparing || this.message.length > 0 && !this.isPlaying) {
      Column({ space: 10 }) {
        if (this.isPreparing) {
          LoadingProgress()
            .width(32)
            .height(32)
            .color('#F37021')
        }
        Text(this.centerStatusText())
          .fontSize(13)
          .fontColor('#F8F6F2')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .padding({ left: 32, right: 32 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .hitTestBehavior(HitTestMode.None)
    }
  }

  @Builder
  buildBottomInfo() {
    Column({ space: 4 }) {
      if (this.source.length > 0) {
        Text(this.source)
          .fontSize(12)
          .fontColor('#BEB6AA')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(12)
          .fontColor('#F37021')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 18 })
    .backgroundColor('#201D19')
  }

  @Builder
  buildEmptyPlayer() {
    Column({ space: 12 }) {
      Blank()
      SymbolGlyph($r('sys.symbol.play_fill'))
        .fontSize(48)
        .fontColor(['#F37021'])
      Text('未获取到播放地址')
        .fontSize(15)
        .fontColor(Color.White)
      Blank()
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  private async startPlayback(): Promise<void> {
    if (this.hasStarted || this.playUrl.length === 0 || this.surfaceId.length === 0) {
      return
    }
    this.hasStarted = true
    this.isPreparing = true
    this.playerReady = false
    this.isPlaying = false
    this.message = '正在准备播放器...'
    try {
      let avPlayer: media.AVPlayer = await media.createAVPlayer()
      this.player = avPlayer
      this.registerPlayerEvents(avPlayer)
      let source: media.MediaSource = this.mediaSource()
      await avPlayer.setMediaSource(source)
    } catch (err) {
      this.message = this.errorText(err)
      this.isPreparing = false
      this.playerReady = false
      this.isPlaying = false
    }
  }

  private registerPlayerEvents(avPlayer: media.AVPlayer): void {
    avPlayer.on('stateChange', (state: media.AVPlayerState, reason: media.StateChangeReason) => {
      this.handleStateChange(state, reason)
    })
    avPlayer.on('error', (err: BusinessError) => {
      this.message = '播放失败: ' + err.message
      this.isPreparing = false
      this.playerReady = false
      this.isPlaying = false
    })
  }

  private handleStateChange(state: media.AVPlayerState, reason: media.StateChangeReason): void {
    if (state === 'initialized') {
      this.prepareWhenInitialized()
      return
    }
    if (state === 'prepared') {
      this.message = '播放器已准备'
      this.isPreparing = false
      this.playerReady = true
      this.playWhenPrepared()
      return
    }
    if (state === 'playing') {
      this.message = '正在播放'
      this.isPreparing = false
      this.playerReady = true
      this.isPlaying = true
      return
    }
    if (state === 'paused') {
      this.message = '已暂停'
      this.isPlaying = false
      return
    }
    if (state === 'completed') {
      this.message = '播放结束'
      this.isPlaying = false
      return
    }
    if (state === 'error') {
      this.message = '播放失败，请检查网盘账号或播放地址'
      this.isPreparing = false
      this.playerReady = false
      this.isPlaying = false
    }
  }

  private mediaSource(): media.MediaSource {
    let headers: PlayerNormalizedHeaders = this.playerHeaders()
    if (headers.enabled) {
      return media.createMediaSourceWithUrl(this.playUrl,
        JSON.parse(this.mediaSourceHeadersJson(headers)) as Record<string, string>)
    }
    return media.createMediaSourceWithUrl(this.playUrl)
  }

  private mediaSourceHeadersJson(headers: PlayerNormalizedHeaders): string {
    return '{"Cookie":' + JSON.stringify(headers.cookie) +
      ',"User-Agent":' + JSON.stringify(headers.userAgent) +
      ',"Referer":' + JSON.stringify(headers.referer) +
      ',"Origin":' + JSON.stringify(headers.origin) + '}'
  }

  private prepareWhenInitialized(): void {
    if (this.preparingRequested) {
      return
    }
    let avPlayer: media.AVPlayer | null = this.player
    if (avPlayer === null) {
      return
    }
    this.preparingRequested = true
    this.message = '正在缓冲视频...'
    avPlayer.surfaceId = this.surfaceId
    avPlayer.prepare().catch((err: BusinessError) => {
      this.message = this.errorText(err)
      this.isPreparing = false
      this.playerReady = false
      this.isPlaying = false
    })
  }

  private playWhenPrepared(): void {
    if (this.playRequested) {
      return
    }
    let avPlayer: media.AVPlayer | null = this.player
    if (avPlayer === null) {
      return
    }
    this.playRequested = true
    avPlayer.play().catch((err: BusinessError) => {
      this.message = this.errorText(err)
      this.isPreparing = false
      this.playerReady = false
      this.isPlaying = false
    })
  }

  private playerHeaders(): PlayerNormalizedHeaders {
    let result = new PlayerNormalizedHeaders()
    let text: string = this.headersJson.trim()
    if (text.length === 0) {
      return result
    }
    try {
      let parsed = JSON.parse(this.normalizedHeadersJson(text)) as PlayerHeaderPayload
      if (parsed.Cookie !== undefined && parsed.Cookie.length > 0) {
        result.cookie = parsed.Cookie
        result.enabled = true
      }
      if (parsed.UserAgent !== undefined && parsed.UserAgent.length > 0) {
        result.userAgent = parsed.UserAgent
        result.enabled = true
      }
      if (parsed.Referer !== undefined && parsed.Referer.length > 0) {
        result.referer = parsed.Referer
        result.enabled = true
      }
      if (parsed.Origin !== undefined && parsed.Origin.length > 0) {
        result.origin = parsed.Origin
        result.enabled = true
      }
    } catch (err) {
      this.message = '播放头解析失败，尝试无 Cookie 播放'
    }
    if (result.enabled && result.userAgent.length === 0) {
      result.userAgent = DEFAULT_USER_AGENT
    }
    if (result.enabled && result.referer.length === 0) {
      result.referer = DEFAULT_REFERER
    }
    if (result.enabled && result.origin.length === 0) {
      result.origin = DEFAULT_ORIGIN
    }
    return result
  }

  private normalizedHeadersJson(text: string): string {
    return text
      .replace(/"User-Agent"\s*:/g, '"UserAgent":')
      .replace(/"user-agent"\s*:/g, '"UserAgent":')
      .replace(/"cookie"\s*:/g, '"Cookie":')
      .replace(/"referer"\s*:/g, '"Referer":')
      .replace(/"origin"\s*:/g, '"Origin":')
  }

  private releasePlayer(): void {
    let avPlayer: media.AVPlayer | null = this.player
    if (avPlayer !== null) {
      this.player = null
      avPlayer.release((err: BusinessError) => {
        if (err !== undefined && err !== null && err.message.length > 0) {
          this.message = '播放器释放失败: ' + err.message
        }
      })
    }
    this.hasStarted = false
    this.preparingRequested = false
    this.playRequested = false
    this.isPreparing = false
    this.isPlaying = false
  }

  private centerStatusText(): string {
    if (this.isPreparing) {
      return '正在加载视频...'
    }
    return this.message
  }

  private errorText(err: Object): string {
    if (err instanceof Error && err.message.length > 0) {
      return err.message
    }
    return '播放失败，请检查网盘账号或播放地址'
  }
}
