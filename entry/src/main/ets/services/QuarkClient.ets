import { http } from '@kit.NetworkKit'

export interface EpisodeInfo {
  title: string
  url: string
  size: number
}

interface QuarkFileItem {
  fid: string
  file_name: string
  pdir_fid: string
  category: number       // 0=folder, 1=video, others
  file_type: number
  size: number
  format_type: string
  dir: boolean
  include_items: number
  share_fid_token: string
  preview_url: string
  thumbnail: string
  video_max_resolution: string
}

interface QuarkDetailData {
  list: QuarkFileItem[]
  metadata: Record<string, Object>
}

export class QuarkClient {
  private timeout: number

  constructor(timeout: number = 15000) {
    this.timeout = timeout
  }

  /**
   * 从夸克分享链接获取所有视频文件（剧集）
   * 支持文件夹嵌套（自动递归进入文件夹）
   * @param shareUrl 如 https://pan.quark.cn/s/2a2031c3f9a1
   */
  async getEpisodes(shareUrl: string): Promise<EpisodeInfo[]> {
    // 1. 解析 pwd_id
    let pwdId: string = this.extractPwdId(shareUrl)
    if (pwdId.length === 0) {
      return []
    }

    // 2. 获取 stoken
    let stoken: string = await this.getStoken(pwdId)
    if (stoken.length === 0) {
      return []
    }

    // 3. 递归获取所有视频文件（从根目录开始，支持文件夹）
    let allFiles: QuarkFileItem[] = await this.fetchAllVideoFiles(pwdId, stoken, '0')

    // 4. 文件名自然排序（按数字提取排序）
    allFiles.sort((a: QuarkFileItem, b: QuarkFileItem) => {
      return this.extractEpisodeNum(a.file_name) - this.extractEpisodeNum(b.file_name)
    })

    // 5. 生成剧集信息
    let episodes: EpisodeInfo[] = []
    for (let i = 0; i < allFiles.length; i++) {
      let f: QuarkFileItem = allFiles[i]
      let ep: EpisodeInfo = {
        title: f.file_name,
        url: f.preview_url.length > 0 ? f.preview_url : shareUrl,
        size: f.size
      }
      episodes.push(ep)
    }

    // 如果没有任何视频，尝试列出所有文件
    if (episodes.length === 0) {
      let allItems: QuarkFileItem[] = await this.fetchAllItems(pwdId, stoken, '0')
      for (let i = 0; i < allItems.length; i++) {
        let f: QuarkFileItem = allItems[i]
        if (!f.dir) {
          let ep: EpisodeInfo = {
            title: f.file_name,
            url: f.preview_url.length > 0 ? f.preview_url : shareUrl,
            size: f.size
          }
          episodes.push(ep)
        }
      }
    }

    return episodes
  }

  // ── 递归获取所有视频文件 ──

  private async fetchAllVideoFiles(
    pwdId: string, stoken: string, pdirFid: string
  ): Promise<QuarkFileItem[]> {
    let result: QuarkFileItem[] = []
    let page: number = 1
    let hasMore: boolean = true

    while (hasMore) {
      let data: QuarkDetailData | null = await this.getDetail(pwdId, stoken, pdirFid, page, 100)
      if (data === null || data.list.length === 0) {
        hasMore = false
        break
      }

      for (let i = 0; i < data.list.length; i++) {
        let item: QuarkFileItem = data.list[i]
        if (item.dir && item.include_items > 0) {
          // 递归进入子文件夹
          let subFiles: QuarkFileItem[] = await this.fetchAllVideoFiles(pwdId, stoken, item.fid)
          for (let j = 0; j < subFiles.length; j++) {
            result.push(subFiles[j])
          }
        } else if (this.isVideoFile(item)) {
          result.push(item)
        }
      }

      // 检查是否还有下一页
      let total: number = 0
      let meta: Record<string, Object> = data.metadata
      if (meta !== undefined && meta !== null) {
        total = (meta['_total'] as number) ?? 0
      }
      let fetched: number = page * 100
      if (fetched >= total) {
        hasMore = false
      } else {
        page++
      }
    }

    return result
  }

  // ── 获取所有条目（非递归，用于兜底）──

  private async fetchAllItems(
    pwdId: string, stoken: string, pdirFid: string
  ): Promise<QuarkFileItem[]> {
    let result: QuarkFileItem[] = []
    let data: QuarkDetailData | null = await this.getDetail(pwdId, stoken, pdirFid, 1, 200)
    if (data !== null) {
      for (let i = 0; i < data.list.length; i++) {
        result.push(data.list[i])
      }
    }
    return result
  }

  // ── API: 获取 stoken ──

  private async getStoken(pwdId: string): Promise<string> {
    let client: http.HttpRequest = http.createHttp()
    try {
      let resp: http.HttpResponse = await client.request(
        'https://drive-pc.quark.cn/1/clouddrive/share/sharepage/token',
        {
          method: http.RequestMethod.POST,
          connectTimeout: this.timeout,
          readTimeout: this.timeout,
          header: {
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
          },
          extraData: JSON.stringify({ pwd_id: pwdId, passcode: '' })
        }
      )
      if (resp.responseCode === 200 && typeof resp.result === 'string') {
        let data: Record<string, Object> = JSON.parse(resp.result) as Record<string, Object>
        let status: number = (data['status'] as number) ?? 0
        if (status === 200) {
          let inner: Record<string, Object> = data['data'] as Record<string, Object>
          // 真实 API 返回字段是 stoken 不是 share_token
          let token: string = (inner['stoken'] as string) ?? ''
          if (token.length > 0) {
            return token
          }
          // 兼容旧字段名
          return (inner['share_token'] as string) ?? ''
        }
      }
      return ''
    } catch (_err) {
      return ''
    } finally {
      client.destroy()
    }
  }

  // ── API: 获取文件列表 ──

  private async getDetail(
    pwdId: string, stoken: string, pdirFid: string, page: number, size: number
  ): Promise<QuarkDetailData | null> {
    let client: http.HttpRequest = http.createHttp()
    try {
      // 正确的 Quark API 参数名: pwd_id, stoken, pdir_fid, _page, _size
      let url: string =
        'https://drive-pc.quark.cn/1/clouddrive/share/sharepage/detail' +
        '?pwd_id=' + pwdId +
        '&stoken=' + stoken +
        '&pdir_fid=' + pdirFid +
        '&_page=' + page +
        '&_size=' + size +
        '&_fetch_total=1' +
        '&pr=ucpro&fr=pc'

      let resp: http.HttpResponse = await client.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: this.timeout,
        readTimeout: this.timeout,
        header: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
      })

      if (resp.responseCode === 200 && typeof resp.result === 'string') {
        let data: Record<string, Object> = JSON.parse(resp.result) as Record<string, Object>
        let status: number = (data['status'] as number) ?? 0
        if (status === 200) {
          let inner: Record<string, Object> = data['data'] as Record<string, Object>
          let rawList: Object[] = (inner['list'] as Object[]) ?? []
          let meta: Record<string, Object> = (inner['metadata'] as Record<string, Object>) ?? {}
          let files: QuarkFileItem[] = []
          for (let i = 0; i < rawList.length; i++) {
            let item: Record<string, Object> = rawList[i] as Record<string, Object>
            let f: QuarkFileItem = {
              fid: (item['fid'] as string) ?? '',
              file_name: (item['file_name'] as string) ?? '',
              pdir_fid: (item['pdir_fid'] as string) ?? '',
              category: (item['category'] as number) ?? 0,
              file_type: (item['file_type'] as number) ?? 0,
              size: (item['size'] as number) ?? 0,
              format_type: (item['format_type'] as string) ?? '',
              dir: (item['dir'] as boolean) ?? false,
              include_items: (item['include_items'] as number) ?? 0,
              share_fid_token: (item['share_fid_token'] as string) ?? '',
              preview_url: (item['preview_url'] as string) ?? '',
              thumbnail: (item['thumbnail'] as string) ?? '',
              video_max_resolution: (item['video_max_resolution'] as string) ?? ''
            }
            files.push(f)
          }
          return { list: files, metadata: meta }
        }
      }
      return null
    } catch (_err) {
      return null
    } finally {
      client.destroy()
    }
  }

  // ── 工具 ──

  private extractPwdId(url: string): string {
    // https://pan.quark.cn/s/2a2031c3f9a1 → 2a2031c3f9a1
    let m: RegExpMatchArray | null = url.match(/pan\.quark\.cn\/s\/([a-zA-Z0-9]+)/)
    if (m !== null && m[1] !== undefined) {
      return m[1]
    }
    return ''
  }

  private isVideoFile(item: QuarkFileItem): boolean {
    // 通过 API 返回的 category 判断 (1=video)
    if (item.category === 1) {
      return true
    }
    // 通过 MIME 类型判断
    if (item.format_type.length > 0 && item.format_type.indexOf('video/') >= 0) {
      return true
    }
    // 通过扩展名兜底
    let name: string = item.file_name.toLowerCase()
    let videoExts: string[] = [
      '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv',
      '.m3u8', '.ts', '.rmvb', '.webm', '.m4v', '.mpg'
    ]
    for (let i = 0; i < videoExts.length; i++) {
      if (name.endsWith(videoExts[i])) {
        return true
      }
    }
    return false
  }

  // 从文件名中提取数字用于自然排序
  private extractEpisodeNum(name: string): number {
    let m: RegExpMatchArray | null = name.match(/(\d+)/)
    if (m !== null && m[1] !== undefined) {
      let num: number = parseInt(m[1])
      if (!isNaN(num)) {
        return num
      }
    }
    return 99999
  }
}
