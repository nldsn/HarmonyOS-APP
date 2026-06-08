import { webview } from '@kit.ArkWeb'

@Component
export struct JsSandboxView {
  @State private ready: boolean = false
  @StorageLink('jsSandboxScript') script: string = ''
  @StorageLink('jsSandboxCommand') command: string = ''
  @StorageLink('jsSandboxResult') result: string = ''
  @StorageLink('jsSandboxState') state: string = 'idle'
  private controller: webview.WebviewController = new webview.WebviewController()
  private timerId: number = -1
  private chunkSize: number = 32768

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  isReady(): boolean {
    return this.ready
  }

  async run(script: string): Promise<string> {
    if (!this.ready || script.length === 0) {
      return ''
    }
    let result = await this.controller.runJavaScript(script)
    if (typeof result === 'string') {
      return result
    }
    return result.toString()
  }

  private startPolling(): void {
    if (this.timerId >= 0) {
      return
    }
    this.timerId = setInterval(() => {
      this.handleCommand()
    }, 300)
  }

  private async handleCommand(): Promise<void> {
    if (!this.ready || this.command.length === 0) {
      return
    }
    let currentCommand = this.command
    this.command = ''
    if (currentCommand === 'load') {
      await this.loadCachedScript()
    } else if (currentCommand === 'probe') {
      await this.runProbe()
    }
  }

  private async loadCachedScript(): Promise<void> {
    if (this.script.length === 0) {
      this.state = 'missing_script'
      this.result = ''
      return
    }
    this.state = 'loading'
    try {
      this.result = ''
      await this.run('window.CobranderSandbox.resetBundle()')
      this.state = 'injecting'
      await this.appendScriptChunks()
      this.state = 'evaluating'
      let loadOutput = await this.run('window.CobranderSandbox.evaluateBundle()')
      let probeOutput = await this.run('window.CobranderSandbox.serverProbe()')
      this.result = 'load=' + loadOutput + '\nprobe=' + probeOutput
      this.state = 'probed'
    } catch (err) {
      this.result = this.errorText(err)
      this.state = 'error'
    }
  }

  private async appendScriptChunks(): Promise<void> {
    let total = this.script.length
    let offset = 0
    while (offset < total) {
      let end = offset + this.chunkSize
      if (end > total) {
        end = total
      }
      let chunk = this.script.substring(offset, end)
      await this.run('window.CobranderSandbox.appendBundle(' + this.quoteForJavaScript(chunk) + ')')
      offset = end
      this.state = 'injecting ' + offset.toString() + '/' + total.toString()
    }
  }

  private async runProbe(): Promise<void> {
    this.state = 'probing'
    try {
      let output = await this.run('window.CobranderSandbox.serverProbe()')
      this.result = output
      this.state = 'probed'
    } catch (err) {
      this.result = this.errorText(err)
      this.state = 'error'
    }
  }

  private errorText(err: Object): string {
    if (err instanceof Error && err.message.length > 0) {
      return err.message
    }
    return 'JS 沙箱执行失败'
  }

  private quoteForJavaScript(script: string): string {
    let quoted = '\''
    for (let i = 0; i < script.length; i++) {
      let ch = script.charAt(i)
      if (ch === '\\') {
        quoted += '\\\\'
      } else if (ch === '\'') {
        quoted += '\\\''
      } else if (ch === '\n') {
        quoted += '\\n'
      } else if (ch === '\r') {
        quoted += '\\r'
      } else if (ch === '\t') {
        quoted += '\\t'
      } else {
        quoted += ch
      }
    }
    quoted += '\''
    return quoted
  }

  build() {
    Web({ src: $rawfile('js_sandbox.html'), controller: this.controller })
      .width(1)
      .height(1)
      .opacity(0.01)
      .onPageEnd(() => {
        this.ready = true
        this.state = 'ready'
        this.startPolling()
      })
      .onErrorReceive(() => {
        this.ready = false
        this.state = 'error'
      })
  }
}
