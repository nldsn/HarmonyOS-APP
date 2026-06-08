import { fileIo } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { util } from '@kit.ArkTS'

export class CacheStore {
  private context: common.UIAbilityContext
  private rootDir: string

  constructor(context: common.UIAbilityContext) {
    this.context = context
    this.rootDir = this.context.filesDir + '/source_cache'
    this.ensureDir(this.rootDir)
  }

  readText(relativePath: string, fallback: string = ''): string {
    let path = this.pathOf(relativePath)
    try {
      if (!fileIo.accessSync(path)) {
        return fallback
      }
      let file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY)
      try {
        let stat = fileIo.statSync(path)
        let buffer = new ArrayBuffer(stat.size)
        fileIo.readSync(file.fd, buffer)
        return this.bufferToString(buffer)
      } finally {
        fileIo.closeSync(file.fd)
      }
    } catch (err) {
      return fallback
    }
  }

  writeText(relativePath: string, content: string): void {
    let path = this.pathOf(relativePath)
    this.removeIfExists(path)
    let file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY)
    try {
      fileIo.writeSync(file.fd, content)
    } finally {
      fileIo.closeSync(file.fd)
    }
  }

  private pathOf(relativePath: string): string {
    return this.rootDir + '/' + relativePath
  }

  private ensureDir(path: string): void {
    try {
      if (!fileIo.accessSync(path)) {
        fileIo.mkdirSync(path)
      }
    } catch (err) {
      fileIo.mkdirSync(path)
    }
  }

  private removeIfExists(path: string): void {
    try {
      if (fileIo.accessSync(path)) {
        fileIo.unlinkSync(path)
      }
    } catch (err) {
    }
  }

  private bufferToString(buffer: ArrayBuffer): string {
    let decoder = util.TextDecoder.create('utf-8')
    return decoder.decodeToString(new Uint8Array(buffer))
  }
}
