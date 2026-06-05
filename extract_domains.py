#!/usr/bin/env python3
"""
WexGuard 站点域名提取脚本
============================
方案：Android 模拟器 + mitmproxy 流量抓取

前置准备：
  1. 安装 Android Studio 或 MuMu 模拟器
  2. 模拟器中安装 OK影视 APK
  3. pip install mitmproxy

步骤：
  1. 启动 mitmproxy:  mitmweb --listen-port 8080
  2. 模拟器设置 WiFi 代理 → PC_IP:8080
  3. 模拟器浏览器访问 mitm.it 安装证书
  4. 打开 OK影视 → 导入数据源 → 逐个点进 4K 站点
  5. mitmweb 界面里能看到所有请求的域名
  6. 把域名列表导出，填入 site_config.json

一键脚本（本文件）：解析 mitmproxy 导出的流量文件
"""

import json
import sys
import re
from collections import Counter
from urllib.parse import urlparse


def parse_mitmproxy_dump(filepath: str) -> list[str]:
    """从 mitmproxy 导出的流量文件中提取所有域名"""
    domains: Counter = Counter()

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 匹配 mitmproxy flow 格式
    # 也支持直接粘贴浏览器 Network 面板的 HAR 文件
    try:
        har = json.loads(content)
        if 'log' in har:  # HAR format
            for entry in har['log']['entries']:
                url = entry['request']['url']
                domain = urlparse(url).netloc
                if domain and not is_noise(domain):
                    domains[domain] += 1
    except json.JSONDecodeError:
        # 纯文本格式：每行一个 URL
        urls = re.findall(r'https?://[^\s"\'<>]+', content)
        for url in urls:
            domain = urlparse(url).netloc
            if domain and not is_noise(domain):
                domains[domain] += 1

    return [d for d, _ in domains.most_common(100)]


def is_noise(domain: str) -> bool:
    """过滤非站点域名（CDN、统计、广告等）"""
    noise_patterns = [
        'google', 'gtag', 'gstatic', 'doubleclick',
        'baidu.com', 'bdstatic', 'bcebos',
        'github', 'cdn', 'cloudflare',
        'mmstat', 'umeng', 'cnzz',
        'alicdn', 'alipay', 'taobao',
        'qq.com', 'weixin', 'wechat',
        'apple', 'icloud', 'microsoft',
        'android', 'googleapis',
        'firebase', 'crashlytics',
        'hls', 'm3u8', 'ts', 'segment',
    ]
    return any(p in domain.lower() for p in noise_patterns)


def guess_site_mapping(domains: list[str]) -> dict[str, str]:
    """根据域名特征推测站点名称"""
    mapping = {}
    # 已知的 WexGuard 4K 站点关键字
    keywords = {
        'erxiao': '二小', 'wogg': '玩偶', 'zhizhen': '至臻',
        'guanying': '观影', 'jutou': '剧透', 'huban': '虎斑',
        'shayang': '傻样', 'muou': '木偶', 'duoduo': '多多',
        '4kzn': '原盘', 'leijing': '雷鲸', 'panta': '盘他',
        'panme123': 'NewPanMe123',
    }

    for domain in domains:
        host = domain.split(':')[0].split('.')[0]  # 取主域名部分
        for keyword, name in keywords.items():
            if keyword.lower() in host.lower():
                mapping[name] = f'https://{domain}'
                break

    return mapping


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        print("\n用法:")
        print("  python extract_domains.py <流量文件>")
        print("\n流量文件可以是:")
        print("  - mitmproxy 导出的 HAR/JSON 文件")
        print("  - Chrome DevTools Network 面板导出的 HAR")
        print("  - 包含 URL 列表的文本文件")
        print("\n或直接粘贴 URL 列表到标准输入")
        return

    filepath = sys.argv[1]
    domains = parse_mitmproxy_dump(filepath)

    print(f"\n找到 {len(domains)} 个域名:\n")
    for d in domains:
        print(f"  {d}")

    # 尝试推测站点映射
    mapping = guess_site_mapping(domains)
    if mapping:
        print(f"\n推测站点映射 ({len(mapping)} 个):\n")
        print(json.dumps(mapping, ensure_ascii=False, indent=2))

        print("\n--- 可直接粘贴到 site_config.json 的 sites 部分 ---\n")
        for name, url in mapping.items():
            print(f'    "{name}": {{"baseUrl": "{url}", "protocol": "html"}},')


if __name__ == '__main__':
    main()
