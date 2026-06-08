import { HttpClient } from '../data/http/HttpClient'
import { SourceRepository } from '../data/repository/SourceRepository'
import {
  SourceDescriptor,
  SourceLoadRequest,
  SourceLoadResult,
  SourceProtocol,
  SourceStatus
} from '../common/model/SourceModels'

export class SourceManager {
  private httpClient: HttpClient
  private repository: SourceRepository

  constructor(httpClient: HttpClient, repository: SourceRepository) {
    this.httpClient = httpClient
    this.repository = repository
  }

  async loadSource(request: SourceLoadRequest): Promise<SourceLoadResult> {
    let normalizedUrl = request.inputUrl.trim()
    if (normalizedUrl.length === 0) {
      throw new Error('请输入订阅源地址')
    }

    let md5Url = this.resolveMd5Url(normalizedUrl)
    let scriptUrl = this.resolveScriptUrl(normalizedUrl)
    let md5Response = await this.httpClient.getText(md5Url)
    if (md5Response.statusCode < 200 || md5Response.statusCode >= 300) {
      throw new Error('MD5 文件请求失败: ' + md5Response.statusCode.toString())
    }

    let md5 = this.normalizeMd5(md5Response.body)
    if (md5.length === 0) {
      throw new Error('MD5 内容为空')
    }

    let current = this.repository.getCurrentSource()
    let currentScript = this.repository.getCurrentScript()
    if (current !== null && current.md5 === md5 && currentScript.length > 0) {
      return {
        descriptor: current,
        changed: false
      }
    }

    let scriptResponse = await this.httpClient.getText(scriptUrl, 30000)
    if (scriptResponse.statusCode < 200 || scriptResponse.statusCode >= 300) {
      throw new Error('JS 文件请求失败: ' + scriptResponse.statusCode.toString())
    }

    if (!this.looksLikeMiraBundle(scriptResponse.body)) {
      throw new Error('JS 文件未识别到 Mira/Cat bundle 特征')
    }

    let descriptor: SourceDescriptor = {
      id: this.makeSourceId(scriptUrl),
      name: this.resolveDisplayName(request.displayName, scriptUrl),
      inputUrl: normalizedUrl,
      manifestUrl: md5Url,
      scriptUrl: scriptUrl,
      protocol: SourceProtocol.MIRA_CAT_JS,
      md5: md5,
      scriptSize: scriptResponse.body.length,
      cachedAt: new Date().getTime(),
      status: SourceStatus.READY,
      message: 'JS 订阅源已缓存，等待协议探测'
    }
    this.repository.saveSource(descriptor, scriptResponse.body)
    return {
      descriptor: descriptor,
      changed: true
    }
  }

  getCurrentSource(): SourceDescriptor | null {
    return this.repository.getCurrentSource()
  }

  private resolveMd5Url(inputUrl: string): string {
    if (inputUrl.endsWith('.md5')) {
      return inputUrl
    }
    if (inputUrl.endsWith('.js')) {
      return inputUrl + '.md5'
    }
    return inputUrl
  }

  private resolveScriptUrl(inputUrl: string): string {
    if (inputUrl.endsWith('.md5')) {
      return inputUrl.substring(0, inputUrl.length - 4)
    }
    return inputUrl
  }

  private normalizeMd5(content: string): string {
    let trimmed = content.trim()
    let fromByteText = this.decodeByteText(trimmed)
    if (fromByteText.length > 0) {
      trimmed = fromByteText
    }
    let compact = ''
    for (let i = 0; i < trimmed.length; i++) {
      let ch = trimmed.charAt(i)
      if (ch !== ' ' && ch !== '\n' && ch !== '\r' && ch !== '\t') {
        compact += ch
      }
    }
    return compact
  }

  private decodeByteText(content: string): string {
    let parts = this.splitWhitespace(content)
    if (parts.length < 32) {
      return ''
    }
    let decoded = ''
    for (let i = 0; i < parts.length; i++) {
      let token = parts[i].trim()
      if (token.length === 0) {
        continue
      }
      let code = Number(token)
      if (code < 32 || code > 126) {
        return ''
      }
      decoded += String.fromCharCode(code)
    }
    return decoded
  }

  private splitWhitespace(content: string): string[] {
    let parts: string[] = []
    let current = ''
    for (let i = 0; i < content.length; i++) {
      let ch = content.charAt(i)
      if (ch === ' ' || ch === '\n' || ch === '\r' || ch === '\t') {
        if (current.length > 0) {
          parts.push(current)
          current = ''
        }
      } else {
        current += ch
      }
    }
    if (current.length > 0) {
      parts.push(current)
    }
    return parts
  }

  private looksLikeMiraBundle(content: string): boolean {
    return content.indexOf('globalThis.websiteBundle') >= 0 ||
      content.indexOf('websiteBundle') >= 0 ||
      content.indexOf('module.exports') >= 0
  }

  private makeSourceId(scriptUrl: string): string {
    let hash = 0
    for (let i = 0; i < scriptUrl.length; i++) {
      hash = ((hash * 31) + scriptUrl.charCodeAt(i)) % 2147483647
    }
    return 'source_' + hash.toString()
  }

  private resolveDisplayName(displayName: string, scriptUrl: string): string {
    let trimmedName = displayName.trim()
    if (trimmedName.length > 0) {
      return trimmedName
    }
    return scriptUrl
  }
}
