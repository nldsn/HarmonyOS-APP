export class SourceProtocol {
  static readonly MIRA_CAT_JS: string = 'mira_cat_js'
  static readonly TVBOX_JSON: string = 'tvbox_json'
  static readonly UNKNOWN: string = 'unknown'
}

export interface SourceDescriptor {
  id: string
  name: string
  inputUrl: string
  manifestUrl: string
  scriptUrl: string
  protocol: string
  md5: string
  scriptSize: number
  cachedAt: number
  status: string
  message: string
}

export interface SourceLoadRequest {
  inputUrl: string
  displayName: string
}

export interface SourceLoadResult {
  descriptor: SourceDescriptor
  changed: boolean
}

export class SourceStatus {
  static readonly READY: string = 'ready'
  static readonly FAILED: string = 'failed'
  static readonly LOADING: string = 'loading'
}
