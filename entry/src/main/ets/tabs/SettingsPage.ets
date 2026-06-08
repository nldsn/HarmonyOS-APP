import { common } from '@kit.AbilityKit'
import { JsDetectResult, JsRuntimePlan } from '../common/model/BridgeModels'
import { SourceDescriptor } from '../common/model/SourceModels'
import { HttpClient } from '../data/http/HttpClient'
import { SourceRepository } from '../data/repository/SourceRepository'
import { CacheStore } from '../data/storage/CacheStore'
import { JsSandboxView } from '../components/runtime/JsSandboxView'
import { SourceManager } from '../domain/SourceManager'
import { JsPluginManager } from '../engine/js/JsPluginManager'
import { JsRuntimeHost } from '../engine/js/JsRuntimeHost'

@Component
export struct SettingsPage {
  @State private sourceUrl: string = 'https://9280.kstore.vip/cat/index.js.md5'
  @State private isLoading: boolean = false
  @State private statusMsg: string = ''
  @State private isError: boolean = false
  @State private currentSource: SourceDescriptor | null = null
  @State private detectMsg: string = ''
  @State private hasWebsiteBundle: boolean = false
  @State private hasWebsiteBundleString: boolean = false
  @State private hasModuleExports: boolean = false
  @State private hasWindowAccess: boolean = false
  @State private hasServerFactory: boolean = false
  @State private hasStartFunction: boolean = false
  @State private hasFullConfigRoute: boolean = false
  @State private hasSitesListRoute: boolean = false
  @State private defaultServerPort: number = 0
  @State private runtimePlan: string = ''
  @StorageLink('jsSandboxScript') sandboxScript: string = ''
  @StorageLink('jsSandboxCommand') sandboxCommand: string = ''
  @StorageLink('jsSandboxResult') sandboxResult: string = ''
  @StorageLink('jsSandboxState') sandboxState: string = 'idle'
  @StorageProp('statusBarTop') statusBarTop: number = 44

  private sourceManager: SourceManager | null = null
  private pluginManager: JsPluginManager | null = null

  aboutToAppear(): void {
    this.ensureManager()
    this.restoreCurrentSource()
  }

  private ensureManager(): SourceManager | null {
    if (this.sourceManager !== null) {
      return this.sourceManager
    }
    let context = getContext(this) as common.UIAbilityContext
    if (context === null || context === undefined) {
      return null
    }
    let cacheStore = new CacheStore(context)
    let repository = new SourceRepository(cacheStore)
    let runtimeHost = new JsRuntimeHost()
    this.pluginManager = new JsPluginManager(repository, runtimeHost)
    this.sourceManager = new SourceManager(new HttpClient(), repository)
    return this.sourceManager
  }

  private restoreCurrentSource(): void {
    let manager = this.ensureManager()
    if (manager === null) {
      return
    }
    this.currentSource = manager.getCurrentSource()
    if (this.currentSource !== null) {
      this.sourceUrl = this.currentSource.inputUrl
      this.statusMsg = '已恢复上次缓存的 JS 订阅源'
      this.isError = false
      this.detectCachedScript()
    }
  }

  private async loadSource(): Promise<void> {
    let manager = this.ensureManager()
    if (manager === null) {
      this.statusMsg = '无法获取应用上下文'
      this.isError = true
      return
    }

    this.isLoading = true
    this.statusMsg = '正在拉取 MD5 与 JS 订阅源...'
    this.isError = false

    try {
      let result = await manager.loadSource({
        inputUrl: this.sourceUrl,
        displayName: 'Mira/Cat JS 源'
      })
      this.currentSource = result.descriptor
      this.detectCachedScript()
      this.statusMsg = result.changed ? 'JS 订阅源已下载并缓存' : '本地缓存已是最新'
      this.isError = false
    } catch (err) {
      this.currentSource = null
      this.statusMsg = this.errorText(err)
      this.isError = true
    } finally {
      this.isLoading = false
    }
  }

  private detectCachedScript(): void {
    let manager = this.pluginManager
    if (manager === null) {
      this.detectMsg = ''
      this.hasWebsiteBundle = false
      this.hasWebsiteBundleString = false
      this.hasModuleExports = false
      this.hasWindowAccess = false
      this.hasServerFactory = false
      this.hasStartFunction = false
      this.hasFullConfigRoute = false
      this.hasSitesListRoute = false
      this.defaultServerPort = 0
      this.runtimePlan = ''
      return
    }
    let result = manager.prepareCachedRuntime()
    this.applyDetectResult(result)
  }

  private runSandboxProbe(): void {
    if (this.isSandboxProbeRunning()) {
      return
    }
    let manager = this.pluginManager
    if (manager === null) {
      this.sandboxState = 'missing_manager'
      return
    }
    let script = manager.buildSandboxLoadScript()
    if (script.length === 0) {
      this.sandboxState = 'missing_script'
      return
    }
    this.sandboxScript = script
    this.sandboxResult = ''
    this.sandboxCommand = 'load'
  }

  private isSandboxProbeRunning(): boolean {
    return this.sandboxState === 'loading' ||
      this.sandboxState === 'injecting' ||
      this.sandboxState.indexOf('injecting ') === 0 ||
      this.sandboxState === 'evaluating' ||
      this.sandboxState === 'probing'
  }

  private applyDetectResult(result: JsDetectResult): void {
    this.detectMsg = result.message
    this.hasWebsiteBundle = result.hasWebsiteBundle
    this.hasWebsiteBundleString = result.hasWebsiteBundleString
    this.hasModuleExports = result.hasModuleExports
    this.hasWindowAccess = result.hasWindow
    this.hasServerFactory = result.hasServerFactory
    this.hasStartFunction = result.hasStartFunction
    this.hasFullConfigRoute = result.hasFullConfigRoute
    this.hasSitesListRoute = result.hasSitesListRoute
    this.defaultServerPort = result.defaultPort
    this.runtimePlan = this.resolveRuntimePlan(result)
  }

  private resolveRuntimePlan(result: JsDetectResult): string {
    if (result.hasServerFactory || result.hasFullConfigRoute) {
      return JsRuntimePlan.LOCAL_SERVER
    }
    if (result.hasWebsiteBundle) {
      return JsRuntimePlan.WEB_BUNDLE_ONLY
    }
    return JsRuntimePlan.UNKNOWN
  }

  private errorText(err: Object): string {
    if (err instanceof Error && err.message.length > 0) {
      return err.message
    }
    return '订阅源加载失败'
  }

  private sourceSizeText(): string {
    if (this.currentSource === null) {
      return ''
    }
    let size = this.currentSource.scriptSize
    if (size >= 1024 * 1024) {
      return (size / 1024 / 1024).toFixed(2) + ' MB'
    }
    if (size >= 1024) {
      return (size / 1024).toFixed(2) + ' KB'
    }
    return size.toString() + ' B'
  }

  private cachedAtText(): string {
    if (this.currentSource === null) {
      return ''
    }
    return new Date(this.currentSource.cachedAt).toLocaleString()
  }

  build() {
    Stack() {
      JsSandboxView()

      Scroll() {
        Column({ space: 12 }) {
          Text('源地址')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          TextInput({
            placeholder: '请输入源地址',
            text: this.sourceUrl
          })
            .fontSize(14)
            .placeholderColor($r('app.color.text_secondary'))
            .placeholderFont({ size: 14 })
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(12)
            .height(48)
            .padding({ left: 16, right: 16 })
            .onChange((value: string) => {
              this.sourceUrl = value
            })

          if (this.statusMsg.length > 0) {
            Text(this.statusMsg)
              .fontSize(13)
              .fontColor(
                this.isError ? '#FF3B30'
                  : this.isLoading ? $r('app.color.hermes_orange')
                  : '#34C759'
              )
              .width('100%')
              .padding({ left: 4 })
          }

          Button(this.isLoading ? '加载中...' : '加载 JS 订阅源')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .width('100%')
            .height(48)
            .borderRadius(12)
            .backgroundColor(
              this.isLoading ? $r('app.color.text_secondary')
                : $r('app.color.hermes_orange')
            )
            .enabled(!this.isLoading)
            .onClick(async () => {
              await this.loadSource()
            })

          if (this.currentSource !== null) {
            Button(this.isSandboxProbeRunning() ? '沙箱探测中...' : '运行沙箱探测')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.hermes_orange'))
              .width('100%')
              .height(44)
              .borderRadius(10)
              .backgroundColor($r('app.color.card_background'))
              .enabled(!this.isSandboxProbeRunning())
              .onClick(() => {
                this.runSandboxProbe()
              })

            this.buildSourceInfo()
          }

          Column().height(120)
        }
        .width('100%')
        .padding({ left: 16, top: 24 + this.statusBarTop, right: 16, bottom: 24 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  @Builder
  buildSourceInfo() {
    Column({ space: 8 }) {
      this.buildInfoRow('协议', this.currentSourceProtocol())
      this.buildInfoRow('MD5', this.currentSourceMd5())
      this.buildInfoRow('大小', this.sourceSizeText())
      this.buildInfoRow('缓存时间', this.cachedAtText())
      this.buildInfoRow('探测结果', this.detectMsg)
      this.buildInfoRow('websiteBundle', this.flagText(this.hasWebsiteBundle))
      this.buildInfoRow('websiteBundle 字符串', this.flagText(this.hasWebsiteBundleString))
      this.buildInfoRow('module.exports', this.flagText(this.hasModuleExports))
      this.buildInfoRow('window 访问', this.flagText(this.hasWindowAccess))
      this.buildInfoRow('JS Server', this.flagText(this.hasServerFactory))
      this.buildInfoRow('启动入口', this.flagText(this.hasStartFunction))
      this.buildInfoRow('/full-config', this.flagText(this.hasFullConfigRoute))
      this.buildInfoRow('/sites/list', this.flagText(this.hasSitesListRoute))
      this.buildInfoRow('默认端口', this.serverPortText())
      this.buildInfoRow('运行计划', this.runtimePlan)
      this.buildInfoRow('沙箱状态', this.sandboxState)
      this.buildInfoRow('沙箱结果', this.sandboxResult)
      this.buildInfoRow('脚本地址', this.currentSourceScriptUrl())
    }
    .width('100%')
    .padding(12)
    .borderRadius(8)
    .backgroundColor($r('app.color.card_background'))
  }

  @Builder
  buildInfoRow(label: string, value: string) {
    Column({ space: 2 }) {
      Text(label)
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
      Text(value)
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
        .maxLines(this.infoValueMaxLines(label))
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  private currentSourceProtocol(): string {
    if (this.currentSource === null) {
      return ''
    }
    return this.currentSource.protocol
  }

  private currentSourceMd5(): string {
    if (this.currentSource === null) {
      return ''
    }
    return this.currentSource.md5
  }

  private currentSourceScriptUrl(): string {
    if (this.currentSource === null) {
      return ''
    }
    return this.currentSource.scriptUrl
  }

  private flagText(flag: boolean): string {
    return flag ? '是' : '否'
  }

  private serverPortText(): string {
    if (this.defaultServerPort <= 0) {
      return '未识别'
    }
    return this.defaultServerPort.toString()
  }

  private infoValueMaxLines(label: string): number {
    if (label === '沙箱结果') {
      return 18
    }
    if (label === '脚本地址') {
      return 3
    }
    return 2
  }
}
