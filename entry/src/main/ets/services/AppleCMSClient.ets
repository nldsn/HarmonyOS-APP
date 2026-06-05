import { http } from '@kit.NetworkKit'
import {
  VodItem,
  VodClass,
  VodDetail,
  AppleCMSDetail,
  CategoryWithVods,
  CategoryPageResult
} from '../models/SiteData'

/**
 * Apple CMS 协议客户端
 */
export class AppleCMSClient {
  private baseUrl: string
  private timeout: number

  constructor(baseUrl: string, timeout: number = 15000) {
    let url: string = baseUrl.replace(/\/+$/, '')
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://' + url
    }
    this.baseUrl = url
    this.timeout = timeout
  }

  async fetchHome(): Promise<CategoryWithVods[]> {
    const raw: Record<string, Object> | null =
      await this.doGet(`/api.php/provide/vod?ac=home`)
    if (raw === null) {
      throw new Error('无法连接站点')
    }

    const code: number = (raw['code'] as number) ?? -1
    if (code !== 1) {
      const msg: string = (raw['msg'] as string) ?? '站点返回错误'
      throw new Error(msg)
    }

    const rawClasses: Object[] = (raw['class'] as Object[]) ?? []
    const rawList: Object[] = (raw['list'] as Object[]) ?? []

    // 构建分类
    const classList: VodClass[] = []
    for (let i = 0; i < rawClasses.length; i++) {
      const c: Record<string, Object> = rawClasses[i] as Record<string, Object>
      const cls: VodClass = {
        type_id: (c['type_id'] as string) ?? '',
        type_name: (c['type_name'] as string) ?? ''
      }
      classList.push(cls)
    }

    // 构建视频列表 + 补全图片 URL
    const vodList: VodItem[] = []
    for (let i = 0; i < rawList.length; i++) {
      const v: Record<string, Object> = rawList[i] as Record<string, Object>
      const rawPic: string = (v['vod_pic'] as string) ?? ''
      const vod: VodItem = {
        vod_id: (v['vod_id'] as string) ?? '',
        vod_name: (v['vod_name'] as string) ?? '',
        vod_pic: this.makeAbsoluteUrl(rawPic),
        vod_remarks: (v['vod_remarks'] as string) ?? '',
        type_name: (v['type_name'] as string) ?? ''
      }
      vodList.push(vod)
    }

    return this.buildCategories(classList, vodList)
  }

  async fetchCategory(tid: string, pg: number): Promise<CategoryPageResult> {
    const raw: Record<string, Object> | null =
      await this.doGet(`/api.php/provide/vod?ac=list&t=${tid}&pg=${pg}`)
    if (raw === null) {
      throw new Error('无法获取分类列表')
    }

    const code: number = (raw['code'] as number) ?? -1
    if (code !== 1) {
      const msg: string = (raw['msg'] as string) ?? '获取分类列表失败'
      throw new Error(msg)
    }

    const rawList: Object[] = (raw['list'] as Object[]) ?? []
    const vodList: VodItem[] = []
    for (let i = 0; i < rawList.length; i++) {
      const v: Record<string, Object> = rawList[i] as Record<string, Object>
      const rawPic: string = (v['vod_pic'] as string) ?? ''
      const vod: VodItem = {
        vod_id: (v['vod_id'] as string) ?? '',
        vod_name: (v['vod_name'] as string) ?? '',
        vod_pic: this.makeAbsoluteUrl(rawPic),
        vod_remarks: (v['vod_remarks'] as string) ?? '',
        type_name: ''
      }
      vodList.push(vod)
    }

    const result: CategoryPageResult = {
      list: vodList,
      page: (raw['page'] as number) ?? pg,
      pagecount: (raw['pagecount'] as number) ?? 1,
      total: (raw['total'] as number) ?? 0
    }
    return result
  }

  async fetchDetail(ids: string): Promise<AppleCMSDetail | null> {
    const raw: Record<string, Object> | null =
      await this.doGet(`/api.php/provide/vod?ac=detail&ids=${ids}`)
    if (raw === null) {
      return null
    }

    const code: number = (raw['code'] as number) ?? -1
    if (code !== 1) {
      return null
    }

    const rawList: Object[] = (raw['list'] as Object[]) ?? []
    const vodList: VodDetail[] = []
    for (let i = 0; i < rawList.length; i++) {
      const v: Record<string, Object> = rawList[i] as Record<string, Object>
      const vod: VodDetail = {
        vod_id: (v['vod_id'] as string) ?? ids,
        vod_name: (v['vod_name'] as string) ?? '',
        vod_pic: this.makeAbsoluteUrl((v['vod_pic'] as string) ?? ''),
        vod_content: (v['vod_content'] as string) ?? (v['content'] as string) ?? '',
        vod_actor: (v['vod_actor'] as string) ?? (v['actor'] as string) ?? '',
        vod_director: (v['vod_director'] as string) ?? (v['director'] as string) ?? '',
        vod_year: (v['vod_year'] as string) ?? (v['year'] as string) ?? '',
        vod_area: (v['vod_area'] as string) ?? (v['area'] as string) ?? '',
        type_name: (v['type_name'] as string) ?? '',
        vod_remarks: (v['vod_remarks'] as string) ?? (v['remarks'] as string) ?? '',
        vod_play_from: (v['vod_play_from'] as string) ?? '',
        vod_play_url: (v['vod_play_url'] as string) ?? ''
      }
      vodList.push(vod)
    }
    const result: AppleCMSDetail = { code: 1, msg: '', list: vodList }
    return result
  }

  async search(wd: string): Promise<VodItem[]> {
    const raw: Record<string, Object> | null =
      await this.doGet(`/api.php/provide/vod?ac=detail&wd=${encodeURIComponent(wd)}`)
    if (raw === null) {
      return []
    }

    const code: number = (raw['code'] as number) ?? -1
    if (code !== 1) {
      return []
    }

    const rawList: Object[] = (raw['list'] as Object[]) ?? []
    const vodList: VodItem[] = []
    for (let i = 0; i < rawList.length; i++) {
      const v: Record<string, Object> = rawList[i] as Record<string, Object>
      const rawPic: string = (v['vod_pic'] as string) ?? ''
      const vod: VodItem = {
        vod_id: (v['vod_id'] as string) ?? '',
        vod_name: (v['vod_name'] as string) ?? '',
        vod_pic: this.makeAbsoluteUrl(rawPic),
        vod_remarks: (v['vod_remarks'] as string) ?? '',
        type_name: ''
      }
      vodList.push(vod)
    }
    return vodList
  }

  static async probeAppleCMS(baseUrl: string, timeout: number = 8000): Promise<boolean> {
    const url: string = `${baseUrl.replace(/\/+$/, '')}/api.php/provide/vod?ac=home`
    const client: http.HttpRequest = http.createHttp()

    try {
      const resp: http.HttpResponse = await client.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: timeout,
        readTimeout: timeout
      })

      if (resp.responseCode !== 200) {
        return false
      }

      const body: string | ArrayBuffer | Object = resp.result
      if (typeof body === 'string') {
        const data: Object = JSON.parse(body) as Object
        const dataRec: Record<string, Object> = data as Record<string, Object>
        return (dataRec['code'] as number) === 1
      }
      if (typeof body === 'object' && body !== null) {
        const dataRec: Record<string, Object> = body as Record<string, Object>
        return (dataRec['code'] as number) === 1
      }
      return false
    } catch (_err) {
      return false
    } finally {
      client.destroy()
    }
  }

  // ── 底层 HTTP ──

  private async doGet(path: string): Promise<Record<string, Object> | null> {
    const url: string = `${this.baseUrl}${path}`
    const client: http.HttpRequest = http.createHttp()

    try {
      const resp: http.HttpResponse = await client.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: this.timeout,
        readTimeout: this.timeout,
        header: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'application/json, text/plain, */*'
        }
      })

      if (resp.responseCode !== 200) {
        return null
      }

      const body: string | ArrayBuffer | Object = resp.result
      if (typeof body === 'string') {
        return JSON.parse(body) as Record<string, Object>
      }
      if (typeof body === 'object' && body !== null) {
        return body as Record<string, Object>
      }
      return null
    } catch (_err) {
      return null
    } finally {
      client.destroy()
    }
  }

  // ── 内部分类构建 ──
  // 所有分类都展示为 Tab；第一个分类承载首页推荐视频，其余按需加载

  private buildCategories(
    classList: VodClass[],
    vodList: VodItem[]
  ): CategoryWithVods[] {
    const result: CategoryWithVods[] = []

    // 所有分类都创建条目
    for (let i = 0; i < classList.length; i++) {
      const cls: VodClass = classList[i]
      const cat: CategoryWithVods = {
        type_id: cls.type_id,
        type_name: cls.type_name,
        vods: i === 0 ? vodList : []  // 第一个分类放首页视频，其余空（按需加载）
      }
      result.push(cat)
    }

    // 如果 API 没返回分类但返回了视频，创建"推荐"分类兜底
    if (result.length === 0 && vodList.length > 0) {
      const cat: CategoryWithVods = {
        type_id: '0',
        type_name: '推荐',
        vods: vodList
      }
      result.push(cat)
    }

    return result
  }

  // ── URL 补全 ──

  private makeAbsoluteUrl(url: string): string {
    if (url.length === 0) {
      return ''
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url
    }
    if (url.startsWith('//')) {
      return 'https:' + url
    }
    if (url.startsWith('/')) {
      return this.baseUrl + url
    }
    return this.baseUrl + '/' + url
  }
}
