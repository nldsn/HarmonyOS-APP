import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { ResolverDefaults, ResolverVodItem, SiteSearchResult } from '../common/model/ResolverModels'
import { SiteSimple } from '../common/model/SourceModels'
import { HttpClient } from '../data/http/HttpClient'
import { ResolverRepository } from '../data/repository/ResolverRepository'
import { CacheStore } from '../data/storage/CacheStore'
import { SearchHistoryStore } from '../data/storage/SearchHistoryStore'
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  ScrollEffectType,
  hdsMaterial
} from '@kit.UIDesignKit'

/**
 * 搜索页 — 沉浸光感
 *
 * 顶部：HDS 沉浸式导航栏（只保留返回按钮 + 内嵌搜索框），搜索框通过 stackBuilder
 * 嵌入标题栏区域，继承 IMMERSIVE 沉浸光感材质。
 * 下面依次：搜索记录 → 站点（横向胶囊）→ 影片列表（网格）。
 * 全页单一纵向滚动，内容滑入沉浸式导航栏下方触发渐变模糊与光感材质。
 *
 * 沉浸光感等级按官方”自定义沉浸光感”指引，依据设备材质能力自适应选择。
 */

const EMPTY_POSTER: string = 'https://via.placeholder.com/300x420/333333/F37021?text=Poster'

@Entry
@Component
struct SearchPage {
  @StorageLink('siteList') siteList: SiteSimple[] = []
  @StorageLink('resolverBaseUrl') resolverBaseUrl: string = ResolverDefaults.BASE_URL
  @StorageLink('resolverSourceId') resolverSourceId: string = ''
  @StorageProp('statusBarTop') statusBarTop: number = 44

  @State private keyword: string = ''
  @State private siteResults: SiteSearchResult[] = []
  @State private selectedSiteIndex: number = 0
  @State private isSearching: boolean = false
  @State private hasSearched: boolean = false
  @State private history: string[] = []
  // 沉浸光感材质等级：默认精致(EXQUISITE)，设备不支持 IMMERSIVE 时降级为 SMOOTH，降低卡顿与发热
  @State private materialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.EXQUISITE

  private resolverRepository: ResolverRepository = new ResolverRepository(new HttpClient())
  private mainScroller: Scroller = new Scroller()

  aboutToAppear(): void {
    // 查询当前设备支持的材质能力，按官方建议选择沉浸光感等级
    let materialTypes: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes()
    if (materialTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) < 0) {
      this.materialLevel = hdsMaterial.MaterialLevel.SMOOTH
    }
    this.history = this.historyStore().getHistory()
  }

  build() {
    Column() {
      HdsNavigation() {
        Scroll(this.mainScroller) {
          Column() {
            // 顶部避让沉浸式导航栏（标题栏 56vp + 状态栏高度）
            Column().height(56 + this.statusBarTop)

            if (!this.hasSearched) {
              if (this.history.length > 0) {
                this.buildHistorySection()
              } else {
                this.buildInitialHint()
              }
            } else if (this.siteResults.length === 0) {
              this.buildNoSiteHint()
            } else {
              // —— 站点 ——
              this.buildSitesSection()
              // —— 影片列表 ——
              this.buildFilmSection()
            }

            // 底部留白
            Column().height(32)
          }
          .width('100%')
          .constraintSize({ minHeight: '100%' })
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        }
        .scrollBar(BarState.Auto)
        .height('100%')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      }
      .mode(NavigationMode.Stack)
      .titleBar({
        content: {
          title: { mainTitle: '' },
          stackBuilder: (): void => { this.buildNavSearchBox() }
        },
        style: {
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: ScrollEffectType.GRADIENT_BLUR
          },
          // 标题栏沉浸光感：标准 IMMERSIVE 材质，等级按设备能力自适应
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: this.materialLevel
          }
        },
        avoidLayoutSafeArea: true,
        enableComponentSafeArea: false
      })
      .bindToScrollable([this.mainScroller])
      .hideBackButton(false)
      .titleMode(HdsNavigationTitleMode.MINI)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  // ═══════════════════════════════════════════════
  // 导航栏内嵌搜索框（通过 stackBuilder 嵌入，继承沉浸光感材质）
  // — 使用 Search 组件（自带搜索图标 + 清除按钮 + 内置圆角背景）
  // — 外层 Row left:48 避让返回按钮
  // ═══════════════════════════════════════════════
  @Builder
  buildNavSearchBox() {
    Row() {
      Search({
        value: this.keyword,
        placeholder: '搜索影片名称'
      }).searchButton('搜索')
      .layoutWeight(1)
      .height(40)
      .placeholderColor($r('app.color.text_secondary'))
      .fontColor($r('app.color.text_primary'))
      .caretStyle({ width: 2, color: $r('app.color.hermes_orange') })
      .cancelButton({
        style: CancelButtonStyle.INPUT
      })
      .onChange((value: string) => {
        this.keyword = value
      })
      .onSubmit(() => {
        this.doSearch()
      })
    }
    .width('90%')
    .height('100%')
    .padding({ left: 58, right: 8 })
    .alignItems(VerticalAlign.Center)
  }

  // ═══════════════════════════════════════════════
  // 搜索记录
  // ═══════════════════════════════════════════════
  @Builder
  buildHistorySection() {
    Column({ space: 12 }) {
      Row() {
        Text('搜索记录')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(14)
            .fontColor([$r('app.color.text_secondary')])
          Text('清空')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
        }
        .onClick(() => {
          this.clearHistory()
        })
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.history, (kw: string) => {
          this.buildHistoryChip(kw)
        }, (kw: string) => kw)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildHistoryChip(kw: string) {
    Text(kw)
      .fontSize(13)
      .fontColor($r('app.color.text_primary'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .constraintSize({ maxWidth: 160 })
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .borderRadius(16)
      .backgroundColor($r('app.color.background'))
      .margin({ right: 10, bottom: 10 })
      .onClick(() => {
        this.keyword = kw
        this.doSearch()
      })
  }

  // ═══════════════════════════════════════════════
  // 初始提示 / 空站点提示
  // ═══════════════════════════════════════════════
  @Builder
  buildInitialHint() {
    Column({ space: 18 }) {
      Blank()
      Stack() {
        Column()
          .width(96).height(96).borderRadius(48)
          .backgroundColor($r('app.color.background'))
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(40)
          .fontColor(['#F37021'])
          .shadow({ radius: 8, color: '#40F37021' })
      }
      Text('输入关键词，搜索全站影片')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
      Blank()
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 40, bottom: 40 })
  }

  @Builder
  buildNoSiteHint() {
    Column({ space: 10 }) {
      Blank()
      SymbolGlyph($r('sys.symbol.questionmark_circle_fill'))
        .fontSize(38)
        .fontColor([$r('app.color.text_secondary')])
      Text('暂无可搜索的站点')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
      Text('请先在设置页解析订阅源')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
      Blank()
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 40, bottom: 40 })
  }

  // ═══════════════════════════════════════════════
  // 站点（横向胶囊）
  // ═══════════════════════════════════════════════
  @Builder
  buildSitesSection() {
    Column({ space: 10 }) {
      Row() {
        Text('站点')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text(' · ' + this.siteResults.length.toString() + ' 个')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
        Blank()
        if (this.isSearching) {
          Row({ space: 6 }) {
            LoadingProgress()
              .width(14).height(14)
              .color($r('app.color.hermes_orange'))
            Text('搜索中')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      List({ space: 10 }) {
        ForEach(this.siteResults, (result: SiteSearchResult, index: number) => {
          ListItem() {
            this.buildSiteChip(result, index)
          }
        }, (result: SiteSearchResult) => result.siteKey)
      }
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(36)
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildSiteChip(result: SiteSearchResult, index: number) {
    Row({ space: 6 }) {
      Text(result.siteName)
        .fontSize(13)
        .fontWeight(index === this.selectedSiteIndex ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(index === this.selectedSiteIndex ? Color.White : $r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: 120 })

      this.buildSiteBadge(result, index)
    }
    .height(36)
    .padding({ left: 14, right: 12 })
    .borderRadius(18)
    .backgroundColor(
      index === this.selectedSiteIndex
        ? $r('app.color.hermes_orange')
        : $r('app.color.background')
    )
    .onClick(() => {
      this.selectedSiteIndex = index
    })
  }

  @Builder
  buildSiteBadge(result: SiteSearchResult, index: number) {
    if (result.isLoading) {
      LoadingProgress()
        .width(14).height(14)
        .color(index === this.selectedSiteIndex ? Color.White : $r('app.color.hermes_orange'))
    } else if (result.errorMsg.length > 0) {
      Text('!')
        .fontSize(11).fontWeight(FontWeight.Bold)
        .fontColor(index === this.selectedSiteIndex ? Color.White : '#FF453A')
        .width(16).height(16).borderRadius(8)
        .textAlign(TextAlign.Center)
        .backgroundColor(index === this.selectedSiteIndex ? '#33FFFFFF' : '#1AFF453A')
    } else {
      Text(result.items.length.toString())
        .fontSize(11).fontWeight(FontWeight.Bold)
        .fontColor(index === this.selectedSiteIndex ? Color.White : $r('app.color.text_secondary'))
    }
  }

  // ═══════════════════════════════════════════════
  // 影片列表
  // ═══════════════════════════════════════════════
  @Builder
  buildFilmSection() {
    Column() {
      Row({ space: 4 }) {
        Text('影片列表')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        if (!this.selectedSite().isLoading && this.selectedSite().errorMsg.length === 0) {
          Text('· ' + this.selectedSiteName() + ' ' + this.selectedSiteItemCount().toString() + ' 个结果')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 10 })

      if (this.selectedSite().isLoading) {
        this.buildFilmLoading()
      } else if (this.selectedSite().errorMsg.length > 0) {
        this.buildFilmError()
      } else if (this.selectedSiteItemCount() === 0) {
        this.buildFilmEmpty()
      } else {
        this.buildFilmGrid()
      }
    }
    .width('100%')
  }

  // 影片网格：手动分行（每行 3 列），内容自适应高度随外层滚动，避免嵌套纵向滚动
  @Builder
  buildFilmGrid() {
    Column({ space: 16 }) {
      ForEach(this.filmRows(), (row: ResolverVodItem[], rowIndex: number) => {
        Row({ space: 10 }) {
          this.buildFilmCell(row, 0)
          this.buildFilmCell(row, 1)
          this.buildFilmCell(row, 2)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }, (row: ResolverVodItem[], rowIndex: number) => {
        return this.selectedSiteKey() + '_' + rowIndex.toString() + '_' + (row.length > 0 ? row[0].vodId : '')
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 2, bottom: 8 })
  }

  @Builder
  buildFilmCell(row: ResolverVodItem[], col: number) {
    if (col < row.length) {
      this.buildFilmCard(row[col])
    } else {
      // 占位以保持网格列对齐
      Column().layoutWeight(1)
    }
  }

  @Builder
  buildFilmCard(item: ResolverVodItem) {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Image(this.posterUrl(item.vodPic))
          .width('100%')
          .aspectRatio(0.7)
          .objectFit(ImageFit.Cover)
          .borderRadius(12)
          .backgroundColor($r('app.color.background'))
          .shadow({ radius: 8, color: '#20000000', offsetY: 4 })

        if (item.vodRemarks.length > 0) {
          Text(item.vodRemarks)
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .padding({ left: 7, right: 7, top: 3, bottom: 3 })
            .borderRadius(6)
            .backgroundColor('#B3F37021')
            .margin({ right: 6, bottom: 6 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: '90%' })
        }
      }
      .width('100%')
      .aspectRatio(0.7)

      Text(item.vodName)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .lineHeight(17)
    }
    .layoutWeight(1)
    .onClick(() => {
      router.pushUrl({
        url: 'pages/DetailPage',
        params: {
          vod_id: item.vodId,
          vod_name: item.vodName,
          vod_pic: item.vodPic,
          resolver_base_url: this.resolverBaseUrl,
          resolver_source_id: this.resolverSourceId,
          site_key: this.selectedSiteKey(),
          site_name: this.selectedSiteName()
        }
      })
    })
  }

  @Builder
  buildFilmLoading() {
    Column({ space: 12 }) {
      LoadingProgress()
        .width(32).height(32)
        .color($r('app.color.hermes_orange'))
      Text('正在搜索 ' + this.selectedSiteName() + ' ...')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .height(200)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildFilmError() {
    Column({ space: 12 }) {
      Text('!')
        .fontSize(22).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.hermes_orange'))
        .width(40).height(40).borderRadius(20)
        .textAlign(TextAlign.Center)
        .border({ width: 2, color: $r('app.color.hermes_orange') })
      Text(this.selectedSiteErrorMsg())
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .padding({ left: 32, right: 32 })
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(220)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildFilmEmpty() {
    Column() {
      Text('该站点暂无结果')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .height(160)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // ═══════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════

  private historyStore(): SearchHistoryStore {
    let context = getContext(this) as common.UIAbilityContext
    return new SearchHistoryStore(new CacheStore(context))
  }

  private clearHistory(): void {
    this.historyStore().clear()
    this.history = []
  }

  private resetSearch(): void {
    this.keyword = ''
    this.siteResults = []
    this.selectedSiteIndex = 0
    this.isSearching = false
    this.hasSearched = false
    this.history = this.historyStore().getHistory()
  }

  private posterUrl(url: string): string {
    let trimmed: string = url.trim()
    if (trimmed.length > 0) {
      return trimmed
    }
    return EMPTY_POSTER
  }

  private filmRows(): ResolverVodItem[][] {
    let items: ResolverVodItem[] = this.selectedSiteItems()
    let rows: ResolverVodItem[][] = []
    for (let i = 0; i < items.length; i += 3) {
      let row: ResolverVodItem[] = []
      for (let j = i; j < i + 3 && j < items.length; j++) {
        row.push(items[j])
      }
      rows.push(row)
    }
    return rows
  }

  private selectedSite(): SiteSearchResult {
    if (this.siteResults.length === 0) {
      return { siteKey: '', siteName: '', items: [], isLoading: true, errorMsg: '' }
    }
    let idx: number = this.selectedSiteIndex
    if (idx < 0) {
      idx = 0
    }
    if (idx >= this.siteResults.length) {
      idx = this.siteResults.length - 1
    }
    return this.siteResults[idx]
  }

  private selectedSiteName(): string {
    return this.selectedSite().siteName
  }

  private selectedSiteKey(): string {
    return this.selectedSite().siteKey
  }

  private selectedSiteItemCount(): number {
    return this.selectedSite().items.length
  }

  private selectedSiteErrorMsg(): string {
    return this.selectedSite().errorMsg
  }

  private selectedSiteItems(): ResolverVodItem[] {
    return this.selectedSite().items
  }

  // ═══════════════════════════════════════════════
  // 搜索逻辑
  // ═══════════════════════════════════════════════
  private async doSearch(): Promise<void> {
    let kw: string = this.keyword.trim()
    if (kw.length === 0) {
      return
    }

    // 写入搜索记录（最近置顶、去重）
    this.history = this.historyStore().addKeyword(kw)

    let sites: SiteSimple[] = this.siteList
    if (sites.length === 0) {
      this.siteResults = []
      this.selectedSiteIndex = 0
      this.isSearching = false
      this.hasSearched = true
      return
    }

    let initialResults: SiteSearchResult[] = []
    for (let i = 0; i < sites.length; i++) {
      initialResults.push({
        siteKey: sites[i].key,
        siteName: sites[i].name,
        items: [],
        isLoading: true,
        errorMsg: ''
      })
    }
    this.siteResults = initialResults
    this.selectedSiteIndex = 0
    this.isSearching = true
    this.hasSearched = true

    let promises: Promise<void>[] = []
    for (let i = 0; i < sites.length; i++) {
      promises.push(this.searchSite(i, sites[i], kw))
    }

    try {
      await Promise.all(promises)
    } catch (err) {
      // 单站点错误已在 searchSite 内处理
    } finally {
      this.isSearching = false
    }
  }

  private async searchSite(index: number, site: SiteSimple, keyword: string): Promise<void> {
    try {
      let result = await this.resolverRepository.getSearch(
        this.resolverBaseUrl,
        this.resolverSourceId,
        site.key,
        keyword,
        1
      )

      if (this.keyword.trim() !== keyword) {
        return
      }

      let updated: SiteSearchResult[] = []
      for (let i = 0; i < this.siteResults.length; i++) {
        if (i === index) {
          updated.push({
            siteKey: site.key,
            siteName: site.name,
            items: result.items,
            isLoading: false,
            errorMsg: ''
          })
        } else {
          updated.push(this.siteResults[i])
        }
      }
      this.siteResults = updated
    } catch (err) {
      if (this.keyword.trim() !== keyword) {
        return
      }

      let errorMessage: string = ''
      if (err instanceof Error) {
        errorMessage = err.message
      } else {
        errorMessage = '搜索请求失败'
      }

      let updated: SiteSearchResult[] = []
      for (let i = 0; i < this.siteResults.length; i++) {
        if (i === index) {
          updated.push({
            siteKey: site.key,
            siteName: site.name,
            items: [],
            isLoading: false,
            errorMsg: errorMessage
          })
        } else {
          updated.push(this.siteResults[i])
        }
      }
      this.siteResults = updated
    }
  }
}
