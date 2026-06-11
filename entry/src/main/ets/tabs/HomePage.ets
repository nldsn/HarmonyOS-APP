import { router, promptAction } from '@kit.ArkUI'
import {
  ResolverCategoryItem,
  ResolverDefaults,
  ResolverVodItem
} from '../common/model/ResolverModels'
import { SiteSimple } from '../common/model/SourceModels'
import { HttpClient } from '../data/http/HttpClient'
import { ResolverRepository } from '../data/repository/ResolverRepository'

/**
 * 首页 — 视频网格展示（UI 样式模板，数据为硬编码示例）
 *
 * 品牌色：爱马仕橙 #F37021
 */

// ── 本地数据类型 ──────────────────────────────────
interface VodItem {
  vod_id: string
  vod_name: string
  vod_pic: string
  vod_remarks: string
}

interface CategoryWithVods {
  type_id: string
  type_name: string
  vods: VodItem[]
}

interface SiteMenuItem {
  value: string
  action: () => void
}

const EMPTY_POSTER: string = 'https://via.placeholder.com/300x420/333333/F37021?text=Poster'

@Component
export struct HomePage {
  @StorageLink('siteList') siteList: SiteSimple[] = []
  @StorageLink('resolverBaseUrl') resolverBaseUrl: string = ResolverDefaults.BASE_URL
  @StorageLink('resolverSourceId') resolverSourceId: string = ''
  @StorageProp('statusBarTop') statusBarTop: number = 44

  @State private selectedSiteKey: string = ''
  @State private categories: CategoryWithVods[] = []
  @State private activeCategoryIndex: number = 0
  @State private isLoading: boolean = false
  @State private isLoadingCategory: boolean = false
  @State private isRefreshing: boolean = false
  @State private errorMsg: string = ''
  @State private handlerName: string = ''
  @State private lastLoadedSourceId: string = ''
  @State private lastLoadedSiteKey: string = ''
  @State private configCenterPageUrl: string = ''

  private resolverRepository: ResolverRepository = new ResolverRepository(new HttpClient())

  aboutToAppear(): void {
    this.loadCurrentSiteHomeIfReady()
  }

  build() {
    Column() {
      this.buildTopBar()

      Divider().color($r('app.color.background'))

      if (this.isLoading) {
        this.buildLoading()
      } else if (this.siteList.length === 0) {
        this.buildEmpty()
      } else if (this.errorMsg.length > 0 && this.categories.length === 0) {
        this.buildError()
      } else if (this.categories.length > 0) {
        this.buildCategoryTabs()
        Refresh({ refreshing: $$this.isRefreshing }) {
          this.buildVideoGrid()
        }
        .onRefreshing(async () => {
          await this.loadCurrentSiteHome()
          this.isRefreshing = false
        })
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
        Text(this.currentSiteBadgeText())
          .fontSize(14).fontColor(Color.White)
      }
      .width(44).height(44).borderRadius(12)
      .backgroundColor($r('app.color.hermes_orange'))
      .bindMenu(this.menuItems())

      if (this.currentSiteName().length > 0) {
        Column({ space: 1 }) {
          Text(this.currentSiteName())
            .fontSize(16).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.handlerName.length > 0) {
            Text(this.handlerName)
              .fontSize(10).fontColor($r('app.color.text_secondary'))
          }
        }.alignItems(HorizontalAlign.Start)
      }
      Blank()

      Button() {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(22)
          .fontColor([$r('app.color.text_primary')])
      }
      .type(ButtonType.Circle)
      .width(44).height(44)
      .backgroundColor('transparent')
      .onClick(() => {
        router.pushUrl({
          url: 'pages/SearchPage'
        }).catch((err: Error) => {
          promptAction.showToast({ message: '跳转搜索页失败: ' + err.message })
        })
      })
    }
    .width('100%')
    .padding({ left: 16, top: 12 + this.statusBarTop, right: 16, bottom: 12 })
  }

  @Builder
  buildLoading() {
    Column({ space: 12 }) {
      Blank()
      LoadingProgress().width(40).height(40).color($r('app.color.hermes_orange'))
      Text('正在拉取站点数据...').fontSize(14).fontColor($r('app.color.text_secondary'))
      Blank()
    }.width('100%').layoutWeight(1)
  }

  @Builder
  buildError() {
    Column({ space: 12 }) {
      Blank()
      Text('!').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#FF3B30')
        .width(40).height(40).textAlign(TextAlign.Center)
        .borderRadius(20).border({ width: 2, color: '#FF3B30' })
      Text(this.errorMsg).fontSize(14).fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center).padding({ left: 40, right: 40 })
      Blank()
    }.width('100%').layoutWeight(1)
  }

  @Builder
  buildEmpty() {
    Column({ space: 8 }) {
      Blank()
      Text('暂无站点数据').fontSize(14).fontColor($r('app.color.text_secondary'))
      Text('请前往设置页解析订阅源').fontSize(12)
        .fontColor($r('app.color.text_secondary'))
      Blank()
    }.width('100%').layoutWeight(1)
  }

  @Builder
  buildCategoryTabs() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.categories, (cat: CategoryWithVods, index: number) => {
          this.buildCategoryChip(cat, index)
        })
      }
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    }
    .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
    .width('100%').height(44)
  }

  @Builder
  buildCategoryChip(cat: CategoryWithVods, index: number) {
    Text(cat.type_name)
      .fontSize(13)
      .fontWeight(this.activeCategoryIndex === index ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.activeCategoryIndex === index ? Color.White : $r('app.color.text_secondary'))
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .borderRadius(14)
      .backgroundColor(
        this.activeCategoryIndex === index
          ? $r('app.color.hermes_orange')
          : $r('app.color.background')
      )
      .onClick(async () => {
        await this.selectCategory(index)
      })
  }

  @Builder
  buildVideoGrid() {
    Column() {
      if (this.activeCategoryIndex >= this.categories.length) {
        Text('').width('100%').layoutWeight(1)
      } else if (this.isLoadingCategory) {
        Column({ space: 12 }) {
          Blank()
          LoadingProgress().width(32).height(32).color($r('app.color.hermes_orange'))
          Text('加载中...').fontSize(13).fontColor($r('app.color.text_secondary'))
          Blank()
        }.width('100%').layoutWeight(1)
      } else if (this.categories[this.activeCategoryIndex].vods.length > 0) {
        Scroll() {
          Column() {
            this.buildCategoryHeader()
            Grid() {
              ForEach(this.categories[this.activeCategoryIndex].vods, (vod: VodItem) => {
                GridItem() {
                  this.buildVodCard(vod)
                }
              })
            }
            .columnsTemplate('1fr 1fr 1fr').columnsGap(10).rowsGap(16)
            .padding({ left: 16, right: 16, bottom: 24 })
          }
        }
        .scrollBar(BarState.Auto)
        .layoutWeight(1)
      } else {
        Column({ space: 8 }) {
          Blank()
          Text('该分类暂无数据').fontSize(14).fontColor($r('app.color.text_secondary'))
          Text('可切换分类或下拉刷新当前站点').fontSize(12).fontColor($r('app.color.text_secondary'))
          Blank()
        }.width('100%').layoutWeight(1)
      }
    }
    .layoutWeight(1)
  }

  @Builder
  buildCategoryHeader() {
    Row() {
      Text(this.categories[this.activeCategoryIndex].type_name)
        .fontSize(18).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text('(' + this.categories[this.activeCategoryIndex].vods.length + ')')
        .fontSize(14).fontColor($r('app.color.text_secondary'))
      Blank()
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 8 })
  }

  @Builder
  buildVodCard(vod: VodItem) {
    Column({ space: 6 }) {
      if (this.isConfigCenterCard(vod)) {
        Column({ space: 8 }) {
          Blank()
          SymbolGlyph($r('sys.symbol.gearshape_fill'))
            .fontSize(38)
            .fontColor([$r('app.color.hermes_orange')])
          Text('配置')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
          Blank()
        }
        .width('100%')
        .aspectRatio(0.7)
        .borderRadius(8)
        .backgroundColor($r('app.color.background'))
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Image(vod.vod_pic)
          .width('100%')
          .aspectRatio(0.7)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
          .backgroundColor($r('app.color.background'))
      }

      Text(vod.vod_name)
        .fontSize(13).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })

      if (vod.vod_remarks.length > 0) {
        Text(vod.vod_remarks).fontSize(11)
          .fontColor($r('app.color.text_secondary')).maxLines(1)
      }
    }
    .width('100%')
    .onClick(() => {
      let site = this.currentSite()
      if (site === null) {
        return
      }
      if (this.isConfigCenterCard(vod)) {
        this.openConfigCenter(site.name)
        return
      }
      router.pushUrl({
        url: 'pages/DetailPage',
        params: {
          vod_id: vod.vod_id,
          vod_name: vod.vod_name,
          vod_pic: vod.vod_pic,
          resolver_base_url: this.resolverBaseUrl,
          resolver_source_id: this.resolverSourceId,
          site_key: site.key,
          site_name: site.name
        }
      })
    })
  }

  // ── 站点下拉菜单 ──
  private menuItems(): SiteMenuItem[] {
    let items: SiteMenuItem[] = []
    for (let i = 0; i < this.siteList.length; i++) {
      let s: SiteSimple = this.siteList[i]
      let item: SiteMenuItem = {
        value: s.name,
        action: () => {
          this.selectSite(s.key)
        }
      }
      items.push(item)
    }
    return items
  }

  private currentSiteName(): string {
    let site = this.currentSite()
    if (site === null) {
      return ''
    }
    return site.name
  }

  private currentSiteBadgeText(): string {
    let name = this.currentSiteName()
    if (name.length === 0) {
      return '选站'
    }
    if (name.length <= 3) {
      return name
    }
    return name.substring(0, 3)
  }

  private currentSite(): SiteSimple | null {
    if (this.siteList.length === 0) {
      return null
    }
    for (let i = 0; i < this.siteList.length; i++) {
      let s: SiteSimple = this.siteList[i]
      if (s.key === this.selectedSiteKey) {
        return s
      }
    }
    return this.siteList[0]
  }

  private loadCurrentSiteHomeIfReady(): void {
    if (this.resolverSourceId.length === 0 || this.siteList.length === 0) {
      return
    }
    let site = this.currentSite()
    if (site === null) {
      return
    }
    if (this.lastLoadedSourceId === this.resolverSourceId &&
      this.lastLoadedSiteKey === site.key &&
      this.categories.length > 0) {
      return
    }
    this.loadCurrentSiteHome()
  }

  private selectSite(siteKey: string): void {
    this.selectedSiteKey = siteKey
    this.categories = []
    this.configCenterPageUrl = ''
    this.activeCategoryIndex = 0
    this.loadCurrentSiteHome()
  }

  private async selectCategory(index: number): Promise<void> {
    this.activeCategoryIndex = index
    await this.loadCategory(index)
  }

  private async loadCurrentSiteHome(): Promise<void> {
    let site = this.currentSite()
    if (site === null) {
      this.categories = []
      this.errorMsg = ''
      return
    }
    if (this.resolverBaseUrl.trim().length === 0 || this.resolverSourceId.length === 0) {
      this.categories = []
      this.errorMsg = '请先在设置页完成远端解析'
      return
    }

    let sourceId: string = this.resolverSourceId
    let baseUrl: string = this.resolverBaseUrl
    let siteKey: string = site.key
    this.selectedSiteKey = siteKey
    this.isLoading = true
    this.isLoadingCategory = false
    this.errorMsg = ''
    this.configCenterPageUrl = ''
    this.handlerName = '正在读取分类'

    try {
      let home = await this.resolverRepository.getSiteHome(baseUrl, sourceId, siteKey)
      if (sourceId !== this.resolverSourceId || siteKey !== this.selectedSiteKey) {
        return
      }
      this.categories = this.mapCategories(home.categories)
      this.configCenterPageUrl = this.extractConfigCenterPageUrl(home.categories)
      this.activeCategoryIndex = 0
      this.lastLoadedSourceId = sourceId
      this.lastLoadedSiteKey = siteKey
      if (this.isConfigCenterSite(site)) {
        this.handlerName = '配置中心'
      } else {
        this.handlerName = '远端分类 ' + this.categories.length.toString() + ' 个'
      }
      if (this.categories.length > 0) {
        await this.loadCategory(0)
      }
    } catch (err) {
      this.categories = []
      this.errorMsg = this.errorText(err)
      this.handlerName = ''
    } finally {
      this.isLoading = false
      this.isLoadingCategory = false
      this.isRefreshing = false
    }
  }

  private async loadCategory(index: number): Promise<void> {
    if (index < 0 || index >= this.categories.length) {
      return
    }
    let site = this.currentSite()
    if (site === null) {
      return
    }
    let sourceId: string = this.resolverSourceId
    let baseUrl: string = this.resolverBaseUrl
    let siteKey: string = site.key
    let typeId: string = this.categories[index].type_id
    if (sourceId.length === 0 || typeId.length === 0) {
      return
    }

    this.isLoadingCategory = true
    this.errorMsg = ''
    try {
      let result = await this.resolverRepository.getCategory(baseUrl, sourceId, siteKey, typeId, 1)
      if (sourceId !== this.resolverSourceId || siteKey !== this.selectedSiteKey) {
        return
      }
      let vods: VodItem[] = this.mapVods(result.items)
      let nextCategories: CategoryWithVods[] = []
      for (let i = 0; i < this.categories.length; i++) {
        let current: CategoryWithVods = this.categories[i]
        if (i === index) {
          nextCategories.push({
            type_id: current.type_id,
            type_name: current.type_name,
            vods: vods
          })
        } else {
          nextCategories.push(current)
        }
      }
      this.categories = nextCategories
      this.handlerName = '第 ' + result.page.toString() + ' 页 / 共 ' +
        result.pageCount.toString() + ' 页'
      if (this.isConfigCenterSite(site)) {
        this.handlerName = '扫码配置'
      }
    } catch (err) {
      this.errorMsg = this.errorText(err)
    } finally {
      this.isLoadingCategory = false
    }
  }

  private mapCategories(items: ResolverCategoryItem[]): CategoryWithVods[] {
    let result: CategoryWithVods[] = []
    for (let i = 0; i < items.length; i++) {
      let item: ResolverCategoryItem = items[i]
      let typeId: string = item.typeId
      let typeName: string = item.typeName
      if (typeName.length === 0) {
        typeName = typeId
      }
      if (this.isConfigCenterCategory(typeId, typeName)) {
        typeName = '配置中心'
      }
      if (typeId.length > 0 && typeName.length > 0) {
        result.push({
          type_id: typeId,
          type_name: typeName,
          vods: []
        })
      }
    }
    return result
  }

  private mapVods(items: ResolverVodItem[]): VodItem[] {
    let result: VodItem[] = []
    for (let i = 0; i < items.length; i++) {
      let item: ResolverVodItem = items[i]
      result.push({
        vod_id: item.vodId,
        vod_name: item.vodName,
        vod_pic: this.posterUrl(item.vodPic),
        vod_remarks: item.vodRemarks
      })
    }
    return result
  }

  private posterUrl(url: string): string {
    let trimmed: string = url.trim()
    if (trimmed.length > 0) {
      return trimmed
    }
    return EMPTY_POSTER
  }

  private errorText(err: Object): string {
    if (err instanceof Error && err.message.length > 0) {
      return err.message
    }
    return '站点内容加载失败'
  }

  private isConfigCenterSite(site: SiteSimple): boolean {
    let key: string = site.key.toLowerCase()
    let name: string = site.name
    return key.indexOf('nodejs_baseset') >= 0 || key.indexOf('baseset') >= 0 ||
      name.indexOf('配置') >= 0
  }

  private isConfigCenterCategory(typeId: string, typeName: string): boolean {
    let lowerName: string = typeName.toLowerCase()
    return typeId === 'setting' && lowerName.indexOf('/website') >= 0
  }

  private isConfigCenterCard(vod: VodItem): boolean {
    let site = this.currentSite()
    if (site !== null && this.isConfigCenterSite(site)) {
      return true
    }
    let lowerPic: string = vod.vod_pic.toLowerCase()
    return vod.vod_name.indexOf('配置') >= 0 && lowerPic.indexOf('/runtime/website') >= 0
  }

  private openConfigCenter(title: string): void {
    if (this.resolverSourceId.length === 0) {
      this.errorMsg = '缺少订阅源上下文'
      return
    }
    let targetUrl: string = this.configCenterPageUrl
    if (targetUrl.length === 0) {
      targetUrl = this.resolverRepository.runtimeWebsiteUrl(this.resolverBaseUrl, this.resolverSourceId)
    }
    router.pushUrl({
      url: 'pages/ConfigCenterPage',
      params: {
        title: title,
        page_url: targetUrl,
        resolver_base_url: this.resolverBaseUrl,
        resolver_source_id: this.resolverSourceId
      }
    })
  }

  private extractConfigCenterPageUrl(items: ResolverCategoryItem[]): string {
    for (let i = 0; i < items.length; i++) {
      let item: ResolverCategoryItem = items[i]
      if (this.isConfigCenterCategory(item.typeId, item.typeName)) {
        return this.configCenterUrlFromTypeName(item.typeName)
      }
    }
    return ''
  }

  private configCenterUrlFromTypeName(typeName: string): string {
    let lower: string = typeName.toLowerCase()
    let marker: string = '/website'
    let markerIndex: number = lower.indexOf(marker)
    if (markerIndex < 0) {
      return ''
    }
    let pathText: string = typeName.substring(markerIndex)
    return this.resolverRepository.runtimePathUrl(this.resolverBaseUrl, this.resolverSourceId, pathText)
  }
}
