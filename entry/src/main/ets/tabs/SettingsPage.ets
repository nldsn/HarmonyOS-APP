import { ResolverDefaults, ResolverHealthResult, ResolverInspectResult } from '../common/model/ResolverModels'
import { SiteSimple } from '../common/model/SourceModels'
import { HttpClient } from '../data/http/HttpClient'
import { ResolverRepository } from '../data/repository/ResolverRepository'

@Component
export struct SettingsPage {
  @StorageLink('resolverBaseUrl') resolverUrl: string = ResolverDefaults.BASE_URL
  @StorageLink('resolverSourceId') resolverSourceId: string = ''
  @State private sourceUrl: string = 'https://9280.kstore.vip/cat/index.js.md5'
  @State private isLoading: boolean = false
  @State private statusMsg: string = ''
  @State private isError: boolean = false
  @State private resolverVersion: string = ''
  @State private inspectResult: ResolverInspectResult | null = null
  @State private healthResult: ResolverHealthResult | null = null
  @StorageLink('siteList') siteList: SiteSimple[] = []
  @StorageProp('statusBarTop') statusBarTop: number = 44

  private resolverRepository: ResolverRepository = new ResolverRepository(new HttpClient())
  private resolverInputController: TextInputController = new TextInputController()
  private sourceInputController: TextInputController = new TextInputController()

  private async checkResolverHealth(): Promise<void> {
    this.stopAllEditing()
    if (this.resolverUrl.trim().length === 0) {
      this.statusMsg = '请输入 Resolver 服务地址'
      this.isError = true
      return
    }

    this.isLoading = true
    this.isError = false
    this.statusMsg = '正在检测 Resolver 连通性...'
    try {
      let result = await this.resolverRepository.checkHealth(this.resolverUrl)
      this.healthResult = result
      this.resolverVersion = this.versionFromHealth(result)
      this.statusMsg = 'Resolver 连通成功，版本 ' + this.resolverVersion
      this.isError = false
    } catch (err) {
      this.healthResult = null
      this.resolverVersion = ''
      this.statusMsg = this.errorText(err)
      this.isError = true
    } finally {
      this.isLoading = false
    }
  }

  private async inspectRemoteSource(): Promise<void> {
    this.stopAllEditing()
    if (this.resolverUrl.trim().length === 0) {
      this.statusMsg = '请输入 Resolver 服务地址'
      this.isError = true
      return
    }
    if (this.sourceUrl.trim().length === 0) {
      this.statusMsg = '请输入订阅源地址'
      this.isError = true
      return
    }

    this.isLoading = true
    this.isError = false
    this.statusMsg = '正在请求远端解析服务...'

    try {
      await this.refreshResolverVersion()
      let result = await this.resolverRepository.inspectSource(this.resolverUrl, this.sourceUrl)
      this.inspectResult = result
      this.resolverSourceId = result.sourceId
      let loadedSites: SiteSimple[] = result.sites
      if (loadedSites.length === 0) {
        this.statusMsg = '正在启动远端运行时并加载站点...'
        let sitesResult = await this.resolverRepository.getSites(this.resolverUrl, result.sourceId)
        loadedSites = sitesResult.sites
        result.sites = loadedSites
      }
      this.inspectResult = result
      if (loadedSites.length > 0) {
        this.siteList = loadedSites
      }
      this.statusMsg = '远端解析成功，已加载 ' + loadedSites.length.toString() + ' 个站点'
      this.isError = false
    } catch (err) {
      this.inspectResult = null
      this.statusMsg = this.errorText(err)
      this.isError = true
    } finally {
      this.isLoading = false
    }
  }

  private errorText(err: Object): string {
    if (err instanceof Error && err.message.length > 0) {
      return err.message
    }
    return '远端解析检测失败'
  }

  private scriptSizeText(): string {
    if (this.inspectResult === null) {
      return ''
    }
    let size = this.inspectResult.scriptSize
    if (size >= 1024 * 1024) {
      return (size / 1024 / 1024).toFixed(2) + ' MB'
    }
    if (size >= 1024) {
      return (size / 1024).toFixed(2) + ' KB'
    }
    return size.toString() + ' B'
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 12 }) {
          this.buildTextInput('Resolver 地址', '请输入远端解析服务地址', this.resolverUrl, true)
          Text('真机调试请填写电脑局域网 IP，例如 http://192.168.0.166:8787')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .padding({ left: 4 })

          this.buildTextInput('订阅源地址', '请输入 index.js.md5 地址', this.sourceUrl, false)

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

          Row({ space: 10 }) {
            Button(this.isLoading ? '检测中...' : '连通性')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.hermes_orange'))
              .layoutWeight(1)
              .height(48)
              .borderRadius(12)
              .backgroundColor($r('app.color.card_background'))
              .enabled(!this.isLoading)
              .onClick(async () => {
                await this.checkResolverHealth()
              })

            Button(this.isLoading ? '检测中...' : '解析检测')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .layoutWeight(1)
              .height(48)
              .borderRadius(12)
              .backgroundColor(
                this.isLoading ? $r('app.color.text_secondary')
                  : $r('app.color.hermes_orange')
              )
              .enabled(!this.isLoading)
              .onClick(async () => {
                await this.inspectRemoteSource()
              })
          }
          .width('100%')

          if (this.inspectResult !== null) {
            this.buildResolverInfo()
          }

          if (this.healthResult !== null && this.inspectResult === null) {
            this.buildHealthInfo()
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
  buildTextInput(label: string, placeholder: string, textValue: string, isResolver: boolean) {
    Column({ space: 8 }) {
      Text(label)
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      TextInput({
        placeholder: placeholder,
        text: textValue,
        controller: this.textInputController(isResolver)
      })
        .fontSize(14)
        .placeholderColor($r('app.color.text_secondary'))
        .placeholderFont({ size: 14 })
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(12)
        .height(48)
        .padding({ left: 16, right: 16 })
        .enterKeyType(EnterKeyType.Done)
        .onChange((value: string) => {
          if (isResolver) {
            this.resolverUrl = value
          } else {
            this.sourceUrl = value
          }
        })
        .onSubmit((enterKey: EnterKeyType, event: SubmitEvent) => {
          this.stopEditing(isResolver)
        })
    }
    .width('100%')
  }

  @Builder
  buildHealthInfo() {
    Column({ space: 8 }) {
      this.buildInfoRow('服务', this.healthServiceText())
      this.buildInfoRow('版本', this.healthVersionText())
      this.buildInfoRow('运行时', this.healthRuntimeText())
      this.buildInfoRow('缓存源数量', this.healthSourcesText())
    }
    .width('100%')
    .padding(12)
    .borderRadius(8)
    .backgroundColor($r('app.color.card_background'))
  }

  @Builder
  buildResolverInfo() {
    Column({ space: 8 }) {
      this.buildInfoRow('解析模式', 'remote_node')
      this.buildInfoRow('服务版本', this.resolverVersionText())
      this.buildInfoRow('Source ID', this.resultSourceId())
      this.buildInfoRow('协议', this.resultProtocol())
      this.buildInfoRow('MD5', this.resultMd5())
      this.buildInfoRow('大小', this.scriptSizeText())
      this.buildInfoRow('运行时', this.resultRuntime())
      this.buildInfoRow('检测结果', this.resultMessage())
      this.buildInfoRow('websiteBundle', this.flagText(this.resultHasWebsiteBundle()))
      this.buildInfoRow('module.exports', this.flagText(this.resultHasModuleExports()))
      this.buildInfoRow('window 访问', this.flagText(this.resultHasWindowAccess()))
      this.buildInfoRow('JS Server', this.flagText(this.resultHasServerFactory()))
      this.buildInfoRow('/full-config', this.flagText(this.resultHasFullConfigRoute()))
      this.buildInfoRow('/sites/list', this.flagText(this.resultHasSitesListRoute()))
      this.buildInfoRow('默认端口', this.resultDefaultPortText())
      this.buildInfoRow('站点数', this.resultSiteCountText())
      this.buildInfoRow('脚本地址', this.resultScriptUrl())
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

  private resultSourceId(): string {
    if (this.inspectResult === null) {
      return ''
    }
    return this.inspectResult.sourceId
  }

  private textInputController(isResolver: boolean): TextInputController {
    if (isResolver) {
      return this.resolverInputController
    }
    return this.sourceInputController
  }

  private stopEditing(isResolver: boolean): void {
    this.textInputController(isResolver).stopEditing()
  }

  private stopAllEditing(): void {
    this.resolverInputController.stopEditing()
    this.sourceInputController.stopEditing()
  }

  private async refreshResolverVersion(): Promise<void> {
    try {
      let result = await this.resolverRepository.checkHealth(this.resolverUrl)
      this.healthResult = result
      this.resolverVersion = this.versionFromHealth(result)
    } catch (err) {
      this.healthResult = null
      this.resolverVersion = ''
    }
  }

  private versionFromHealth(result: ResolverHealthResult): string {
    let version: string | undefined = result.version
    if (version === undefined || version.length === 0) {
      return '旧版本或未上报'
    }
    return version
  }

  private resolverVersionText(): string {
    if (this.resolverVersion.length === 0) {
      return '未连接'
    }
    return this.resolverVersion
  }

  private healthServiceText(): string {
    if (this.healthResult === null) {
      return ''
    }
    return this.healthResult.service
  }

  private healthRuntimeText(): string {
    if (this.healthResult === null) {
      return ''
    }
    return this.healthResult.runtime
  }

  private healthVersionText(): string {
    if (this.healthResult === null) {
      return ''
    }
    return this.versionFromHealth(this.healthResult)
  }

  private healthSourcesText(): string {
    if (this.healthResult === null) {
      return '0'
    }
    return this.healthResult.sources.toString()
  }

  private resultProtocol(): string {
    if (this.inspectResult === null) {
      return ''
    }
    return this.inspectResult.protocol
  }

  private resultMd5(): string {
    if (this.inspectResult === null) {
      return ''
    }
    return this.inspectResult.md5
  }

  private resultRuntime(): string {
    if (this.inspectResult === null) {
      return ''
    }
    return this.inspectResult.runtime
  }

  private resultMessage(): string {
    if (this.inspectResult === null) {
      return ''
    }
    return this.inspectResult.message
  }

  private resultScriptUrl(): string {
    if (this.inspectResult === null) {
      return ''
    }
    return this.inspectResult.scriptUrl
  }

  private resultHasWebsiteBundle(): boolean {
    if (this.inspectResult === null) {
      return false
    }
    return this.inspectResult.features.hasWebsiteBundle
  }

  private resultHasModuleExports(): boolean {
    if (this.inspectResult === null) {
      return false
    }
    return this.inspectResult.features.hasModuleExports
  }

  private resultHasWindowAccess(): boolean {
    if (this.inspectResult === null) {
      return false
    }
    return this.inspectResult.features.hasWindowAccess
  }

  private resultHasServerFactory(): boolean {
    if (this.inspectResult === null) {
      return false
    }
    return this.inspectResult.features.hasServerFactory
  }

  private resultHasFullConfigRoute(): boolean {
    if (this.inspectResult === null) {
      return false
    }
    return this.inspectResult.features.hasFullConfigRoute
  }

  private resultHasSitesListRoute(): boolean {
    if (this.inspectResult === null) {
      return false
    }
    return this.inspectResult.features.hasSitesListRoute
  }

  private resultDefaultPortText(): string {
    if (this.inspectResult === null || this.inspectResult.features.defaultPort <= 0) {
      return '未识别'
    }
    return this.inspectResult.features.defaultPort.toString()
  }

  private resultSiteCountText(): string {
    if (this.inspectResult === null) {
      return '0'
    }
    return this.inspectResult.sites.length.toString()
  }

  private flagText(flag: boolean): string {
    return flag ? '是' : '否'
  }

  private infoValueMaxLines(label: string): number {
    if (label === '脚本地址') {
      return 3
    }
    if (label === '检测结果') {
      return 4
    }
    return 2
  }
}
