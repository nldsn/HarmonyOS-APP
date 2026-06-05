/**
 * 站点数据模型 — TVBox 多仓配置 + Apple CMS 协议响应
 * ArkTS: Record<string, Object> 可用; 自定义索引签名不可用; 禁止内联对象类型
 */

// ── 分类 ────────────────────────────────────────
export interface VodClass {
  type_id: string
  type_name: string
}

// ── 单个视频条目 ────────────────────────────────
export interface VodItem {
  vod_id: string
  vod_name: string
  vod_pic: string
  vod_remarks: string
  type_name: string
}

// ── 视频详情 ────────────────────────────────────
export interface VodDetail {
  vod_id: string
  vod_name: string
  vod_pic: string
  vod_content: string
  vod_actor: string
  vod_director: string
  vod_year: string
  vod_area: string
  type_name: string
  vod_remarks: string
  vod_play_from: string
  vod_play_url: string
}

// ── Apple CMS 首页响应 ──────────────────────────
export interface AppleCMSHome {
  code: number
  msg: string
  class: VodClass[]
  list: VodItem[]
}

// ── Apple CMS 分类列表响应 ──────────────────────
export interface AppleCMSCategory {
  code: number
  msg: string
  page: number
  pagecount: number
  limit: number
  total: number
  list: VodItem[]
}

// ── 分类列表分页结果 ────────────────────────────
export interface CategoryPageResult {
  list: VodItem[]
  page: number
  pagecount: number
  total: number
}

// ── Apple CMS 详情响应 ──────────────────────────
export interface AppleCMSDetail {
  code: number
  msg: string
  list: VodDetail[]
}

// ── 首页展示用：带视频列表的分类 ────────────────
export interface CategoryWithVods {
  type_id: string
  type_name: string
  vods: VodItem[]
}

// ── 站点基础信息 ────────────────────────────────
export interface SiteInfo {
  key: string
  name: string
  type: number
  api: string
  searchable: number
  quickSearch: number
  filterable: number
  changeable: number
  ext?: string | Object
  timeout?: number
  style?: Object
}

// ── 站点运行时状态 ──────────────────────────────
export interface SiteRuntime {
  info: SiteInfo
  baseUrl: string
  categories: CategoryWithVods[]
  isLoading: boolean
  errorMsg: string
}

// ═══════════════════════════════════════════════════
// 处理器接口 — 所有站点处理器必须实现
// ═══════════════════════════════════════════════════
export interface ISiteHandler {
  readonly name: string
  readonly baseUrl: string

  fetchHome(): Promise<CategoryWithVods[]>
  fetchCategory(tid: string, page: number): Promise<CategoryPageResult>
  fetchDetail(vodId: string): Promise<VodDetail | null>
  search(keyword: string, page: number): Promise<VodItem[]>
}

// ── 站点配置（新架构） ────────────────────────────
export interface SiteFullConfig {
  key: string
  name: string
  baseUrl: string
  protocol: 'auto' | 'applecms' | 'html' | 'wexguard' | 'drpy' | 'bilibili' | 'live'
  scrapeRuleKey?: string
  timeout?: number
  headers?: Record<string, string>
  searchable: boolean
  filterable: boolean
  changeable: boolean
}

// ── 域名注册表条目 ────────────────────────────────
export interface DomainEntry {
  baseUrl: string
  cmsType: string           // 'applecms' | 'dyxs2-short' | 'dyxs2-php' | 'maccms' | 'generic' | ...
  ext?: string              // 原始 ext 数据
  verifiedAt?: string       // 最后验证时间
}

// ── 域名注册表 ────────────────────────────────────
export interface DomainRegistry {
  version: number
  updated: string
  entries: Record<string, DomainEntry>
}

