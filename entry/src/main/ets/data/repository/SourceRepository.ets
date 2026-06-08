import { CacheStore } from '../storage/CacheStore'
import { SourceDescriptor, SourceProtocol, SourceStatus } from '../../common/model/SourceModels'

export class SourceRepository {
  private static readonly META_FILE: string = 'current_source.meta'
  private static readonly SCRIPT_FILE: string = 'current_index.js'
  private cacheStore: CacheStore

  constructor(cacheStore: CacheStore) {
    this.cacheStore = cacheStore
  }

  saveSource(descriptor: SourceDescriptor, scriptContent: string): void {
    this.cacheStore.writeText(SourceRepository.SCRIPT_FILE, scriptContent)
    this.cacheStore.writeText(SourceRepository.META_FILE, this.serialize(descriptor))
  }

  getCurrentSource(): SourceDescriptor | null {
    let content = this.cacheStore.readText(SourceRepository.META_FILE, '')
    if (content.length === 0) {
      return null
    }
    return this.deserialize(content)
  }

  getCurrentScript(): string {
    return this.cacheStore.readText(SourceRepository.SCRIPT_FILE, '')
  }

  private serialize(descriptor: SourceDescriptor): string {
    let lines: string[] = []
    lines.push(descriptor.id)
    lines.push(descriptor.name)
    lines.push(descriptor.inputUrl)
    lines.push(descriptor.manifestUrl)
    lines.push(descriptor.scriptUrl)
    lines.push(descriptor.protocol)
    lines.push(descriptor.md5)
    lines.push(descriptor.scriptSize.toString())
    lines.push(descriptor.cachedAt.toString())
    lines.push(descriptor.status)
    lines.push(descriptor.message)
    return lines.join('\n')
  }

  private deserialize(content: string): SourceDescriptor {
    let lines = content.split('\n')
    return {
      id: this.lineAt(lines, 0),
      name: this.lineAt(lines, 1),
      inputUrl: this.lineAt(lines, 2),
      manifestUrl: this.lineAt(lines, 3),
      scriptUrl: this.lineAt(lines, 4),
      protocol: this.lineAt(lines, 5, SourceProtocol.UNKNOWN),
      md5: this.lineAt(lines, 6),
      scriptSize: Number(this.lineAt(lines, 7, '0')),
      cachedAt: Number(this.lineAt(lines, 8, '0')),
      status: this.lineAt(lines, 9, SourceStatus.FAILED),
      message: this.lineAt(lines, 10)
    }
  }

  private lineAt(lines: string[], index: number, fallback: string = ''): string {
    if (index < lines.length) {
      return lines[index]
    }
    return fallback
  }
}
