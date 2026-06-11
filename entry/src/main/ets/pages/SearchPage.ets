import { router } from '@kit.ArkUI'
import { ResolverDefaults, ResolverVodItem, SiteSearchResult } from '../common/model/ResolverModels'
import { SiteSimple } from '../common/model/SourceModels'
import { HttpClient } from '../data/http/HttpClient'
import { ResolverRepository } from '../data/repository/ResolverRepository'
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsNavigationMenuContentOptions,
  ScrollEffectType,
  hdsMaterial
} from '@kit.UIDesignKit'
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

  private resolverRepository: ResolverRepository = new ResolverRepository(new HttpClient())
  private siteListScroller: Scroller = new Scroller()
  private contentGridScroller: Scroller = new Scroller()
  private mainScroller: Scroller = new Scroller()
  build() {
    Column() {
      HdsNavigation() {
        Scroll(this.mainScroller) {
          Column() {
            // 顶部的 padding 避让 HDS 沉浸式导航栏的高度 (56vp + 状态栏高度)
            Column().height(56 + this.statusBarTop)

            // 搜索输入区域，作为内容的顶部部分，跟随页面滑动并能隐入沉浸式导航栏下方
            this.buildSearchBar()

            if (this.isSearching && this.siteResults.length === 0) {
              this.buildLoading()
            } else if (this.hasSearched && this.allSitesEmpty()) {
              this.buildEmpty()
            } else if (this.siteResults.length > 0) {
              this.buildMasterDetail()
            } else {
              this.buildInitialHint()
            }
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
          title: { mainTitle: '搜索' },
          menu: this.buildSearchMenus()
        },
        style: {
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.ADAPTIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
          },
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
    .backgroundColor($r('app.color.card_background')) // 使用全局底色，无缝融为一体
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  // ═══════════════════════════════════════════════
  // Search Bar
  // ═══════════════════════════════════════════════
  @Builder
  buildSearchBar() {
    Row({ space: 12 }) {
      TextInput({ placeholder: '搜索影片', text: this.keyword })
        .layoutWeight(1)
        .height(38)
        .backgroundColor($r('app.color.background'))
        .placeholderColor($r('app.color.text_secondary'))
        .fontColor($r('app.color.text_primary'))
        .borderRadius(19)
        .padding({ left: 16, right: 16 })
        .fontSize(14)
        .caretColor($r('app.color.hermes_orange'))
        .onChange((value: string) => {
          this.keyword = value
        })
        .onSubmit(() => {
          this.doSearch()
        })

      Text('搜索')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .height(36)
        .padding({ left: 18, right: 18 })
        .textAlign(TextAlign.Center)
        .borderRadius(18)
        .linearGradient(
          this.keyword.trim().length > 0 && !this.isSearching
            ? {
                direction: GradientDirection.Right,
                colors: [['#FF9554', 0.0], ['#F37021', 1.0]]
              }
            : {
                direction: GradientDirection.Right,
                colors: [[$r('app.color.tag_background'), 0.0], [$r('app.color.tag_background'), 1.0]]
              }
        )
        .fontColor(
          this.keyword.trim().length > 0 && !this.isSearching
            ? Color.White
            : $r('app.color.text_secondary')
        )
        .onClick(() => {
          this.doSearch()
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 14, right: 14 })
    .backgroundColor(Color.Transparent)
  }
  // ═══════════════════════════════════════════════
  // Initial Hint (before any search)
  // ═══════════════════════════════════════════════
  @Builder
  buildInitialHint() {
    Column({ space: 20 }) {
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
      Text('输入关键词搜索全站影片')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
      Blank()
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // ═══════════════════════════════════════════════
  // Loading
  // ═══════════════════════════════════════════════
  @Builder
  buildLoading() {
    Column({ space: 16 }) {
      Blank()
      LoadingProgress()
        .width(44).height(44)
        .color($r('app.color.hermes_orange'))
      Text('正在搜索...')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
      Blank()
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // ═══════════════════════════════════════════════
  // Empty
  // ═══════════════════════════════════════════════
  @Builder
  buildEmpty() {
    Column({ space: 20 }) {
      Blank()
      Stack() {
        Column()
          .width(96).height(96).borderRadius(48)
          .backgroundColor($r('app.color.background'))
        SymbolGlyph($r('sys.symbol.questionmark_circle_fill'))
          .fontSize(38)
          .fontColor([$r('app.color.text_secondary')])
      }
      Text('没有找到相关的结果')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
      Blank()
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // ═══════════════════════════════════════════════
  // Master-Detail: Site List + Selected Results
  // ═══════════════════════════════════════════════
  @Builder
  buildMasterDetail() {
    Row() {
      // —— Left: Site List ——
      this.buildSiteList()

      // 垂直分割线
      Divider()
        .vertical(true)
        .color($r('app.color.background'))
        .height('100%')

      // —— Right: Selected Site Results ——
      this.buildContentPanel()
    }
    .width('100%')
    .layoutWeight(1)
  }

  // ── Left Sidebar: Site Tabs ────────────────────
  @Builder
  buildSiteList() {
    Column() {
      Scroll(this.siteListScroller) {
        Column({ space: 4 }) {
          ForEach(this.siteResults, (result: SiteSearchResult, index: number) => {
            this.buildSiteTab(result, index)
          })
        }
        .padding({ top: 12, bottom: 20 })
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .width(90)
      .layoutWeight(1)
    }
    .width(90)
    .backgroundColor($r('app.color.background')) // 侧边栏使用自适应底色
  }

  @Builder
  buildSiteTab(result: SiteSearchResult, index: number) {
    Column({ space: 6 }) {
      // 状态徽标 (Badge)
      if (result.isLoading) {
        LoadingProgress()
          .width(16).height(16)
          .color($r('app.color.hermes_orange'))
      } else if (result.errorMsg.length > 0) {
        Text('!')
          .fontSize(10).fontWeight(FontWeight.Bold)
          .fontColor('#FF453A')
          .width(18).height(18).borderRadius(9)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.background'))
          .border({ width: 1, color: '#FF453A' })
      } else if (result.items.length > 0) {
        Text(result.items.length.toString())
          .fontSize(10).fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .padding({ left: 6, right: 6 })
          .height(16)
          .borderRadius(8)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.hermes_orange'))
          .textShadow({ radius: 4, color: '#40F37021' })
      } else {
        Text('-')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .height(16)
      }

      Text(result.siteName)
        .fontSize(12)
        .fontWeight(index === this.selectedSiteIndex ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(
          index === this.selectedSiteIndex
            ? $r('app.color.hermes_orange')
            : $r('app.color.text_secondary')
        )
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .width(76)
        .lineHeight(16)
    }
    .width(90)
    .padding({ top: 14, bottom: 14, left: 6, right: 6 })
    .border({
      width: index === this.selectedSiteIndex ? { left: 3.5 } : 0,
      color: $r('app.color.hermes_orange')
    })
    .backgroundColor(
      index === this.selectedSiteIndex
        ? $r('app.color.card_background') // 选中项采用和展示栏一致的主体底色，无缝衔接消除割裂感
        : 'transparent'
    )
    .onClick(() => {
      this.selectedSiteIndex = index
    })
  }

  // ── Right Content Panel ────────────────────────
  @Builder
  buildContentPanel() {
    Column() {
      if (this.showContentHeader()) {
        this.buildContentHeader()
        Divider().color($r('app.color.background'))
      }

      if (this.showContentLoading()) {
        this.buildContentLoadingBody()
      } else if (this.showContentError()) {
        this.buildContentErrorBody()
      } else if (this.showContentEmpty()) {
        this.buildContentEmptyBody()
      } else {
        this.buildResultGrid()
      }
    }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
  }

  @Builder
  buildContentHeader() {
    Row({ space: 6 }) {
      Text(this.selectedSiteName())
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('· ' + this.selectedSiteItemCount().toString() + ' 个结果')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  buildContentLoadingBody() {
    Column({ space: 12 }) {
      Blank()
      LoadingProgress().width(32).height(32).color($r('app.color.hermes_orange'))
      Text('正在搜索...').fontSize(13).fontColor($r('app.color.text_secondary'))
      Blank()
    }.width('100%').layoutWeight(1)
  }

  @Builder
  buildContentErrorBody() {
    Column({ space: 12 }) {
      Blank()
      Text('!')
        .fontSize(24).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.hermes_orange'))
        .width(44).height(44).borderRadius(22)
        .textAlign(TextAlign.Center)
        .border({ width: 2, color: $r('app.color.hermes_orange') })
      Text(this.selectedSiteErrorMsg())
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .padding({ left: 24, right: 24 })
        .maxLines(4)
      Blank()
    }.width('100%').layoutWeight(1)
  }

  @Builder
  buildContentEmptyBody() {
    Column({ space: 8 }) {
      Blank()
      Text('该站点暂无结果')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
      Blank()
    }.width('100%').layoutWeight(1)
  }

  // ── Result Grid (2 columns) ────────────────────
  @Builder
  buildResultGrid() {
    Scroll(this.contentGridScroller) {
      Grid() {
        ForEach(this.selectedSiteItems(), (item: ResolverVodItem) => {
          GridItem() {
            this.buildResultCard(item)
          }
        })
      }
      .columnsTemplate('1fr 1fr')
      .columnsGap(10)
      .rowsGap(16)
      .padding({ left: 16, right: 16, top: 12, bottom: 24 })
    }
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Off)
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  buildResultCard(item: ResolverVodItem) {
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
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .borderRadius(6)
            .backgroundColor('#B3F37021')
            .margin({ right: 6, bottom: 6 })
            .textShadow({ radius: 2, color: '#40000000' })
        }
      }
      .width('100%')
      .aspectRatio(0.7)

      Text(item.vodName)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .padding({ left: 2, right: 2 })
    }
    .width('100%')
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

  // ═══════════════════════════════════════════════
  // Helpers (called from @Builder methods)
  // ═══════════════════════════════════════════════
  private posterUrl(url: string): string {
    let trimmed: string = url.trim()
    if (trimmed.length > 0) {
      return trimmed
    }
    return EMPTY_POSTER
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

  private showContentHeader(): boolean {
    return this.siteResults.length > 0
  }

  private showContentLoading(): boolean {
    return this.siteResults.length > 0 && this.selectedSite().isLoading
  }

  private showContentError(): boolean {
    let s: SiteSearchResult = this.selectedSite()
    return !s.isLoading && s.errorMsg.length > 0
  }

  private showContentEmpty(): boolean {
    let s: SiteSearchResult = this.selectedSite()
    return !s.isLoading && s.errorMsg.length === 0 && s.items.length === 0
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

  private allSitesEmpty(): boolean {
    for (let i = 0; i < this.siteResults.length; i++) {
      let r: SiteSearchResult = this.siteResults[i]
      if (!r.isLoading && r.errorMsg.length === 0 && r.items.length > 0) {
        return false
      }
    }
    return true
  }

  // ═══════════════════════════════════════════════
  // Title Bar Menu（HDS 沉浸光感按钮）
  // ═══════════════════════════════════════════════
  private buildSearchMenus(): HdsNavigationMenuContentOptions {
    return {
      value: [
        {
          content: {
            label: '清空',
            icon: $r('sys.symbol.trash'),
            action: () => {
              this.clearSearch()
            }
          }
        }
      ]
    }
  }

  private clearSearch(): void {
    this.keyword = ''
    this.siteResults = []
    this.selectedSiteIndex = 0
    this.isSearching = false
    this.hasSearched = false
  }

  // ═══════════════════════════════════════════════
  // Search Logic
  // ═══════════════════════════════════════════════
  private async doSearch(): Promise<void> {
    let kw: string = this.keyword.trim()
    if (kw.length === 0) {
      return
    }

    let sites: SiteSimple[] = this.siteList
    if (sites.length === 0) {
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
      // Errors handled per-site
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
