import { router, window } from '@kit.ArkUI'
import { media } from '@kit.MediaKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { common } from '@kit.AbilityKit'
import { QuarkPanRepository } from '../data/repository/QuarkPanRepository'
import { PanPlayRequest, PanPlayResult } from '../common/model/PanModels'

interface PlayerRouteParams {
  play_url?: string
  title?: string
  cover?: string
  source?: string
  message?: string
  headers_json?: string
  quark_request_json?: string
  quark_cookie?: string
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

interface PlayerMenuItem {
  value: string
  action: () => void
}

const EMPTY_COVER: string = 'https://via.placeholder.com/640x360/201D19/F37021?text=CobranderTV'
const DEFAULT_USER_AGENT: string = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
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
  @State private duration: number = 0
  @State private currentTime: number = 0
  @State private isVolumeMuted: boolean = false
  @State private volume: number = 1.0
  @State private showControls: boolean = true
  @State private isSliderDragging: boolean = false
  
  @State private displayMode: number = 0 // 0: 默认, 1: 平铺, 2: 拉伸
  @State private videoWidth: number = 0
  @State private videoHeight: number = 0
  @State private playbackSpeed: media.PlaybackSpeed = media.PlaybackSpeed.SPEED_FORWARD_1_00_X
  @State private quarkRequestJson: string = ''
  @State private quarkCookie: string = ''

  private player: media.AVPlayer | null = null
  private xComponentController: XComponentController = new XComponentController()
  private surfaceId: string = ''
  private hasStarted: boolean = false
  private preparingRequested: boolean = false
  private playRequested: boolean = false
  private controlsTimerId: number = -1
  private quarkPanRepository: QuarkPanRepository = new QuarkPanRepository()

  aboutToAppear(): void {
    let params = router.getParams()
    if (params !== null && params !== undefined) {
      let p: PlayerRouteParams = params as PlayerRouteParams
      if (p.play_url) this.playUrl = p.play_url
      if (p.title) this.title = p.title
      if (p.cover) this.cover = p.cover
      if (p.source) this.source = p.source
      if (p.message) this.message = p.message
      if (p.headers_json) this.headersJson = p.headers_json
      if (p.quark_request_json) this.quarkRequestJson = p.quark_request_json
      if (p.quark_cookie) this.quarkCookie = p.quark_cookie
    }
    
    if (this.quarkRequestJson.length > 0) {
      this.resolveQuarkResource()
    }
  }

  onPageShow(): void {
    let context = getContext(this) as common.UIAbilityContext
    window.getLastWindow(context).then((win) => {
      win.setPreferredOrientation(window.Orientation.LANDSCAPE).catch((err: BusinessError) => {
        // ignore
      })
      win.setWindowSystemBarEnable([]).catch((err: BusinessError) => {
        // ignore
      })
    }).catch((err: BusinessError) => {
      this.message = '设置全屏横屏失败: ' + err.message
    })
  }

  onPageHide(): void {
    this.clearControlsTimer()
    let context = getContext(this) as common.UIAbilityContext
    window.getLastWindow(context).then((win) => {
      win.setPreferredOrientation(window.Orientation.PORTRAIT).catch((err: BusinessError) => {
        // ignore
      })
      win.setWindowSystemBarEnable(['status', 'navigation']).catch((err: BusinessError) => {
        // ignore
      })
    }).catch((err: BusinessError) => {
      this.message = '恢复窗口方向失败: ' + err.message
    })
  }

  aboutToDisappear(): void {
    this.releasePlayer()
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.playUrl.length > 0) {
        this.buildAvPlayerSurface()
      } else if (this.quarkRequestJson.length > 0) {
        // 等待解析中，不渲染 EmptyPlayer
      } else {
        this.buildEmptyPlayer()
      }

      this.buildCenterStatus()

      if (this.showControls) {
        this.buildControlsOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .gesture(
      GestureGroup(GestureMode.Exclusive,
        TapGesture({ count: 2 }).onAction(() => {
          this.togglePlayPause()
        }),
        TapGesture({ count: 1 }).onAction(() => {
          this.toggleControls()
        })
      )
    )
  }

  @Builder
  buildAvPlayerSurface() {
    Stack({ alignContent: Alignment.Center }) {
      Image(this.cover)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Contain)
        .opacity(this.playerReady ? 0 : 0.42)
        .backgroundColor(Color.Black)

      Stack({ alignContent: Alignment.Center }) {
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
      .height('100%')
      .aspectRatio(this.displayMode === 0 && this.videoWidth > 0 && this.videoHeight > 0 ? this.videoWidth / this.videoHeight : undefined)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildControlsOverlay() {
    Column() {
      // 顶部渐变控制栏
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([Color.White])
        }
        .width(40)
        .height(40)
        .type(ButtonType.Circle)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          router.back()
        })
        
        Column() {
          Text(this.title)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            
          if (this.source.length > 0) {
            Text('解析源: ' + this.source)
              .fontSize(12)
              .fontColor('#CCFFFFFF')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
        }
        .layoutWeight(1)
        .margin({ left: 16 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 16, bottom: 24 })
      .linearGradient({
        angle: 180,
        colors: [['#99000000', 0.0], ['#00000000', 1.0]]
      })
      .alignItems(VerticalAlign.Center)
      .transition(TransitionEffect.OPACITY)

      Blank() // 推挤至底部

      // 底部渐变控制栏
      Row({ space: 16 }) {
        Button() {
          SymbolGlyph(this.isPlaying ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
            .fontSize(24)
            .fontColor([Color.White])
        }
        .width(40)
        .height(40)
        .type(ButtonType.Circle)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.togglePlayPause()
        })

        Text(this.formatTime(this.currentTime))
          .fontSize(12)
          .fontColor('#E6FFFFFF')

        Slider({
          value: this.currentTime,
          min: 0,
          max: this.duration,
          style: SliderStyle.OutSet
        })
        .layoutWeight(1)
        .blockColor('#F37021')
        .trackColor('#4DFFFFFF')
        .selectedColor('#F37021')
        .showSteps(false)
        .onChange((value: number, mode: SliderChangeMode) => {
          if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving) {
            this.isSliderDragging = true
            this.currentTime = value
          } else if (mode === SliderChangeMode.End) {
            this.isSliderDragging = false
            let avPlayer = this.player
            if (avPlayer !== null) {
              try {
                avPlayer.seek(value)
              } catch (e) {
                // 静默忽略
              }
            }
            this.startControlsTimer()
          }
        })

        Text(this.formatTime(this.duration))
          .fontSize(12)
          .fontColor('#E6FFFFFF')

        Button(this.speedText())
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor(Color.Transparent)
          .padding({ left: 8, right: 8, top: 8, bottom: 8 })
          .onClick(() => {
            this.startControlsTimer()
          })
          .bindMenu(this.speedMenuItems())

        Button(this.scaleText())
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor(Color.Transparent)
          .padding({ left: 8, right: 8, top: 8, bottom: 8 })
          .onClick(() => {
            this.startControlsTimer()
          })
          .bindMenu(this.scaleMenuItems())
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 24, bottom: 24 })
      .linearGradient({
        angle: 180,
        colors: [['#00000000', 0.0], ['#B3000000', 1.0]]
      })
      .alignItems(VerticalAlign.Center)
      .transition(TransitionEffect.OPACITY)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildCenterStatus() {
    if (this.isPreparing || (this.message.length > 0 && !this.isPlaying)) {
      Column({ space: 16 }) {
        if (this.isPreparing) {
          LoadingProgress()
            .width(48)
            .height(48)
            .color('#F37021')
        }
        Text(this.centerStatusText())
          .fontSize(14)
          .fontColor(Color.White)
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
  buildEmptyPlayer() {
    Column({ space: 16 }) {
      SymbolGlyph($r('sys.symbol.play_fill'))
        .fontSize(64)
        .fontColor(['#F37021'])
      Text('未获取到播放地址')
        .fontSize(16)
        .fontColor(Color.White)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  private async resolveQuarkResource(): Promise<void> {
    this.isPreparing = true
    this.message = '缓冲中...'
    try {
      let req = JSON.parse(this.quarkRequestJson) as PanPlayRequest
      let result: PanPlayResult = await this.quarkPanRepository.resolve(req, this.quarkCookie)
      if (result.ok && result.url.length > 0) {
        this.playUrl = result.url
        this.source = result.source
        if (result.headersJson) {
           this.headersJson = result.headersJson
        }
      } else {
        this.message = result.message || '解析失败，请检查资源或账号'
        this.isPreparing = false
      }
    } catch (e) {
      let err = e as BusinessError
      this.message = this.errorText(err)
      this.isPreparing = false
    }
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
    avPlayer.on('videoSizeChange', (width: number, height: number) => {
      this.videoWidth = width
      this.videoHeight = height
    })
    avPlayer.on('timeUpdate', (time: number) => {
      if (!this.isSliderDragging) {
        this.currentTime = time
      }
    })
    avPlayer.on('error', (err: BusinessError) => {
      this.message = '播放异常: ' + err.message
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
      this.message = '已就绪'
      this.isPreparing = false
      this.playerReady = true
      let avPlayer = this.player
      if (avPlayer !== null) {
        this.duration = avPlayer.duration
        try {
          if (this.displayMode === 1) {
            avPlayer.videoScaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT_CROP
          } else {
            avPlayer.videoScaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT
          }
          avPlayer.setSpeed(this.playbackSpeed)
        } catch (err) {
          // 静默
        }
      }
      this.playWhenPrepared()
      this.startControlsTimer()
      return
    }
    if (state === 'playing') {
      this.message = ''
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
      this.message = '播放失败，请检查视频源有效性'
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
    try {
      avPlayer.surfaceId = this.surfaceId
      avPlayer.prepare().catch((err: BusinessError) => {
        this.message = this.errorText(err)
        this.isPreparing = false
        this.playerReady = false
        this.isPlaying = false
      })
    } catch (e) {
      let err = e as BusinessError
      this.message = this.errorText(err)
      this.isPreparing = false
    }
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
    try {
      avPlayer.play()
    } catch (err) {
      let error = err as BusinessError
      this.message = this.errorText(error)
      this.isPreparing = false
      this.playerReady = false
      this.isPlaying = false
    }
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
      // 忽略解析失败
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
    this.clearControlsTimer()
    let avPlayer: media.AVPlayer | null = this.player
    if (avPlayer !== null) {
      this.player = null
      try {
        avPlayer.release((err: BusinessError) => {
          // 内部忽略
        })
      } catch (e) {
        // 忽略
      }
    }
    this.hasStarted = false
    this.preparingRequested = false
    this.playRequested = false
    this.isPreparing = false
    this.isPlaying = false
  }

  private centerStatusText(): string {
    if (this.isPreparing) {
      return this.message.length > 0 ? this.message : '正在加载视频...'
    }
    return this.message
  }

  private errorText(err: Object): string {
    if (err instanceof Error && err.message.length > 0) {
      return err.message
    }
    return '加载失败'
  }

  private startControlsTimer(): void {
    this.clearControlsTimer()
    this.controlsTimerId = setTimeout(() => {
      this.showControls = false
    }, 4000)
  }

  private clearControlsTimer(): void {
    if (this.controlsTimerId !== -1) {
      clearTimeout(this.controlsTimerId)
      this.controlsTimerId = -1
    }
  }

  private togglePlayPause(): void {
    let avPlayer: media.AVPlayer | null = this.player
    if (avPlayer === null) {
      return
    }
    try {
      if (this.isPlaying) {
        avPlayer.pause()
      } else {
        avPlayer.play()
      }
    } catch (err) {
      let error = err as BusinessError
      this.message = '操作失败: ' + error.message
    }
    this.startControlsTimer()
  }

  private toggleControls(): void {
    this.showControls = !this.showControls
    if (this.showControls) {
      this.startControlsTimer()
    } else {
      this.clearControlsTimer()
    }
  }

  private formatTime(ms: number): string {
    if (isNaN(ms) || ms <= 0) {
      return '00:00'
    }
    let totalSec = Math.floor(ms / 1000)
    let sec = totalSec % 60
    let min = Math.floor(totalSec / 60) % 60
    let hour = Math.floor(totalSec / 3600)

    let pad = (num: number): string => {
      if (num < 10) {
        return '0' + num.toString()
      }
      return num.toString()
    }

    if (hour > 0) {
      return pad(hour) + ':' + pad(min) + ':' + pad(sec)
    }
    return pad(min) + ':' + pad(sec)
  }

  private speedText(): string {
    if (this.playbackSpeed === media.PlaybackSpeed.SPEED_FORWARD_0_75_X) {
      return '0.75x'
    }
    if (this.playbackSpeed === media.PlaybackSpeed.SPEED_FORWARD_1_25_X) {
      return '1.25x'
    }
    if (this.playbackSpeed === media.PlaybackSpeed.SPEED_FORWARD_1_75_X) {
      return '1.75x'
    }
    if (this.playbackSpeed === media.PlaybackSpeed.SPEED_FORWARD_2_00_X) {
      return '2.0x'
    }
    return '倍速'
  }

  private scaleText(): string {
    if (this.displayMode === 1) {
      return '平铺'
    }
    if (this.displayMode === 2) {
      return '拉伸'
    }
    return '默认'
  }

  private speedMenuItems(): PlayerMenuItem[] {
    let items: PlayerMenuItem[] = [
      {
        value: '0.75x 慢速',
        action: () => {
          this.changePlaybackSpeed(media.PlaybackSpeed.SPEED_FORWARD_0_75_X)
        }
      },
      {
        value: '1.0x 常规',
        action: () => {
          this.changePlaybackSpeed(media.PlaybackSpeed.SPEED_FORWARD_1_00_X)
        }
      },
      {
        value: '1.25x 稍快',
        action: () => {
          this.changePlaybackSpeed(media.PlaybackSpeed.SPEED_FORWARD_1_25_X)
        }
      },
      {
        value: '1.75x 极快',
        action: () => {
          this.changePlaybackSpeed(media.PlaybackSpeed.SPEED_FORWARD_1_75_X)
        }
      },
      {
        value: '2.0x 双倍速',
        action: () => {
          this.changePlaybackSpeed(media.PlaybackSpeed.SPEED_FORWARD_2_00_X)
        }
      }
    ]
    return items
  }

  private scaleMenuItems(): PlayerMenuItem[] {
    let items: PlayerMenuItem[] = [
      {
        value: '默认 (保持原比例)',
        action: () => {
          this.changeDisplayMode(0)
        }
      },
      {
        value: '平铺 (等比无黑边)',
        action: () => {
          this.changeDisplayMode(1)
        }
      },
      {
        value: '拉伸 (撑满全屏)',
        action: () => {
          this.changeDisplayMode(2)
        }
      }
    ]
    return items
  }

  private changeDisplayMode(mode: number): void {
    this.displayMode = mode
    let avPlayer = this.player
    if (avPlayer === null) {
      return
    }
    try {
      if (mode === 1) {
        avPlayer.videoScaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT_CROP
      } else {
        avPlayer.videoScaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT
      }
    } catch (err) {
      // 忽略
    }
    this.startControlsTimer()
  }

  private changePlaybackSpeed(speed: media.PlaybackSpeed): void {
    let avPlayer = this.player
    if (avPlayer === null) {
      return
    }
    try {
      avPlayer.setSpeed(speed)
      this.playbackSpeed = speed
    } catch (err) {
      // 忽略
    }
    this.startControlsTimer()
  }
}
