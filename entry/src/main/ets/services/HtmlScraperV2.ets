/**
 * 纯正则驱动的 HTML 解析引擎 (V2)
 *
 * 使用正则表达式直接解析 HTML，无需 WebView 依赖。
 * 多策略按顺序尝试，第一个匹配的生效。
 * 通过 DataNormalizer 输出标准数据模型。
 */

import { http } from '@kit.NetworkKit'
import { ScrapeRuleSet, ListStrategy, DetailExtractionRule } from '../models/SiteRule'
import { VodItem, VodDetail, CategoryWithVods, VodClass, CategoryPageResult, ISiteHandler } from '../models/SiteData'
import { DataNormalizer } from './DataNormalizer'

const NOISE_NAMES: string[] = ['玩偶哥哥', '网盘资源', '资源分享', '首页', '全部影片', '最新更新', '推荐视频']

export class HtmlScraperV2 implements ISiteHandler {
  readonly name: string = 'HtmlScraperV2'
  readonly baseUrl: string

  private rule: ScrapeRuleSet
  private timeout: number
  public lastHtml: string = ''

  constructor(rule: ScrapeRuleSet, baseUrl: string) {
    this.rule = rule
    this.baseUrl = baseUrl.replace(/\/+$/, '')
    this.timeout = rule.timeout > 0 ? rule.timeout : 15000
  }

  // ═══ ISiteHandler ═══

  async fetchHome(): Promise<CategoryWithVods[]> {
    let html: string | null = await this.doGet(this.rule.urls.home)
    if (html === null) {
      throw new Error('无法连接站点: ' + this.baseUrl)
    }
    if (this.isBlocked(html)) {
      throw new Error('站点受 Cloudflare 保护')
    }
    this.lastHtml = html

    let classes: VodClass[] = this.parseCategories(html)
    let vods: VodItem[] = this.parseVodList(html)
    return this.buildCategories(classes, vods)
  }

  async fetchCategory(tid: string, pg: number): Promise<CategoryPageResult> {
    let path: string = this.buildUrl(this.rule.urls.category, tid, pg.toString(), '')
    let html: string | null = await this.doGet(path)
    if (html === null) {
      throw new Error('无法获取分类页')
    }
    this.lastHtml = html
    let vods: VodItem[] = this.parseVodList(html)
    let result: CategoryPageResult = { list: vods, page: pg, pagecount: 1, total: vods.length }
    return result
  }

  async fetchDetail(vodId: string): Promise<VodDetail | null> {
    let path: string = this.buildUrl(this.rule.urls.detail, vodId, '1', '')
    let html: string | null = await this.doGet(path)
    if (html === null) {
      return null
    }
    this.lastHtml = html
    return this.parseDetail(html, vodId)
  }

  async search(keyword: string, page: number): Promise<VodItem[]> {
    let path: string = this.buildUrl(this.rule.urls.search, keyword, page.toString(), keyword)
    let html: string | null = await this.doGet(path)
    if (html === null) {
      return []
    }
    return this.parseVodList(html)
  }

  // ═══ 指纹匹配 ═══

  static matchFingerprint(html: string, rule: ScrapeRuleSet): boolean {
    let fps: string[] = rule.fingerprints
    if (fps.length === 0) {
      return false
    }
    for (let i = 0; i < fps.length; i++) {
      if (html.indexOf(fps[i]) >= 0) {
        return true
      }
    }
    return false
  }

  // ═══════════════════════════════════════════════════
  // 正则解析
  // ═══════════════════════════════════════════════════

  private parseCategories(html: string): VodClass[] {
    let result: VodClass[] = []
    let seen: Set<string> = new Set()
    let cfg = this.rule.category

    if (cfg.cateRegex.length === 0) {
      return result
    }

    let re: RegExp = new RegExp(cfg.cateRegex, 'gi')
    let idRe: RegExp = new RegExp(cfg.cateIdRegex, 'i')
    let m: RegExpExecArray | null = re.exec(html)

    while (m !== null) {
      let url: string = m[cfg.cateUrlGroup] ?? ''
      let name: string = m[cfg.cateNameGroup] ?? ''
      if (cfg.cateStripName) {
        name = this.stripHtml(name).trim()
      } else {
        name = name.trim()
      }
      if (name.length === 0 || name.length > 20 || name === '首页') {
        m = re.exec(html)
        continue
      }
      let idM: RegExpMatchArray | null = url.match(idRe)
      let tid: string = idM !== null && idM[cfg.cateIdGroup] !== undefined
        ? idM[cfg.cateIdGroup] : ''
      if (tid.length === 0 || seen.has(tid)) {
        m = re.exec(html)
        continue
      }
      seen.add(tid)
      let cls: VodClass = { type_id: tid, type_name: name }
      result.push(cls)
      m = re.exec(html)
    }
    return result
  }

  private parseVodList(html: string): VodItem[] {
    let vods: VodItem[] = []
    let seen: Set<string> = new Set()
    let strategies: ListStrategy[] = this.rule.listStrategies

    for (let s = 0; s < strategies.length; s++) {
      let st: ListStrategy = strategies[s]
      if (!st.enabled) { continue }

      // ── 主正则匹配 ──
      let re: RegExp = new RegExp(st.itemRegex, 'gi')
      let m: RegExpExecArray | null = re.exec(html)

      while (m !== null) {
        let vid: string = m[st.urlGroup] ?? ''
        let vname: string = m[st.nameGroup] ?? ''

        if (st.stripTitle) {
          vname = this.stripHtml(vname).trim()
        } else {
          vname = vname.trim()
        }

        // 过滤无效条目
        if (vid.length === 0 || vname.length === 0 || vname.length > 80 || seen.has(vid)) {
          m = re.exec(html)
          continue
        }

        // 噪音过滤
        let isNoise: boolean = false
        for (let ni = 0; ni < NOISE_NAMES.length; ni++) {
          if (vname.indexOf(NOISE_NAMES[ni]) >= 0) { isNoise = true; break }
        }
        if (isNoise) { m = re.exec(html); continue }

        seen.add(vid)

        // ── 窗口提取图片：从匹配位置附近搜数据源 ──
        let matchPos: number = m.index
        let windowStart: number = matchPos > 800 ? matchPos - 800 : 0
        let windowEnd: number = matchPos + 2000 < html.length ? matchPos + 2000 : html.length
        let context: string = html.substring(windowStart, windowEnd)

        let vodPic: string = ''
        // data-src 优先
        let picDsRe: RegExp = /<img[^>]*?data-src\s*=\s*"([^"]*)"/i
        let picM: RegExpMatchArray | null = context.match(picDsRe)
        if (picM !== null && picM[1] !== undefined) {
          vodPic = this.fixUrl(picM[1])
        } else {
          // data-original
          let picDoRe: RegExp = /<img[^>]*?data-original\s*=\s*"([^"]*)"/i
          picM = context.match(picDoRe)
          if (picM !== null && picM[1] !== undefined) {
            vodPic = this.fixUrl(picM[1])
          } else {
            // src 兜底
            let picSrcRe: RegExp = /<img[^>]*?src\s*=\s*"([^"]*)"/i
            picM = context.match(picSrcRe)
            if (picM !== null && picM[1] !== undefined) {
              vodPic = this.fixUrl(picM[1])
            }
          }
        }

        // ── 窗口提取 remarks ──
        let vodRemarks: string = ''
        if (st.remarksGroup > 0 && m[st.remarksGroup] !== undefined) {
          vodRemarks = this.stripHtml(m[st.remarksGroup]).trim()
        } else if (st.remarksRegex.length > 0) {
          let rmRe: RegExp = new RegExp(st.remarksRegex, 'i')
          let rmM: RegExpMatchArray | null = context.match(rmRe)
          if (rmM !== null && rmM[st.remarksRegexGroup] !== undefined) {
            vodRemarks = this.stripHtml(rmM[st.remarksRegexGroup]).trim()
          }
        }
        if (vodRemarks === vname || vodRemarks === vid) {
          vodRemarks = ''
        }

        let vod: VodItem = {
          vod_id: vid,
          vod_name: vname,
          vod_pic: vodPic,
          vod_remarks: vodRemarks,
          type_name: ''
        }
        vods.push(vod)
        m = re.exec(html)
      }

      // 当前策略匹配到数据，停止
      if (vods.length > 0) {
        break
      }
    }

    // ── 全局图片兜底 ──
    let hasPic: boolean = false
    for (let i = 0; i < vods.length; i++) {
      if (vods[i].vod_pic.length > 0) { hasPic = true; break }
    }
    if (!hasPic) {
      let imgs: string[] = this.extractImages(html)
      for (let i = 0; i < vods.length && i < imgs.length; i++) {
        vods[i].vod_pic = imgs[i]
      }
    }

    return vods
  }

  private parseDetail(html: string, vodId: string): VodDetail | null {
    let de: DetailExtractionRule = this.rule.detail

    // ── 片名 ──
    let vodName: string = this.extractOne(html, de.titleRegex, de.titleGroup)
    if (vodName.length === 0) {
      vodName = this.extractOne(html, de.titleFallbackRegex, de.titleFallbackGroup)
      let dash: number = vodName.indexOf(' - ')
      if (dash > 0) { vodName = vodName.substring(0, dash) }
      let pipe: number = vodName.indexOf('--')
      if (pipe > 0) { vodName = vodName.substring(0, pipe) }
    }
    vodName = this.stripHtml(vodName).trim()

    // ── 海报 — 优先从页面顶部海报区域提取 ──
    let vodPic: string = this.extractPosterImage(html)

    // ── 类型 ──
    let typeName: string = this.extractOne(html, de.typeRegex, de.typeGroup)
    if (typeName.length === 0) {
      typeName = this.extractOne(html, de.typeFallbackRegex, de.typeFallbackGroup)
    }
    typeName = this.stripHtml(typeName).trim()

    // ── 标签提取 ──
    let vodDirector: string = this.extractByLabel(html, de, de.labelDirector)
    let vodActor: string = this.extractByLabel(html, de, de.labelActor)
    let vodYear: string = this.extractByLabel(html, de, de.labelYear)
    let vodArea: string = this.extractByLabel(html, de, de.labelArea)
    let vodContent: string = this.extractByLabel(html, de, de.labelContent)
    let vodRemarks: string = this.extractByLabel(html, de, de.labelRemarks)

    // ── DEBUG: 打印提取结果 ──
    console.info('[HtmlScraperV2] Detail extraction results:')
    console.info('  vodName: ' + vodName)
    console.info('  vodPic: ' + (vodPic.length > 0 ? vodPic.substring(0, 80) : '(empty)'))
    console.info('  typeName: ' + typeName)
    console.info('  vodDirector: ' + vodDirector)
    console.info('  vodActor: ' + vodActor)
    console.info('  vodYear: ' + vodYear)
    console.info('  vodArea: ' + vodArea)
    console.info('  vodContent: ' + (vodContent.length > 0 ? vodContent.substring(0, 100) : '(empty)'))
    console.info('  vodRemarks: ' + vodRemarks)
    console.info('  labelPattern used: ' + de.labelPattern.substring(0, 80))
    // 打印 HTML 前2000字符用于分析结构
    console.info('  HTML head (0-2000): ' + html.substring(0, 2000))
    console.info('  HTML body (3000-6000): ' + html.substring(3000, 6000))

    // ── 分享链接（云盘）──
    let shareUrls: string[] = this.extractShareUrls(html)
    let playFrom: string = shareUrls.length > 0 ? '云盘资源' : ''
    let playUrl: string = shareUrls.length > 0 ? shareUrls.join('#') : ''

    // ── 普通播放列表 ──
    if (playUrl.length === 0) {
      let pf: string = this.extractOne(html, de.playFromRegex, de.playFromGroup)
      let pu: string = this.extractOne(html, de.playUrlRegex, de.playUrlGroup)
      if (pf.length > 0 && pu.length > 0) {
        playFrom = pf
        playUrl = pu
      }
    }

    let detail: VodDetail = {
      vod_id: vodId,
      vod_name: vodName,
      vod_pic: vodPic,
      vod_content: vodContent,
      vod_actor: vodActor,
      vod_director: vodDirector,
      vod_year: vodYear,
      vod_area: vodArea,
      type_name: typeName,
      vod_remarks: vodRemarks,
      vod_play_from: playFrom,
      vod_play_url: playUrl
    }
    return detail
  }

  // ═══════════════════════════════════════════════════
  // 正则工具
  // ═══════════════════════════════════════════════════

  private extractOne(html: string, pattern: string, group: number): string {
    if (pattern.length === 0) { return '' }
    try {
      let re: RegExp = new RegExp(pattern, 'i')
      let m: RegExpMatchArray | null = html.match(re)
      if (m !== null && m[group] !== undefined) {
        return this.stripHtml(m[group]).trim()
      }
    } catch (_e) {
      // 正则语法错误
    }
    return ''
  }

  private extractByLabel(html: string, de: DetailExtractionRule, label: string): string {
    if (label.length === 0) { return '' }

    let escaped: string = label.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')

    // 依次尝试所有策略，拿到有效值就返回
    let candidates: string[] = []

    // 策略1: 规则中的 labelPattern（DYXS2 video-info-item 结构）
    if (de.labelPattern.length > 0) {
      let pat1: string = de.labelPattern.replace('%s', escaped)
      let r1: string = this.extractOne(html, pat1, 1)
      if (r1.length > 0) { candidates.push(r1) }
    }

    // 策略2: span/div 标签-值配对结构
    let pat2: string = '<(?:span|div|p)[^>]*?>\\s*' + escaped + '\\s*[：:]?\\s*</(?:span|div|p)>\\s*<(?:span|div|p|a)[^>]*?>([^<]{1,300})</(?:span|div|p|a)>'
    let r2: string = this.extractOne(html, pat2, 1)
    if (r2.length > 0) { candidates.push(r2.trim()) }

    // 策略3: "导演：xxx" 纯文本格式
    let pat3: string = escaped + '\\s*[：:]\\s*([^<\\n]{1,300})'
    let r3: string = this.extractOne(html, pat3, 1)
    if (r3.length > 0) { candidates.push(r3.trim()) }

    // 策略4: 跨元素匹配
    let pat4: string = escaped + '[：:]?\\s*(?:</[^>]+>)?\\s*<[^>]+>\\s*([^<]{1,300})\\s*</[^>]+>'
    let r4: string = this.extractOne(html, pat4, 1)
    if (r4.length > 0) { candidates.push(r4.trim()) }

    // 策略5: 去HTML标签纯文本搜索
    let plainText: string = html.replace(/<[^>]*>/g, ' ').replace(/&[a-z]+;/gi, ' ')
    let pat5: string = escaped + '\\s*[：:]\\s*([^\\n]{1,300})'
    try {
      let re5: RegExp = new RegExp(pat5, 'i')
      let m5: RegExpMatchArray | null = plainText.match(re5)
      if (m5 !== null && m5[1] !== undefined) {
        let r5: string = this.stripHtml(m5[1]).trim()
        if (r5.length > 0) { candidates.push(r5) }
      }
    } catch (_e) { /* ignore */ }

    // 选第一个有效候选值（排除 "/"、单字符等无效值）
    for (let i = 0; i < candidates.length; i++) {
      let val: string = candidates[i]
      // 排除明显无效的值
      if (val === '/' || val === '-' || val === '：' || val === ':') { continue }
      if (val.length < 2) { continue }
      if (val === label) { continue }  // 值等于标签本身
      // 排除纯标点/空格
      if (/^[\s\/\-\|\.\,，。、；;：:]+$/.test(val)) { continue }
      return val
    }

    return ''
  }

  // ═══════════════════════════════════════════════════
  // 图片提取
  // ═══════════════════════════════════════════════════

  private extractImages(html: string): string[] {
    // 优先从内容区域提取
    let contentHtml: string = html
    let start: number = html.indexOf('module-items')
    if (start < 0) { start = html.indexOf('public-list-box') }
    if (start < 0) { start = html.indexOf('index-main') }
    if (start < 0) { start = html.indexOf('vodlist') }
    if (start >= 0) { contentHtml = html.substring(start) }

    let urls: string[] = []
    // data-src 优先
    let dsRe: RegExp = /<img[^>]*?data-src\s*=\s*"([^"]*)"/gi
    let m: RegExpExecArray | null = dsRe.exec(contentHtml)
    while (m !== null) {
      if (m[1] !== undefined && m[1].length > 5 && m[1].indexOf('data:') < 0) {
        urls.push(this.fixUrl(m[1].trim()))
      }
      m = dsRe.exec(contentHtml)
    }
    // data-original
    let doRe: RegExp = /<img[^>]*?data-original\s*=\s*"([^"]*)"/gi
    m = doRe.exec(contentHtml)
    while (m !== null) {
      if (m[1] !== undefined && m[1].length > 5 && m[1].indexOf('data:') < 0) {
        urls.push(this.fixUrl(m[1].trim()))
      }
      m = doRe.exec(contentHtml)
    }
    // src 兜底
    if (urls.length === 0) {
      let srcRe: RegExp = /<img[^>]*?src\s*=\s*"([^"]*)"/gi
      m = srcRe.exec(contentHtml)
      while (m !== null) {
        if (m[1] !== undefined && m[1].length > 5 && m[1].indexOf('data:') < 0) {
          urls.push(this.fixUrl(m[1].trim()))
        }
        m = srcRe.exec(contentHtml)
      }
    }
    return urls
  }

  // ── 详情页专用：精准提取海报图 ──
  private extractPosterImage(html: string): string {
    // 1. 在页面前 8000 字符内找
    let top: string = html.length > 8000 ? html.substring(0, 8000) : html

    // 策略1: DYXS2 video-pic / detail-pic 容器
    let divPatterns: string[] = [
      '<div[^>]*?class="[^"]*(?:video-pic|detail-pic|vod_img|poster)[^"]*"[^>]*?>[\\s\\S]*?<img[^>]*?(?:data-src|data-original|src)="([^"]*)"',
      '<(?:div|span|a)[^>]*?class="[^"]*(?:video-pic|detail-pic|vod_img|poster|thumb|pic)[^"]*"[^>]*?>[\\s\\S]*?<img[^>]*?(?:data-src|data-original|src)="([^"]*)"',
    ]
    for (let k = 0; k < divPatterns.length; k++) {
      let re: RegExp = new RegExp(divPatterns[k], 'i')
      let m: RegExpMatchArray | null = top.match(re)
      if (m !== null && m[1] !== undefined && m[1].length > 10 && m[1].indexOf('data:') < 0) {
        return this.fixUrl(m[1].trim())
      }
    }

    // 策略2: img 标签 class 含 pic/poster/cover/thumb/lazy
    let imgPatterns: string[] = [
      '<img[^>]*?class="[^"]*(?:pic|poster|cover|thumb|lazy)[^"]*"[^>]*?(?:data-src|data-original|src)="([^"]*)"',
      '<img[^>]*?(?:data-src|data-original|src)="([^"]*)"[^>]*?class="[^"]*(?:pic|poster|cover|thumb|lazy)[^"]*"',
    ]
    for (let k = 0; k < imgPatterns.length; k++) {
      let re: RegExp = new RegExp(imgPatterns[k], 'i')
      let m: RegExpMatchArray | null = top.match(re)
      if (m !== null && m[1] !== undefined && m[1].length > 10 && m[1].indexOf('data:') < 0) {
        return this.fixUrl(m[1].trim())
      }
    }

    // 策略3: 页面中所有 data-src 图片（排除 icon/logo）
    let allDsRe: RegExp = /<img[^>]*?data-src\s*=\s*"([^"]*\.(?:jpg|jpeg|png|webp)[^"]*)"/gi
    let dsM: RegExpExecArray | null = allDsRe.exec(top)
    while (dsM !== null) {
      if (dsM[1] !== undefined) {
        let u: string = dsM[1].trim()
        if (u.length > 10 && u.indexOf('icon') < 0 && u.indexOf('logo') < 0 && u.indexOf('loading') < 0) {
          return this.fixUrl(u)
        }
      }
      dsM = allDsRe.exec(top)
    }

    // 策略4: 回退 → 前 3 张图片的第一张
    let imgs: string[] = this.extractImages(top)
    if (imgs.length > 0) { return imgs[0] }

    return ''
  }

  // ═══════════════════════════════════════════════════
  // 云盘链接
  // ═══════════════════════════════════════════════════

  private extractShareUrls(html: string): string[] {
    let urls: string[] = []
    let seen: Set<string> = new Set()
    let patterns: string[] = [
      'data-clipboard-text="(https?://pan\\.quark\\.cn/[^"]+)"',
      '<p>\\s*(https?://pan\\.quark\\.cn/[^<\\s]+)\\s*</p>',
      'https?://pan\\.quark\\.cn/[a-zA-Z0-9/._-]+',
      'https?://www\\.aliyundrive\\.com/[a-zA-Z0-9/._-]+',
      'https?://drive\\.uc\\.cn/[a-zA-Z0-9/._-]+',
    ]
    for (let k = 0; k < patterns.length; k++) {
      let re: RegExp = new RegExp(patterns[k], 'gi')
      let m: RegExpExecArray | null = re.exec(html)
      while (m !== null) {
        let u: string = m[1] ?? m[0]
        if (u.length > 25 && !seen.has(u)) {
          seen.add(u)
          urls.push(u)
        }
        m = re.exec(html)
      }
    }
    return urls
  }

  // ═══════════════════════════════════════════════════
  // 工具
  // ═══════════════════════════════════════════════════

  private buildCategories(classes: VodClass[], vods: VodItem[]): CategoryWithVods[] {
    let result: CategoryWithVods[] = []
    for (let i = 0; i < classes.length; i++) {
      let cat: CategoryWithVods = {
        type_id: classes[i].type_id,
        type_name: classes[i].type_name,
        vods: i === 0 ? vods : []
      }
      result.push(cat)
    }
    if (result.length === 0 && vods.length > 0) {
      let cat: CategoryWithVods = { type_id: '0', type_name: '推荐', vods: vods }
      result.push(cat)
    }
    return result
  }

  private fixUrl(url: string): string {
    if (url.length === 0) { return '' }
    let fixed: string = url
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, '\'')
    if (fixed.startsWith('http://') || fixed.startsWith('https://')) {
      return fixed
    }
    if (fixed.startsWith('//')) {
      return 'https:' + fixed
    }
    if (fixed.startsWith('/')) {
      return this.baseUrl + fixed
    }
    return this.baseUrl + '/' + fixed
  }

  private stripHtml(raw: string): string {
    return raw.replace(/<[^>]*>/g, '').replace(/&[a-z]+;/g, ' ')
  }

  private buildUrl(template: string, id: string, pg: string, wd: string): string {
    let url: string = template
    url = url.replace(/\{cateId\}/g, id)
    url = url.replace(/\{vodId\}/g, id)
    url = url.replace(/\{page\}/g, pg)
    url = url.replace(/\{wd\}/g, encodeURIComponent(wd))
    return url
  }

  private isBlocked(html: string): boolean {
    return html.indexOf('cf_chl') >= 0 ||
      html.indexOf('Just a moment') >= 0 ||
      html.indexOf('challenges.cloudflare.com') >= 0 ||
      html.length < 200
  }

  // ═══ HTTP ═══

  private async doGet(path: string): Promise<string | null> {
    return await this.doGetWithTimeout(path, this.timeout)
  }

  private async doGetWithTimeout(path: string, timeout: number): Promise<string | null> {
    let url: string = path.startsWith('http') ? path : this.baseUrl + path
    let client: http.HttpRequest = http.createHttp()
    try {
      let resp: http.HttpResponse = await client.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: timeout,
        readTimeout: timeout,
        header: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9',
        }
      })
      if (resp.responseCode === 200 && typeof resp.result === 'string') {
        return resp.result
      }
      return null
    } catch (_err) {
      return null
    } finally {
      client.destroy()
    }
  }
}
