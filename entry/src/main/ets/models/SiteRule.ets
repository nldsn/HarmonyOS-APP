/**
 * 站点爬取规则 — 正则驱动，纯 ArkTS 无 WebView 依赖
 *
 * 每个 CMS 模板 = 一个 ScrapeRuleSet。
 * HtmlScraperV2 读取 ScrapeRuleSet 执行正则解析。
 * 多策略按顺序尝试，第一个匹配的生效。
 */

// ═══════════════════════════════════════════════════
// 基础规则类
// ═══════════════════════════════════════════════════

export class ListStrategy {
  enabled: boolean = true
  itemRegex: string = ''       // 匹配每个视频条目: 捕获组1=vod_id, 组2=vod_name, 组3(可选)=remarks
  urlGroup: number = 1
  nameGroup: number = 2
  remarksGroup: number = 0     // 0 = remarks不在主正则中
  picRegex: string = ''        // 独立提取图片URL(1个捕获组)
  picGroup: number = 1
  remarksRegex: string = ''    // 独立提取remarks(1个捕获组)
  remarksRegexGroup: number = 1
  stripTitle: boolean = false  // 标题是否需要去除HTML标签
  blockRegex: string = ''      // 提取每个条目的HTML块(用于per-item图片提取)
  blockPicRegex: string = ''   // 从块中提取图片
  blockPicGroup: number = 1
}

export class DetailExtractionRule {
  titleRegex: string = ''
  titleGroup: number = 1
  titleFallbackRegex: string = ''
  titleFallbackGroup: number = 1
  typeRegex: string = ''
  typeGroup: number = 1
  typeFallbackRegex: string = ''
  typeFallbackGroup: number = 1
  // 标签提取: %s 会被替换为实际标签名
  labelPattern: string = ''
  labelDirector: string = '导演'
  labelActor: string = '主演'
  labelYear: string = '年代'
  labelArea: string = '地区'
  labelContent: string = '剧情'
  labelRemarks: string = '备注'
  // 播放列表
  playFromRegex: string = ''
  playFromGroup: number = 1
  playUrlRegex: string = ''
  playUrlGroup: number = 1
}

export class ScrapeUrls {
  home: string = '/'
  category: string = '/'
  detail: string = '{vodId}'
  search: string = '/'
  ajaxPlaylist: string = ''

  constructor(home: string, category: string, detail: string, search: string, ajaxPlaylist?: string) {
    this.home = home
    this.category = category
    this.detail = detail
    this.search = search
    if (ajaxPlaylist !== undefined) { this.ajaxPlaylist = ajaxPlaylist }
  }
}

export class ScrapeCategoryConfig {
  cateRegex: string = ''
  cateUrlGroup: number = 1
  cateNameGroup: number = 2
  cateIdRegex: string = ''     // 从分类URL中提取type_id
  cateIdGroup: number = 1
  cateStripName: boolean = true
}

export class ScrapeRuleSet {
  name: string = ''
  host: string = ''
  fingerprints: string[] = []
  urls: ScrapeUrls = new ScrapeUrls('/', '/', '{vodId}', '/')
  category: ScrapeCategoryConfig = new ScrapeCategoryConfig()
  listStrategies: ListStrategy[] = []
  detail: DetailExtractionRule = new DetailExtractionRule()
  encoding: string = 'utf-8'
  timeout: number = 15000
}

// ═══════════════════════════════════════════════════
// 工厂: 创建带host的规则副本
// ═══════════════════════════════════════════════════

function copyListStrategy(src: ListStrategy): ListStrategy {
  let dst: ListStrategy = new ListStrategy()
  dst.enabled = src.enabled
  dst.itemRegex = src.itemRegex
  dst.urlGroup = src.urlGroup
  dst.nameGroup = src.nameGroup
  dst.remarksGroup = src.remarksGroup
  dst.picRegex = src.picRegex
  dst.picGroup = src.picGroup
  dst.remarksRegex = src.remarksRegex
  dst.remarksRegexGroup = src.remarksRegexGroup
  dst.stripTitle = src.stripTitle
  dst.blockRegex = src.blockRegex
  dst.blockPicRegex = src.blockPicRegex
  dst.blockPicGroup = src.blockPicGroup
  return dst
}

export function createScrapeRule(templateKey: string, host: string): ScrapeRuleSet {
  let t: ScrapeRuleSet | undefined = BUILTIN_SCRAPE_RULES[templateKey]
  if (t === undefined) {
    t = BUILTIN_SCRAPE_RULES['generic']
  }

  let rule: ScrapeRuleSet = new ScrapeRuleSet()
  rule.name = t.name
  rule.host = host
  // 复制指纹
  let fps: string[] = []
  for (let i = 0; i < t.fingerprints.length; i++) { fps.push(t.fingerprints[i]) }
  rule.fingerprints = fps
  // URLs
  rule.urls = new ScrapeUrls(t.urls.home, t.urls.category, t.urls.detail, t.urls.search, t.urls.ajaxPlaylist)
  // 分类
  rule.category = new ScrapeCategoryConfig()
  rule.category.cateRegex = t.category.cateRegex
  rule.category.cateUrlGroup = t.category.cateUrlGroup
  rule.category.cateNameGroup = t.category.cateNameGroup
  rule.category.cateIdRegex = t.category.cateIdRegex
  rule.category.cateIdGroup = t.category.cateIdGroup
  rule.category.cateStripName = t.category.cateStripName
  // 列表策略
  let strats: ListStrategy[] = []
  for (let i = 0; i < t.listStrategies.length; i++) { strats.push(copyListStrategy(t.listStrategies[i])) }
  rule.listStrategies = strats
  // 详情
  let de: DetailExtractionRule = new DetailExtractionRule()
  de.titleRegex = t.detail.titleRegex; de.titleGroup = t.detail.titleGroup
  de.titleFallbackRegex = t.detail.titleFallbackRegex; de.titleFallbackGroup = t.detail.titleFallbackGroup
  de.typeRegex = t.detail.typeRegex; de.typeGroup = t.detail.typeGroup
  de.typeFallbackRegex = t.detail.typeFallbackRegex; de.typeFallbackGroup = t.detail.typeFallbackGroup
  de.labelPattern = t.detail.labelPattern
  de.labelDirector = t.detail.labelDirector; de.labelActor = t.detail.labelActor
  de.labelYear = t.detail.labelYear; de.labelArea = t.detail.labelArea
  de.labelContent = t.detail.labelContent; de.labelRemarks = t.detail.labelRemarks
  de.playFromRegex = t.detail.playFromRegex; de.playFromGroup = t.detail.playFromGroup
  de.playUrlRegex = t.detail.playUrlRegex; de.playUrlGroup = t.detail.playUrlGroup
  rule.detail = de
  // HTTP
  rule.encoding = t.encoding
  rule.timeout = t.timeout
  return rule
}

// ═══════════════════════════════════════════════════
// 内置规则
// ═══════════════════════════════════════════════════

export const BUILTIN_SCRAPE_RULES: Record<string, ScrapeRuleSet> = {}

// ─── DYXS2 短URL（玩偶 / wogg.net）───
let dyxs2s: ScrapeRuleSet = new ScrapeRuleSet()
dyxs2s.name = 'DYXS2-短URL'
dyxs2s.fingerprints = ['template/DYXS2', 'nav-link', 'module-item']
dyxs2s.urls = new ScrapeUrls(
  '/', '/vodshow/{cateId}--------{page}---.html', '{vodId}',
  '/vodsearch/{wd}----------{page}---.html',
  '/index.php/vod/playlist/id/{vodId}/sid/1'
)
dyxs2s.category = new ScrapeCategoryConfig()
dyxs2s.category.cateRegex = '<a[^>]*?class="nav-link[^"]*"[^>]*?href="([^"]*)"[^>]*?>([\\s\\S]*?)</a>'
dyxs2s.category.cateUrlGroup = 1
dyxs2s.category.cateNameGroup = 2
dyxs2s.category.cateIdRegex = '/(\\d+)\\.html'
dyxs2s.category.cateIdGroup = 1
dyxs2s.category.cateStripName = true

// 策略1: 精确匹配
let ls1: ListStrategy = new ListStrategy()
ls1.itemRegex = '<a[^>]*?href="(/voddetail/\\d+\\.html)"[^>]*?title="([^"]*)"[^>]*?>'
ls1.urlGroup = 1
ls1.nameGroup = 2
ls1.remarksGroup = 0
ls1.stripTitle = false
ls1.blockRegex = '<div class="module-item"[^>]*?>[\\s\\S]*?</div>\\s*</div>\\s*</div>'
ls1.blockPicRegex = '<img[^>]*?data-src="([^"]*)"'
ls1.blockPicGroup = 1
dyxs2s.listStrategies.push(ls1)

// 策略2: 宽松匹配
let ls2: ListStrategy = new ListStrategy()
ls2.itemRegex = '<a[^>]*?href="(/voddetail/[^"]*)"[^>]*?title="([^"]*)"'
ls2.urlGroup = 1
ls2.nameGroup = 2
dyxs2s.listStrategies.push(ls2)

// 详情
dyxs2s.detail = new DetailExtractionRule()
dyxs2s.detail.titleRegex = '<h1[^>]*?class="[^"]*page-title[^"]*"[^>]*?>([\\s\\S]*?)</h1>'
dyxs2s.detail.titleGroup = 1
dyxs2s.detail.titleFallbackRegex = '<title>([\\s\\S]*?)</title>'
dyxs2s.detail.titleFallbackGroup = 1
dyxs2s.detail.typeRegex = '<a[^>]*?href="/vodtype/\\d+\\.html"[^>]*?class="[^"]*tag-link[^"]*"[^>]*?>([\\s\\S]*?)</a>'
dyxs2s.detail.typeGroup = 1
dyxs2s.detail.typeFallbackRegex = '<a[^>]*?href="/index\\.php/vod/type/id/\\d+\\.html"[^>]*?>([\\s\\S]*?)</a>'
dyxs2s.detail.typeFallbackGroup = 1
dyxs2s.detail.labelPattern = '<span[^>]*?video-info-itemtitle[^>]*?>\\s*%s[：:]?\\s*</span>\\s*<(?:div|span)[^>]*?video-info-item[^>]*?>([\\s\\S]*?)</(?:div|span)>'
dyxs2s.detail.labelDirector = '导演'
dyxs2s.detail.labelActor = '主演'
dyxs2s.detail.labelYear = '年代'
dyxs2s.detail.labelArea = '地区'
dyxs2s.detail.labelContent = '剧情'
dyxs2s.detail.labelRemarks = '备注'
dyxs2s.encoding = 'utf-8'
dyxs2s.timeout = 15000
BUILTIN_SCRAPE_RULES['dyxs2-short'] = dyxs2s

// ─── DYXS2 PHP URL（木偶 / 666.666291.xyz）───
let dyxs2p: ScrapeRuleSet = new ScrapeRuleSet()
dyxs2p.name = 'DYXS2-PHP'
dyxs2p.fingerprints = ['module-item-title', 'nav-link', '/index.php/vod/detail']
dyxs2p.urls = new ScrapeUrls(
  '/', '/index.php/vod/show/id/{cateId}.html', '{vodId}',
  '/index.php/vod/search/wd/{wd}/page/{page}.html',
  '/index.php/vod/playlist/id/{vodId}/sid/1'
)
dyxs2p.category = new ScrapeCategoryConfig()
dyxs2p.category.cateRegex = '<a[^>]*?class="nav-link[^"]*"[^>]*?href="([^"]*)"[^>]*?>([\\s\\S]*?)</a>'
dyxs2p.category.cateUrlGroup = 1
dyxs2p.category.cateNameGroup = 2
dyxs2p.category.cateIdRegex = '/id/(\\d+)\\.html'
dyxs2p.category.cateIdGroup = 1
dyxs2p.category.cateStripName = true

// 策略1
let pls1: ListStrategy = new ListStrategy()
pls1.itemRegex = '<a[^>]*?class="module-item-title"[^>]*?href="(/index\\.php/vod/detail/id/\\d+\\.html)"[^>]*?title="([^"]*)"[^>]*?>'
pls1.urlGroup = 1
pls1.nameGroup = 2
pls1.remarksRegex = '<div class="module-item-text"[^>]*?>([\\s\\S]*?)</div>'
pls1.remarksRegexGroup = 1
pls1.blockRegex = '(<div class="module-item"[^>]*?>[\\s\\S]*?</div>\\s*</div>\\s*</div>)'
pls1.blockPicRegex = '<img[^>]*?data-src="([^"]*)"'
pls1.blockPicGroup = 1
dyxs2p.listStrategies.push(pls1)

// 策略2
let pls2: ListStrategy = new ListStrategy()
pls2.itemRegex = '<a[^>]*?href="(/index\\.php/vod/detail/id/\\d+\\.html)"[^>]*?title="([^"]*)"[^>]*?>'
pls2.urlGroup = 1
pls2.nameGroup = 2
dyxs2p.listStrategies.push(pls2)

// 详情
dyxs2p.detail = new DetailExtractionRule()
dyxs2p.detail.titleRegex = '<h1[^>]*?class="[^"]*page-title[^"]*"[^>]*?>([\\s\\S]*?)</h1>'
dyxs2p.detail.titleGroup = 1
dyxs2p.detail.titleFallbackRegex = '<title>([\\s\\S]*?)</title>'
dyxs2p.detail.titleFallbackGroup = 1
dyxs2p.detail.typeRegex = '<a[^>]*?href="/vodtype/\\d+\\.html"[^>]*?class="[^"]*tag-link[^"]*"[^>]*?>([\\s\\S]*?)</a>'
dyxs2p.detail.typeGroup = 1
dyxs2p.detail.typeFallbackRegex = '<a[^>]*?href="/index\\.php/vod/type/id/\\d+\\.html"[^>]*?>([\\s\\S]*?)</a>'
dyxs2p.detail.typeFallbackGroup = 1
dyxs2p.detail.labelPattern = '<span[^>]*?video-info-itemtitle[^>]*?>\\s*%s[：:]?\\s*</span>\\s*<(?:div|span)[^>]*?video-info-item[^>]*?>([\\s\\S]*?)</(?:div|span)>'
dyxs2p.detail.labelDirector = '导演'
dyxs2p.detail.labelActor = '主演'
dyxs2p.detail.labelYear = '年代'
dyxs2p.detail.labelArea = '地区'
dyxs2p.detail.labelContent = '剧情'
dyxs2p.detail.labelRemarks = '备注'
dyxs2p.encoding = 'utf-8'
dyxs2p.timeout = 15000
BUILTIN_SCRAPE_RULES['dyxs2-php'] = dyxs2p

// ─── MacCMS（观影/剧透/虎斑 等）───
let mac: ScrapeRuleSet = new ScrapeRuleSet()
mac.name = 'MacCMS'
mac.fingerprints = ['MacCMS', 'mac_cms', 'vodlist', 'class="vodlist']
mac.urls = new ScrapeUrls(
  '/', '/index.php/vod/type/id/{cateId}/page/{page}.html', '{vodId}',
  '/index.php/vod/search/wd/{wd}/page/{page}.html',
  '/index.php/vod/playlist/id/{vodId}/sid/1'
)
mac.category = new ScrapeCategoryConfig()
mac.category.cateRegex = '<a[^>]*?href="[^"]*?(?:/type/|/vod/|/show/)[^"]*?"[^>]*?>([\\s\\S]*?)</a>'
mac.category.cateUrlGroup = 1
mac.category.cateNameGroup = 1
mac.category.cateIdRegex = '/id/(\\d+)'
mac.category.cateIdGroup = 1
mac.category.cateStripName = true

let mls1: ListStrategy = new ListStrategy()
mls1.itemRegex = '<a[^>]*?href="([^"]*(?:/voddetail/|/vod/detail/|/detail/)[^"]*)"[^>]*?title="([^"]*)"[^>]*?>'
mls1.urlGroup = 1
mls1.nameGroup = 2
mls1.remarksRegex = '<(?:span|div|p)[^>]*?class="[^"]*(?:remarks|note|text|subtitle|pic_text)[^"]*"[^>]*?>([\\s\\S]*?)</(?:span|div|p)>'
mls1.remarksRegexGroup = 1
mls1.blockPicRegex = '<img[^>]*?(?:data-src|data-original|src)="([^"]*)"'
mls1.blockPicGroup = 1
mac.listStrategies.push(mls1)

let mls2: ListStrategy = new ListStrategy()
mls2.itemRegex = '<a[^>]*?href="([^"]*)"[^>]*?title="([^"]*)"[^>]*?>'
mls2.urlGroup = 1
mls2.nameGroup = 2
mac.listStrategies.push(mls2)

mac.detail = new DetailExtractionRule()
mac.detail.titleRegex = '<h1[^>]*?>([\\s\\S]*?)</h1>'
mac.detail.titleGroup = 1
mac.detail.titleFallbackRegex = '<title>([\\s\\S]*?)</title>'
mac.detail.titleFallbackGroup = 1
mac.detail.labelPattern = '<(?:span|div|p)[^>]*?>\\s*%s[：:]?\\s*</(?:span|div|p)>\\s*<(?:span|div|p)[^>]*?>([\\s\\S]*?)</(?:span|div|p)>'
mac.detail.labelDirector = '导演'
mac.detail.labelActor = '主演'
mac.detail.labelYear = '年代'
mac.detail.labelArea = '地区'
mac.detail.labelContent = '剧情'
mac.detail.labelRemarks = '备注'
mac.encoding = 'utf-8'
mac.timeout = 15000
BUILTIN_SCRAPE_RULES['maccms'] = mac

// ─── 通用兜底 ───
let gen: ScrapeRuleSet = new ScrapeRuleSet()
gen.name = '通用'
gen.fingerprints = []
gen.urls = new ScrapeUrls('/', '/', '{vodId}', '/')
gen.category = new ScrapeCategoryConfig()
gen.category.cateRegex = '<a[^>]*?href="([^"]*)"[^>]*?>([\\s\\S]*?)</a>'
gen.category.cateUrlGroup = 1
gen.category.cateNameGroup = 2
gen.category.cateIdRegex = '/(\\d+)'
gen.category.cateIdGroup = 1
gen.category.cateStripName = true

let gls: ListStrategy = new ListStrategy()
gls.itemRegex = '<a[^>]*?href="([^"]*)"[^>]*?title="([^"]*)"[^>]*?>'
gls.urlGroup = 1
gls.nameGroup = 2
gen.listStrategies.push(gls)

gen.detail = new DetailExtractionRule()
gen.detail.titleRegex = '<h1[^>]*?>([\\s\\S]*?)</h1>'
gen.detail.titleGroup = 1
gen.detail.titleFallbackRegex = '<title>([\\s\\S]*?)</title>'
gen.detail.titleFallbackGroup = 1
gen.detail.labelPattern = '<(?:span|div)[^>]*?>\\s*%s[：:]?\\s*</(?:span|div)>\\s*<(?:span|div)[^>]*?>([\\s\\S]*?)</(?:span|div)>'
gen.detail.labelDirector = '导演'
gen.detail.labelActor = '主演'
gen.detail.labelYear = '年代'
gen.detail.labelArea = '地区'
gen.detail.labelContent = '剧情'
gen.detail.labelRemarks = '备注'
gen.encoding = 'utf-8'
gen.timeout = 15000
BUILTIN_SCRAPE_RULES['generic'] = gen
