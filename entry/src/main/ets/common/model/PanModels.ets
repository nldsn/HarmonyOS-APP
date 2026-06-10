export interface HeaderBag {
  cookie: string
  userAgent: string
  referer: string
  origin: string
}

export interface PanCookieProfile {
  ok: boolean
  hasQuark: boolean
  quarkCookie: string
  quarkUpdatedAt: string
  message: string
}

export interface PanPlayRequest {
  panType: string
  shareUrl: string
  shareId: string
  fileId: string
  fileToken: string
  stoken: string
  fileName: string
  title: string
  cover: string
}

export interface PanPlayResult {
  ok: boolean
  url: string
  headersJson: string
  cover: string
  source: string
  message: string
}

export class PanDefaults {
  static readonly QUARK_API_BASE: string = 'https://drive-pc.quark.cn'
  static readonly QUARK_QUERY: string = 'pr=ucpro&fr=pc&uc_param_str='
  static readonly QUARK_REFERER: string = 'https://pan.quark.cn'
  static readonly QUARK_ORIGIN: string = 'https://pan.quark.cn'
  static readonly QUARK_USER_AGENT: string =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
}

export class QuarkShareFile {
  fid: string = ''
  fileName: string = ''
  fileToken: string = ''
  thumbnail: string = ''
  size: number = 0
  dir: boolean = false
}

export interface QuarkApiResponse<T> {
  status?: number
  code?: number
  message?: string
  data?: T
}

export interface QuarkTokenData {
  stoken?: string
  title?: string
}

export interface QuarkFileItem {
  fid?: string
  file_name?: string
  name?: string
  file_token?: string
  fid_token?: string
  thumbnail?: string
  preview_url?: string
  size?: number
  file_size?: number
  dir?: boolean
  file_type?: number
  format_type?: string
  obj_category?: string
}

export interface QuarkShareInfo {
  first_fid?: string
  first_file?: QuarkFileItem
  title?: string
  share_title?: string
  file_name?: string
  first_file_name?: string
  file_token?: string
  first_file_token?: string
  thumbnail?: string
  first_thumbnail?: string
  size?: number
}

export interface QuarkDetailData {
  list?: QuarkFileItem[]
  share?: QuarkShareInfo
}

export interface QuarkTaskFileData {
  fid?: string
  file_id?: string
  file_name?: string
  name?: string
  thumbnail?: string
  preview_url?: string
  dir?: boolean
  file_type?: number
}

export interface QuarkTaskSaveAsData {
  save_as_top_dir_fid?: string
  top_fid?: string
  to_pdir_fid?: string
  fid?: string
  file_id?: string
  file?: QuarkTaskFileData
  first_file?: QuarkTaskFileData
  file_list?: QuarkTaskFileData[]
  list?: QuarkTaskFileData[]
}

export interface QuarkTaskResultData {
  fid?: string
  file_id?: string
  save_as?: QuarkTaskSaveAsData
  file?: QuarkTaskFileData
  first_file?: QuarkTaskFileData
  file_list?: QuarkTaskFileData[]
  list?: QuarkTaskFileData[]
}

export interface QuarkSaveData {
  task_id?: string
  taskId?: string
  fid?: string
  file_id?: string
  save_as?: QuarkTaskSaveAsData
  file?: QuarkTaskFileData
  first_file?: QuarkTaskFileData
  file_list?: QuarkTaskFileData[]
  list?: QuarkTaskFileData[]
  result?: QuarkTaskResultData
}

export interface QuarkTaskData {
  status?: number
  task_id?: string
  taskId?: string
  finish?: boolean
  finished?: boolean
  fid?: string
  file_id?: string
  save_as?: QuarkTaskSaveAsData
  file?: QuarkTaskFileData
  first_file?: QuarkTaskFileData
  file_list?: QuarkTaskFileData[]
  list?: QuarkTaskFileData[]
  result?: QuarkTaskResultData
}

export interface QuarkVideoInfo {
  url?: string
}

export interface QuarkVideoItem {
  url?: string
  play_url?: string
  resolution?: string
  video_info?: QuarkVideoInfo
}

export interface QuarkPlayData {
  url?: string
  play_url?: string
  download_url?: string
  video_list?: QuarkVideoItem[]
}

export interface QuarkDownloadItem {
  download_url?: string
  url?: string
}

export interface QuarkDownloadData {
  download_url?: string
  url?: string
  list?: QuarkDownloadItem[]
}
