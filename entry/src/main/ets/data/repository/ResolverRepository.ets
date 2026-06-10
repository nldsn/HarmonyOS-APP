import { HttpClient } from '../http/HttpClient'
import {
  ResolverCategoryResult,
  ResolverDetailResult,
  ResolverHealthResult,
  ResolverInspectResult,
  ResolverPlayResult,
  ResolverSiteHomeResult,
  ResolverSitesResult,
  ResolverVodDetail
} from '../../common/model/ResolverModels'
import { PanCookieProfile } from '../../common/model/PanModels'

export class ResolverRepository {
  private httpClient: HttpClient

  constructor(httpClient: HttpClient) {
    this.httpClient = httpClient
  }

  async inspectSource(baseUrl: string, sourceUrl: string): Promise<ResolverInspectResult> {
    let endpoint = this.normalizeBaseUrl(baseUrl) + '/api/source/inspect'
    let body = '{"url":' + JSON.stringify(sourceUrl) + '}'
    let response = await this.httpClient.postJson(endpoint, body, 30000)
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error('Resolver 请求失败: ' + response.statusCode.toString() + ' ' + response.body)
    }
    let result = JSON.parse(response.body) as ResolverInspectResult
    if (!result.ok) {
      throw new Error(result.message)
    }
    return result
  }

  async checkHealth(baseUrl: string): Promise<ResolverHealthResult> {
    let endpoint = this.normalizeBaseUrl(baseUrl) + '/api/health'
    let response = await this.httpClient.getText(endpoint, 8000)
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error('Resolver 连通失败: ' + response.statusCode.toString() + ' ' + response.body)
    }
    let result = JSON.parse(response.body) as ResolverHealthResult
    if (!result.ok) {
      throw new Error('Resolver 服务未就绪')
    }
    return result
  }

  async getSites(baseUrl: string, sourceId: string): Promise<ResolverSitesResult> {
    let endpoint = this.normalizeBaseUrl(baseUrl) + '/api/source/' + encodeURIComponent(sourceId) + '/sites'
    let response = await this.httpClient.getText(endpoint, 60000)
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error('站点列表请求失败: ' + response.statusCode.toString() + ' ' + response.body)
    }
    let result = JSON.parse(response.body) as ResolverSitesResult
    if (!result.ok) {
      throw new Error('站点列表解析失败')
    }
    return result
  }

  async getSiteHome(baseUrl: string, sourceId: string, siteKey: string): Promise<ResolverSiteHomeResult> {
    let endpoint = this.siteEndpoint(baseUrl, sourceId, siteKey, 'home')
    let response = await this.httpClient.postJson(endpoint, '{}', 40000)
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error('站点首页请求失败: ' + response.statusCode.toString() + ' ' + response.body)
    }
    let result = JSON.parse(response.body) as ResolverSiteHomeResult
    if (!result.ok) {
      throw new Error('站点首页解析失败')
    }
    return result
  }

  async getCategory(baseUrl: string, sourceId: string, siteKey: string, typeId: string,
    page: number = 1): Promise<ResolverCategoryResult> {
    let endpoint = this.siteEndpoint(baseUrl, sourceId, siteKey, 'category')
    let body = '{"typeId":' + JSON.stringify(typeId) + ',"page":' + page.toString() + '}'
    let response = await this.httpClient.postJson(endpoint, body, 60000)
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error('分类内容请求失败: ' + response.statusCode.toString() + ' ' + response.body)
    }
    let result = JSON.parse(response.body) as ResolverCategoryResult
    if (!result.ok) {
      throw new Error('分类内容解析失败')
    }
    return result
  }

  async getDetail(baseUrl: string, sourceId: string, siteKey: string, vodId: string): Promise<ResolverVodDetail> {
    let endpoint = this.siteEndpoint(baseUrl, sourceId, siteKey, 'detail')
    let body = '{"vodId":' + JSON.stringify(vodId) + '}'
    let response = await this.httpClient.postJson(endpoint, body, 60000)
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error('详情请求失败: ' + response.statusCode.toString() + ' ' + response.body)
    }
    let result = JSON.parse(response.body) as ResolverDetailResult
    if (!result.ok) {
      throw new Error('详情解析失败')
    }
    let detail: ResolverVodDetail | undefined = result.item
    if (detail === undefined || detail === null) {
      throw new Error('详情数据为空，请重启 0.4.0 版本 resolver 服务')
    }
    return detail
  }

  async getPlay(baseUrl: string, sourceId: string, siteKey: string, flag: string,
    playId: string): Promise<ResolverPlayResult> {
    let endpoint = this.siteEndpoint(baseUrl, sourceId, siteKey, 'play')
    let body = '{"flag":' + JSON.stringify(flag) + ',"playId":' + JSON.stringify(playId) + '}'
    let response = await this.httpClient.postJson(endpoint, body, 60000)
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error('播放解析请求失败: ' + response.statusCode.toString() + ' ' + response.body)
    }
    let result = JSON.parse(response.body) as ResolverPlayResult
    if (!result.ok) {
      throw new Error('播放解析失败')
    }
    return result
  }

  async getProfile(baseUrl: string): Promise<PanCookieProfile> {
    let endpoint = this.normalizeBaseUrl(baseUrl) + '/api/profile'
    let response = await this.httpClient.getText(endpoint, 8000)
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error('账号配置同步失败: ' + response.statusCode.toString() + ' ' + response.body)
    }
    let result = JSON.parse(response.body) as PanCookieProfile
    if (!result.ok) {
      throw new Error(result.message)
    }
    return result
  }

  runtimeWebsiteUrl(baseUrl: string, sourceId: string): string {
    return this.normalizeBaseUrl(baseUrl) + '/api/source/' + encodeURIComponent(sourceId) + '/runtime/website'
  }

  runtimePathUrl(baseUrl: string, sourceId: string, runtimePath: string): string {
    let path: string = runtimePath.trim()
    if (path.length === 0) {
      path = '/website'
    }
    if (!path.startsWith('/')) {
      path = '/' + path
    }
    return this.normalizeBaseUrl(baseUrl) + '/api/source/' + encodeURIComponent(sourceId) + '/runtime' + path
  }

  private normalizeBaseUrl(baseUrl: string): string {
    let trimmed = baseUrl.trim()
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1)
    }
    return trimmed
  }

  private siteEndpoint(baseUrl: string, sourceId: string, siteKey: string, action: string): string {
    return this.normalizeBaseUrl(baseUrl) + '/api/source/' + encodeURIComponent(sourceId) +
      '/site/' + encodeURIComponent(siteKey) + '/' + action
  }
}
