import { JsDetectResult, JsRuntimeInfo } from '../../common/model/BridgeModels'

export class JsRuntimeHost {
  private runtimeInfo: JsRuntimeInfo | null = null
  private detectResult: JsDetectResult | null = null
  private ready: boolean = false

  markReady(info: JsRuntimeInfo, detectResult: JsDetectResult): void {
    this.runtimeInfo = info
    this.detectResult = detectResult
    this.ready = true
  }

  markNotReady(): void {
    this.runtimeInfo = null
    this.detectResult = null
    this.ready = false
  }

  isReady(): boolean {
    return this.ready
  }

  getRuntimeInfo(): JsRuntimeInfo | null {
    return this.runtimeInfo
  }

  getDetectResult(): JsDetectResult | null {
    return this.detectResult
  }
}
