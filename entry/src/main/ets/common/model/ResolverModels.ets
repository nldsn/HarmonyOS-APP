import { SiteSimple } from './SourceModels'

export interface ResolverFeatureInfo {
  hasWebsiteBundle: boolean
  hasModuleExports: boolean
  hasWindowAccess: boolean
  hasServerFactory: boolean
  hasFullConfigRoute: boolean
  hasSitesListRoute: boolean
  defaultPort: number
}

export interface ResolverInspectResult {
  ok: boolean
  sourceId: string
  protocol: string
  md5: string
  scriptUrl: string
  scriptSize: number
  runtime: string
  message: string
  features: ResolverFeatureInfo
  sites: SiteSimple[]
}

export interface ResolverHealthResult {
  ok: boolean
  service: string
  version?: string
  runtime: string
  sources: number
}

export interface ResolverSitesResult {
  ok: boolean
  sourceId: string
  runtimeUrl: string
  sites: SiteSimple[]
}

export interface ResolverCategoryItem {
  typeId: string
  typeName: string
}

export interface ResolverVodItem {
  vodId: string
  vodName: string
  vodPic: string
  vodRemarks: string
}

export interface SiteSearchResult {
  siteKey: string
  siteName: string
  items: ResolverVodItem[]
  isLoading: boolean
  errorMsg: string
}

export interface ResolverSiteHomeResult {
  ok: boolean
  sourceId: string
  siteKey: string
  categories: ResolverCategoryItem[]
}

export interface ResolverCategoryResult {
  ok: boolean
  sourceId: string
  siteKey: string
  typeId: string
  page: number
  pageCount: number
  items: ResolverVodItem[]
}

export interface ResolverEpisode {
  title: string
  url: string
  flag: string
  size: number
  pic?: string
  fileName?: string
  fileExt?: string
  panType?: string
  shareId?: string
  fileId?: string
  fileToken?: string
  stoken?: string
}

export interface ResolverPlaySource {
  name: string
  flag: string
  episodes: ResolverEpisode[]
}

export interface ResolverVodDetail {
  vodId: string
  vodName: string
  vodPic: string
  typeName: string
  vodYear: string
  vodArea: string
  vodRemarks: string
  vodDirector: string
  vodActor: string
  vodContent: string
  playSources: ResolverPlaySource[]
}

export interface ResolverDetailResult {
  ok: boolean
  sourceId: string
  siteKey: string
  item?: ResolverVodDetail
}

export interface ResolverPlayResult {
  ok: boolean
  sourceId: string
  siteKey: string
  flag: string
  playId: string
  url: string
  parse: number
  playable: boolean
  headersJson: string
  cover?: string
  rawJson?: string
  message: string
}

export class ResolverDefaults {
  static readonly BASE_URL: string = 'http://192.168.0.166:8787'
}
