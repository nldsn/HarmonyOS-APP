import { common } from '@kit.AbilityKit'
import { SiteSimple } from '../../common/model/SourceModels'
import { CacheStore } from './CacheStore'

export interface AppConfig {
  resolverBaseUrl?: string;
  sourceUrl?: string;
  resolverSourceId?: string;
  siteList?: SiteSimple[];
}

export class AppConfigStore {
  private cacheStore: CacheStore

  constructor(context: common.UIAbilityContext) {
    this.cacheStore = new CacheStore(context)
  }

  saveConfig(config: AppConfig): void {
    try {
      this.cacheStore.writeText('app_config.json', JSON.stringify(config))
    } catch (err) {
      // 忽略写入错误
    }
  }

  getConfig(): AppConfig | null {
    let text = this.cacheStore.readText('app_config.json')
    if (text.length > 0) {
      try {
        return JSON.parse(text) as AppConfig
      } catch (err) {
        return null
      }
    }
    return null
  }
}
