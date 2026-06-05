/**
 * 站点配置模型 — 配置中心下发 / 本地内置
 */

// ── 单个站点的远程配置 ──
export interface SiteRemoteConfig {
  baseUrl: string
  protocol: string          // "applecms" | "html"
  adapter?: string          // 指定 CMS 适配器: "dyxs2-short" | "dyxs2-php" | "generic"
  categoryPattern?: string  // 分类页 URL 模板，{id} 占位
  listPattern?: string      // 列表页 URL 模板，{id} {pg} 占位
  searchPattern?: string    // 搜索 URL 模板，{wd} 占位
}

// ── 配置中心完整响应 ──
export interface ConfigCenterResponse {
  version: number
  updated: string
  description: string
  sites: Record<string, SiteRemoteConfig>
}

// ── 内置默认配置（随 App 发布，离线也能用）───
export const BUILTIN_CONFIG: ConfigCenterResponse = {
  version: 2,
  updated: '2026-06-04',
  description: 'CobranderTV — 开源社区域名映射（部分WexGuard私有站点缺失）',
  sites: {
    // ── 已验证 ──
    '玩偶':    { baseUrl: 'https://www.wogg.net',       protocol: 'html' },
    '新6V':   { baseUrl: 'https://www.xb6v.com',        protocol: 'html' },
    // ── 来自开源社区映射 ──
    '賤賤':   { baseUrl: 'http://api2.rinhome.com',      protocol: 'html' },
    'WexBoBo':{ baseUrl: 'https://api.nivodz.com',       protocol: 'html' },
    'WexBtTwo':{ baseUrl: 'https://api.nivodz.com',      protocol: 'html' },
    'WexDuBoKu':{ baseUrl: 'http://v.rbotv.cn',          protocol: 'html' },
    'WexIkanBot':{ baseUrl: 'https://v.ikanbot.com',     protocol: 'html' },
    'WexWenCai':{ baseUrl: 'http://cj.ffzyapi.com',      protocol: 'html' },
    'WexReBo': { baseUrl: 'http://cj.ffzyapi.com',       protocol: 'html' },
    'WexYiYs': { baseUrl: 'https://cj.lzcaiji.com',      protocol: 'html' },
    'bilibili':{ baseUrl: 'https://www.bilibili.com',    protocol: 'html' },
    'bilibiliys':{ baseUrl: 'https://www.bilibili.com',  protocol: 'html' },
    'bilixiqu':{ baseUrl: 'https://www.bilibili.com',    protocol: 'html' },
    'biliych': { baseUrl: 'https://www.bilibili.com',    protocol: 'html' },
    // ── 直播 ──
    'LiveHuYa':{ baseUrl: 'https://www.huya.com',        protocol: 'html' },
    'LiveDouYu':{ baseUrl: 'https://www.douyu.com',      protocol: 'html' },
    'LiveBiLi':{ baseUrl: 'https://live.bilibili.com',   protocol: 'html' },
    // ── 动漫 ──
    'AnimeXiFan':{ baseUrl: 'https://www.mxdm4.com',     protocol: 'html' },
    // ── 猫爪JS源码确认 ──
    '雷鲸':   { baseUrl: 'https://www.leijing1.com',     protocol: 'html' },
    'NewMuOu':{ baseUrl: 'https://666.666291.xyz',       protocol: 'html' },
    // ── 以下 WexGuard 站点域名仍在猫爪服务器的数据库中，无法从源码提取 ──
    // '二小'、'NewZhiZhen'、'NewGuanYing'、'NewJuTou'、
    // 'NewHuBan'、'NewShaYang'、'NewDuoDuo'、
    // '原盘'、'盘他'、'NewPanMe123'
  }
}

// ── 远程配置地址（设为空则仅用内置配置；填入你的 site_config.json 托管地址即可动态更新）──
export const DEFAULT_CONFIG_URL: string = ''
