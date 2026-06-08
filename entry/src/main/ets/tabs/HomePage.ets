import { router } from '@kit.ArkUI'
import { SiteSimple } from '../common/model/SourceModels'

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

// ── 硬编码示例站点 ──────────────────────────────────
export const DEMO_SITES: SiteSimple[] = [
  { key: 'site1', name: '示例站点A' },
  { key: 'site2', name: '示例站点B' },
  { key: 'site3', name: '示例站点C' },
]

const DEMO_POSTER: string = 'https://via.placeholder.com/300x420/333333/F37021?text=Poster'

// ── 硬编码示例分类 + 视频 ──────────────────────────
const DEMO_CATEGORIES: CategoryWithVods[] = [
  {
    type_id: '1',
    type_name: '推荐',
    vods: [
      { vod_id: '1', vod_name: '示例电影 - 星际穿越', vod_pic: DEMO_POSTER, vod_remarks: '9.4分' },
      { vod_id: '2', vod_name: '示例电影 - 盗梦空间', vod_pic: DEMO_POSTER, vod_remarks: '9.3分' },
      { vod_id: '3', vod_name: '示例电影 - 肖申克的救赎', vod_pic: DEMO_POSTER, vod_remarks: '9.7分' },
      { vod_id: '4', vod_name: '示例电影 - 阿甘正传', vod_pic: DEMO_POSTER, vod_remarks: '9.5分' },
      { vod_id: '5', vod_name: '示例剧集 - 权力的游戏', vod_pic: DEMO_POSTER, vod_remarks: '全8季' },
      { vod_id: '6', vod_name: '示例剧集 - 绝命毒师', vod_pic: DEMO_POSTER, vod_remarks: '全5季' },
    ]
  },
  {
    type_id: '2',
    type_name: '电影',
    vods: []
  },
  {
    type_id: '3',
    type_name: '电视剧',
    vods: []
  },
  {
    type_id: '4',
    type_name: '综艺',
    vods: []
  },
  {
    type_id: '5',
    type_name: '动漫',
    vods: []
  },
]

@Component
export struct HomePage {
  @StorageLink('siteList') siteList: SiteSimple[] = DEMO_SITES
  @StorageProp('statusBarTop') statusBarTop: number = 44

  @State private selectedSiteName: string = '示例站点A'
  @State private selectedSiteKey: string = 'site1'
  @State private categories: CategoryWithVods[] = DEMO_CATEGORIES
  @State private activeCategoryIndex: number = 0
  @State private isLoading: boolean = false
  @State private isLoadingCategory: boolean = false
  @State private errorMsg: string = ''
  @State private handlerName: string = ''
  @State private showUrlInput: boolean = false
  @State private urlInput: string = ''

  build() {
    Column() {
      this.buildTopBar()

      Divider().color($r('app.color.background'))

      if (this.isLoading) {
        this.buildLoading()
      } else if (this.errorMsg.length > 0 && this.categories.length === 0) {
        this.buildError()
      } else if (this.categories.length > 0) {
        this.buildCategoryTabs()
        this.buildVideoGrid()
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
      Text('请前往"设置"页面配置数据源').fontSize(12)
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
      .onClick(() => { this.activeCategoryIndex = index })
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
          Text('点击上方分类可切换').fontSize(12).fontColor($r('app.color.text_secondary'))
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
          this.selectedSiteKey = s.key
          this.selectedSiteName = s.name
          this.categories = DEMO_CATEGORIES
          this.activeCategoryIndex = 0
        }
      }
      items.push(item)
    }
    return items
  }
}
