/**
 * 协议路由 — 自动探测站点协议类型，路由到正确的处理器
 *
 * 探测链路（按顺序）:
 *   1. DomainRegistry 查表 — 已知的直接返回
 *   2. Apple CMS JSON API 探测 — /api.php/provide/vod?ac=home
 *   3. HTML 指纹匹配 — 拉取首页 HTML，匹配 ScrapeRuleSet.fingerprints
 *   4. 通用兜底 — 通用 CSS 规则抓取
 *
 * 探测结果会被缓存到本地 DomainRegistry，下次直接命中。
 */

import { http } from '@kit.NetworkKit'
import { ISiteHandler, DomainEntry, DomainRegistry, CategoryWithVods, CategoryPageResult, VodItem, VodDetail } from '../models/SiteData'
import { ScrapeRuleSet, BUILTIN_SCRAPE_RULES, createScrapeRule } from '../models/SiteRule'
import { AppleCMSClient } from './AppleCMSClient'
import { HtmlScraperV2 } from './HtmlScraperV2'
import { DataNormalizer } from './DataNormalizer'

// ═══════════════════════════════════════════════════
// AppleCMSHandler — 适配器，将 AppleCMSClient 包装为 ISiteHandler
// ═══════════════════════════════════════════════════

class AppleCMSHandlerAdapter implements ISiteHandler {
  readonly name: string = 'AppleCMS'
  readonly baseUrl: string
  private client: AppleCMSClient

  constructor(baseUrl: string, timeout: number = 15000) {
    this.baseUrl = baseUrl
    this.client = new AppleCMSClient(baseUrl, timeout)
  }

  async fetchHome(): Promise<CategoryWithVods[]> {
    return await this.client.fetchHome()
  }

  async fetchCategory(tid: string, page: number): Promise<CategoryPageResult> {
    return await this.client.fetchCategory(tid, page)
  }

  async fetchDetail(vodId: string): Promise<VodDetail | null> {
    let result = await this.client.fetchDetail(vodId)
    if (result === null) {
      return null
    }
    return result.list.length > 0 ? result.list[0] : null
  }

  async search(keyword: string, _page: number): Promise<VodItem[]> {
    return await this.client.search(keyword)
  }
}

// ═══════════════════════════════════════════════════
// ProtocolRouter
// ═══════════════════════════════════════════════════

export class ProtocolRouter {

  // ── 内置域名注册表（从社区数据 + 抓取分析积累）──
  private static registry: DomainRegistry = {
    version: 1,
    updated: '2026-06-05',
    entries: {
      // ── 4K 类（直接域名 - key 必须与 data.json 完全一致）──
      '玩偶':    { baseUrl: 'https://www.wogg.net',        cmsType: 'dyxs2-short' },
      'NewMuOu': { baseUrl: 'https://666.666291.xyz',      cmsType: 'dyxs2-php' },
      '雷鲸':    { baseUrl: 'https://www.leijing1.com',    cmsType: 'dyxs2-php' },
      '新6V':   { baseUrl: 'https://www.xb6v.com',         cmsType: 'dyxs2-short' },
      // ── 4K 类（待补充域名）──
      '二小':    { baseUrl: '',                             cmsType: 'html' },
      'NewZhiZhen':{ baseUrl: '',                           cmsType: 'html' },
      'NewGuanYing':{ baseUrl: '',                          cmsType: 'html' },
      'NewJuTou': { baseUrl: '',                            cmsType: 'html' },
      'NewHuBan': { baseUrl: '',                            cmsType: 'html' },
      'NewShaYang':{ baseUrl: '',                           cmsType: 'html' },
      'NewDuoDuo':{ baseUrl: '',                            cmsType: 'html' },
      '原盘':    { baseUrl: '',                             cmsType: 'html' },
      'NewPanMe123':{ baseUrl: '',                          cmsType: 'html' },
      '盘他':    { baseUrl: '',                             cmsType: 'html' },
      'WexBoBo':{ baseUrl: 'https://api.nivodz.com',       cmsType: 'maccms' },
      'WexBtTwo':{ baseUrl: 'https://api.nivodz.com',      cmsType: 'maccms' },
      'WexWenCai':{ baseUrl: 'http://cj.ffzyapi.com',      cmsType: 'maccms' },
      'WexReBo': { baseUrl: 'http://cj.ffzyapi.com',       cmsType: 'maccms' },
      'WexYiYs': { baseUrl: 'https://cj.lzcaiji.com',      cmsType: 'maccms' },
      'WexDuBoKu':{ baseUrl: 'http://v.rbotv.cn',          cmsType: 'maccms' },
      'WexYueYue':{ baseUrl: 'https://api.nivodz.com',     cmsType: 'maccms' },
      'WexGuaZi':{ baseUrl: 'https://api.nivodz.com',      cmsType: 'maccms' },
      'WexIkanBot':{ baseUrl: 'https://v.ikanbot.com',     cmsType: 'maccms' },
      'WexHanXiaoQuan':{ baseUrl: 'https://api.nivodz.com',cmsType: 'maccms' },
      '賤賤':   { baseUrl: 'http://api2.rinhome.com',      cmsType: 'maccms' },
      // ── 豆瓣/配置类 ──
      'NewDouBan':{ baseUrl: '',                            cmsType: 'wexguard' },
      'Doubana':  { baseUrl: '',                            cmsType: 'wexguard' },
      'Wexconfig':{ baseUrl: '',                            cmsType: 'wexguard' },
      // ── B站类 ──
      'bilibili': { baseUrl: 'https://www.bilibili.com',    cmsType: 'bilibili' },
      'bilibiliys':{ baseUrl: 'https://www.bilibili.com',   cmsType: 'bilibili' },
      'bilixiqu': { baseUrl: 'https://www.bilibili.com',    cmsType: 'bilibili' },
      'biliych':  { baseUrl: 'https://www.bilibili.com',    cmsType: 'bilibili' },
      // ── 直播类 ──
      'LiveHuYa': { baseUrl: 'https://www.huya.com',        cmsType: 'live' },
      'LiveDouYu':{ baseUrl: 'https://www.douyu.com',       cmsType: 'live' },
      'LiveBiLi': { baseUrl: 'https://live.bilibili.com',   cmsType: 'live' },
      // ── 动漫类 ──
      'AnimeXiFan':{ baseUrl: 'https://www.mxdm4.com',     cmsType: 'maccms' },
      'AnimeMoDu': { baseUrl: '',                            cmsType: 'html' },
      'AnimeGiriGiri':{ baseUrl: '',                         cmsType: 'html' },
      'AnimeFanShu':{ baseUrl: '',                           cmsType: 'html' },
      // ── 云盘/我的 ──
      'MyQuark':  { baseUrl: '',                             cmsType: 'wexguard' },
      'MyBaiDu':  { baseUrl: '',                             cmsType: 'wexguard' },
      'MyUcPan':  { baseUrl: '',                             cmsType: 'wexguard' },
      'MyGuangYa':{ baseUrl: '',                             cmsType: 'wexguard' },
      'MyPan189': { baseUrl: '',                             cmsType: 'wexguard' },
      'MyPan115': { baseUrl: '',                             cmsType: 'wexguard' },
      'MyPan123': { baseUrl: '',                             cmsType: 'wexguard' },
      // ── 搜索聚合 ──
      'SoTySo':   { baseUrl: '',                             cmsType: 'wexguard' },
      'SoBaiDuSo':{ baseUrl: '',                             cmsType: 'wexguard' },
      'SoHaiYin': { baseUrl: '',                             cmsType: 'wexguard' },
      'SoTjSo':   { baseUrl: '',                             cmsType: 'wexguard' },
      'SoAiPan':  { baseUrl: '',                             cmsType: 'wexguard' },
      'So97So':   { baseUrl: '',                             cmsType: 'wexguard' },
      'SoZhaoPanSo':{ baseUrl: '',                           cmsType: 'wexguard' },
      // ── 音乐/戏曲 ──
      'Music163': { baseUrl: '',                             cmsType: 'wexguard' },
      'MusicKuWo':{ baseUrl: '',                             cmsType: 'wexguard' },
      'MusicLunHui':{ baseUrl: '',                           cmsType: 'wexguard' },
      'MusicLiYuan':{ baseUrl: '',                           cmsType: 'wexguard' },
      'MusicQingTing':{ baseUrl: '',                         cmsType: 'wexguard' },
      'MusicIKtv':{ baseUrl: '',                             cmsType: 'wexguard' },
      // ── 其他 ──
      'WexTangDou':{ baseUrl: '',                            cmsType: 'wexguard' },
      'push_agent':{ baseUrl: '',                            cmsType: 'wexguard' },
      'emby':     { baseUrl: '',                             cmsType: 'html' },
      'AList':    { baseUrl: '',                             cmsType: 'html' },
      'webdav':   { baseUrl: '',                             cmsType: 'html' },
    }
  }

  /**
   * 为指定站点创建处理器
   * @param key  站点 key
   * @param baseUrl  已知的 baseUrl（可选，优先于注册表）
   * @param customExt  站点的 ext 字段（可选，优先于注册表）
   */
  static async resolve(key: string, baseUrl?: string): Promise<ISiteHandler | null> {
    // ① 检查注册表
    let entry: DomainEntry | undefined = ProtocolRouter.registry.entries[key]
    let effectiveUrl: string = baseUrl ?? entry?.baseUrl ?? ''

    // 如果注册表中标记为 wexguard（需要代理），返回 null
    if (entry !== undefined && entry.cmsType === 'wexguard') {
      return null
    }

    // ② 如果有 baseUrl，尝试直接创建处理器
    if (effectiveUrl.length > 0 && entry !== undefined) {
      return ProtocolRouter.createHandler(entry.cmsType, effectiveUrl)
    }

    // ③ 没有 baseUrl — 无法处理
    if (effectiveUrl.length === 0) {
      return null
    }

    // ④ 自动探测
    return await ProtocolRouter.autoDetect(effectiveUrl, key)
  }

  /**
   * 自动探测站点的最佳处理器
   */
  static async autoDetect(baseUrl: string, key: string): Promise<ISiteHandler | null> {
    let url: string = baseUrl.replace(/\/+$/, '')

    // ── 探测 1: Apple CMS JSON API ──
    let isAppleCms: boolean = await AppleCMSClient.probeAppleCMS(url, 3000)
    if (isAppleCms) {
      ProtocolRouter.cacheDomain(key, url, 'applecms')
      return new AppleCMSHandlerAdapter(url)
    }

    // ── 探测 2: HTML 指纹匹配 ──
    let html: string | null = await ProtocolRouter.fetchHtml(url, 10000)
    if (html !== null && html.length > 200) {
      // 按优先级匹配规则
      let ruleKeys: string[] = ['dyxs2-php', 'dyxs2-short', 'maccms', 'generic']
      for (let i = 0; i < ruleKeys.length; i++) {
        let rule: ScrapeRuleSet | undefined = BUILTIN_SCRAPE_RULES[ruleKeys[i]]
        if (rule !== undefined && HtmlScraperV2.matchFingerprint(html, rule)) {
          ProtocolRouter.cacheDomain(key, url, ruleKeys[i])
          let clonedRule: ScrapeRuleSet = createScrapeRule(ruleKeys[i], url)
          return new HtmlScraperV2(clonedRule, url)
        }
      }

      // ── 探测 3: 通用兜底 ──
      ProtocolRouter.cacheDomain(key, url, 'generic')
      let genericRule: ScrapeRuleSet = createScrapeRule('generic', url)
      return new HtmlScraperV2(genericRule, url)
    }

    return null
  }

  /**
   * 根据 CMS 类型创建处理器
   */
  static createHandler(cmsType: string, baseUrl: string): ISiteHandler {
    let url: string = baseUrl.replace(/\/+$/, '')

    if (cmsType === 'applecms') {
      return new AppleCMSHandlerAdapter(url)
    }

    // 查找匹配的爬取规则
    let rule: ScrapeRuleSet | undefined = BUILTIN_SCRAPE_RULES[cmsType]
    if (rule !== undefined) {
      let clonedRule: ScrapeRuleSet = createScrapeRule(cmsType, url)
      return new HtmlScraperV2(clonedRule, url)
    }

    // fallback
    let genericRule: ScrapeRuleSet = createScrapeRule('generic', url)
    return new HtmlScraperV2(genericRule, url)
  }

  /**
   * 缓存域名到注册表（内存中，App 重启后失效）
   */
  static cacheDomain(key: string, baseUrl: string, cmsType: string): void {
    ProtocolRouter.registry.entries[key] = {
      baseUrl: baseUrl,
      cmsType: cmsType,
      verifiedAt: new Date().toISOString()
    }
  }

  /**
   * 获取注册表中的条目
   */
  static getDomainEntry(key: string): DomainEntry | undefined {
    return ProtocolRouter.registry.entries[key]
  }

  /**
   * 注册表是否有此 key
   */
  static hasKey(key: string): boolean {
    let entry: DomainEntry | undefined = ProtocolRouter.registry.entries[key]
    return entry !== undefined && entry.baseUrl.length > 0
  }

  /**
   * 更新注册表（从远程 JSON 合并）
   */
  static mergeRegistry(remote: DomainRegistry): void {
    if (remote.version <= ProtocolRouter.registry.version) {
      return
    }
    let remoteKeys: string[] = Object.keys(remote.entries)
    for (let i = 0; i < remoteKeys.length; i++) {
      let k: string = remoteKeys[i]
      ProtocolRouter.registry.entries[k] = remote.entries[k]
    }
    ProtocolRouter.registry.version = remote.version
    ProtocolRouter.registry.updated = remote.updated
  }

  /**
   * 拉取远程注册表
   */
  static async fetchRemoteRegistry(remoteUrl: string): Promise<boolean> {
    let client: http.HttpRequest = http.createHttp()
    try {
      let resp: http.HttpResponse = await client.request(remoteUrl, {
        method: http.RequestMethod.GET,
        connectTimeout: 10000,
        readTimeout: 10000,
      })
      if (resp.responseCode === 200 && typeof resp.result === 'string') {
        let parsed: Record<string, Object> | null = DataNormalizer.safeParseJson(resp.result)
        if (parsed !== null) {
          let remote: DomainRegistry = {
            version: (parsed['version'] as number) ?? 0,
            updated: (parsed['updated'] as string) ?? '',
            entries: (parsed['entries'] as Record<string, DomainEntry>) ?? {}
          }
          ProtocolRouter.mergeRegistry(remote)
          return true
        }
      }
      return false
    } catch (_err) {
      return false
    } finally {
      client.destroy()
    }
  }

  // ═══ 内部 HTTP ═══

  private static async fetchHtml(url: string, timeout: number): Promise<string | null> {
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
