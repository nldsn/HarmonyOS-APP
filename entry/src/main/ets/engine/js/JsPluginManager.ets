import { JsDetectResult, JsRuntimeInfo, JsRuntimePlan } from '../../common/model/BridgeModels'
import { SourceDescriptor } from '../../common/model/SourceModels'
import { SourceRepository } from '../../data/repository/SourceRepository'
import { JsRuntimeHost } from './JsRuntimeHost'

export class JsPluginManager {
  private repository: SourceRepository
  private runtimeHost: JsRuntimeHost

  constructor(repository: SourceRepository, runtimeHost: JsRuntimeHost) {
    this.repository = repository
    this.runtimeHost = runtimeHost
  }

  prepareCachedRuntime(): JsDetectResult {
    let descriptor = this.repository.getCurrentSource()
    if (descriptor === null) {
      this.runtimeHost.markNotReady()
      return this.failed('没有可用的 JS 订阅源缓存')
    }

    let script = this.repository.getCurrentScript()
    if (script.length === 0) {
      this.runtimeHost.markNotReady()
      return this.failed('JS 脚本缓存为空')
    }

    let detectResult = this.detectScript(script)
    if (!detectResult.ok) {
      this.runtimeHost.markNotReady()
      return detectResult
    }

    let info: JsRuntimeInfo = {
      sourceId: descriptor.id,
      scriptUrl: descriptor.scriptUrl,
      md5: descriptor.md5,
      scriptSize: descriptor.scriptSize
    }
    this.runtimeHost.markReady(info, detectResult)
    return detectResult
  }

  buildSandboxLoadScript(): string {
    let script = this.repository.getCurrentScript()
    if (script.length === 0) {
      return ''
    }
    return script
  }

  runtimePlan(): string {
    let result = this.prepareCachedRuntime()
    if (result.hasServerFactory || result.hasFullConfigRoute) {
      return JsRuntimePlan.LOCAL_SERVER
    }
    if (result.hasWebsiteBundle) {
      return JsRuntimePlan.WEB_BUNDLE_ONLY
    }
    return JsRuntimePlan.UNKNOWN
  }

  private detectScript(script: string): JsDetectResult {
    let hasWebsiteBundle = script.indexOf('globalThis.websiteBundle') >= 0 ||
      script.indexOf('websiteBundle') >= 0
    let hasWebsiteBundleString = script.indexOf('globalThis.websiteBundle=\"') >= 0 ||
      script.indexOf('globalThis.websiteBundle = \"') >= 0
    let hasModuleExports = script.indexOf('module.exports') >= 0
    let hasWindow = script.indexOf('window.') >= 0
    let hasServerFactory = script.indexOf('catServerFactory') >= 0
    let hasStartFunction = script.indexOf('async function start') >= 0 ||
      script.indexOf('function start') >= 0 ||
      script.indexOf('async function Lpr') >= 0 ||
      script.indexOf('function Lpr') >= 0
    let hasFullConfigRoute = script.indexOf('/full-config') >= 0
    let hasSitesListRoute = script.indexOf('/sites/list') >= 0
    let defaultPort = script.indexOf('9988') >= 0 ? 9988 : 0
    let ok = hasWebsiteBundle || hasModuleExports || hasServerFactory
    return {
      ok: ok,
      hasWebsiteBundle: hasWebsiteBundle,
      hasWebsiteBundleString: hasWebsiteBundleString,
      hasModuleExports: hasModuleExports,
      hasWindow: hasWindow,
      hasServerFactory: hasServerFactory,
      hasStartFunction: hasStartFunction,
      hasFullConfigRoute: hasFullConfigRoute,
      hasSitesListRoute: hasSitesListRoute,
      defaultPort: defaultPort,
      message: this.detectMessage(ok, hasServerFactory, hasFullConfigRoute)
    }
  }

  private failed(message: string): JsDetectResult {
    return {
      ok: false,
      hasWebsiteBundle: false,
      hasWebsiteBundleString: false,
      hasModuleExports: false,
      hasWindow: false,
      hasServerFactory: false,
      hasStartFunction: false,
      hasFullConfigRoute: false,
      hasSitesListRoute: false,
      defaultPort: 0,
      message: message
    }
  }

  private detectMessage(ok: boolean, hasServerFactory: boolean, hasFullConfigRoute: boolean): string {
    if (!ok) {
      return '脚本缺少可识别的 JS bundle 特征'
    }
    if (hasServerFactory && hasFullConfigRoute) {
      return '识别为 Mira/Cat 本地 JS Server bundle'
    }
    return '脚本具备可探测的 JS bundle 特征'
  }

}
