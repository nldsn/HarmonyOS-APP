/**
 * 站点数据仓库 — 所有 UI 层的唯一数据入口
 *
 * handler 缓存为静态 → HomePage 解析过的站点，DetailPage 直接复用，秒开。
 */

import { ISiteHandler, CategoryWithVods, CategoryPageResult, VodItem, VodDetail } from '../models/SiteData'
import { ProtocolRouter } from './ProtocolRouter'

export class SiteRepository {
  // ═══ 全局共享缓存（跨页面复用） ═══
  private static handlerCache: Map<string, ISiteHandler> = new Map()
  private static cachedBaseUrls: Map<string, string> = new Map()

  private currentKey: string = ''
  private handler: ISiteHandler | null = null

  /**
   * 切换站点 — 优先查缓存
   */
  async selectSite(key: string, baseUrl?: string): Promise<ISiteHandler | null> {
    // ① 全局缓存命中 → 秒开
    if (SiteRepository.handlerCache.has(key)) {
      this.currentKey = key
      this.handler = SiteRepository.handlerCache.get(key)!
      return this.handler
    }

    // ② 通过 ProtocolRouter 获取
    let handler: ISiteHandler | null = await ProtocolRouter.resolve(key, baseUrl)
    if (handler !== null) {
      this.currentKey = key
      this.handler = handler
      SiteRepository.handlerCache.set(key, handler)
      if (handler.baseUrl.length > 0) {
        SiteRepository.cachedBaseUrls.set(key, handler.baseUrl)
      }
    }
    return handler
  }

  /**
   * 跳过 selectSite，直接用已知 baseUrl 创建快速处理器（DetailPage 专用）
   */
  async quickResolve(key: string, baseUrl: string): Promise<boolean> {
    // 全局缓存命中
    if (SiteRepository.handlerCache.has(key)) {
      this.currentKey = key
      this.handler = SiteRepository.handlerCache.get(key)!
      return true
    }

    // 查注册表 → 直接创建 handler，不探测
    let handler: ISiteHandler | null = await ProtocolRouter.resolve(key, baseUrl)
    if (handler !== null) {
      this.currentKey = key
      this.handler = handler
      SiteRepository.handlerCache.set(key, handler)
      return true
    }
    return false
  }

  async fetchHome(): Promise<CategoryWithVods[]> {
    if (this.handler === null) { throw new Error('请先选择站点') }
    return await this.handler.fetchHome()
  }

  async fetchCategory(tid: string, page: number): Promise<CategoryPageResult> {
    if (this.handler === null) { throw new Error('请先选择站点') }
    return await this.handler.fetchCategory(tid, page)
  }

  async fetchDetail(vodId: string): Promise<VodDetail | null> {
    if (this.handler === null) { throw new Error('请先选择站点') }
    return await this.handler.fetchDetail(vodId)
  }

  async search(keyword: string, page: number): Promise<VodItem[]> {
    if (this.handler === null) { throw new Error('请先选择站点') }
    return await this.handler.search(keyword, page)
  }

  getBaseUrl(): string {
    return this.handler !== null ? this.handler.baseUrl : ''
  }

  getHandlerName(): string {
    return this.handler !== null ? this.handler.name : ''
  }

  getCurrentKey(): string {
    return this.currentKey
  }

  isReady(): boolean {
    return this.handler !== null
  }

  release(): void {
    this.handler = null
    this.currentKey = ''
  }

  static clearAllCache(): void {
    SiteRepository.handlerCache.clear()
    SiteRepository.cachedBaseUrls.clear()
  }
}
