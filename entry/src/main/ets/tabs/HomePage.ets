import { router, promptAction } from '@kit.ArkUI'
import {
  ResolverCategoryItem,
  ResolverDefaults,
  ResolverVodDetail,
  ResolverVodItem
} from '../common/model/ResolverModels'
import { SiteSimple } from '../common/model/SourceModels'
import { HttpClient } from '../data/http/HttpClient'
import { ResolverRepository } from '../data/repository/ResolverRepository'
import {
  HdsNavigation,
  HdsNavigationMenuContentOptions,
  HdsNavigationMenuItemOptions,
  HdsNavigationTitleMode,
  ScrollEffectType,
  hdsMaterial
} from '@kit.UIDesignKit'

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
const DOUBAN_DARK_BG: string = '#111214'
const DOUBAN_PANEL_BG: string = '#191A1D'
const DOUBAN_MUTED_TEXT: string = '#8D8F96'

@Component
export struct HomePage {
  @StorageLink('siteList') siteList: SiteSimple[] = []
  @StorageLink('resolverBaseUrl') resolverBaseUrl: string = ResolverDefaults.BASE_URL
  @StorageLink('resolverSourceId') resolverSourceId: string = ''
  @StorageProp('statusBarTop') statusBarTop: number = 44

  @StorageLink('homeSelectedSiteKey') selectedSiteKey: string = ''
  @StorageLink('homeUsesShowcaseStyle') homeUsesShowcaseStyle: boolean = false
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
  @State private doubanHeroIndex: number = 0
  @State private materialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.ADAPTIVE

  private resolverRepository: ResolverRepository = new ResolverRepository(new HttpClient())
  private doubanScroller: Scroller = new Scroller()

  aboutToAppear(): void {
    let materialTypes: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes()
    if (materialTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) < 0) {
      this.materialLevel = hdsMaterial.MaterialLevel.SMOOTH
    }
    this.loadCurrentSiteHomeIfReady()
  }

  build() {
    if (this.isLoading) {
      this.buildHomeLoadingOnly()
    } else if (this.homeUsesShowcaseStyle) {
      this.buildDoubanHome()
    } else {
      this.buildStandardHome()
    }
  }

  @Builder
  buildHomeLoadingOnly() {
    Column({ space: 12 }) {
      Blank()
      LoadingProgress()
        .width(42)
        .height(42)
        .color($r('app.color.hermes_orange'))
      Text('正在加载首页...')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  buildStandardHome() {
    Column() {
      HdsNavigation() {
        Column() {
          Column().height(56 + this.statusBarTop)

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
      }
      .mode(NavigationMode.Stack)
      .titleBar({
        content: {
          title: { mainTitle: '首页' },
          menu: this.homeNavigationMenus()
        },
        style: {
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: ScrollEffectType.GRADIENT_BLUR
          },
          originalStyle: {
            backgroundStyle: {
              backgroundColor: '#00000000',
              maskExtraHeight: 0
            },
            contentStyle: {
              titleStyle: {
                mainTitleColor: $r('app.color.text_primary')
              },
              menuStyle: {
                iconColor: $r('app.color.text_primary'),
                textColor: $r('app.color.text_primary')
              },
              dividerStyle: {
                dividerColor: '#00000000'
              }
            }
          },
          scrollEffectStyle: {
            backgroundStyle: {
              backgroundColor: '#00000000',
              maskExtraHeight: 0
            },
            contentStyle: {
              titleStyle: {
                mainTitleColor: $r('app.color.text_primary')
              },
              menuStyle: {
                iconColor: $r('app.color.text_primary'),
                textColor: $r('app.color.text_primary')
              },
              dividerStyle: {
                dividerColor: '#00000000'
              }
            }
          },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: this.materialLevel
          }
        },
        avoidLayoutSafeArea: true,
        enableComponentSafeArea: false
      })
      .hideBackButton(true)
      .titleMode(HdsNavigationTitleMode.MINI)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  buildDoubanHome() {
    Column() {
      HdsNavigation() {
        Refresh({ refreshing: $$this.isRefreshing }) {
          Scroll(this.doubanScroller) {
            Column() {
              if (this.isLoading) {
                this.buildDoubanLoading()
              } else if (this.siteList.length === 0) {
                this.buildDoubanEmpty()
              } else if (this.errorMsg.length > 0 && this.categories.length === 0) {
                this.buildDoubanError()
              } else if (this.categories.length > 0) {
                this.buildDoubanHero()
                this.buildDoubanCategoryTabs()
                this.buildDoubanCategorySection()
                Column().height(40)
              } else {
                this.buildDoubanEmpty()
              }
            }
            .width('100%')
            .constraintSize({ minHeight: '100%' })
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          }
          .scrollBar(BarState.Off)
          .height('100%')
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        }
        .onRefreshing(async () => {
          await this.loadCurrentSiteHome()
          this.isRefreshing = false
        })
        .layoutWeight(1)
      }
      .mode(NavigationMode.Stack)
      .titleBar({
        content: {
          title: { mainTitle: '首页' },
          menu: this.homeNavigationMenus()
        },
        style: {
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: ScrollEffectType.GRADIENT_BLUR
          },
          originalStyle: {
            backgroundStyle: {
              backgroundColor: '#00000000',
              maskExtraHeight: 0
            },
            contentStyle: {
              titleStyle: {
                mainTitleColor: Color.White
              },
              menuStyle: {
                iconColor: Color.White,
                textColor: Color.White
              },
              dividerStyle: {
                dividerColor: '#00000000'
              }
            }
          },
          scrollEffectStyle: {
            backgroundStyle: {
              backgroundColor: '#00000000',
              maskExtraHeight: 0
            },
            contentStyle: {
              titleStyle: {
                mainTitleColor: Color.White
              },
              menuStyle: {
                iconColor: Color.White,
                textColor: Color.White
              },
              dividerStyle: {
                dividerColor: '#00000000'
              }
            }
          },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: this.materialLevel
          }
        },
        avoidLayoutSafeArea: true,
        enableComponentSafeArea: false
      })
      .bindToScrollable([this.doubanScroller])
      .hideBackButton(true)
      .titleMode(HdsNavigationTitleMode.MINI)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DOUBAN_DARK_BG)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  buildDoubanLoading() {
    Column({ space: 12 }) {
      Blank()
      LoadingProgress().width(42).height(42).color(Color.White)
      Text('正在读取' + this.showcaseSourceName() + '推荐...')
        .fontSize(14)
        .fontColor('#CCFFFFFF')
      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DOUBAN_DARK_BG)
  }

  @Builder
  buildDoubanEmpty() {
    Column({ space: 8 }) {
      Blank()
      Text('暂无' + this.showcaseSourceName() + '推荐')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
      Text('请先在设置页解析订阅源')
        .fontSize(12)
        .fontColor(DOUBAN_MUTED_TEXT)
      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DOUBAN_DARK_BG)
  }

  @Builder
  buildDoubanError() {
    Column({ space: 12 }) {
      Blank()
      Text('!')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.hermes_orange'))
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .borderRadius(20)
        .border({ width: 2, color: $r('app.color.hermes_orange') })
      Text(this.errorMsg)
        .fontSize(14)
        .fontColor('#CCFFFFFF')
        .textAlign(TextAlign.Center)
        .padding({ left: 40, right: 40 })
      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DOUBAN_DARK_BG)
  }

  @Builder
  buildDoubanHero() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.doubanHeroVods().length > 0) {
        Swiper() {
          ForEach(this.doubanHeroVods(), (vod: VodItem) => {
            Stack({ alignContent: Alignment.BottomStart }) {
              Image(vod.vod_pic)
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Cover)
                .syncLoad(false)
                .backgroundColor('#241F1A')

              Column()
                .width('100%')
                .height('100%')
                .hitTestBehavior(HitTestMode.None)
                .linearGradient({
                  direction: GradientDirection.Bottom,
                  colors: [
                    ['#33000000', 0.0],
                    ['#12000000', 0.42],
                    ['#AA000000', 0.78],
                    [DOUBAN_DARK_BG, 1.0]
                  ]
                })

              Column({ space: 8 }) {
                Row({ space: 8 }) {
                  if (vod.vod_remarks.length > 0) {
                    Text(this.doubanRemarkTag(vod.vod_remarks))
                      .fontSize(12)
                      .fontColor(Color.White)
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .borderRadius(7)
                      .backgroundColor('#66000000')
                  }
                  Text(vod.vod_name)
                    .fontSize(24)
                    .fontWeight(FontWeight.Bolder)
                    .fontColor(Color.White)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('100%')

                Text(this.doubanHeroSubtitle(vod))
                  .fontSize(15)
                  .fontColor('#E6FFFFFF')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
              }
              .width('100%')
              .padding({ left: 22, right: 22, bottom: 72 })
            }
            .width('100%')
            .height('100%')
            .onClick(() => {
              this.openDoubanSearch(vod)
            })
          })
        }
        .autoPlay(true)
        .interval(4200)
        .loop(true)
        .disableSwipe(false)
        .indicator(false)
        .onChange((index: number) => {
          this.doubanHeroIndex = index
        })
      } else {
        Column({ space: 10 }) {
          Blank()
          LoadingProgress().width(36).height(36).color(Color.White)
          Text('正在整理推荐内容...')
            .fontSize(13)
            .fontColor('#CCFFFFFF')
          Blank()
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#242528')
      }

      Column()
        .width('100%')
        .height(120)
        .hitTestBehavior(HitTestMode.None)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [
            ['#00000000', 0.0],
            [DOUBAN_DARK_BG, 1.0]
          ]
        })

      this.buildDoubanHeroIndicator(this.doubanHeroVods().length)
    }
    .width('100%')
    .height(640)
  }

  @Builder
  buildDoubanHeroIndicator(count: number) {
    if (count > 0) {
      Row({ space: 9 }) {
        ForEach(this.doubanIndicatorItems(count), (item: number) => {
          Column()
            .height(4)
            .layoutWeight(1)
            .borderRadius(2)
            .backgroundColor(item === this.doubanActiveIndicatorIndex(count) ? Color.White : '#4DFFFFFF')
        })
      }
      .width('100%')
      .height(12)
      .padding({ left: 22, right: 22, bottom: 8 })
    }
  }

  @Builder
  buildDoubanCategoryTabs() {
    Scroll() {
      Row({ space: 12 }) {
        ForEach(this.categories, (cat: CategoryWithVods, index: number) => {
          this.buildDoubanCategoryChip(cat, index)
        })
      }
      .padding({ left: 22, right: 22, top: 16, bottom: 18 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .backgroundColor(DOUBAN_DARK_BG)
  }

  @Builder
  buildDoubanCategoryChip(cat: CategoryWithVods, index: number) {
    Row({ space: 8 }) {
      Text(this.doubanCategoryIcon(cat.type_id))
        .fontSize(16)
        .fontColor(this.activeCategoryIndex === index ? DOUBAN_DARK_BG : '#CCFFFFFF')
      Text(cat.type_name)
        .fontSize(15)
        .fontWeight(this.activeCategoryIndex === index ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.activeCategoryIndex === index ? DOUBAN_DARK_BG : '#D6D7DA')
        .maxLines(1)
    }
    .height(46)
    .padding({ left: 18, right: 18 })
    .borderRadius(23)
    .backgroundColor(this.activeCategoryIndex === index ? Color.White : '#242528')
    .onClick(async () => {
      await this.selectCategory(index)
    })
  }

  @Builder
  buildDoubanCategorySection() {
    Column({ space: 14 }) {
      Row() {
        Text(this.doubanSectionTitle())
          .fontSize(28)
          .fontWeight(FontWeight.Bolder)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Blank()

        Text(this.doubanSectionMeta())
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(DOUBAN_MUTED_TEXT)
      }
      .width('100%')
      .padding({ left: 22, right: 22 })

      if (this.activeCategoryIndex >= this.categories.length) {
        Text('')
          .width('100%')
          .height(180)
      } else if (this.isLoadingCategory) {
        Column({ space: 12 }) {
          LoadingProgress().width(32).height(32).color(Color.White)
          Text('加载中...')
            .fontSize(13)
            .fontColor(DOUBAN_MUTED_TEXT)
        }
        .width('100%')
        .height(220)
        .justifyContent(FlexAlign.Center)
      } else if (this.categories[this.activeCategoryIndex].vods.length > 0) {
        this.buildDoubanPosterRows()
      } else {
        Column({ space: 8 }) {
          Text('该分类暂无数据')
            .fontSize(15)
            .fontColor('#CCFFFFFF')
          Text('可切换分类或下拉刷新当前站点')
            .fontSize(12)
            .fontColor(DOUBAN_MUTED_TEXT)
        }
        .width('100%')
        .height(180)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .backgroundColor(DOUBAN_DARK_BG)
  }

  @Builder
  buildDoubanPosterRows() {
    Grid() {
      ForEach(this.categories[this.activeCategoryIndex].vods, (vod: VodItem) => {
        GridItem() {
          this.buildDoubanPosterCard(vod)
        }
      })
    }
    .columnsTemplate('1fr 1fr 1fr')
    .columnsGap(12)
    .rowsGap(16)
    .padding({ left: 18, right: 18, bottom: 16 })
  }

  @Builder
  buildDoubanPosterCard(vod: VodItem) {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Image(vod.vod_pic)
          .width('100%')
          .aspectRatio(0.72)
          .objectFit(ImageFit.Cover)
          .syncLoad(false)
          .borderRadius(10)
          .backgroundColor(DOUBAN_PANEL_BG)

        Column()
          .width('100%')
          .height(72)
          .borderRadius(10)
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: [
              ['#00000000', 0.0],
              ['#B3000000', 1.0]
            ]
          })

        if (vod.vod_remarks.length > 0) {
          Text(this.doubanRemarkTag(vod.vod_remarks))
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .margin({ right: 8, bottom: 8 })
            .borderRadius(8)
            .backgroundColor('#80000000')
        }
      }
      .width('100%')

      Text(vod.vod_name)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Text(this.doubanCardSubtitle(vod))
        .fontSize(13)
        .fontColor(DOUBAN_MUTED_TEXT)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('100%')
    .onClick(() => {
      this.openDoubanSearch(vod)
    })
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
        this.openSearchPage()
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

  private openSearchPage(keyword: string = ''): void {
    let kw: string = keyword.trim()
    if (kw.length > 0) {
      router.pushUrl({
        url: 'pages/SearchPage',
        params: {
          keyword: kw
        }
      }).catch((err: Error) => {
        promptAction.showToast({ message: '跳转搜索页失败: ' + err.message })
      })
      return
    }
    router.pushUrl({
      url: 'pages/SearchPage'
    }).catch((err: Error) => {
      promptAction.showToast({ message: '跳转搜索页失败: ' + err.message })
    })
  }

  private openDoubanSearch(vod: VodItem): void {
    if (vod.vod_name.trim().length === 0) {
      promptAction.showToast({ message: '条目缺少片名，无法搜索' })
      return
    }
    this.openSearchPage(vod.vod_name)
  }

  private showcaseSourceName(): string {
    let name: string = this.currentSiteName().trim()
    if (name.length > 0) {
      return name
    }
    return '内容'
  }

  private firstLoadedVod(): VodItem | null {
    if (this.activeCategoryIndex >= 0 && this.activeCategoryIndex < this.categories.length) {
      let active: CategoryWithVods = this.categories[this.activeCategoryIndex]
      if (active.vods.length > 0) {
        return active.vods[0]
      }
    }
    for (let i = 0; i < this.categories.length; i++) {
      let category: CategoryWithVods = this.categories[i]
      if (category.vods.length > 0) {
        return category.vods[0]
      }
    }
    return null
  }

  private async detectShowcaseMode(sourceId: string, baseUrl: string, siteKey: string): Promise<void> {
    let site = this.currentSite()
    if (site !== null && this.isConfigCenterSite(site)) {
      this.homeUsesShowcaseStyle = false
      return
    }
    let vod: VodItem | null = this.firstLoadedVod()
    if (vod === null) {
      this.homeUsesShowcaseStyle = false
      return
    }
    if (vod.vod_id.trim().length === 0) {
      this.homeUsesShowcaseStyle = true
      return
    }
    try {
      let detail: ResolverVodDetail = await this.resolverRepository.getDetail(baseUrl, sourceId, siteKey, vod.vod_id)
      if (sourceId !== this.resolverSourceId || siteKey !== this.selectedSiteKey) {
        return
      }
      this.homeUsesShowcaseStyle = !this.detailHasPlayableEpisodes(detail)
    } catch (err) {
      if (sourceId !== this.resolverSourceId || siteKey !== this.selectedSiteKey) {
        return
      }
      this.homeUsesShowcaseStyle = true
    }
  }

  private detailHasPlayableEpisodes(detail: ResolverVodDetail): boolean {
    for (let i = 0; i < detail.playSources.length; i++) {
      if (detail.playSources[i].episodes.length > 0) {
        return true
      }
    }
    return false
  }

  private doubanHeroVods(): VodItem[] {
    if (this.categories.length === 0) {
      return []
    }
    let first: CategoryWithVods = this.categories[0]
    if (first.vods.length > 0) {
      return first.vods
    }
    if (this.activeCategoryIndex >= 0 && this.activeCategoryIndex < this.categories.length) {
      return this.categories[this.activeCategoryIndex].vods
    }
    return []
  }

  private doubanIndicatorItems(count: number): number[] {
    let result: number[] = []
    let maxCount: number = count
    if (maxCount > 6) {
      maxCount = 6
    }
    for (let i = 0; i < maxCount; i++) {
      result.push(i)
    }
    return result
  }

  private doubanActiveIndicatorIndex(count: number): number {
    let maxCount: number = count
    if (maxCount > 6) {
      maxCount = 6
    }
    if (maxCount <= 0) {
      return 0
    }
    let index: number = this.doubanHeroIndex
    while (index >= maxCount) {
      index = index - maxCount
    }
    while (index < 0) {
      index = index + maxCount
    }
    return index
  }

  private doubanCategoryIcon(typeId: string): string {
    if (typeId.indexOf('rank') >= 0) {
      return '榜'
    }
    if (typeId.indexOf('tv') >= 0) {
      return '剧'
    }
    if (typeId.indexOf('show') >= 0) {
      return '综'
    }
    if (typeId.indexOf('movie') >= 0) {
      return '影'
    }
    return '荐'
  }

  private doubanSectionTitle(): string {
    if (this.activeCategoryIndex >= 0 && this.activeCategoryIndex < this.categories.length) {
      return this.categories[this.activeCategoryIndex].type_name
    }
    return this.showcaseSourceName() + '推荐'
  }

  private doubanSectionMeta(): string {
    if (this.activeCategoryIndex >= 0 && this.activeCategoryIndex < this.categories.length) {
      let count: number = this.categories[this.activeCategoryIndex].vods.length
      if (count > 0) {
        return count.toString() + ' 部'
      }
    }
    return '推荐'
  }

  private doubanHeroSubtitle(vod: VodItem): string {
    if (vod.vod_remarks.length > 0) {
      return this.showcaseSourceName() + '推荐 · ' + vod.vod_remarks
    }
    return this.showcaseSourceName() + '推荐 · 发现值得看的片单'
  }

  private doubanCardSubtitle(vod: VodItem): string {
    if (vod.vod_remarks.length > 0) {
      return vod.vod_remarks
    }
    return '推荐条目'
  }

  private doubanRemarkTag(remark: string): string {
    let text: string = remark.trim()
    if (text.length === 0) {
      return '推荐'
    }
    if (text.indexOf('评分：') === 0) {
      return text.replace('评分：', '')
    }
    return text
  }

  private homeNavigationMenus(): HdsNavigationMenuContentOptions {
    let value: HdsNavigationMenuItemOptions[] = []
    value.push({
      content: {
        label: '搜索',
        icon: $r('sys.symbol.magnifyingglass'),
        action: () => {
          this.openSearchPage()
        }
      }
    })
    for (let i = 0; i < this.siteList.length; i++) {
      let site: SiteSimple = this.siteList[i]
      value.push({
        content: {
          label: site.name,
          icon: $r('sys.symbol.ellipsis_circle'),
          action: () => {
            this.selectSite(site.key)
          }
        }
      })
    }
    return {
      value: value,
      maxCount: 2
    }
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
    this.isLoading = true
    this.isLoadingCategory = false
    this.selectedSiteKey = siteKey
    this.categories = []
    this.configCenterPageUrl = ''
    this.activeCategoryIndex = 0
    this.homeUsesShowcaseStyle = false
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
      this.homeUsesShowcaseStyle = false
      return
    }
    if (this.resolverBaseUrl.trim().length === 0 || this.resolverSourceId.length === 0) {
      this.categories = []
      this.homeUsesShowcaseStyle = false
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
    this.homeUsesShowcaseStyle = false
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
        await this.detectShowcaseMode(sourceId, baseUrl, siteKey)
      }
    } catch (err) {
      this.categories = []
      this.errorMsg = this.errorText(err)
      this.handlerName = ''
      this.homeUsesShowcaseStyle = false
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
