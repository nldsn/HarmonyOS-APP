import { router } from '@kit.ArkUI'

/**
 * 详情页 — 影视详情 UI 样式模板（数据为硬编码示例）
 *
 * 品牌色：爱马仕橙 #F37021
 */

// ── 本地数据类型 ──────────────────────────────────
interface PlaySrc { name: string; eps: PlayEp[] }
interface PlayEp { title: string; url: string; size?: number }
interface MenuItem { value: string; action: () => void }

// ── 硬编码示例数据 ─────────────────────────────────
const DEMO_VOD_NAME: string = '星际穿越 Interstellar'
const DEMO_VOD_PIC: string = 'https://via.placeholder.com/300x420/1a1a2e/F37021?text=Interstellar'
const DEMO_TYPE_NAME: string = '科幻'
const DEMO_YEAR: string = '2014'
const DEMO_AREA: string = '美国'
const DEMO_REMARKS: string = '9.4分'
const DEMO_DIRECTOR: string = '克里斯托弗·诺兰'
const DEMO_ACTOR: string = '马修·麦康纳 / 安妮·海瑟薇 / 杰西卡·查斯坦'
const DEMO_CONTENT: string = '近未来的地球黄沙遍野，前NASA宇航员库珀在女儿墨菲的书房发现了奇怪的重力场现象，随即得知某个未知区域内前NASA成员仍在秘密进行拯救人类的计划。在布兰德教授的劝说下，库珀忍痛离开女儿，与艾米莉亚·布兰德等人一同搭乘宇宙飞船前往已知的三个最有可能适合人类居住的星球，穿越遥远的星系银河，感受一小时七年光阴的沧海桑田，窥见了未知星球和黑洞的壮伟与神秘。'

const DEMO_SOURCES: PlaySrc[] = [
  {
    name: '蓝光1080P',
    eps: [
      { title: '星际穿越.BluRay.1080p.x264.DTS-HD.MA.5.1.mkv', url: '', size: 21474836480 },
      { title: '星际穿越.BluRay.1080p.x264.DTS-HD.MA.5.1.part2.mkv', url: '', size: 10737418240 },
      { title: '星际穿越.BluRay.1080p.x264.DTS-HD.MA.5.1.part3.mkv', url: '', size: 5368709120 },
    ]
  },
  {
    name: '4K超清',
    eps: [
      { title: '星际穿越.2014.IMAX.2160p.BluRay.HEVC.DTS-HD.MA.5.1.mkv', url: '', size: 42949672960 },
    ]
  },
  {
    name: '夸克云盘',
    eps: [
      { title: '星际穿越.1080p.特效中英字幕.mp4', url: '', size: 3221225472 },
    ]
  },
]

@Entry
@Component
struct DetailPage {
  @State vodId: string = 'demo1'
  @State vodName: string = DEMO_VOD_NAME
  @State vodPic: string = DEMO_VOD_PIC
  @State typeName: string = DEMO_TYPE_NAME
  @State vodYear: string = DEMO_YEAR
  @State vodArea: string = DEMO_AREA
  @State vodRemarks: string = DEMO_REMARKS
  @State vodDirector: string = DEMO_DIRECTOR
  @State vodActor: string = DEMO_ACTOR
  @State vodContent: string = DEMO_CONTENT
  @State sources: PlaySrc[] = DEMO_SOURCES
  @State isLoading: boolean = false
  @State errorMsg: string = ''
  @State showFullIntro: boolean = false
  @State activeSourceIndex: number = 0

  aboutToAppear(): void {
    let p: Record<string, Object> = router.getParams() as Record<string, Object>
    if (p !== null && p !== undefined) {
      let name: string = (p['vod_name'] as string) ?? ''
      if (name.length > 0) {
        this.vodName = name
      }
      let pic: string = (p['vod_pic'] as string) ?? ''
      if (pic.length > 0) {
        this.vodPic = pic
      }
    }
  }

  // ════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════

  build() {
    Column() {
      if (this.isLoading) {
        this.buildSkeleton()
      } else if (this.errorMsg.length > 0 && this.sources.length === 0) {
        this.buildError()
      } else {
        Stack({ alignContent: Alignment.TopStart }) {
          Scroll() {
            Column() {
              this.buildHero()
              this.buildSynopsis()
              this.buildSourceSection()
              Column().height(40)
            }.width('100%')
          }
          .scrollBar(BarState.Auto).layoutWeight(1)
          this.buildTopBar()
        }.width('100%').layoutWeight(1)
      }
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.background'))
  }

  // ════════════════════════════════════════════
  // 超大英雄海报 — Emby 风格
  // ════════════════════════════════════════════

  @Builder
  buildHero() {
    Column() {
      Stack({ alignContent: Alignment.BottomStart }) {
        Image(this.vodPic)
          .width('100%').height(300)
          .objectFit(ImageFit.Cover).blur(24).brightness(0.35)

        Column()
          .width('100%').height(300)
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: [
              [Color.Transparent, 0.0],
              ['#CC000000', 0.6],
              ['#E6000000', 0.85],
              [$r('app.color.background'), 1.0]
            ]
          })

        Row({ space: 16 }) {
          Image(this.vodPic)
            .width(155).aspectRatio(0.7)
            .objectFit(ImageFit.Cover).borderRadius(12)
            .shadow({ radius: 24, color: '#60000000', offsetY: 8 })

          Column({ space: 8 }) {
            Text(this.vodName)
              .fontSize(22).fontWeight(FontWeight.Bold)
              .fontColor(Color.White).maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            if (this.hasTags()) {
              Flex({ wrap: FlexWrap.Wrap }) {
                if (this.typeName.length > 0) { this.buildTag(this.typeName) }
                if (this.vodYear.length > 0) { this.buildTag(this.vodYear) }
                if (this.vodArea.length > 0) { this.buildTag(this.vodArea) }
                if (this.vodRemarks.length > 0) { this.buildTag(this.vodRemarks) }
              }
            }

            if (this.vodDirector.length > 0) {
              Text('导演: ' + this.vodDirector).fontSize(13)
                .fontColor('#CCCCCC').maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }

            if (this.vodActor.length > 0) {
              Text('主演: ' + this.vodActor).fontSize(12)
                .fontColor('#AAAAAA').maxLines(2).lineHeight(18)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .layoutWeight(1).alignItems(HorizontalAlign.Start)
        }
        .width('100%').padding({ left: 20, right: 20, bottom: 20 })
      }
      .width('100%').height(300)
    }
    .width('100%').backgroundColor($r('app.color.background'))
  }

  @Builder
  buildTag(text: string) {
    Text(text)
      .fontSize(11).fontColor('#FFE0C0')
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .margin({ right: 6, bottom: 6 })
      .borderRadius(4).backgroundColor('#33FFFFFF')
      .border({ width: 1, color: '#44FFFFFF' })
  }

  // ════════════════════════════════════════════
  // 悬浮顶栏
  // ════════════════════════════════════════════

  @Builder
  buildTopBar() {
    Row({ space: 12 }) {
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(22).fontColor([Color.White])
      }
      .width(36).height(36).backgroundColor('#33FFFFFF').borderRadius(18)
      .onClick(() => { router.back() })

      Text(this.vodName).fontSize(16).fontWeight(FontWeight.Medium)
        .fontColor(Color.White).maxLines(1).layoutWeight(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%').padding({ left: 16, top: 48, right: 16, bottom: 10 })
  }

  // ════════════════════════════════════════════
  // 简介
  // ════════════════════════════════════════════

  @Builder
  buildSynopsis() {
    if (this.vodContent.length > 0) {
      Column({ space: 6 }) {
        Row() {
          Text('简介').fontSize(16).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Text(this.showFullIntro ? '收起' : '展开')
            .fontSize(12).fontColor($r('app.color.hermes_orange'))
        }.width('100%').onClick(() => { this.showFullIntro = !this.showFullIntro })

        Text(this.vodContent).fontSize(13)
          .fontColor($r('app.color.text_secondary')).lineHeight(20)
          .maxLines(this.showFullIntro ? 99 : 3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%').padding({ left: 20, right: 20, top: 16, bottom: 8 })
      .alignItems(HorizontalAlign.Start)
    }
  }

  // ════════════════════════════════════════════
  // 剧集区
  // ════════════════════════════════════════════

  @Builder
  buildSourceSection() {
    if (this.sources.length > 0) {
      Column({ space: 8 }) {
        Row() {
          Text('剧集').fontSize(16).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Blank()

          if (this.sources.length > 1) {
            Button() {
              Row({ space: 4 }) {
                Text(this.sources[this.activeSourceIndex].name)
                  .fontSize(12).fontColor($r('app.color.hermes_orange'))
                  .maxLines(1)
                SymbolGlyph($r('sys.symbol.chevron_down'))
                  .fontSize(12).fontColor([$r('app.color.hermes_orange')])
              }
            }
            .height(30).padding({ left: 10, right: 10 })
            .backgroundColor($r('app.color.tag_background'))
            .borderRadius(6)
            .bindMenu(this.sourceMenuItems())
          } else {
            Text(this.sources[0].name)
              .fontSize(12).fontColor($r('app.color.text_secondary'))
              .maxLines(1)
          }
        }
        .width('100%').padding({ left: 20, right: 20, top: 12 })

        this.buildEpisodeRow()
      }.width('100%')
    }
  }

  @Builder
  buildEpisodeRow() {
    if (this.activeSourceIndex < this.sources.length) {
      List({ space: 10 }) {
        ForEach(this.activeSourceEps(), (ep: PlayEp, epIdx: number) => {
          ListItem() { this.buildEpisodeCard(ep, epIdx) }
        })
      }
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Auto)
      .width('100%')
      .padding({ left: 20, right: 20, top: 4, bottom: 12 })
    }
  }

  @Builder
  buildEpisodeCard(ep: PlayEp, epIdx: number) {
    Column({ space: 4 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(140).aspectRatio(1.6).borderRadius(10)
          .backgroundColor($r('app.color.episode_card'))

        Text(this.formatEpNum(epIdx))
          .fontSize(36).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.hermes_orange')).opacity(0.22)
      }
      .width(140)

      Text(ep.title)
        .fontSize(11).fontColor($r('app.color.text_primary'))
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        .lineHeight(15).width(140)

      if (this.epHasSize(ep)) {
        Text(this.epSizeText(ep))
          .fontSize(10).fontColor($r('app.color.text_secondary'))
          .maxLines(1).width(140)
      }
    }
    .width(140)
  }

  // ════════════════════════════════════════════
  // 骨架屏
  // ════════════════════════════════════════════

  @Builder
  buildSkeleton() {
    Column() {
      Row().width('100%').height(200).backgroundColor($r('app.color.episode_card'))
      Column({ space: 8 }) {
        Row().width('15%').height(16).borderRadius(4).backgroundColor($r('app.color.tag_background'))
        Row().width('100%').height(12).borderRadius(4).backgroundColor($r('app.color.tag_background'))
        Row().width('80%').height(12).borderRadius(4).backgroundColor($r('app.color.tag_background'))
      }.width('100%').padding(20).alignItems(HorizontalAlign.Start)
    }.width('100%')
  }

  @Builder
  buildError() {
    Column({ space: 16 }) {
      Blank()
      Text('!').fontSize(36).fontWeight(FontWeight.Bold).fontColor($r('app.color.hermes_orange'))
        .width(48).height(48).textAlign(TextAlign.Center)
        .borderRadius(24).border({ width: 2, color: $r('app.color.hermes_orange') })
      Text(this.errorMsg).fontSize(15).fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center).padding({ left: 40, right: 40 })
      Button('重试').fontSize(14).fontColor(Color.White)
        .backgroundColor($r('app.color.hermes_orange')).borderRadius(20)
        .height(40).padding({ left: 24, right: 24 })
        .onClick(() => { this.isLoading = false; this.errorMsg = '' })
      Blank()
    }.width('100%').layoutWeight(1)
  }

  // ════════════════════════════════════════════
  // HELPERS（纯展示逻辑）
  // ════════════════════════════════════════════

  private sourceMenuItems(): MenuItem[] {
    let items: MenuItem[] = []
    for (let i = 0; i < this.sources.length; i++) {
      let src: PlaySrc = this.sources[i]
      items.push({ value: src.name, action: () => { this.activeSourceIndex = i } })
    }
    return items
  }

  private activeSourceEps(): PlayEp[] {
    if (this.activeSourceIndex < this.sources.length) {
      return this.sources[this.activeSourceIndex].eps
    }
    return []
  }

  private hasTags(): boolean {
    return this.typeName.length > 0 || this.vodYear.length > 0 ||
      this.vodArea.length > 0 || this.vodRemarks.length > 0
  }

  private formatEpNum(idx: number): string {
    let num: number = idx + 1
    return num < 10 ? '0' + num.toString() : num.toString()
  }

  private epHasSize(ep: PlayEp): boolean {
    let s: number | undefined = ep.size
    return s !== undefined && s !== null && s > 0
  }

  private epSizeText(ep: PlayEp): string {
    let s: number | undefined = ep.size
    if (s === undefined || s === null || s <= 0) { return '' }
    let units: string[] = ['B', 'KB', 'MB', 'GB', 'TB']
    let idx: number = 0
    let size: number = s
    while (size >= 1024 && idx < units.length - 1) { size = size / 1024; idx++ }
    return size.toFixed(2) + ' ' + units[idx]
  }
}
