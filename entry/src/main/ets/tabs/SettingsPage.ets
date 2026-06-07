/**
 * 设置页 — UI 样式模板（数据拉取为模拟操作，仅作界面展示）
 *
 * 品牌色：爱马仕橙 #F37021
 */

interface SiteSimple {
  key: string
  name: string
}

@Component
export struct SettingsPage {
  @State private sourceUrl: string = 'https://example.com/sites.json'
  @State private isLoading: boolean = false
  @State private statusMsg: string = ''
  @State private isError: boolean = false
  @State private siteCount: number = 0
  @StorageProp('statusBarTop') statusBarTop: number = 44

  // ── 模拟数据拉取（纯 UI 展示，不实际请求网络）──
  private simulateFetch(): void {
    this.isLoading = true
    this.statusMsg = '正在拉取数据...'
    this.isError = false

    // 模拟 1.5 秒延迟后返回结果
    setTimeout(() => {
      this.isLoading = false
      this.statusMsg = '成功加载 28 个站点（模拟数据）'
      this.isError = false
      this.siteCount = 28

      // 填充示例站点列表到 AppStorage
      let demoSites: SiteSimple[] = [
        { key: 'site1', name: '示例站点A' },
        { key: 'site2', name: '示例站点B' },
        { key: 'site3', name: '示例站点C' },
      ]
      AppStorage.setOrCreate<SiteSimple[]>('siteList', demoSites)
    }, 1500)
  }

  build() {
    Column() {
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

        if (this.statusMsg) {
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

        Button(this.isLoading ? '拉取中...' : '拉取数据')
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
          .onClick(() => {
            this.simulateFetch()
          })

        if (this.siteCount > 0) {
          Text('已加载 ' + this.siteCount + ' 个站点，可在首页查看')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }
}}