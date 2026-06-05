/**
 * 数据规范化器 — 整个系统的数据质量核心
 *
 * 职责：
 *   1. 字段名智能映射 — 不同站点用不同字段名（如 content vs vod_content）
 *   2. URL 补全 — 相对路径 → 绝对路径
 *   3. HTML 标签清洗 — 去除残留的 HTML 标签
 *   4. 空值优雅降级 — 缺字段时返回空字符串而非 undefined
 */

import { VodItem, VodDetail, VodClass, CategoryWithVods, CategoryPageResult } from '../models/SiteData'

// ═══════════════════════════════════════════════════════════
// 字段别名表 — 用类封装（ArkTS 不允许裸 Record 字面量）
// ═══════════════════════════════════════════════════════════

class FieldAliasTable {
  private static data: Map<string, string[]> = new Map()

  static init(): void {
    if (FieldAliasTable.data.size > 0) { return }
    FieldAliasTable.data.set('vod_id',        ['vod_id', 'id', 'vodid', 'video_id', 'vid', 'vodId'])
    FieldAliasTable.data.set('vod_name',      ['vod_name', 'name', 'title', 'vod_title', 'video_name', 'film_name', 'vodName'])
    FieldAliasTable.data.set('vod_pic',       ['vod_pic', 'pic', 'poster', 'cover', 'image', 'thumb', 'img', 'vodPic', 'thumbnail'])
    FieldAliasTable.data.set('vod_remarks',   ['vod_remarks', 'remarks', 'note', 'update_info', 'tips', 'vodRemarks', 'vod_rem'])
    FieldAliasTable.data.set('vod_content',   ['vod_content', 'content', 'description', 'desc', 'vod_desc', 'intro', 'vodContent'])
    FieldAliasTable.data.set('vod_actor',     ['vod_actor', 'actor', 'starring', 'actors', 'performer', 'star', 'vodActor'])
    FieldAliasTable.data.set('vod_director',  ['vod_director', 'director', 'vod_director', 'directors', 'vodDirector'])
    FieldAliasTable.data.set('vod_year',      ['vod_year', 'year', 'pubdate', 'release_date', 'vodYear'])
    FieldAliasTable.data.set('vod_area',      ['vod_area', 'area', 'region', 'country', 'vodArea'])
    FieldAliasTable.data.set('vod_play_from', ['vod_play_from', 'play_from', 'source', 'vodPlayFrom', 'play_list', 'playFrom'])
    FieldAliasTable.data.set('vod_play_url',  ['vod_play_url', 'play_url', 'urls', 'vodPlayUrl', 'episodes', 'playUrl'])
    FieldAliasTable.data.set('type_name',     ['type_name', 'type', 'category', 'genre', 'class_name', 'typeName'])
    FieldAliasTable.data.set('type_id',       ['type_id', 'typeId', 'tid', 'category_id', 'cate_id', 'class_id'])
  }

  static getAliases(target: string): string[] {
    FieldAliasTable.init()
    let result: string[] | undefined = FieldAliasTable.data.get(target)
    if (result !== undefined) {
      return result
    }
    return []
  }
}

// 噪音名称
const NOISE_NAMES: string[] = ['玩偶哥哥', '网盘资源', '资源分享', '首页', '全部影片', '最新更新', '推荐视频']

// ═══════════════════════════════════════════════════════════
// 公开 API
// ═══════════════════════════════════════════════════════════

export class DataNormalizer {

  // ── 标准化单个 VodItem ──────────────────────────
  static vodItem(raw: Record<string, Object>, baseUrl: string): VodItem {
    let item: VodItem = {
      vod_id: DataNormalizer.pickField(raw, 'vod_id', ''),
      vod_name: DataNormalizer.stripHtml(DataNormalizer.pickField(raw, 'vod_name', '未知')),
      vod_pic: DataNormalizer.completeUrl(DataNormalizer.pickField(raw, 'vod_pic', ''), baseUrl),
      vod_remarks: DataNormalizer.stripHtml(DataNormalizer.pickField(raw, 'vod_remarks', '')),
      type_name: DataNormalizer.stripHtml(DataNormalizer.pickField(raw, 'type_name', '')),
    }
    return item
  }

  // ── 标准化 VodItem 列表 ────────────────────────
  static vodList(rawList: Object[], baseUrl: string): VodItem[] {
    let result: VodItem[] = []
    let seen: Set<string> = new Set()
    for (let i = 0; i < rawList.length; i++) {
      let item: VodItem = DataNormalizer.vodItem(rawList[i] as Record<string, Object>, baseUrl)
      if (item.vod_id.length === 0 || seen.has(item.vod_id)) {
        continue
      }
      if (DataNormalizer.isNoise(item.vod_name)) {
        continue
      }
      seen.add(item.vod_id)
      result.push(item)
    }
    return result
  }

  // ── 标准化 VodDetail ───────────────────────────
  static vodDetail(raw: Record<string, Object>, baseUrl: string, vodIdFallback: string): VodDetail {
    let detail: VodDetail = {
      vod_id: DataNormalizer.pickField(raw, 'vod_id', vodIdFallback),
      vod_name: DataNormalizer.stripHtml(DataNormalizer.pickField(raw, 'vod_name', '')),
      vod_pic: DataNormalizer.completeUrl(DataNormalizer.pickField(raw, 'vod_pic', ''), baseUrl),
      vod_content: DataNormalizer.pickField(raw, 'vod_content', ''),
      vod_actor: DataNormalizer.pickField(raw, 'vod_actor', ''),
      vod_director: DataNormalizer.pickField(raw, 'vod_director', ''),
      vod_year: DataNormalizer.pickField(raw, 'vod_year', ''),
      vod_area: DataNormalizer.pickField(raw, 'vod_area', ''),
      type_name: DataNormalizer.stripHtml(DataNormalizer.pickField(raw, 'type_name', '')),
      vod_remarks: DataNormalizer.pickField(raw, 'vod_remarks', ''),
      vod_play_from: DataNormalizer.pickField(raw, 'vod_play_from', ''),
      vod_play_url: DataNormalizer.pickField(raw, 'vod_play_url', ''),
    }
    return detail
  }

  // ── 标准化分类 ─────────────────────────────────
  static vodClass(raw: Record<string, Object>): VodClass {
    let cls: VodClass = {
      type_id: DataNormalizer.pickField(raw, 'type_id', '0'),
      type_name: DataNormalizer.stripHtml(DataNormalizer.pickField(raw, 'type_name', '未知')),
    }
    return cls
  }

  static vodClassList(rawList: Object[]): VodClass[] {
    let result: VodClass[] = []
    let seen: Set<string> = new Set()
    for (let i = 0; i < rawList.length; i++) {
      let cls: VodClass = DataNormalizer.vodClass(rawList[i] as Record<string, Object>)
      if (cls.type_name.length === 0 || cls.type_name === '首页' || seen.has(cls.type_id)) {
        continue
      }
      seen.add(cls.type_id)
      result.push(cls)
    }
    return result
  }

  // ── 构建分类+视频首页数据 ──────────────────────
  static buildCategoryWithVods(
    rawClasses: Object[],
    rawVods: Object[],
    classListFirst: boolean,
    baseUrl: string
  ): CategoryWithVods[] {
    let classes: VodClass[] = DataNormalizer.vodClassList(rawClasses)
    let vods: VodItem[] = DataNormalizer.vodList(rawVods, baseUrl)
    let result: CategoryWithVods[] = []

    if (classes.length > 0) {
      for (let i = 0; i < classes.length; i++) {
        let cat: CategoryWithVods = {
          type_id: classes[i].type_id,
          type_name: classes[i].type_name,
          vods: i === 0 ? vods : []
        }
        result.push(cat)
      }
    } else if (vods.length > 0) {
      let cat: CategoryWithVods = { type_id: '0', type_name: '推荐', vods: vods }
      result.push(cat)
    }

    return result
  }

  // ── 标准化分页结果 ─────────────────────────────
  static categoryPageResult(raw: Record<string, Object>, baseUrl: string, pg: number): CategoryPageResult {
    let rawList: Object[] = (raw['list'] as Object[]) ?? []
    let list: VodItem[] = DataNormalizer.vodList(rawList, baseUrl)
    let pageObj: Object | undefined = raw['page']
    let page: number = (typeof pageObj === 'number') ? (pageObj as number) : pg
    let pcObj: Object | undefined = raw['pagecount']
    let pagecount: number = (typeof pcObj === 'number') ? (pcObj as number) : 1
    let totObj: Object | undefined = raw['total']
    let total: number = (typeof totObj === 'number') ? (totObj as number) : list.length
    let result: CategoryPageResult = { list: list, page: page, pagecount: pagecount, total: total }
    return result
  }

  // ═══════════════════════════════════════════════
  // 内部工具方法
  // ═══════════════════════════════════════════════

  /**
   * 智能字段提取：遍历别名列表，返回第一个在 raw 中存在的值
   */
  static pickField(raw: Record<string, Object>, target: string, fallback: string): string {
    let aliases: string[] = FieldAliasTable.getAliases(target)
    if (aliases.length === 0) {
      let val: Object | undefined = raw[target]
      if (val !== undefined) {
        return String(val)
      }
      return fallback
    }
    for (let i = 0; i < aliases.length; i++) {
      let alias: string = aliases[i]
      let val: Object | undefined = raw[alias]
      if (val !== undefined) {
        let str: string = String(val).trim()
        if (str.length > 0 && str !== 'null' && str !== 'undefined') {
          return str
        }
      }
    }
    return fallback
  }

  /**
   * URL 补全：相对路径 → 绝对路径
   */
  static completeUrl(rawUrl: string, baseUrl: string): string {
    if (rawUrl.length === 0) {
      return ''
    }
    let url: string = rawUrl
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, '\'')
      .trim()

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url
    }
    if (url.startsWith('//')) {
      return 'https:' + url
    }

    let base: string = baseUrl.replace(/\/+$/, '')

    if (url.startsWith('/')) {
      return base + url
    }
    return base + '/' + url
  }

  /**
   * 去除 HTML 标签
   */
  static stripHtml(raw: string): string {
    return raw
      .replace(/<[^>]*>/g, '')
      .replace(/&[a-z]+;/gi, ' ')
      .replace(/&nbsp;/gi, ' ')
      .replace(/\s+/g, ' ')
      .trim()
  }

  /**
   * 判断是否为噪音条目
   */
  static isNoise(name: string): boolean {
    for (let i = 0; i < NOISE_NAMES.length; i++) {
      if (name.indexOf(NOISE_NAMES[i]) >= 0) {
        return true
      }
    }
    if (/^\d+$/.test(name) && name.length > 10) {
      return true
    }
    return false
  }

  /**
   * JSON 安全解析
   */
  static safeParseJson(body: string | Object): Record<string, Object> | null {
    if (typeof body === 'object') {
      return body as Record<string, Object>
    }
    if (typeof body === 'string') {
      try {
        return JSON.parse(body as string) as Record<string, Object>
      } catch (_e) {
        return null
      }
    }
    return null
  }
}
