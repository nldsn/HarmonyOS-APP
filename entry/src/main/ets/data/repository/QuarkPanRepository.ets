import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import {
  PanDefaults,
  PanPlayRequest,
  PanPlayResult,
  QuarkApiResponse,
  QuarkDetailData,
  QuarkDownloadData,
  QuarkDownloadItem,
  QuarkFileItem,
  QuarkPlayData,
  QuarkSaveData,
  QuarkShareFile,
  QuarkShareInfo,
  QuarkTaskData,
  QuarkTaskFileData,
  QuarkTaskResultData,
  QuarkTaskSaveAsData,
  QuarkTokenData,
  QuarkVideoItem
} from '../../common/model/PanModels'

class QuarkHttpTextResponse {
  statusCode: number = 0
  body: string = ''
  cookies: string = ''
}

class QuarkSavedFileResult {
  fileFid: string = ''
  dirFid: string = ''
}

interface QuarkRequestHeaders {
  Cookie: string
  'User-Agent': string
  Referer: string
  Origin: string
  Accept: string
  'Content-Type': string
}

export class QuarkPanRepository {
  async resolve(input: PanPlayRequest, cookie: string): Promise<PanPlayResult> {
    let result: PanPlayResult = this.emptyResult(input.cover)
    let trimmedCookie: string = cookie.trim()
    if (trimmedCookie.length === 0) {
      result.message = '请先在配置中心扫码同步夸克账号'
      return result
    }
    if (!this.isQuarkInput(input)) {
      result.message = '当前剧集不是夸克网盘资源'
      return result
    }

    let shareId: string = this.effectiveShareId(input)
    if (shareId.length === 0) {
      result.message = '未识别到夸克分享 ID'
      return result
    }

    try {
      let runtimeCookie: string = trimmedCookie
      let stoken: string = input.stoken.trim()
      if (stoken.length === 0) {
        stoken = await this.getShareToken(shareId, runtimeCookie)
      }

      let fileId: string = input.fileId.trim()
      let fileToken: string = input.fileToken.trim()
      let targetFileName: string = input.fileName.trim()
      let cover: string = input.cover
      if (fileId.length === 0 || fileToken.length === 0) {
        let file: QuarkShareFile = await this.findShareVideoFile(shareId, stoken, input, runtimeCookie)
        if (file.fid.length > 0) {
          fileId = file.fid
        }
        if (file.fileToken.length > 0) {
          fileToken = file.fileToken
        }
        if (cover.length === 0 && file.thumbnail.length > 0) {
          cover = file.thumbnail
        }
        if (targetFileName.length === 0 && file.fileName.length > 0) {
          targetFileName = file.fileName
        }
      }

      if (fileId.length === 0) {
        result.message = '夸克分享内未找到可播放文件'
        return result
      }

      let directPlay: PanPlayResult = await this.tryPlayOwnFile(fileId, runtimeCookie, cover)
      if (directPlay.ok) {
        directPlay.source = 'quark-local'
        directPlay.message = '夸克本地解析播放'
        return directPlay
      }

      if (fileToken.length === 0) {
        result.message = '缺少夸克文件 token，无法在 App 本地转存解析'
        return result
      }

      let savedFid: string = await this.saveShareFile(shareId, stoken, fileId, fileToken, targetFileName,
        runtimeCookie)
      if (savedFid.length === 0) {
        result.message = '夸克转存任务未返回文件 ID'
        return result
      }

      let savedPlay: PanPlayResult = await this.tryPlayOwnFile(savedFid, runtimeCookie, cover)
      if (savedPlay.ok) {
        savedPlay.source = 'quark-local'
        savedPlay.message = '夸克本地转存解析播放'
        return savedPlay
      }
      result.message = this.nonEmptyText(savedPlay.message, '夸克接口未返回真实播放地址')
      return result
    } catch (err) {
      result.message = this.errorText(err)
      return result
    }
  }

  extractShareId(url: string): string {
    let trimmed: string = url.trim()
    let marker: string = 'pan.quark.cn/s/'
    let idx: number = trimmed.indexOf(marker)
    if (idx < 0) {
      marker = 'drive.uc.cn/s/'
      idx = trimmed.indexOf(marker)
    }
    if (idx < 0) {
      return ''
    }
    let start: number = idx + marker.length
    let tail: string = trimmed.substring(start)
    let end: number = tail.indexOf('/')
    if (end >= 0) {
      tail = tail.substring(0, end)
    }
    let queryIndex: number = tail.indexOf('?')
    if (queryIndex >= 0) {
      tail = tail.substring(0, queryIndex)
    }
    return tail.trim()
  }

  private async tryPlayOwnFile(fid: string, cookie: string, cover: string): Promise<PanPlayResult> {
    let result: PanPlayResult = this.emptyResult(cover)
    try {
      let playResponse: QuarkHttpTextResponse = await this.postQuarkJson(
        PanDefaults.QUARK_API_BASE + '/1/clouddrive/file/v2/play?' + PanDefaults.QUARK_QUERY,
        '{"fid":' + JSON.stringify(fid) +
          ',"resolutions":"normal,low,high,super,2k,4k","supports":"fmp4,m3u8"}',
        cookie
      )
      let playCookie: string = this.mergeCookie(cookie, playResponse.cookies)
      let playParsed = JSON.parse(playResponse.body) as QuarkApiResponse<QuarkPlayData>
      let playData: QuarkPlayData | undefined = playParsed.data
      let playUrl: string = ''
      if (playData !== undefined) {
        playUrl = this.firstPlayUrl(playData)
      }
      if (playUrl.length === 0) {
        let downloadResponse: QuarkHttpTextResponse = await this.postQuarkJson(
          PanDefaults.QUARK_API_BASE + '/1/clouddrive/file/download?' + PanDefaults.QUARK_QUERY,
          '{"fids":[' + JSON.stringify(fid) + ']}',
          playCookie
        )
        playCookie = this.mergeCookie(playCookie, downloadResponse.cookies)
        let downloadParsed = JSON.parse(downloadResponse.body) as QuarkApiResponse<QuarkDownloadData>
        let downloadData: QuarkDownloadData | undefined = downloadParsed.data
        if (downloadData !== undefined) {
          playUrl = this.firstDownloadUrl(downloadData)
        }
      }
      if (playUrl.length === 0) {
        result.message = this.responseMessage(playParsed, '夸克接口未返回真实播放地址')
        return result
      }
      result.ok = true
      result.url = playUrl
      result.cover = cover
      result.headersJson = this.playHeadersJson(playCookie)
      return result
    } catch (err) {
      result.message = this.errorText(err)
      return result
    }
  }

  private effectiveShareId(input: PanPlayRequest): string {
    let shareId: string = input.shareId.trim()
    if (shareId.length > 0) {
      return shareId
    }
    return this.extractShareId(input.shareUrl)
  }

  private isQuarkInput(input: PanPlayRequest): boolean {
    let panType: string = input.panType.toLowerCase()
    if (panType.indexOf('quark') >= 0 || panType.indexOf('夸克') >= 0) {
      return true
    }
    if (input.shareUrl.indexOf('pan.quark.cn/s/') >= 0 || input.shareUrl.indexOf('drive.uc.cn/s/') >= 0) {
      return true
    }
    return input.shareId.length > 0 &&
      (input.stoken.length > 0 || input.fileToken.length > 0 || input.fileId.length > 0)
  }

  private async getShareToken(shareId: string, cookie: string): Promise<string> {
    let endpoint: string = PanDefaults.QUARK_API_BASE + '/1/clouddrive/share/sharepage/token?' +
      PanDefaults.QUARK_QUERY
    let body: string = '{"pwd_id":' + JSON.stringify(shareId) + ',"passcode":""}'
    let response: QuarkHttpTextResponse = await this.postQuarkJson(endpoint, body, cookie)
    let parsed = JSON.parse(response.body) as QuarkApiResponse<QuarkTokenData>
    let data: QuarkTokenData | undefined = parsed.data
    if (data !== undefined && data.stoken !== undefined && data.stoken.length > 0) {
      return data.stoken
    }
    throw new Error(this.responseMessage(parsed, '夸克分享 token 获取失败'))
  }

  private async findShareVideoFile(shareId: string, stoken: string, input: PanPlayRequest,
    cookie: string): Promise<QuarkShareFile> {
    let pendingDirs: string[] = ['0']
    let best = new QuarkShareFile()
    let visited: number = 0
    while (pendingDirs.length > 0 && visited < 24) {
      let pdirFid: string = pendingDirs.shift() ?? '0'
      visited++
      let files: QuarkShareFile[] = await this.listShareFiles(shareId, stoken, pdirFid, cookie)
      for (let i = 0; i < files.length; i++) {
        let file: QuarkShareFile = files[i]
        if (file.dir && file.fid.length > 0) {
          pendingDirs.push(file.fid)
        } else if (this.isTargetFile(file, input)) {
          return file
        } else if (best.fid.length === 0 && this.isCandidateFile(file)) {
          best = file
        }
      }
    }
    return best
  }

  private async listShareFiles(shareId: string, stoken: string, pdirFid: string,
    cookie: string): Promise<QuarkShareFile[]> {
    let endpoint: string = PanDefaults.QUARK_API_BASE + '/1/clouddrive/share/sharepage/detail?' +
      PanDefaults.QUARK_QUERY + '&pwd_id=' + encodeURIComponent(shareId) +
      '&stoken=' + encodeURIComponent(stoken) +
      '&pdir_fid=' + encodeURIComponent(pdirFid) +
      '&force=0&_page=1&_size=100&_fetch_banner=0&_fetch_share=1&_fetch_total=1' +
      '&_sort=file_type:asc,updated_at:desc'
    let response: QuarkHttpTextResponse = await this.getQuarkText(endpoint, cookie)
    let parsed = JSON.parse(response.body) as QuarkApiResponse<QuarkDetailData>
    let data: QuarkDetailData | undefined = parsed.data
    let result: QuarkShareFile[] = []
    if (data !== undefined && data.list !== undefined) {
      for (let i = 0; i < data.list.length; i++) {
        result.push(this.normalizeShareFile(data.list[i]))
      }
    }
    if (data !== undefined && data.share !== undefined) {
      let shareFile: QuarkShareFile = this.normalizeShareInfo(data.share)
      if (shareFile.fid.length > 0 && !this.containsFile(result, shareFile.fid)) {
        result.push(shareFile)
      }
    }
    return result
  }

  private normalizeShareFile(item: QuarkFileItem): QuarkShareFile {
    let file = new QuarkShareFile()
    file.fid = item.fid ?? ''
    file.fileName = this.nonEmptyText(item.file_name ?? '', item.name ?? '')
    file.fileToken = this.nonEmptyText(item.file_token ?? '', item.fid_token ?? '')
    file.thumbnail = this.nonEmptyText(item.thumbnail ?? '', item.preview_url ?? '')
    file.size = this.positiveNumber(item.size ?? 0, item.file_size ?? 0)
    file.dir = item.dir ?? false
    return file
  }

  private normalizeShareInfo(info: QuarkShareInfo): QuarkShareFile {
    let file = new QuarkShareFile()
    if (info.first_file !== undefined) {
      file = this.normalizeShareFile(info.first_file)
    }
    if (file.fid.length === 0) {
      file.fid = info.first_fid ?? ''
    }
    if (file.fileName.length === 0) {
      file.fileName = this.firstNonEmptyText(
        info.first_file_name ?? '',
        info.file_name ?? '',
        info.title ?? '',
        info.share_title ?? ''
      )
    }
    if (file.fileToken.length === 0) {
      file.fileToken = this.nonEmptyText(info.first_file_token ?? '', info.file_token ?? '')
    }
    if (file.thumbnail.length === 0) {
      file.thumbnail = this.nonEmptyText(info.first_thumbnail ?? '', info.thumbnail ?? '')
    }
    if (file.size <= 0) {
      file.size = info.size ?? 0
    }
    return file
  }

  private containsFile(files: QuarkShareFile[], fid: string): boolean {
    for (let i = 0; i < files.length; i++) {
      if (files[i].fid === fid) {
        return true
      }
    }
    return false
  }

  private isTargetFile(file: QuarkShareFile, input: PanPlayRequest): boolean {
    if (!this.isVideoFile(file.fileName)) {
      return false
    }
    if (input.fileId.length > 0 && file.fid === input.fileId) {
      return true
    }
    let fileName: string = input.fileName.trim()
    if (fileName.length > 0 && file.fileName === fileName) {
      return true
    }
    return input.fileId.length === 0 && fileName.length === 0
  }

  private isVideoFile(fileName: string): boolean {
    let lower: string = fileName.toLowerCase()
    return lower.endsWith('.mp4') || lower.endsWith('.mkv') || lower.endsWith('.ts') ||
      lower.endsWith('.m2ts') || lower.endsWith('.mov') || lower.endsWith('.flv') ||
      lower.endsWith('.avi') || lower.endsWith('.wmv') || lower.endsWith('.webm') ||
      lower.endsWith('.m3u8')
  }

  private isCandidateFile(file: QuarkShareFile): boolean {
    if (this.isVideoFile(file.fileName)) {
      return true
    }
    return file.fid.length > 0 && !file.dir
  }

  private savedFileNameMatches(fileName: string, normalizedTarget: string): boolean {
    if (normalizedTarget.length === 0) {
      return true
    }
    let normalizedFileName: string = this.normalizeComparableName(fileName)
    if (normalizedFileName.length === 0) {
      return false
    }
    return normalizedFileName === normalizedTarget ||
      normalizedFileName.indexOf(normalizedTarget) >= 0 ||
      normalizedTarget.indexOf(normalizedFileName) >= 0
  }

  private normalizeComparableName(fileName: string): string {
    let lower: string = fileName.toLowerCase().trim()
    let dotIndex: number = lower.lastIndexOf('.')
    if (dotIndex > 0) {
      lower = lower.substring(0, dotIndex)
    }
    return lower.replace(/\s/g, '')
      .replace(/\[/g, '')
      .replace(/\]/g, '')
      .replace(/【/g, '')
      .replace(/】/g, '')
  }

  private async saveShareFile(shareId: string, stoken: string, fileId: string, fileToken: string,
    targetFileName: string, cookie: string): Promise<string> {
    let endpoint: string = PanDefaults.QUARK_API_BASE + '/1/clouddrive/share/sharepage/save?' +
      PanDefaults.QUARK_QUERY
    let body: string = '{"fid_list":[' + JSON.stringify(fileId) + '],"fid_token_list":[' +
      JSON.stringify(fileToken) + '],"to_pdir_fid":"0","pwd_id":' + JSON.stringify(shareId) +
      ',"stoken":' + JSON.stringify(stoken) + ',"pdir_fid":"0","scene":"link"}'
    let response: QuarkHttpTextResponse = await this.postQuarkJson(endpoint, body, cookie)
    let parsed = JSON.parse(response.body) as QuarkApiResponse<QuarkSaveData>
    let data: QuarkSaveData | undefined = parsed.data
    if (data === undefined) {
      throw new Error(this.responseMessage(parsed, '夸克转存任务创建失败'))
    }
    let directResult: QuarkSavedFileResult = this.savedResultFromSaveData(data)
    if (directResult.fileFid.length > 0) {
      return directResult.fileFid
    }
    if (directResult.dirFid.length > 0) {
      let fileFid: string = await this.findSavedVideoFile(directResult.dirFid, targetFileName, cookie)
      if (fileFid.length > 0) {
        return fileFid
      }
    }

    let taskId: string = this.nonEmptyText(data.task_id ?? '', data.taskId ?? '')
    if (taskId.length === 0) {
      throw new Error(this.responseMessage(parsed, '夸克转存任务创建失败'))
    }
    let taskResult: QuarkSavedFileResult = await this.waitSaveTask(taskId, cookie)
    if (taskResult.fileFid.length > 0) {
      return taskResult.fileFid
    }
    if (taskResult.dirFid.length > 0) {
      return await this.findSavedVideoFile(taskResult.dirFid, targetFileName, cookie)
    }
    return await this.findRecentSavedVideoFile(targetFileName, cookie)
  }

  private async waitSaveTask(taskId: string, cookie: string): Promise<QuarkSavedFileResult> {
    let savedResult = new QuarkSavedFileResult()
    for (let i = 0; i < 20; i++) {
      let endpoint: string = PanDefaults.QUARK_API_BASE + '/1/clouddrive/task?' + PanDefaults.QUARK_QUERY +
        '&task_id=' + encodeURIComponent(taskId) + '&retry_index=' + i.toString()
      let response: QuarkHttpTextResponse = await this.getQuarkText(endpoint, cookie)
      let parsed = JSON.parse(response.body) as QuarkApiResponse<QuarkTaskData>
      let data: QuarkTaskData | undefined = parsed.data
      if (data !== undefined) {
        let currentResult: QuarkSavedFileResult = this.savedResultFromTaskData(data)
        this.mergeSavedResult(savedResult, currentResult)
        if (savedResult.fileFid.length > 0) {
          return savedResult
        }
        if (this.taskFinished(data) && savedResult.dirFid.length > 0) {
          return savedResult
        }
      }
      await this.sleep(500)
    }
    return savedResult
  }

  private async findSavedVideoFile(dirFid: string, targetFileName: string, cookie: string): Promise<string> {
    let pendingDirs: string[] = [dirFid]
    let bestFid: string = ''
    let visited: number = 0
    let normalizedTarget: string = this.normalizeComparableName(targetFileName)
    while (pendingDirs.length > 0 && visited < 24) {
      let pdirFid: string = pendingDirs.shift() ?? ''
      if (pdirFid.length === 0) {
        continue
      }
      visited++
      let files: QuarkShareFile[] = await this.listOwnFiles(pdirFid, cookie)
      for (let i = 0; i < files.length; i++) {
        let file: QuarkShareFile = files[i]
        if (file.dir && file.fid.length > 0) {
          pendingDirs.push(file.fid)
        } else if (file.fid.length > 0 && this.isVideoFile(file.fileName) &&
          this.savedFileNameMatches(file.fileName, normalizedTarget)) {
          return file.fid
        } else if (bestFid.length === 0 && this.isCandidateFile(file)) {
          bestFid = file.fid
        }
      }
    }
    return bestFid
  }

  private async findRecentSavedVideoFile(targetFileName: string, cookie: string): Promise<string> {
    if (targetFileName.trim().length === 0) {
      return ''
    }
    for (let i = 0; i < 6; i++) {
      let files: QuarkShareFile[] = await this.listOwnFiles('0', cookie)
      let fid: string = this.bestSavedFileFromList(files, targetFileName)
      if (fid.length > 0) {
        return fid
      }
      await this.sleep(500)
    }
    return ''
  }

  private bestSavedFileFromList(files: QuarkShareFile[], targetFileName: string): string {
    let normalizedTarget: string = this.normalizeComparableName(targetFileName)
    let bestFid: string = ''
    for (let i = 0; i < files.length; i++) {
      let file: QuarkShareFile = files[i]
      if (file.fid.length > 0 && !file.dir && this.isVideoFile(file.fileName) &&
        this.savedFileNameMatches(file.fileName, normalizedTarget)) {
        return file.fid
      }
      if (bestFid.length === 0 && file.fid.length > 0 && !file.dir && this.isVideoFile(file.fileName)) {
        bestFid = file.fid
      }
    }
    return bestFid
  }

  private async listOwnFiles(pdirFid: string, cookie: string): Promise<QuarkShareFile[]> {
    let endpoint: string = PanDefaults.QUARK_API_BASE + '/1/clouddrive/file/sort?' +
      PanDefaults.QUARK_QUERY +
      '&pdir_fid=' + encodeURIComponent(pdirFid) +
      '&_page=1&_size=100&_fetch_total=1&_fetch_sub_dirs=0' +
      '&_sort=file_type:asc,updated_at:desc'
    let response: QuarkHttpTextResponse = await this.getQuarkText(endpoint, cookie)
    let parsed = JSON.parse(response.body) as QuarkApiResponse<QuarkDetailData>
    let data: QuarkDetailData | undefined = parsed.data
    let result: QuarkShareFile[] = []
    if (data !== undefined && data.list !== undefined) {
      for (let i = 0; i < data.list.length; i++) {
        result.push(this.normalizeShareFile(data.list[i]))
      }
    }
    return result
  }

  private savedResultFromSaveData(data: QuarkSaveData): QuarkSavedFileResult {
    let result = new QuarkSavedFileResult()
    this.applyFileFid(result, data.fid ?? '')
    this.applyFileFid(result, data.file_id ?? '')
    this.mergeSavedResult(result, this.savedResultFromSaveAs(data.save_as))
    this.mergeSavedResult(result, this.savedResultFromTaskFile(data.file))
    this.mergeSavedResult(result, this.savedResultFromTaskFile(data.first_file))
    this.mergeSavedResult(result, this.savedResultFromTaskFileList(data.file_list))
    this.mergeSavedResult(result, this.savedResultFromTaskFileList(data.list))
    this.mergeSavedResult(result, this.savedResultFromTaskResult(data.result))
    return result
  }

  private savedResultFromTaskData(data: QuarkTaskData): QuarkSavedFileResult {
    let result = new QuarkSavedFileResult()
    this.applyFileFid(result, data.fid ?? '')
    this.applyFileFid(result, data.file_id ?? '')
    this.mergeSavedResult(result, this.savedResultFromSaveAs(data.save_as))
    this.mergeSavedResult(result, this.savedResultFromTaskFile(data.file))
    this.mergeSavedResult(result, this.savedResultFromTaskFile(data.first_file))
    this.mergeSavedResult(result, this.savedResultFromTaskFileList(data.file_list))
    this.mergeSavedResult(result, this.savedResultFromTaskFileList(data.list))
    this.mergeSavedResult(result, this.savedResultFromTaskResult(data.result))
    return result
  }

  private savedResultFromTaskResult(data: QuarkTaskResultData | undefined): QuarkSavedFileResult {
    let result = new QuarkSavedFileResult()
    if (data === undefined) {
      return result
    }
    this.applyFileFid(result, data.fid ?? '')
    this.applyFileFid(result, data.file_id ?? '')
    this.mergeSavedResult(result, this.savedResultFromSaveAs(data.save_as))
    this.mergeSavedResult(result, this.savedResultFromTaskFile(data.file))
    this.mergeSavedResult(result, this.savedResultFromTaskFile(data.first_file))
    this.mergeSavedResult(result, this.savedResultFromTaskFileList(data.file_list))
    this.mergeSavedResult(result, this.savedResultFromTaskFileList(data.list))
    return result
  }

  private savedResultFromSaveAs(data: QuarkTaskSaveAsData | undefined): QuarkSavedFileResult {
    let result = new QuarkSavedFileResult()
    if (data === undefined) {
      return result
    }
    this.applyFileFid(result, data.fid ?? '')
    this.applyFileFid(result, data.file_id ?? '')
    this.applyDirFid(result, data.save_as_top_dir_fid ?? '')
    this.applyDirFid(result, data.top_fid ?? '')
    this.mergeSavedResult(result, this.savedResultFromTaskFile(data.file))
    this.mergeSavedResult(result, this.savedResultFromTaskFile(data.first_file))
    this.mergeSavedResult(result, this.savedResultFromTaskFileList(data.file_list))
    this.mergeSavedResult(result, this.savedResultFromTaskFileList(data.list))
    return result
  }

  private savedResultFromTaskFile(file: QuarkTaskFileData | undefined): QuarkSavedFileResult {
    let result = new QuarkSavedFileResult()
    if (file === undefined) {
      return result
    }
    let fid: string = this.nonEmptyText(file.fid ?? '', file.file_id ?? '')
    if (fid.length === 0) {
      return result
    }
    if (file.dir === true) {
      this.applyDirFid(result, fid)
    } else {
      this.applyFileFid(result, fid)
    }
    return result
  }

  private savedResultFromTaskFileList(files: QuarkTaskFileData[] | undefined): QuarkSavedFileResult {
    let result = new QuarkSavedFileResult()
    if (files === undefined || files.length === 0) {
      return result
    }
    for (let i = 0; i < files.length; i++) {
      let file: QuarkTaskFileData = files[i]
      let fileName: string = this.nonEmptyText(file.file_name ?? '', file.name ?? '')
      let fid: string = this.nonEmptyText(file.fid ?? '', file.file_id ?? '')
      if (fid.length > 0 && file.dir !== true && this.isVideoFile(fileName)) {
        result.fileFid = fid
        return result
      }
    }
    for (let i = 0; i < files.length; i++) {
      this.mergeSavedResult(result, this.savedResultFromTaskFile(files[i]))
      if (result.fileFid.length > 0) {
        return result
      }
    }
    return result
  }

  private mergeSavedResult(target: QuarkSavedFileResult, source: QuarkSavedFileResult): void {
    if (target.fileFid.length === 0 && source.fileFid.length > 0) {
      target.fileFid = source.fileFid
    }
    if (target.dirFid.length === 0 && source.dirFid.length > 0) {
      target.dirFid = source.dirFid
    }
  }

  private applyFileFid(result: QuarkSavedFileResult, fid: string): void {
    let value: string = fid.trim()
    if (result.fileFid.length === 0 && value.length > 0) {
      result.fileFid = value
    }
  }

  private applyDirFid(result: QuarkSavedFileResult, fid: string): void {
    let value: string = fid.trim()
    if (result.dirFid.length === 0 && value.length > 0 && value !== '0') {
      result.dirFid = value
    }
  }

  private taskFinished(data: QuarkTaskData): boolean {
    if (data.finish === true || data.finished === true) {
      return true
    }
    return data.status === 2 || data.status === 3
  }

  private firstPlayUrl(data: QuarkPlayData): string {
    if (data.url !== undefined && data.url.length > 0) {
      return data.url
    }
    if (data.play_url !== undefined && data.play_url.length > 0) {
      return data.play_url
    }
    if (data.download_url !== undefined && data.download_url.length > 0) {
      return data.download_url
    }
    let list: QuarkVideoItem[] | undefined = data.video_list
    if (list === undefined || list.length === 0) {
      return ''
    }
    let bestUrl: string = ''
    let bestRank: number = -1
    for (let i = 0; i < list.length; i++) {
      let item: QuarkVideoItem = list[i]
      let url: string = this.videoItemUrl(item)
      let rank: number = this.resolutionRank(item.resolution ?? '')
      if (url.length > 0 && rank >= bestRank) {
        bestUrl = url
        bestRank = rank
      }
    }
    return bestUrl
  }

  private videoItemUrl(item: QuarkVideoItem): string {
    if (item.url !== undefined && item.url.length > 0) {
      return item.url
    }
    if (item.play_url !== undefined && item.play_url.length > 0) {
      return item.play_url
    }
    if (item.video_info !== undefined && item.video_info.url !== undefined && item.video_info.url.length > 0) {
      return item.video_info.url
    }
    return ''
  }

  private resolutionRank(value: string): number {
    let lower: string = value.toLowerCase()
    if (lower.indexOf('4k') >= 0) {
      return 6
    }
    if (lower.indexOf('2k') >= 0) {
      return 5
    }
    if (lower.indexOf('super') >= 0) {
      return 4
    }
    if (lower.indexOf('high') >= 0) {
      return 3
    }
    if (lower.indexOf('normal') >= 0) {
      return 2
    }
    if (lower.indexOf('low') >= 0) {
      return 1
    }
    return 0
  }

  private firstDownloadUrl(data: QuarkDownloadData): string {
    if (data.download_url !== undefined && data.download_url.length > 0) {
      return data.download_url
    }
    if (data.url !== undefined && data.url.length > 0) {
      return data.url
    }
    if (data.list !== undefined && data.list.length > 0) {
      let item: QuarkDownloadItem = data.list[0]
      if (item.download_url !== undefined && item.download_url.length > 0) {
        return item.download_url
      }
      if (item.url !== undefined && item.url.length > 0) {
        return item.url
      }
    }
    return ''
  }

  private async getQuarkText(url: string, cookie: string): Promise<QuarkHttpTextResponse> {
    let request = http.createHttp()
    try {
      let response = await request.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 30000,
        readTimeout: 60000,
        expectDataType: http.HttpDataType.STRING,
        header: this.requestHeaders(cookie)
      })
      return this.normalizeHttpResponse(response.responseCode, response.result, response.cookies)
    } finally {
      request.destroy()
    }
  }

  private async postQuarkJson(url: string, body: string, cookie: string): Promise<QuarkHttpTextResponse> {
    let request = http.createHttp()
    try {
      let response = await request.request(url, {
        method: http.RequestMethod.POST,
        connectTimeout: 30000,
        readTimeout: 60000,
        expectDataType: http.HttpDataType.STRING,
        header: this.requestHeaders(cookie),
        extraData: body
      })
      return this.normalizeHttpResponse(response.responseCode, response.result, response.cookies)
    } finally {
      request.destroy()
    }
  }

  private requestHeaders(cookie: string): QuarkRequestHeaders {
    let headers: QuarkRequestHeaders = {
      'Cookie': cookie,
      'User-Agent': PanDefaults.QUARK_USER_AGENT,
      'Referer': PanDefaults.QUARK_REFERER,
      'Origin': PanDefaults.QUARK_ORIGIN,
      'Accept': 'application/json, text/plain, */*',
      'Content-Type': 'application/json'
    }
    return headers
  }

  private normalizeHttpResponse(statusCode: number, body: string | Object | ArrayBuffer,
    cookies: string): QuarkHttpTextResponse {
    let result = new QuarkHttpTextResponse()
    result.statusCode = statusCode
    result.cookies = cookies
    if (statusCode < 200 || statusCode >= 300) {
      throw new Error('夸克接口请求失败: ' + statusCode.toString())
    }
    result.body = this.responseBodyToString(body)
    return result
  }

  private responseBodyToString(result: string | Object | ArrayBuffer): string {
    if (typeof result === 'string') {
      return result
    }
    if (result instanceof ArrayBuffer) {
      let decoder = util.TextDecoder.create('utf-8')
      return decoder.decodeToString(new Uint8Array(result))
    }
    return JSON.stringify(result)
  }

  private mergeCookie(baseCookie: string, appendCookie: string): string {
    let trimmedAppend: string = appendCookie.trim()
    if (trimmedAppend.length === 0) {
      return baseCookie
    }
    let normalized: string = trimmedAppend.replace(/\r/g, '').replace(/\n/g, ';')
    if (baseCookie.endsWith(';')) {
      return baseCookie + normalized
    }
    return baseCookie + ';' + normalized
  }

  private playHeadersJson(cookie: string): string {
    return '{"Cookie":' + JSON.stringify(cookie) +
      ',"User-Agent":' + JSON.stringify(PanDefaults.QUARK_USER_AGENT) +
      ',"Referer":' + JSON.stringify(PanDefaults.QUARK_REFERER) +
      ',"Origin":' + JSON.stringify(PanDefaults.QUARK_ORIGIN) + '}'
  }

  private emptyResult(cover: string): PanPlayResult {
    return {
      ok: false,
      url: '',
      headersJson: '',
      cover: cover,
      source: 'quark-local',
      message: ''
    }
  }

  private responseMessage<T>(response: QuarkApiResponse<T>, fallback: string): string {
    let message: string | undefined = response.message
    if (message !== undefined && message.length > 0) {
      return message
    }
    return fallback
  }

  private sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(resolve, ms)
    })
  }

  private nonEmptyText(value: string, fallback: string): string {
    let trimmed: string = value.trim()
    if (trimmed.length > 0) {
      return trimmed
    }
    return fallback
  }

  private firstNonEmptyText(first: string, second: string, third: string, fourth: string): string {
    let value: string = first.trim()
    if (value.length > 0) {
      return value
    }
    value = second.trim()
    if (value.length > 0) {
      return value
    }
    value = third.trim()
    if (value.length > 0) {
      return value
    }
    return fourth.trim()
  }

  private positiveNumber(value: number, fallback: number): number {
    if (value > 0) {
      return value
    }
    return fallback
  }

  private errorText(err: Object): string {
    if (err instanceof Error && err.message.length > 0) {
      return err.message
    }
    return '夸克本地解析失败'
  }
}
