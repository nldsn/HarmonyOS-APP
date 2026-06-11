import { CacheStore } from './CacheStore'

/**
 * 搜索记录本地持久化 — 基于 CacheStore 读写 search_history.json
 *
 * 最近搜索置顶、去重、限制最大条数。
 */
export class SearchHistoryStore {
  private static readonly FILE: string = 'search_history.json'
  private static readonly MAX: number = 12
  private cacheStore: CacheStore

  constructor(cacheStore: CacheStore) {
    this.cacheStore = cacheStore
  }

  getHistory(): string[] {
    let text: string = this.cacheStore.readText(SearchHistoryStore.FILE, '')
    if (text.length === 0) {
      return []
    }
    try {
      let parsed = JSON.parse(text) as Object
      if (Array.isArray(parsed)) {
        let arr = parsed as Object[]
        let result: string[] = []
        for (let i = 0; i < arr.length; i++) {
          let value: string = String(arr[i]).trim()
          if (value.length > 0) {
            result.push(value)
          }
        }
        return result
      }
    } catch (err) {
      // 解析失败视为无记录
    }
    return []
  }

  // 新增一条记录，最近搜索置顶、去重，返回更新后的列表
  addKeyword(keyword: string): string[] {
    let kw: string = keyword.trim()
    if (kw.length === 0) {
      return this.getHistory()
    }
    let current: string[] = this.getHistory()
    let next: string[] = [kw]
    for (let i = 0; i < current.length; i++) {
      if (current[i] !== kw && next.length < SearchHistoryStore.MAX) {
        next.push(current[i])
      }
    }
    this.save(next)
    return next
  }

  removeKeyword(keyword: string): string[] {
    let current: string[] = this.getHistory()
    let next: string[] = []
    for (let i = 0; i < current.length; i++) {
      if (current[i] !== keyword) {
        next.push(current[i])
      }
    }
    this.save(next)
    return next
  }

  clear(): void {
    this.save([])
  }

  private save(list: string[]): void {
    try {
      this.cacheStore.writeText(SearchHistoryStore.FILE, JSON.stringify(list))
    } catch (err) {
      // 忽略写入错误
    }
  }
}
