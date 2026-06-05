import { router } from '@kit.ArkUI'
import { pasteboard } from '@kit.BasicServicesKit'
import { SiteRepository } from '../services/SiteRepository'
import { AppleCMSClient } from '../services/AppleCMSClient'
import { QuarkClient, EpisodeInfo } from '../services/QuarkClient'
import { VodDetail } from '../models/SiteData'

interface PlaySrc { name: string; eps: PlayEp[] }
interface PlayEp { title: string; url: string; size?: number }
interface MenuItem { value: string; action: () => void }

@Entry
@Component
struct DetailPage {
  @State vodId: string = ''
  @State vodName: string = ''
  @State vodPic: string = ''
  @State baseUrl: string = ''
  @State vodContent: string = ''
  @State vodActor: string = ''
  @State vodDirector: string = ''
  @State vodYear: string = ''
  @State vodArea: string = ''
  @State typeName: string = ''
  @State vodRemarks: string = ''
  @State sources: PlaySrc[] = []
  @State isLoading: boolean = true
  @State errorMsg: string = ''
  @State showFullIntro: boolean = false
  @State isResolvingCloud: boolean = false
  @State activeSourceIndex: number = 0

  private repository: SiteRepository = new SiteRepository()
  private siteKey: string = ''

  aboutToAppear(): void {
    let p: Record<string, Object> = router.getParams() as Record<string, Object>
    if (p !== null && p !== undefined) {
      this.vodId = (p['vod_id'] as string) ?? ''
      this.vodName = (p['vod_name'] as string) ?? ''
      this.vodPic = (p['vod_pic'] as string) ?? ''
      this.baseUrl = (p['baseUrl'] as string) ?? ''
      this.siteKey = (p['siteKey'] as string) ?? ''
    }
    this.loadDetail()
  }

  aboutToDisappear(): void {
    this.repository.release()
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
  // 超大英雄海报 — Emby 风格，只调大了图片
  // ════════════════════════════════════════════

  @Builder
  buildHero() {
    Column() {
      // 模糊背景 + 海报 + 元数据
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
  // 网盘选择 + 剧集区
  // ════════════════════════════════════════════

  @Builder
  buildSourceSection() {
    if (this.sources.length > 0) {
      Column({ space: 8 }) {
        // ── 标题行 + 网盘下拉 ──
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

        // ── 剧集横向滑动 ──
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
      // 缩略图占位
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(140).aspectRatio(1.6).borderRadius(10)
          .backgroundColor($r('app.color.episode_card'))
        // 集数编号
        Text(this.formatEpNum(epIdx))
          .fontSize(36).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.hermes_orange')).opacity(0.22)
      }
      .width(140)

      // 文件名
      Text(ep.title)
        .fontSize(11).fontColor($r('app.color.text_primary'))
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        .lineHeight(15).width(140)

      // 大小
      if (this.epHasSize(ep)) {
        Text(this.epSizeText(ep))
          .fontSize(10).fontColor($r('app.color.text_secondary'))
          .maxLines(1).width(140)
      }
    }
    .width(140)
    .onClick(() => {
      if (ep.url.length > 0) {
        try {
          let data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, ep.url)
          pasteboard.getSystemPasteboard().setData(data)
        } catch (_e) { /* ignore */ }
      }
    })
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
        .onClick(() => { this.loadDetail() })
      Blank()
    }.width('100%').layoutWeight(1)
  }

  // ════════════════════════════════════════════
  // HELPERS
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

  // ════════════════════════════════════════════
  // DATA LOADING
  // ════════════════════════════════════════════

  private loadDetail(): void {
    if (this.vodId.length === 0 || this.baseUrl.length === 0) {
      this.isLoading = false; this.errorMsg = '参数错误'; return
    }
    this.isLoading = true; this.errorMsg = ''

    this.repository.selectSite(this.siteKey, this.baseUrl).then(() => {
      if (!this.repository.isReady()) { this.loadDetailFallback(); return }
      this.repository.fetchDetail(this.vodId).then((detail: VodDetail | null) => {
        if (detail !== null && detail.vod_name.length > 0) {
          this.applyDetail(detail); this.isLoading = false
        } else { this.loadDetailFallback() }
      }).catch((_e: Error) => { this.loadDetailFallback() })
    }).catch((_e: Error) => { this.loadDetailFallback() })
  }

  private loadDetailFallback(): void {
    if (this.baseUrl.indexOf('wogg.net') >= 0 ||
        this.baseUrl.indexOf('xb6v.com') >= 0 ||
        this.baseUrl.indexOf('666291.xyz') >= 0 ||
        this.baseUrl.indexOf('leijing1') >= 0 ||
        this.baseUrl.indexOf('nivodz.com') >= 0 ||
        this.baseUrl.indexOf('ffzyapi.com') >= 0 ||
        this.baseUrl.indexOf('rbotv.cn') >= 0 ||
        this.baseUrl.indexOf('lzcaiji.com') >= 0 ||
        this.baseUrl.indexOf('ikanbot.com') >= 0) {
      this.isLoading = false; this.errorMsg = '详情加载失败，请重试'; return
    }
    let nm: RegExpMatchArray | null = this.vodId.match(/(\d+)/)
    let nid: string = nm !== null && nm[1] !== undefined ? nm[1] : this.vodId
    let c: AppleCMSClient = new AppleCMSClient(this.baseUrl, 5000)
    c.fetchDetail(nid).then((raw: Object | null) => {
      if (raw !== null) {
        let list: Object[] = ((raw as Record<string, Object>)['list'] as Object[]) ?? []
        if (list.length > 0) { this.applyRawDetail(list[0] as Record<string, Object>); this.isLoading = false; return }
      }
      this.isLoading = false; this.errorMsg = '加载失败'
    }).catch((_e: Error) => { this.isLoading = false; this.errorMsg = '网络错误' })
  }

  private applyDetail(d: VodDetail): void {
    this.vodName = this.pick(d.vod_name, this.vodName)
    if (this.vodPic.length === 0 && d.vod_pic.length > 0) { this.vodPic = d.vod_pic }
    this.vodContent = d.vod_content; this.vodActor = d.vod_actor
    this.vodDirector = d.vod_director; this.vodYear = d.vod_year
    this.vodArea = d.vod_area; this.typeName = d.type_name
    this.vodRemarks = d.vod_remarks
    this.doResolve(d.vod_play_from, d.vod_play_url)
  }

  private applyRawDetail(d: Record<string, Object>): void {
    this.vodName = this.pick(d['vod_name'] as string, this.vodName)
    if (this.vodPic.length === 0) { this.vodPic = this.pick(d['vod_pic'] as string, '') }
    this.vodContent = this.pick(d['vod_content'] as string, '')
    this.vodActor = this.pick(d['vod_actor'] as string, '')
    this.vodDirector = this.pick(d['vod_director'] as string, '')
    this.vodYear = this.pick(d['vod_year'] as string, '')
    this.vodArea = this.pick(d['vod_area'] as string, '')
    this.typeName = this.pick(d['type_name'] as string, '')
    this.vodRemarks = this.pick(d['vod_remarks'] as string, '')
    this.doResolve(this.pick(d['vod_play_from'] as string, ''), this.pick(d['vod_play_url'] as string, ''))
  }

  private pick(a: string | undefined, b: string): string {
    return (a !== undefined && a !== null && a.length > 0) ? a : b
  }

  // ════════════════════════════════════════════
  // CLOUD DRIVE RESOLUTION
  // ════════════════════════════════════════════

  private doResolve(pf: string, pu: string): void {
    if (pu.length === 0) { return }
    let isCloud: boolean = pu.indexOf('pan.quark.cn') >= 0 ||
      pu.indexOf('aliyundrive.com') >= 0 || pu.indexOf('drive.uc.cn') >= 0 ||
      pu.indexOf('pan.baidu.com') >= 0 || pu.indexOf('cloud.189.cn') >= 0 ||
      pu.indexOf('115.com') >= 0

    if (isCloud) {
      let urls: string[] = pu.split('#')
      let cloudSources: PlaySrc[] = []
      for (let i = 0; i < urls.length; i++) {
        let u: string = urls[i].trim()
        if (u.length === 0) { continue }
        let driveName: string = this.cloudDriveName(u)
        cloudSources.push({ name: driveName + '(解析中...)', eps: [{ title: '正在获取...', url: u }] })
      }
      if (cloudSources.length > 0) {
        this.sources = cloudSources
        this.activeSourceIndex = 0
        this.resolveCloudUrls()
      }
      return
    }
    this.doParsePU(pf, pu)
  }

  private cloudDriveName(url: string): string {
    if (url.indexOf('pan.quark.cn') >= 0) { return '夸克云盘' }
    if (url.indexOf('aliyundrive.com') >= 0) { return '阿里云盘' }
    if (url.indexOf('drive.uc.cn') >= 0) { return 'UC网盘' }
    if (url.indexOf('pan.baidu.com') >= 0) { return '百度网盘' }
    if (url.indexOf('cloud.189.cn') >= 0) { return '天翼云盘' }
    if (url.indexOf('115.com') >= 0) { return '115网盘' }
    return '云盘资源'
  }

  private async resolveCloudUrls(): Promise<void> {
    this.isResolvingCloud = true
    let quarkClient: QuarkClient = new QuarkClient(12000)
    let newSources: PlaySrc[] = []

    for (let i = 0; i < this.sources.length; i++) {
      let src: PlaySrc = this.sources[i]
      let url: string = src.eps.length > 0 ? src.eps[0].url : ''
      if (url.length === 0) { newSources.push(src); continue }

      let driveName: string = this.cloudDriveName(url)
      try {
        let episodes: EpisodeInfo[] = []
        if (url.indexOf('pan.quark.cn') >= 0) { episodes = await quarkClient.getEpisodes(url) }
        if (episodes.length > 0) {
          let eps: PlayEp[] = []
          for (let j = 0; j < episodes.length; j++) {
            eps.push({ title: episodes[j].title, url: episodes[j].url, size: episodes[j].size })
          }
          newSources.push({ name: driveName, eps: eps })
        } else {
          newSources.push({ name: driveName + '(需App内打开)', eps: [{ title: url, url: url }] })
        }
      } catch (_e) {
        newSources.push({ name: driveName + '(解析失败)', eps: [{ title: url, url: url }] })
      }
    }

    this.sources = newSources
    this.activeSourceIndex = 0
    this.isResolvingCloud = false
  }

  private doParsePU(pf: string, pu: string): void {
    if (pf.length === 0 || pu.length === 0) { return }
    let sl: PlaySrc[] = []
    let fns: string[] = pf.split('$$$')
    let ubs: string[] = pu.split('$$$')
    let lim: number = fns.length < ubs.length ? fns.length : ubs.length
    for (let i = 0; i < lim; i++) {
      let nm: string = fns[i].trim()
      let bl: string = ubs[i].trim()
      if (nm.length === 0 || bl.length === 0) { continue }
      let eps: PlayEp[] = []
      let pts: string[] = bl.split('#')
      for (let j = 0; j < pts.length; j++) {
        let pt: string = pts[j].trim()
        if (pt.length === 0) { continue }
        let di: number = pt.indexOf('$')
        if (di >= 0) {
          let t: string = pt.substring(0, di).trim()
          let eu: string = pt.substring(di + 1).trim()
          if (t.length > 0) { eps.push({ title: t, url: eu }) }
        } else {
          eps.push({ title: pt, url: pt })
        }
      }
      if (eps.length > 0) { sl.push({ name: nm, eps: eps }) }
    }
    this.sources = sl
    this.activeSourceIndex = 0
  }
}
