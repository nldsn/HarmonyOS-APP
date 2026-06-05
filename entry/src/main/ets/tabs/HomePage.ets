import { router } from '@kit.ArkUI'
import { SiteRepository } from '../services/SiteRepository'
import { ProtocolRouter } from '../services/ProtocolRouter'
import {
  SiteInfo,
  VodItem,
  CategoryWithVods,
  CategoryPageResult
} from '../models/SiteData'

interface SiteSimple {
  key: string
  name: string
}

interface SiteMenuItem {
  value: string
  action: () => void
}

@Component
export struct HomePage {
  @StorageLink('siteList') siteList: SiteSimple[] = []
  @StorageLink('fullSiteList') fullSiteList: SiteInfo[] = []
  @StorageProp('statusBarTop') statusBarTop: number = 44

  @State private selectedSiteName: string = ''
  @State private selectedSiteKey: string = ''
  @State private categories: CategoryWithVods[] = []
  @State private activeCategoryIndex: number = 0
  @State private isLoading: boolean = false
  @State private isLoadingCategory: boolean = false
  @State private errorMsg: string = ''
  @State private baseUrl: string = ''
  @State private handlerName: string = ''
  @State private showUrlInput: boolean = false
  @State private urlInput: string = ''

  private repository: SiteRepository = new SiteRepository()
  private autoSelected: boolean = false

  aboutToAppear(): void {
    if (!this.autoSelected && !this.selectedSiteKey && this.siteList.length > 0) {
      this.autoSelected = true
      this.selectSite('玩偶', '玩偶')
    }
  }

  aboutToDisappear(): void {
    this.repository.release()
  }

  build() {
    Column() {
      this.buildTopBar()

      Divider().color($r('app.color.background'))

      if (this.isLoading) {
        this.buildLoading()
      } else if (this.errorMsg.length > 0 && this.categories.length === 0) {
        this.buildError()
      } else if (this.selectedSiteKey.length === 0) {
        this.buildEmpty()
      } else if (this.categories.length > 0) {
        this.buildCategoryTabs()
        this.buildVideoGrid()
      } else if (this.baseUrl.length === 0 && this.handlerName.length === 0) {
        this.buildUrlInput()
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
        Text(this.selectedSiteName.length > 0 ? this.selectedSiteName.substring(0, 3) : '选站')
          .fontSize(14).fontColor(Color.White)
      }
      .width(44).height(44).borderRadius(12)
      .backgroundColor($r('app.color.hermes_orange'))
      .bindMenu(this.menuItems())

      if (this.selectedSiteName.length > 0) {
        Column({ space: 1 }) {
          Text(this.selectedSiteName)
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
      if (this.selectedSiteKey.length > 0 && this.baseUrl.length > 0) {
        Button() {
          SymbolGlyph($r('sys.symbol.link'))
            .fontSize(18)
            .fontColor([$r('app.color.hermes_orange')])
        }
        .width(32).height(32)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.showUrlInput = !this.showUrlInput
          this.urlInput = this.baseUrl
        })
      }
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
      if (this.handlerName.length > 0) {
        Text('处理器: ' + this.handlerName).fontSize(11).fontColor($r('app.color.text_secondary'))
      }
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
      Button('重试').fontSize(14).fontColor(Color.White)
        .backgroundColor($r('app.color.hermes_orange')).borderRadius(8).height(36)
        .onClick(() => { this.loadSiteData() })
      Blank()
    }.width('100%').layoutWeight(1)
  }

  @Builder
  buildEmpty() {
    Column({ space: 8 }) {
      Blank()
      if (this.siteList.length === 0) {
        Text('暂无站点数据').fontSize(14).fontColor($r('app.color.text_secondary'))
        Text('请前往"设置"输入数据源地址并拉取').fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      } else {
        Text('点击左上角按钮选择站点').fontSize(14)
          .fontColor($r('app.color.text_secondary'))
      }
      Blank()
    }.width('100%').layoutWeight(1)
  }

  @Builder
  buildUrlInput() {
    Column({ space: 16 }) {
      Blank()
      Text('需要配置站点地址').fontSize(16).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Text('该站点的地址未知，请手动输入域名').fontSize(13)
        .fontColor($r('app.color.text_secondary'))

      TextInput({ placeholder: '例如 https://www.wogg.net', text: this.urlInput })
        .fontSize(14).placeholderColor($r('app.color.text_secondary'))
        .backgroundColor($r('app.color.background')).borderRadius(10)
        .height(44).width('70%')
        .onChange((value: string) => { this.urlInput = value })

      Button('确认并加载').fontSize(14).fontColor(Color.White)
        .backgroundColor($r('app.color.hermes_orange')).borderRadius(8).height(40)
        .onClick(() => {
          let url: string = this.urlInput.trim()
          if (url.length > 0) {
            if (!url.startsWith('http://') && !url.startsWith('https://')) {
              url = 'https://' + url
            }
            this.baseUrl = url
            this.showUrlInput = false
            this.loadSiteData()
          }
        })

      if (this.errorMsg.length > 0) {
        Text(this.errorMsg).fontSize(12).fontColor('#FF3B30')
          .padding({ left: 20, right: 20 }).textAlign(TextAlign.Center)
      }
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
      .onClick(() => { this.onCategoryClick(index) })
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
          Text('点击上方分类自动加载').fontSize(12).fontColor($r('app.color.text_secondary'))
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
      Image(vod.vod_pic)
        .width('100%')
        .aspectRatio(0.7)
        .objectFit(ImageFit.Cover)
        .borderRadius(8)
        .backgroundColor($r('app.color.background'))

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
      router.pushUrl({
        url: 'pages/DetailPage',
        params: {
          vod_id: vod.vod_id,
          vod_name: vod.vod_name,
          vod_pic: vod.vod_pic,
          baseUrl: this.baseUrl,
          siteKey: this.selectedSiteKey
        }
      })
    })
  }

  // ═══════════════════════════════════════════════════
  // 菜单
  // ═══════════════════════════════════════════════════

  private menuItems(): SiteMenuItem[] {
    let items: SiteMenuItem[] = []
    for (let i = 0; i < this.siteList.length; i++) {
      let s: SiteSimple = this.siteList[i]
      let item: SiteMenuItem = {
        value: s.name,
        action: () => { this.selectSite(s.key, s.name) }
      }
      items.push(item)
    }
    return items
  }

  // ═══════════════════════════════════════════════════
  // 数据层（统一通过 SiteRepository）
  // ═══════════════════════════════════════════════════

  private selectSite(key: string, name: string): void {
    this.selectedSiteKey = key
    this.selectedSiteName = name
    this.categories = []
    this.activeCategoryIndex = 0
    this.errorMsg = ''
    this.handlerName = ''
    this.repository.release()

    // 先查注册表
    let hasEntry: boolean = ProtocolRouter.hasKey(key)
    if (hasEntry) {
      this.baseUrl = ProtocolRouter.getDomainEntry(key)?.baseUrl ?? ''
      this.loadSiteData()
      return
    }

    // 需要手动输入 URL
    this.baseUrl = ''
    this.urlInput = ''
    this.showUrlInput = true
  }

  private async loadSiteData(): Promise<void> {
    if (this.baseUrl.length === 0) {
      this.errorMsg = '请先配置站点地址'
      return
    }

    this.isLoading = true
    this.errorMsg = ''
    this.categories = []
    this.handlerName = ''

    try {
      // 使用 SiteRepository 统一入口
      let handler = await this.repository.selectSite(this.selectedSiteKey, this.baseUrl)
      if (handler === null) {
        this.errorMsg = '该站点需要 WexGuard 代理支持，请先配置代理地址'
        this.isLoading = false
        return
      }

      this.handlerName = handler.name
      let result: CategoryWithVods[] = await this.repository.fetchHome()
      this.categories = result

      if (result.length === 0) {
        this.errorMsg = '站点已连接但返回了空数据'
      }
    } catch (err) {
      let msg: string = '无法连接站点'
      if (err instanceof Error) {
        msg = err.message
      }
      this.errorMsg = msg + ' (' + this.baseUrl + ')'
    } finally {
      this.isLoading = false
    }
  }

  private onCategoryClick(index: number): void {
    this.activeCategoryIndex = index
    if (this.categories[index].vods.length > 0) {
      return // 已有数据，无需加载
    }
    if (!this.repository.isReady()) {
      return
    }
    this.loadCategoryData(index)
  }

  private async loadCategoryData(index: number): Promise<void> {
    let cat: CategoryWithVods = this.categories[index]
    this.isLoadingCategory = true
    try {
      let result: CategoryPageResult = await this.repository.fetchCategory(cat.type_id, 1)

      let updated: CategoryWithVods = {
        type_id: cat.type_id,
        type_name: cat.type_name,
        vods: result.list
      }
      let newCats: CategoryWithVods[] = []
      for (let i = 0; i < this.categories.length; i++) {
        if (i === index) {
          newCats.push(updated)
        } else {
          newCats.push(this.categories[i])
        }
      }
      this.categories = newCats
    } catch (_err) {
      // silent fail — 分类加载失败不影响已显示的分类
    } finally {
      this.isLoadingCategory = false
    }
  }
}
