import { http } from '@kit.NetworkKit'
import { inputMethod } from '@kit.IMEKit'
import { SiteInfo } from '../models/SiteData'
import { DEFAULT_CONFIG_URL } from '../models/SiteConfig'

/**
 * 设置页 — 输入源地址，拉取影视站点数据
 * 存储完整的 SiteInfo 到 AppStorage，供首页使用
 */

interface SiteSimple {
  key: string
  name: string
}

@Component
export struct SettingsPage {
  @State private sourceUrl: string = 'https://9280.kstore.vip/newwex.json'
  @State private isLoading: boolean = false
  @State private statusMsg: string = ''
  @State private isError: boolean = false
  @State private siteCount: number = 0
  @StorageProp('statusBarTop') statusBarTop: number = 44

  // ── 清理 URL 中的不可见字符 ──────────────────
  private cleanUrl(raw: string): string {
    return raw.replace(/[​-‍﻿ ]/g, '').trim()
  }

  // ── 收起输入法 ──────────────────────────────
  private hideKeyboard(): void {
    try {
      const controller = inputMethod.getController()
      controller.stopInputSession()
    } catch (e) {
      // 静默失败
    }
  }

  // ── 拉取数据 ──────────────────────────────────
  private async fetchData(): Promise<void> {
    this.hideKeyboard()

    const url = this.cleanUrl(this.sourceUrl)
    if (!url) {
      this.statusMsg = '请输入源地址'
      this.isError = true
      return
    }

    this.isLoading = true
    this.statusMsg = '正在拉取数据...'
    this.isError = false

    const httpRequest = http.createHttp()
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 15000,
        readTimeout: 15000
      })

      if (response.responseCode !== 200) {
        this.statusMsg = `请求失败，状态码：${response.responseCode}`
        this.isError = true
        return
      }

      const result = response.result
      let data: Record<string, Object>
      if (typeof result === 'string') {
        data = JSON.parse(result) as Record<string, Object>
      } else if (typeof result === 'object') {
        data = result as Record<string, Object>
      } else {
        this.statusMsg = '响应数据格式无法识别'
        this.isError = true
        return
      }

      const rawSites = data['sites'] as Array<Object>
      if (!rawSites || rawSites.length === 0) {
        this.statusMsg = '数据中没有站点信息'
        this.isError = true
        return
      }

      // ── 构建完整 SiteInfo 数组 ──────────────────
      const fullSites: SiteInfo[] = []
      const simpleSites: SiteSimple[] = []

      for (let i = 0; i < rawSites.length; i++) {
        const item: Record<string, Object> = rawSites[i] as Record<string, Object>
        const siteInfo: SiteInfo = {
          key: (item['key'] as string) ?? '',
          name: (item['name'] as string) ?? '',
          type: (item['type'] as number) ?? 3,
          api: (item['api'] as string) ?? '',
          searchable: (item['searchable'] as number) ?? 0,
          quickSearch: (item['quickSearch'] as number) ?? 0,
          filterable: (item['filterable'] as number) ?? 0,
          changeable: (item['changeable'] as number) ?? 0,
          ext: item['ext'],
          timeout: item['timeout'] as (number | undefined),
          style: item['style'] as (Object | undefined)
        }
        fullSites.push(siteInfo)
        simpleSites.push({ key: siteInfo.key, name: siteInfo.name })
      }

      // 存两个版本：简化版给下拉菜单，完整版给数据获取
      AppStorage.setOrCreate<SiteSimple[]>('siteList', simpleSites)
      AppStorage.setOrCreate<SiteInfo[]>('fullSiteList', fullSites)
      this.siteCount = fullSites.length
      this.statusMsg = `成功加载 ${fullSites.length} 个站点`
      this.isError = false

    } catch (err) {
      this.statusMsg = `请求失败：${JSON.stringify(err)}`
      this.isError = true
    } finally {
      httpRequest.destroy()
      this.isLoading = false
    }
  }

  build() {
    Column() {
      Column({ space: 12 }) {
        Text('数据源地址')
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .width('100%')

        TextInput({
          placeholder: '请输入 JSON 数据源地址',
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
            this.fetchData()
          })

        if (this.siteCount > 0) {
          Text('已加载 ' + this.siteCount + ' 个站点，可在首页查看')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }

        Divider().color($r('app.color.background')).margin({ top: 8, bottom: 8 })

        Text('配置中心')
          .fontSize(14).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')

        Text('站点域名由配置中心下发。把 site_config.json 托管到CDN/GitHub，填地址即可动态更新。')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')

        TextInput({ placeholder: '远程配置URL（留空用内置）', text: DEFAULT_CONFIG_URL })
          .fontSize(13).height(40).borderRadius(8)
          .backgroundColor($r('app.color.card_background'))
          .padding({ left: 12, right: 12 })
          .width('100%')

        Text('内置: 玩偶、新6V  |  新建站点自动保存到本地配置')
          .fontSize(10)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16 + this.statusBarTop })

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

}
