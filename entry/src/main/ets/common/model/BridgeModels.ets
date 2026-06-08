export interface JsRuntimeInfo {
  sourceId: string
  scriptUrl: string
  md5: string
  scriptSize: number
}

export interface JsDetectResult {
  ok: boolean
  hasWebsiteBundle: boolean
  hasWebsiteBundleString: boolean
  hasModuleExports: boolean
  hasWindow: boolean
  hasServerFactory: boolean
  hasStartFunction: boolean
  hasFullConfigRoute: boolean
  hasSitesListRoute: boolean
  defaultPort: number
  message: string
}

export interface JsServerEndpoint {
  name: string
  path: string
  method: string
}

export class JsRuntimePlan {
  static readonly WEB_BUNDLE_ONLY: string = 'web_bundle_only'
  static readonly LOCAL_SERVER: string = 'local_server'
  static readonly UNKNOWN: string = 'unknown'
}

export interface JsCallRequest {
  callId: string
  method: string
  payload: string
}

export interface JsCallResult {
  callId: string
  ok: boolean
  payload: string
  errorMessage: string
}
