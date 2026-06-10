import { PanCookieProfile } from '../../common/model/PanModels'
import { CacheStore } from './CacheStore'

export class PanCookieStore {
  private static readonly PROFILE_FILE: string = 'pan_cookie.profile'
  private cacheStore: CacheStore

  constructor(cacheStore: CacheStore) {
    this.cacheStore = cacheStore
  }

  saveProfile(profile: PanCookieProfile): void {
    let lines: string[] = []
    lines.push(profile.ok ? '1' : '0')
    lines.push(profile.hasQuark ? '1' : '0')
    lines.push(profile.quarkUpdatedAt)
    lines.push(profile.message)
    lines.push(profile.quarkCookie)
    this.cacheStore.writeText(PanCookieStore.PROFILE_FILE, lines.join('\n'))
  }

  getProfile(): PanCookieProfile {
    let content: string = this.cacheStore.readText(PanCookieStore.PROFILE_FILE, '')
    if (content.length === 0) {
      return this.emptyProfile()
    }
    let lines: string[] = content.split('\n')
    return {
      ok: this.lineAt(lines, 0) === '1',
      hasQuark: this.lineAt(lines, 1) === '1',
      quarkUpdatedAt: this.lineAt(lines, 2),
      message: this.lineAt(lines, 3),
      quarkCookie: this.lineAt(lines, 4)
    }
  }

  getQuarkCookie(): string {
    let profile: PanCookieProfile = this.getProfile()
    if (profile.hasQuark) {
      return profile.quarkCookie
    }
    return ''
  }

  private emptyProfile(): PanCookieProfile {
    return {
      ok: true,
      hasQuark: false,
      quarkCookie: '',
      quarkUpdatedAt: '',
      message: '未同步网盘账号'
    }
  }

  private lineAt(lines: string[], index: number): string {
    if (index >= 0 && index < lines.length) {
      return lines[index]
    }
    return ''
  }
}
