import crypto from 'node:crypto';
import fs from 'node:fs';
import http from 'node:http';
import { createRequire } from 'node:module';
import os from 'node:os';
import path from 'node:path';
import { Readable } from 'node:stream';

const VERSION = '0.6.0';
const PORT = Number(process.env.PORT || 8787);
const PROFILE_FILE = path.resolve(process.cwd(), 'db.json');
const sources = new Map();
const runtimes = new Map();
const siteInitPromises = new Map();

function sendJson(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS'
  });
  res.end(body);
}

function sendError(res, statusCode, message) {
  sendJson(res, statusCode, { ok: false, message });
}

function readLocalProfile() {
  try {
    if (!fs.existsSync(PROFILE_FILE)) {
      return {};
    }
    const text = fs.readFileSync(PROFILE_FILE, 'utf8');
    if (text.trim().length === 0) {
      return {};
    }
    return JSON.parse(text);
  } catch (_err) {
    return {};
  }
}

function localProfileSummary() {
  const profile = readLocalProfile();
  const quark = isPlainObject(profile.quark) ? profile.quark : {};
  let quarkCookie = '';
  for (const key of Object.keys(quark)) {
    const value = quark[key];
    if (key !== 'qktime' && typeof value === 'string' && value.includes('__puus=')) {
      quarkCookie = value;
      break;
    }
  }
  return {
    ok: true,
    hasQuark: quarkCookie.length > 0,
    quarkCookie,
    quarkUpdatedAt: typeof quark.qktime === 'string' ? quark.qktime : '',
    message: quarkCookie.length > 0 ? 'profile loaded' : 'quark cookie not found'
  };
}

async function readJson(req) {
  let body = '';
  for await (const chunk of req) {
    body += chunk.toString('utf8');
  }
  if (body.trim().length === 0) {
    return {};
  }
  return JSON.parse(body);
}

async function readBodyBuffer(req) {
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  return Buffer.concat(chunks);
}

function withBasicAuth(urlText) {
  const parsed = new URL(urlText);
  const headers = {};
  if (parsed.username.length > 0 || parsed.password.length > 0) {
    const username = decodeURIComponent(parsed.username);
    const password = decodeURIComponent(parsed.password);
    const token = Buffer.from(`${username}:${password}`, 'utf8').toString('base64');
    headers.Authorization = `Basic ${token}`;
    parsed.username = '';
    parsed.password = '';
  }
  return {
    url: parsed.toString(),
    headers
  };
}

async function fetchText(urlText) {
  const request = withBasicAuth(urlText);
  const response = await fetch(request.url, {
    headers: {
      'User-Agent': 'CobranderResolver/0.1',
      ...request.headers
    }
  });
  const text = await response.text();
  return {
    status: response.status,
    text
  };
}

function resolveMd5Url(inputUrl) {
  if (inputUrl.endsWith('.md5')) {
    return inputUrl;
  }
  if (inputUrl.endsWith('.js')) {
    return `${inputUrl}.md5`;
  }
  return inputUrl;
}

function resolveScriptUrl(inputUrl) {
  if (inputUrl.endsWith('.md5')) {
    return inputUrl.slice(0, -4);
  }
  return inputUrl;
}

function normalizeMd5(text) {
  const compact = text.trim().replace(/\s+/g, '');
  if (/^\d+(\s+\d+)*$/.test(text.trim()) && text.trim().includes(' ')) {
    const chars = text.trim().split(/\s+/).map((part) => Number(part));
    if (chars.length >= 32 && chars.every((code) => code >= 32 && code <= 126)) {
      return String.fromCharCode(...chars).trim();
    }
  }
  return compact;
}

function detectScript(script) {
  return {
    hasWebsiteBundle: script.includes('websiteBundle'),
    hasModuleExports: script.includes('module.exports'),
    hasWindowAccess: script.includes('window.'),
    hasServerFactory: script.includes('catServerFactory'),
    hasFullConfigRoute: script.includes('/full-config'),
    hasSitesListRoute: script.includes('/sites/list'),
    defaultPort: script.includes('9988') ? 9988 : 0
  };
}

function sourceIdFor(scriptUrl) {
  return `source_${crypto.createHash('sha1').update(scriptUrl).digest('hex').slice(0, 16)}`;
}

function ensureWorkDir(sourceId) {
  const dir = path.join(os.tmpdir(), 'cobrander-resolver', sourceId);
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}

function installCatGlobals(sourceId) {
  const pending = {
    sourceId,
    server: null,
    module: null,
    resolve: null,
    reject: null,
    promise: null
  };
  pending.promise = new Promise((resolve, reject) => {
    pending.resolve = resolve;
    pending.reject = reject;
  });
  globalThis.catServerFactory = (handle) => {
    const server = http.createServer((req, res) => {
      handle(req, res);
    });
    pending.server = server;
    server.once('listening', () => {
      const address = server.address();
      if (address && typeof address === 'object') {
        pending.resolve({
          sourceId,
          server,
          module: pending.module,
          port: address.port,
          baseUrl: `http://127.0.0.1:${address.port}`
        });
      } else {
        pending.reject(new Error('Runtime address is unavailable'));
      }
    });
    server.once('error', (err) => {
      pending.reject(err instanceof Error ? err : new Error('Runtime server error'));
    });
    return server;
  };
  globalThis.catDartServerPort = () => 0;
  return pending;
}

async function writeRuntimeBundle(source) {
  const workDir = ensureWorkDir(source.result.sourceId);
  const bundlePath = path.join(workDir, 'index.cjs');
  fs.writeFileSync(bundlePath, source.script, 'utf8');
  return bundlePath;
}

function createRuntimeConfig(source) {
  const config = {
    color: [],
    sites: {
      list: []
    },
    pans: {
      list: []
    }
  };
  deepMerge(config, inferRuntimeConfigFromScript(source.script));
  deepMerge(config, normalizeParsedSourceConfig(source.parsedConfig));
  return config;
}

function inferRuntimeConfigFromScript(script) {
  const config = {};
  const namespaceFields = new Map();
  const dbNamespaces = collectDbBackedNamespaces(script);
  collectConfigAccess(namespaceFields, script);
  collectWebsiteConfigRoutes(namespaceFields, script);
  for (const [namespace, fields] of namespaceFields) {
    const section = {};
    let hasMaterializedField = false;
    for (const field of fields) {
      if (shouldMaterializeRuntimeField(namespace, field)) {
        section[field] = defaultRuntimeFieldValue(field);
        hasMaterializedField = true;
      }
    }
    if (hasMaterializedField || dbNamespaces.has(namespace) || fields.has('__dynamic__')) {
      config[namespace] = section;
    }
  }
  return config;
}

function collectWebsiteConfigRoutes(namespaceFields, script) {
  const routePattern = /\b(?:cacheUrl|api)\s*:\s*\\?"\/([^\/"\\]+)\/([^"\\]+)\\?"/g;
  let match = routePattern.exec(script);
  while (match !== null) {
    const namespace = match[1];
    const field = match[2];
    for (const alias of routeNamespaceAliases(namespace)) {
      addConfigField(namespaceFields, alias, field);
    }
    match = routePattern.exec(script);
  }
}

function routeNamespaceAliases(namespace) {
  const aliases = [];
  addUniqueText(aliases, namespace);
  const dashIndex = namespace.indexOf('-');
  if (dashIndex > 0) {
    addUniqueText(aliases, namespace.slice(0, dashIndex));
    addUniqueText(aliases, toCamelIdentifier(namespace));
  }
  if (/^\d/.test(namespace)) {
    addUniqueText(aliases, `y${namespace}`);
  }
  return aliases;
}

function toCamelIdentifier(value) {
  return value.replace(/[-_]+([A-Za-z0-9])/g, (_match, letter) => String(letter).toUpperCase());
}

function addUniqueText(values, value) {
  if (value.length > 0 && !values.includes(value)) {
    values.push(value);
  }
}

function collectDbBackedNamespaces(script) {
  const namespaces = new Set();
  const pattern = /\bdb\.(?:getObjectDefault|getData|push|delete|exists)\(\s*[`'"]\/([A-Za-z0-9_$-]+)/g;
  let match = pattern.exec(script);
  while (match !== null) {
    namespaces.add(match[1]);
    match = pattern.exec(script);
  }
  return namespaces;
}

function collectConfigAccess(namespaceFields, script) {
  const fieldPatterns = [
    /\.config\.([A-Za-z_$][\w$]*)\.([A-Za-z_$][\w$]*)/g,
    /\bconfig\.([A-Za-z_$][\w$]*)\.([A-Za-z_$][\w$]*)/g
  ];
  for (const pattern of fieldPatterns) {
    let match = pattern.exec(script);
    while (match !== null) {
      addConfigField(namespaceFields, match[1], match[2]);
      match = pattern.exec(script);
    }
  }

  const namespacePatterns = [
    /\.config\.([A-Za-z_$][\w$]*)\s*\[/g,
    /\bconfig\.([A-Za-z_$][\w$]*)\s*\[/g,
    /\.config\.([A-Za-z_$][\w$]*)\?\./g,
    /\bconfig\.([A-Za-z_$][\w$]*)\?\./g
  ];
  for (const pattern of namespacePatterns) {
    let match = pattern.exec(script);
    while (match !== null) {
      addConfigField(namespaceFields, match[1], '__dynamic__');
      match = pattern.exec(script);
    }
  }
}

function addConfigField(namespaceFields, namespace, field) {
  const fields = ensureConfigNamespace(namespaceFields, namespace);
  fields.add(field);
}

function ensureConfigNamespace(namespaceFields, namespace) {
  if (!namespaceFields.has(namespace)) {
    namespaceFields.set(namespace, new Set());
  }
  return namespaceFields.get(namespace);
}

function shouldMaterializeRuntimeField(namespace, field) {
  if ((namespace === 'sites' || namespace === 'pans' || namespace === 'cms' || namespace === 't4') && field === 'list') {
    return true;
  }
  if (field === 'url' || field === 'cookie' || field === 'token' || field === 'token280' ||
    field === 'ut' || field === 'refreshtoken' || field === 'refreshToken') {
    return true;
  }
  return false;
}

function defaultRuntimeFieldValue(field) {
  if (field === 'list') {
    return [];
  }
  return '';
}

function normalizeParsedSourceConfig(parsedConfig) {
  if (!isPlainObject(parsedConfig)) {
    return {};
  }
  const config = deepClone(parsedConfig);
  if (Array.isArray(config.sites)) {
    config.sites = {
      list: config.sites
    };
  }
  if (Array.isArray(config.pans)) {
    config.pans = {
      list: config.pans
    };
  }
  if (!Array.isArray(config.color)) {
    config.color = [];
  }
  return config;
}

function parseSourceConfig(script) {
  const trimmed = script.trim();
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
    return {};
  }
  try {
    const parsed = JSON.parse(trimmed);
    return isPlainObject(parsed) ? parsed : {};
  } catch (_err) {
    return {};
  }
}

function deepMerge(target, source) {
  if (!isPlainObject(source)) {
    return target;
  }
  for (const key of Object.keys(source)) {
    const value = source[key];
    if (isPlainObject(value)) {
      if (!isPlainObject(target[key])) {
        target[key] = {};
      }
      deepMerge(target[key], value);
    } else {
      target[key] = deepClone(value);
    }
  }
  return target;
}

function deepClone(value) {
  if (Array.isArray(value)) {
    return value.map((item) => deepClone(item));
  }
  if (isPlainObject(value)) {
    const cloned = {};
    for (const key of Object.keys(value)) {
      cloned[key] = deepClone(value[key]);
    }
    return cloned;
  }
  return value;
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

async function startSourceRuntime(sourceId) {
  const existing = runtimes.get(sourceId);
  if (existing) {
    return existing;
  }
  const source = sources.get(sourceId);
  if (!source) {
    throw new Error(`Source not inspected: ${sourceId}`);
  }

  const pending = installCatGlobals(sourceId);
  const bundlePath = await writeRuntimeBundle(source);
  const requireBundle = createRequire(bundlePath);
  const cacheKey = requireBundle.resolve(bundlePath);
  delete requireBundle.cache[cacheKey];
  const loaded = requireBundle(bundlePath);
  pending.module = loaded;
  if (typeof loaded.start !== 'function') {
    throw new Error('Bundle missing start(config) export');
  }
  const previousRuntimePort = process.env.DEV_HTTP_PORT;
  process.env.DEV_HTTP_PORT = '0';
  try {
    await loaded.start(createRuntimeConfig(source));
  } finally {
    if (previousRuntimePort === undefined) {
      delete process.env.DEV_HTTP_PORT;
    } else {
      process.env.DEV_HTTP_PORT = previousRuntimePort;
    }
  }
  const runtime = await waitForRuntime(pending);
  runtimes.set(sourceId, runtime);
  return runtime;
}

async function waitForRuntime(pending) {
  const runtime = await Promise.race([
    pending.promise,
    sleep(12000).then(() => {
      throw new Error('Runtime start timeout');
    })
  ]);
  const health = await requestRuntimeJson(runtime.port, '/check');
  if (health.ok && health.data && health.data.run === true) {
    return runtime;
  }
  return runtime;
}

async function requestRuntimeJson(port, pathname) {
  try {
    const response = await fetch(`http://127.0.0.1:${port}${pathname}`, {
      signal: AbortSignal.timeout(80)
    });
    if (!response.ok) {
      return { ok: false, data: null };
    }
    return {
      ok: true,
      data: await response.json()
    };
  } catch (_err) {
    return { ok: false, data: null };
  }
}

function sleep(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

async function sourceSites(sourceId) {
  const data = await runtimeConfig(sourceId);
  const config = data.config;
  const sites = normalizeSites(config);
  const source = sources.get(sourceId);
  if (source) {
    source.result.sites = sites;
  }
  return {
    ok: true,
    sourceId,
    runtimeUrl: data.runtime.baseUrl,
    sites
  };
}

async function runtimeConfig(sourceId) {
  const runtime = await startSourceRuntime(sourceId);
  const response = await fetch(`${runtime.baseUrl}/config`);
  if (!response.ok) {
    throw new Error(`Runtime config failed: ${response.status}`);
  }
  const config = await response.json();
  return {
    runtime,
    config
  };
}

function normalizeSites(config) {
  const result = [];
  appendSites(result, 'video', config.video && config.video.sites ? config.video.sites : []);
  appendSites(result, 'read', config.read && config.read.sites ? config.read.sites : []);
  appendSites(result, 'comic', config.comic && config.comic.sites ? config.comic.sites : []);
  appendSites(result, 'music', config.music && config.music.sites ? config.music.sites : []);
  appendSites(result, 'pan', config.pan && config.pan.sites ? config.pan.sites : []);
  return result;
}

function appendSites(result, group, sites) {
  for (let index = 0; index < sites.length; index++) {
    const site = sites[index];
    const key = String(site.key || site.api || site.name || '');
    result.push({
      key: siteRuntimeId(group, index, key),
      name: String(site.name || site.key || site.api || '')
    });
  }
}

function findRuntimeSite(config, siteKey) {
  const groups = runtimeSiteGroups(config);
  const siteId = parseSiteRuntimeId(siteKey);
  if (siteId) {
    for (const group of groups) {
      if (group.name === siteId.group && siteId.index >= 0 && siteId.index < group.sites.length) {
        const site = group.sites[siteId.index];
        const key = String(site.key || site.api || site.name || '');
        if (key === siteId.key || siteId.key.length === 0) {
          return site;
        }
      }
    }
  }
  for (const group of groups) {
    for (const site of group.sites) {
      if (String(site.key || '') === siteKey || String(site.api || '') === siteKey || String(site.name || '') === siteKey) {
        return site;
      }
    }
  }
  return null;
}

function runtimeSiteGroups(config) {
  return [
    { name: 'video', sites: config.video && config.video.sites ? config.video.sites : [] },
    { name: 'read', sites: config.read && config.read.sites ? config.read.sites : [] },
    { name: 'comic', sites: config.comic && config.comic.sites ? config.comic.sites : [] },
    { name: 'music', sites: config.music && config.music.sites ? config.music.sites : [] },
    { name: 'pan', sites: config.pan && config.pan.sites ? config.pan.sites : [] }
  ];
}

function siteRuntimeId(group, index, key) {
  return `${group}@${index}@${key}`;
}

function parseSiteRuntimeId(value) {
  const text = String(value || '');
  const first = text.indexOf('@');
  const second = text.indexOf('@', first + 1);
  if (first <= 0 || second <= first) {
    return null;
  }
  const index = Number(text.slice(first + 1, second));
  if (!Number.isInteger(index)) {
    return null;
  }
  return {
    group: text.slice(0, first),
    index,
    key: text.slice(second + 1)
  };
}

function matchSiteRoute(pathname) {
  const parts = pathname.split('/');
  if (parts.length !== 7 || parts[1] !== 'api' || parts[2] !== 'source' || parts[4] !== 'site') {
    return null;
  }
  const action = decodeURIComponent(parts[6]);
  if (!['home', 'category', 'detail', 'play', 'search'].includes(action)) {
    return null;
  }
  return {
    sourceId: decodeURIComponent(parts[3]),
    siteKey: decodeURIComponent(parts[5]),
    action
  };
}

function matchProxyRoute(pathname) {
  const parts = pathname.split('/');
  if (parts.length !== 5 || parts[1] !== 'api' || parts[2] !== 'source' || parts[4] !== 'proxy') {
    return null;
  }
  return {
    sourceId: decodeURIComponent(parts[3])
  };
}

function matchRuntimeRoute(pathname) {
  const parts = pathname.split('/');
  if (parts.length < 5 || parts[1] !== 'api' || parts[2] !== 'source' || parts[4] !== 'runtime') {
    return null;
  }
  const pathParts = [];
  for (let i = 5; i < parts.length; i++) {
    pathParts.push(decodeURIComponent(parts[i]));
  }
  return {
    sourceId: decodeURIComponent(parts[3]),
    runtimePath: pathParts.length > 0 ? `/${pathParts.join('/')}` : '/'
  };
}

async function callRuntimeSite(sourceId, siteKey, action, payload, publicBaseUrl) {
  const data = await runtimeConfig(sourceId);
  const site = findRuntimeSite(data.config, siteKey);
  if (!site || !site.api) {
    throw new Error(`Site not found: ${siteKey}`);
  }
  await ensureRuntimeSiteInitialized(data.runtime, sourceId, site);
  const runtimePayload = toRuntimePayload(action, payload, site);
  let raw = await callRuntimeAction(data.runtime, site, action, runtimePayload);
  if (action === 'play') {
    raw = await resolvePendingPlay(data.runtime, site, action, runtimePayload, raw);
  }
  if (action === 'home') {
    return {
      ok: true,
      sourceId,
      siteKey,
      categories: normalizeCategories(raw)
    };
  }
  if (action === 'category') {
    return normalizeCategoryResult(sourceId, siteKey, payload, raw, data.runtime, publicBaseUrl);
  }
  if (action === 'detail') {
    return normalizeDetailResult(sourceId, siteKey, payload, raw, data.runtime, publicBaseUrl);
  }
  if (action === 'play') {
    return normalizePlayResult(sourceId, siteKey, payload, raw, data.runtime, publicBaseUrl);
  }
  return {
    ok: true,
    sourceId,
    siteKey,
    action,
    data: raw
  };
}

async function callRuntimeAction(runtime, site, action, runtimePayload) {
  const response = await fetch(runtimeActionUrl(runtime, site, action), {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(runtimePayload)
  });
  const text = await response.text();
  if (!response.ok) {
    throw new Error(`Runtime ${action} failed: ${response.status} ${text.slice(0, 200)}`);
  }
  return text.length > 0 ? JSON.parse(text) : {};
}

async function resolvePendingPlay(runtime, site, action, runtimePayload, raw) {
  let current = raw;
  for (let attempt = 0; attempt < 12 && isPendingPlayResult(current); attempt++) {
    await sleep(playPollGap(current));
    current = await callRuntimeAction(runtime, site, action, runtimePayload);
  }
  return current;
}

function isPendingPlayResult(raw) {
  if (!isPlainObject(raw)) {
    return false;
  }
  const data = isPlainObject(raw.data) ? raw.data : {};
  if (data.finish === false && String(data.task_id || data.taskId || '').length > 0) {
    return true;
  }
  return raw.finish === false && String(raw.task_id || raw.taskId || '').length > 0;
}

function playPollGap(raw) {
  const metadata = isPlainObject(raw) && isPlainObject(raw.metadata) ? raw.metadata : {};
  const value = Number(metadata.tq_gap || raw.tq_gap || 1000);
  if (!Number.isFinite(value)) {
    return 1000;
  }
  return Math.min(2500, Math.max(500, value));
}

async function ensureRuntimeSiteInitialized(runtime, sourceId, site) {
  const key = `${sourceId}:${String(site.key || site.api || site.name || '')}`;
  const existing = siteInitPromises.get(key);
  if (existing) {
    await existing;
    return;
  }
  const promise = initRuntimeSite(runtime, site).catch((err) => {
    siteInitPromises.delete(key);
    throw err;
  });
  siteInitPromises.set(key, promise);
  await promise;
}

async function initRuntimeSite(runtime, site) {
  const response = await fetch(runtimeActionUrl(runtime, site, 'init'), {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(toRuntimePayload('init', {}, site))
  });
  const text = await response.text();
  if (!response.ok && response.status !== 404 && response.status !== 405) {
    throw new Error(`Runtime init failed: ${response.status} ${text.slice(0, 200)}`);
  }
}

function runtimeActionUrl(runtime, site, action) {
  const apiPath = String(site.api || '');
  if (apiPath.startsWith('http://') || apiPath.startsWith('https://')) {
    return `${apiPath.replace(/\/$/, '')}/${action}`;
  }
  const normalizedPath = apiPath.startsWith('/') ? apiPath : `/${apiPath}`;
  return `${runtime.baseUrl}${normalizedPath}/${action}`;
}

function toRuntimePayload(action, payload, site) {
  const siteBase = siteRuntimePayload(site);
  if (action === 'category') {
    const tid = String(payload.typeId || payload.tid || payload.id || '');
    const extend = payload.extend || payload.filter || payload.filters || {};
    return Object.assign({}, siteBase, {
      id: tid,
      tid,
      page: Number(payload.page || 1),
      filter: extend,
      filters: extend,
      extend
    });
  }
  if (action === 'detail') {
    const id = String(payload.vodId || payload.id || payload.ids || payload.vod_id || '');
    return Object.assign({}, siteBase, {
      id,
      ids: id,
      vod_id: id
    });
  }
  if (action === 'play') {
    const flag = String(payload.flag || payload.from || payload.playFrom || '');
    const id = String(payload.playId || payload.id || payload.url || payload.playUrl || '');
    return Object.assign({}, siteBase, {
      flag,
      from: flag,
      id,
      url: id,
      playUrl: id,
      siteUrl: siteBase.siteUrl
    });
  }
  return Object.assign({}, siteBase, payload || {});
}

function siteRuntimePayload(site) {
  const key = String(site.key || site.api || site.name || '');
  const name = String(site.name || site.key || site.api || '');
  const api = String(site.api || '');
  const ext = site.ext === undefined || site.ext === null ? '' : site.ext;
  const siteUrl = runtimeSiteUrl(site, ext);
  const cookie = site.cookie === undefined || site.cookie === null ? '' : String(site.cookie);
  const headers = site.headers || site.header || {};
  const siteInfo = {
    key,
    name,
    type: Number(site.type || 0),
    api,
    ext,
    extend: ext,
    jar: site.jar || '',
    url: siteUrl,
    siteUrl,
    cookie,
    header: headers,
    headers
  };
  return {
    key,
    name,
    type: Number(site.type || 0),
    api,
    ext,
    extend: ext,
    jar: site.jar || '',
    url: siteUrl,
    siteUrl,
    cookie,
    header: headers,
    headers,
    site: siteInfo,
    config: siteInfo
  };
}

function runtimeSiteUrl(site, ext) {
  if (site.url !== undefined && site.url !== null) {
    return String(site.url);
  }
  if (typeof ext === 'string') {
    return ext;
  }
  return '';
}

function normalizeCategories(raw) {
  const result = [];
  const categories = Array.isArray(raw.class) ? raw.class : [];
  for (const item of categories) {
    result.push({
      typeId: String(item.type_id || ''),
      typeName: String(item.type_name || '')
    });
  }
  return result;
}

function normalizeCategoryResult(sourceId, siteKey, payload, raw, runtime, publicBaseUrl) {
  const items = [];
  const list = Array.isArray(raw.list) ? raw.list : [];
  for (const item of list) {
    items.push({
      vodId: String(item.vod_id || ''),
      vodName: String(item.vod_name || ''),
      vodPic: normalizeRuntimeImageUrl(bestVodImageText(item), runtime, publicBaseUrl, sourceId),
      vodRemarks: String(item.vod_remarks || '')
    });
  }
  return {
    ok: true,
    sourceId,
    siteKey,
    typeId: String(payload.typeId || payload.tid || ''),
    page: Number(raw.page || payload.page || 1),
    pageCount: Number(raw.pagecount || raw.pageCount || 1),
    items
  };
}

function normalizeDetailResult(sourceId, siteKey, payload, raw, runtime, publicBaseUrl) {
  const item = firstDetailItem(raw);
  const fallbackId = String(payload.vodId || payload.id || payload.ids || payload.vod_id || '');
  const detail = {
    vodId: String(item.vod_id || item.id || fallbackId),
    vodName: String(item.vod_name || item.name || ''),
    vodPic: normalizeRuntimeImageUrl(bestVodImageText(item), runtime, publicBaseUrl, sourceId),
    typeName: String(item.type_name || item.vod_class || item.class || ''),
    vodYear: String(item.vod_year || item.year || ''),
    vodArea: String(item.vod_area || item.area || ''),
    vodRemarks: String(item.vod_remarks || item.vod_score || item.score || ''),
    vodDirector: String(item.vod_director || item.director || ''),
    vodActor: String(item.vod_actor || item.actor || ''),
    vodContent: String(item.vod_content || item.content || item.desc || ''),
    playSources: normalizePlaySources(item, runtime, publicBaseUrl, sourceId)
  };
  return {
    ok: true,
    sourceId,
    siteKey,
    item: detail
  };
}

function firstDetailItem(raw) {
  if (!raw || typeof raw !== 'object') {
    return {};
  }
  if (Array.isArray(raw.list) && raw.list.length > 0) {
    return raw.list[0] || {};
  }
  if (raw.data && Array.isArray(raw.data.list) && raw.data.list.length > 0) {
    return raw.data.list[0] || {};
  }
  if (raw.data && typeof raw.data === 'object' && !Array.isArray(raw.data)) {
    return raw.data;
  }
  if (raw.item && typeof raw.item === 'object') {
    return raw.item;
  }
  return raw && typeof raw === 'object' ? raw : {};
}

function normalizePlaySources(item, runtime, publicBaseUrl, sourceId) {
  const structuredSources = normalizeStructuredPlaySources(item, runtime, publicBaseUrl, sourceId);
  if (structuredSources.length > 0) {
    return structuredSources;
  }
  const result = [];
  const fromText = primitiveText(item.vod_play_from || item.play_from || item.from || '');
  const urlText = primitiveText(item.vod_play_url || item.play_url || item.urls || '');
  const fromParts = splitSourceBlocks(fromText);
  const urlParts = splitSourceBlocks(urlText);
  const count = Math.max(fromParts.length, urlParts.length);
  for (let i = 0; i < count; i++) {
    const fallbackName = `线路${i + 1}`;
    const flag = String(fromParts[i] || fallbackName).trim();
    const name = flag.length > 0 ? flag : fallbackName;
    const episodes = normalizeEpisodes(String(urlParts[i] || ''), name, runtime, publicBaseUrl, sourceId);
    result.push({
      name,
      flag: name,
      episodes
    });
  }
  return result.filter((source) => source.episodes.length > 0);
}

function normalizeStructuredPlaySources(item, runtime, publicBaseUrl, sourceId) {
  const result = [];
  const keys = [
    'playSources',
    'play_sources',
    'sources',
    'vod_play_list',
    'playList',
    'playlist',
    'vod_play_url',
    'play_url',
    'urls',
    'episodes'
  ];
  for (const key of keys) {
    const value = item[key];
    if (Array.isArray(value)) {
      appendStructuredArraySources(result, value, runtime, publicBaseUrl, sourceId);
    }
  }
  return result.filter((source) => source.episodes.length > 0);
}

function appendStructuredArraySources(result, values, runtime, publicBaseUrl, sourceId) {
  if (values.length === 0) {
    return;
  }
  if (hasSourceWrapper(values)) {
    for (let i = 0; i < values.length; i++) {
      const source = values[i];
      if (!isPlainObject(source)) {
        continue;
      }
      const fallbackName = `线路${i + 1}`;
      const name = firstTextField(source, ['name', 'flag', 'from', 'title', 'source']) || fallbackName;
      const flag = firstTextField(source, ['flag', 'from', 'name', 'source']) || name;
      const episodes = episodesFromStructuredSource(source, flag, runtime, publicBaseUrl, sourceId);
      if (episodes.length > 0) {
        result.push({ name, flag, episodes });
      }
    }
    return;
  }
  const episodes = normalizeEpisodeObjects(values, '线路1', runtime, publicBaseUrl, sourceId);
  if (episodes.length > 0) {
    result.push({ name: '线路1', flag: '线路1', episodes });
  }
}

function hasSourceWrapper(values) {
  for (const value of values) {
    if (isPlainObject(value) && (
      Array.isArray(value.episodes) || Array.isArray(value.list) || Array.isArray(value.items) ||
      Array.isArray(value.urls) || primitiveText(value.vod_play_url || value.play_url || value.url_list).length > 0
    )) {
      return true;
    }
  }
  return false;
}

function episodesFromStructuredSource(source, flag, runtime, publicBaseUrl, sourceId) {
  const keys = ['episodes', 'list', 'items', 'urls', 'data'];
  for (const key of keys) {
    const value = source[key];
    if (Array.isArray(value)) {
      return normalizeEpisodeObjects(value, flag, runtime, publicBaseUrl, sourceId);
    }
  }
  const text = primitiveText(source.vod_play_url || source.play_url || source.url_list || source.urls || '');
  if (text.length > 0) {
    return normalizeEpisodes(text, flag, runtime, publicBaseUrl, sourceId);
  }
  return [];
}

function normalizeEpisodeObjects(values, flag, runtime, publicBaseUrl, sourceId) {
  const result = [];
  for (let i = 0; i < values.length; i++) {
    const value = values[i];
    if (typeof value === 'string') {
      const episode = normalizeEpisodeText(value, flag, i, runtime, publicBaseUrl, sourceId);
      if (episode.url.length > 0) {
        result.push(episode);
      }
      continue;
    }
    if (!isPlainObject(value)) {
      continue;
    }
    const title = firstTextField(value, ['title', 'name', 'episode', 'ep', 'label']) || `第${i + 1}集`;
    const url = firstTextField(value, ['url', 'playUrl', 'play_url', 'id', 'vod_id', 'href', 'path']);
    const pic = firstTextField(value, [
      'pic',
      'vod_pic',
      'cover',
      'cover_url',
      'thumb',
      'thumbnail',
      'image',
      'img',
      'still',
      'still_path',
      'screenshot'
    ]);
    const meta = episodeMetaFromUrl(url, flag, title);
    if (url.length > 0) {
      result.push({
        title,
        url,
        flag,
        size: numericField(value, ['size', 'fileSize', 'file_size']),
        pic: normalizeRuntimeImageUrl(firstNonEmptyText(pic, meta.cover), runtime, publicBaseUrl, sourceId),
        fileName: firstNonEmptyText(meta.fileName, title),
        fileExt: meta.fileExt,
        panType: meta.panType,
        shareId: meta.shareId,
        fileId: meta.fileId,
        fileToken: meta.fileToken,
        stoken: meta.stoken
      });
    }
  }
  return result;
}

function firstTextField(item, keys) {
  for (const key of keys) {
    const value = item[key];
    if (typeof value === 'string' && value.trim().length > 0) {
      return value.trim();
    }
    if (typeof value === 'number' && Number.isFinite(value)) {
      return String(value);
    }
  }
  return '';
}

function numericField(item, keys) {
  for (const key of keys) {
    const value = Number(item[key] || 0);
    if (Number.isFinite(value) && value > 0) {
      return value;
    }
  }
  return 0;
}

function primitiveText(value) {
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    return String(value);
  }
  return '';
}

function splitSourceBlocks(text) {
  if (text.length === 0) {
    return [];
  }
  return text.split('$$$');
}

function normalizeEpisodes(text, flag, runtime, publicBaseUrl, sourceId) {
  const result = [];
  if (text.length === 0) {
    return result;
  }
  const parts = text.split('#');
  for (let i = 0; i < parts.length; i++) {
    const raw = String(parts[i] || '').trim();
    if (raw.length === 0) {
      continue;
    }
    const episode = normalizeEpisodeText(raw, flag, i, runtime, publicBaseUrl, sourceId);
    if (episode.url.length > 0) {
      result.push(episode);
    }
  }
  return result;
}

function normalizeEpisodeText(raw, flag, index, runtime, publicBaseUrl, sourceId) {
  const fallbackTitle = `第${index + 1}集`;
  const segments = raw.split('$').map((part) => String(part || '').trim()).filter((part) => part.length > 0);
  let title = fallbackTitle;
  let url = raw.trim();
  let pic = '';
  if (segments.length > 1) {
    const first = segments[0];
    if (!isLikelyUrl(first) && !isLikelyImageUrl(first)) {
      title = first;
    }
    pic = firstLikelyImageUrl(segments);
    url = firstLikelyPlayUrl(segments, title, pic);
    if (url.length === 0) {
      url = segments[segments.length - 1];
    }
    if (isLikelyUrl(first) && !isLikelyImageUrl(first) && !isLikelyUrl(segments[segments.length - 1])) {
      title = segments[segments.length - 1];
      url = first;
    }
  }
  if (title.length === 0) {
    title = fallbackTitle;
  }
  if (isLikelyImageUrl(url) && pic.length === 0) {
    pic = url;
    url = '';
  }
  const meta = episodeMetaFromUrl(url, flag, title);
  return {
    title,
    url,
    flag,
    size: 0,
    pic: normalizeRuntimeImageUrl(firstNonEmptyText(pic, meta.cover), runtime, publicBaseUrl, sourceId),
    fileName: firstNonEmptyText(meta.fileName, title),
    fileExt: meta.fileExt,
    panType: meta.panType,
    shareId: meta.shareId,
    fileId: meta.fileId,
    fileToken: meta.fileToken,
    stoken: meta.stoken
  };
}

function firstLikelyImageUrl(values) {
  for (const value of values) {
    if (isLikelyImageUrl(value)) {
      return value;
    }
  }
  return '';
}

function firstLikelyPlayUrl(values, title, pic) {
  for (const value of values) {
    if (value !== title && value !== pic && !isLikelyImageUrl(value)) {
      return value;
    }
  }
  return '';
}

function episodeMetaFromUrl(url, flag, title) {
  const meta = {
    fileName: '',
    fileExt: '',
    panType: panTypeFromFlag(flag),
    shareId: '',
    fileId: '',
    fileToken: '',
    stoken: '',
    cover: ''
  };
  const text = String(url || '');
  if (text.includes('***')) {
    const parts = text.split('***');
    meta.fileName = firstNonEmptyText(parts.length > 1 ? parts[1] : '', title);
    applyEncodedPanParts(meta, parts[0]);
    finalizeEpisodeMeta(meta);
    return meta;
  }
  if (text.includes('|')) {
    const parts = text.split('|');
    meta.shareId = parts.length > 0 ? parts[0] : '';
    meta.fileId = parts.length > 2 ? parts[2] : firstNonEmptyText(parts.length > 1 ? parts[1] : '', '');
    meta.fileName = firstNonEmptyText(parts.length > 3 ? parts[3] : '', title);
    meta.cover = firstLikelyImageUrl(parts);
    finalizeEpisodeMeta(meta);
    return meta;
  }
  meta.fileName = firstNonEmptyText(fileNameFromUrl(text), title);
  meta.cover = isLikelyImageUrl(text) ? text : '';
  finalizeEpisodeMeta(meta);
  return meta;
}

function applyEncodedPanParts(meta, encoded) {
  const parts = String(encoded || '').split('*');
  meta.shareId = parts.length > 0 ? parts[0] : '';
  if (parts.length > 1) {
    meta.stoken = parts[1];
  }
  if (parts.length > 2) {
    meta.fileId = parts[2];
  } else if (parts.length > 1) {
    meta.fileId = parts[1];
  }
  if (parts.length > 3) {
    meta.fileToken = parts[3];
  }
}

function finalizeEpisodeMeta(meta) {
  if (meta.panType.length === 0) {
    meta.panType = panTypeFromEncodedMeta(meta);
  }
  meta.fileName = cleanEpisodeFileName(meta.fileName);
  meta.fileExt = fileExtFromName(meta.fileName);
}

function panTypeFromEncodedMeta(meta) {
  if (meta.shareId.length > 0 && meta.stoken.length > 0 && meta.fileToken.length > 0) {
    return 'quark';
  }
  if (meta.shareId.length > 0 && meta.fileId.length > 0) {
    return 'pan';
  }
  return '';
}

function panTypeFromFlag(flag) {
  const text = String(flag || '').toLowerCase();
  if (text.includes('夸') || text.includes('quark')) {
    return 'quark';
  }
  if (text.includes('uc')) {
    return 'uc';
  }
  if (text.includes('百度') || text.includes('baidu')) {
    return 'baidu';
  }
  if (text.includes('阿里') || text.includes('aliyun') || text.includes('alipan')) {
    return 'aliyun';
  }
  if (text.includes('逸') || text.includes('yidong') || text.includes('139')) {
    return 'yidong';
  }
  if (text.includes('天翼') || text.includes('189')) {
    return '189';
  }
  if (text.includes('115')) {
    return '115';
  }
  if (text.includes('123')) {
    return '123';
  }
  return '';
}

function cleanEpisodeFileName(value) {
  const text = String(value || '').trim();
  if (text.length === 0) {
    return '';
  }
  return text.replace(/\s+\[[0-9.]+\s*(?:B|KB|MB|GB|TB)\]$/i, '').trim();
}

function fileExtFromName(value) {
  const text = String(value || '').trim();
  const withoutQuery = text.split('?')[0] || '';
  const index = withoutQuery.lastIndexOf('.');
  if (index >= 0 && index < withoutQuery.length - 1) {
    return withoutQuery.slice(index + 1).toLowerCase();
  }
  return '';
}

function fileNameFromUrl(url) {
  const text = String(url || '');
  const withoutQuery = text.split('?')[0] || '';
  const index = withoutQuery.lastIndexOf('/');
  if (index >= 0 && index < withoutQuery.length - 1) {
    return decodeURIComponent(withoutQuery.slice(index + 1));
  }
  return '';
}

function firstNonEmptyText(primary, fallback) {
  const text = String(primary || '').trim();
  if (text.length > 0) {
    return text;
  }
  return String(fallback || '').trim();
}

function normalizePlayResult(sourceId, siteKey, payload, raw, runtime, publicBaseUrl) {
  const item = raw && typeof raw === 'object' ? raw : {};
  const data = item.data && typeof item.data === 'object' ? item.data : {};
  const rawUrl = bestPlayUrl(item);
  const url = normalizeRuntimeUrl(rawUrl, runtime, publicBaseUrl, sourceId);
  const parse = Number(item.parse || item.needParse || data.parse || 0);
  const flag = String(payload.flag || payload.from || payload.playFrom || '');
  const playId = String(payload.playId || payload.id || payload.url || payload.playUrl || '');
  const playable = url.length > 0 && (parse === 0 || isLikelyDirectUrl(url));
  const cover = normalizeRuntimeImageUrl(bestImageFromObject(item), runtime, publicBaseUrl, sourceId);
  return {
    ok: true,
    sourceId,
    siteKey,
    flag,
    playId,
    url,
    parse,
    playable,
    headersJson: JSON.stringify(item.header || item.headers || data.header || {}),
    cover,
    rawJson: JSON.stringify(playRawSummary(item)),
    message: playMessage(item, url)
  };
}

function playMessage(item, url) {
  if (url.length > 0) {
    return '';
  }
  if (isPendingPlayResult(item)) {
    return '播放任务仍在处理中，请稍后重试';
  }
  return '未返回播放地址';
}

function bestPlayUrl(item) {
  if (!isPlainObject(item)) {
    return '';
  }
  const data = isPlainObject(item.data) ? item.data : {};
  const values = [
    item.url,
    item.playUrl,
    item.play_url,
    item.videoUrl,
    item.video_url,
    data.url,
    data.playUrl,
    data.play_url,
    data.videoUrl,
    data.video_url
  ];
  for (const value of values) {
    const url = firstPlayableUrl(value);
    if (url.length > 0) {
      return url;
    }
  }
  return '';
}

function firstPlayableUrl(value) {
  if (typeof value === 'string') {
    const text = value.trim();
    return isLikelyUrl(text) ? text : '';
  }
  if (Array.isArray(value)) {
    return firstPlayableUrlFromArray(value);
  }
  if (isPlainObject(value)) {
    return firstPlayableUrlFromObject(value);
  }
  return '';
}

function firstPlayableUrlFromArray(values) {
  for (const value of values) {
    const url = firstPlayableUrl(value);
    if (url.length > 0) {
      return url;
    }
  }
  return '';
}

function firstPlayableUrlFromObject(value) {
  const keys = [
    'url',
    'playUrl',
    'play_url',
    'videoUrl',
    'video_url',
    'src',
    'href',
    'link'
  ];
  for (const key of keys) {
    const url = firstPlayableUrl(value[key]);
    if (url.length > 0) {
      return url;
    }
  }
  return '';
}

function isLikelyDirectUrl(urlText) {
  return urlText.startsWith('http://') || urlText.startsWith('https://') ||
    urlText.startsWith('file://') || urlText.startsWith('rtmp://') ||
    urlText.startsWith('rtsp://');
}

function isLikelyUrl(value) {
  return value.startsWith('http://') || value.startsWith('https://') || value.startsWith('/') ||
    value.startsWith('file://') || value.startsWith('rtmp://') || value.startsWith('rtsp://');
}

function isLikelyImageUrl(value) {
  const text = String(value || '').trim();
  if (text.length === 0) {
    return false;
  }
  if (text.includes('image.tmdb.org/t/p/')) {
    return true;
  }
  return /\.(?:jpg|jpeg|png|webp|gif|bmp|avif)(?:[?#].*)?$/i.test(text);
}

function bestVodImageText(item) {
  const preferredKeys = [
    'vod_pic_slide',
    'vod_pic_banner',
    'vod_pic_backdrop',
    'vod_backdrop',
    'backdrop',
    'landscape',
    'cover',
    'cover_url',
    'poster',
    'poster_url',
    'vod_pic_large',
    'vod_pic_big',
    'vod_pic_original',
    'vod_pic_thumb',
    'vod_pic',
    'pic',
    'image',
    'img',
    'thumb',
    'thumbnail'
  ];
  const fallbackKeys = [
    'backdrop_path',
    'still_path',
    'poster_path'
  ];
  for (const key of preferredKeys) {
    const value = item[key];
    const text = imageFieldText(key, value);
    if (text.length > 0 && isLikelyImageUrl(text) && !text.startsWith('/')) {
      return text;
    }
  }
  for (const key of preferredKeys) {
    const value = item[key];
    const text = imageFieldText(key, value);
    if (text.length > 0) {
      return text;
    }
  }
  for (const key of fallbackKeys) {
    const value = item[key];
    const text = imageFieldText(key, value);
    if (text.length > 0) {
      return text;
    }
  }
  return '';
}

function bestImageFromObject(item) {
  if (!isPlainObject(item)) {
    return '';
  }
  const direct = bestVodImageText(item);
  if (direct.length > 0) {
    return direct;
  }
  const data = item.data;
  if (isPlainObject(data)) {
    return bestVodImageText(data);
  }
  const extra = item.extra;
  if (isPlainObject(extra)) {
    return bestVodImageText(extra);
  }
  return '';
}

function playRawSummary(item) {
  if (!isPlainObject(item)) {
    return {};
  }
  return {
    image: bestImageFromObject(item),
    extra: isPlainObject(item.extra) ? item.extra : {},
    data: isPlainObject(item.data) ? item.data : {}
  };
}

function imageFieldText(key, value) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    return '';
  }
  const text = value.trim();
  if ((key === 'backdrop_path' || key === 'poster_path' || key === 'still_path') && text.startsWith('/')) {
    return `https://image.tmdb.org/t/p/w780${text}`;
  }
  return text;
}

function normalizeRuntimeImageUrl(urlText, runtime, publicBaseUrl, sourceId) {
  return upgradeImageQuality(normalizeRuntimeUrl(urlText, runtime, publicBaseUrl, sourceId));
}

function upgradeImageQuality(urlText) {
  if (urlText.length === 0) {
    return '';
  }
  return urlText.replace(/(image\.tmdb\.org\/t\/p\/)(w\d+|original)(\/)/i, '$1w780$3');
}

function normalizeRuntimeUrl(urlText, runtime, publicBaseUrl, sourceId) {
  if (urlText.length === 0) {
    return '';
  }
  if (urlText.startsWith(runtime.baseUrl)) {
    return `${publicBaseUrl}/api/source/${encodeURIComponent(sourceId)}/proxy?url=${encodeURIComponent(urlText)}`;
  }
  return urlText;
}

function runtimeProxyPrefix(sourceId) {
  return `/api/source/${encodeURIComponent(sourceId)}/runtime`;
}

async function proxyRuntimeUrl(sourceId, targetUrl, req, res) {
  const runtime = await startSourceRuntime(sourceId);
  if (!targetUrl.startsWith(runtime.baseUrl)) {
    sendError(res, 400, 'Proxy target is outside runtime');
    return;
  }
  const response = await fetch(targetUrl, {
    headers: forwardProxyRequestHeaders(req),
    redirect: 'follow'
  });
  if (!response.ok) {
    sendError(res, response.status, `Proxy failed: ${response.status}`);
    return;
  }
  const headers = forwardProxyResponseHeaders(response);
  res.writeHead(response.status, headers);
  if (req.method === 'HEAD' || response.body === null) {
    res.end();
    return;
  }
  Readable.fromWeb(response.body).pipe(res);
}

async function proxyRuntimePath(sourceId, runtimePath, req, res, search, publicBaseUrl) {
  const runtime = await startSourceRuntime(sourceId);
  const target = new URL(runtimePath, runtime.baseUrl);
  target.search = search || '';
  const method = String(req.method || 'GET').toUpperCase();
  const hasBody = method !== 'GET' && method !== 'HEAD';
  const body = hasBody ? await readBodyBuffer(req) : undefined;
  const response = await fetch(target, {
    method,
    headers: forwardRequestHeaders(req),
    body,
    redirect: 'manual'
  });
  const contentType = response.headers.get('content-type') || 'application/octet-stream';
  let buffer = Buffer.from(await response.arrayBuffer());
  const headers = forwardResponseHeaders(response, runtime, publicBaseUrl, sourceId);
  if (contentType.includes('text/html')) {
    const html = buffer.toString('utf8');
    buffer = Buffer.from(rewriteRuntimeHtml(html, sourceId), 'utf8');
    headers['Content-Type'] = withUtf8ContentType(contentType);
  } else if (!headers['Content-Type']) {
    headers['Content-Type'] = contentType;
  }
  headers['Access-Control-Allow-Origin'] = '*';
  headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization, Cookie';
  headers['Access-Control-Allow-Methods'] = 'GET,POST,PUT,PATCH,DELETE,OPTIONS';
  res.writeHead(response.status, headers);
  if (method === 'HEAD') {
    res.end();
    return;
  }
  res.end(buffer);
}

function forwardRequestHeaders(req) {
  const result = {};
  const blocked = new Set([
    'host',
    'connection',
    'content-length',
    'transfer-encoding',
    'upgrade',
    'proxy-authenticate',
    'proxy-authorization',
    'te',
    'trailer'
  ]);
  for (const name of Object.keys(req.headers)) {
    const lower = name.toLowerCase();
    if (blocked.has(lower)) {
      continue;
    }
    const value = req.headers[name];
    if (Array.isArray(value)) {
      result[name] = value.join('; ');
    } else if (value !== undefined) {
      result[name] = String(value);
    }
  }
  return result;
}

function forwardProxyRequestHeaders(req) {
  const result = {};
  const allowed = [
    'range',
    'if-range',
    'accept',
    'accept-language',
    'user-agent'
  ];
  for (const name of allowed) {
    const value = req.headers[name];
    if (Array.isArray(value)) {
      result[name] = value.join('; ');
    } else if (value !== undefined) {
      result[name] = String(value);
    }
  }
  return result;
}

function forwardProxyResponseHeaders(response) {
  const result = {};
  const blocked = new Set([
    'connection',
    'transfer-encoding',
    'upgrade',
    'proxy-authenticate',
    'proxy-authorization',
    'te',
    'trailer',
    'set-cookie'
  ]);
  response.headers.forEach((value, name) => {
    const lower = name.toLowerCase();
    if (blocked.has(lower)) {
      return;
    }
    result[headerName(name)] = value;
  });
  if (!result['Content-Type']) {
    result['Content-Type'] = response.headers.get('content-type') || 'application/octet-stream';
  }
  result['Access-Control-Allow-Origin'] = '*';
  result['Access-Control-Allow-Headers'] = 'Range, Content-Type, Authorization, Cookie';
  result['Access-Control-Allow-Methods'] = 'GET,HEAD,OPTIONS';
  result['Accept-Ranges'] = response.headers.get('accept-ranges') || 'bytes';
  return result;
}

function forwardResponseHeaders(response, runtime, publicBaseUrl, sourceId) {
  const result = {};
  const blocked = new Set([
    'connection',
    'content-length',
    'content-encoding',
    'transfer-encoding',
    'upgrade',
    'proxy-authenticate',
    'proxy-authorization',
    'te',
    'trailer'
  ]);
  response.headers.forEach((value, name) => {
    const lower = name.toLowerCase();
    if (blocked.has(lower) || lower === 'set-cookie') {
      return;
    }
    if (lower === 'location') {
      result.Location = rewriteRuntimeLocation(value, runtime, publicBaseUrl, sourceId);
      return;
    }
    result[headerName(name)] = value;
  });
  if (typeof response.headers.getSetCookie === 'function') {
    const cookies = response.headers.getSetCookie();
    if (cookies.length > 0) {
      result['Set-Cookie'] = cookies;
    }
  }
  return result;
}

function headerName(name) {
  return name.split('-').map((part) => {
    if (part.length === 0) {
      return part;
    }
    return part.slice(0, 1).toUpperCase() + part.slice(1);
  }).join('-');
}

function rewriteRuntimeLocation(location, runtime, publicBaseUrl, sourceId) {
  if (location.startsWith(runtime.baseUrl)) {
    return `${publicBaseUrl}${runtimeProxyPrefix(sourceId)}${location.slice(runtime.baseUrl.length)}`;
  }
  if (location.startsWith('/')) {
    return `${runtimeProxyPrefix(sourceId)}${location}`;
  }
  return location;
}

function withUtf8ContentType(contentType) {
  if (contentType.toLowerCase().includes('charset=')) {
    return contentType;
  }
  return `${contentType}; charset=utf-8`;
}

function rewriteRuntimeHtml(html, sourceId) {
  let result = html;
  const prefix = runtimeProxyPrefix(sourceId);
  const roots = [
    'website',
    'full-config',
    'check',
    'config',
    'spider',
    'assets',
    'static',
    'favicon.ico'
  ];
  for (const root of roots) {
    const pattern = new RegExp("([(\"'=:\\s`])/" + escapeRegExp(root) + "(?=([/?#\"'`\\s)]|$))", 'g');
    result = result.replace(pattern, `$1${prefix}/${root}`);
  }
  return result;
}

function escapeRegExp(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

async function inspectSource(payload) {
  const inputUrl = String(payload.url || '').trim();
  if (inputUrl.length === 0) {
    throw new Error('Missing source url');
  }

  const md5Url = resolveMd5Url(inputUrl);
  const scriptUrl = resolveScriptUrl(inputUrl);
  const md5Response = await fetchText(md5Url);
  if (md5Response.status < 200 || md5Response.status >= 300) {
    throw new Error(`MD5 request failed: ${md5Response.status}`);
  }
  const md5 = normalizeMd5(md5Response.text);
  if (md5.length === 0) {
    throw new Error('MD5 is empty');
  }

  const scriptResponse = await fetchText(scriptUrl);
  if (scriptResponse.status < 200 || scriptResponse.status >= 300) {
    throw new Error(`Script request failed: ${scriptResponse.status}`);
  }
  const script = scriptResponse.text;
  const features = detectScript(script);
  const sourceId = sourceIdFor(scriptUrl);
  const protocol = features.hasServerFactory || features.hasFullConfigRoute ? 'mira_cat_js_server' : 'mira_cat_js';

  const result = {
    ok: true,
    sourceId,
    protocol,
    md5,
    scriptUrl,
    scriptSize: script.length,
    runtime: 'remote_node',
    message: features.hasServerFactory ? '识别为 Mira/Cat Node JS Server bundle' : '识别为 JS bundle',
    features,
    sites: []
  };
  sources.set(sourceId, {
    inputUrl,
    md5Url,
    scriptUrl,
    md5,
    script,
    parsedConfig: parseSourceConfig(script),
    result
  });
  if (features.hasServerFactory || features.hasFullConfigRoute) {
    try {
      const sitesResult = await sourceSites(sourceId);
      result.sites = sitesResult.sites;
      result.message = `${result.message}，已加载 ${sitesResult.sites.length} 个站点`;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Runtime site load failed';
      result.message = `${result.message}，站点加载失败: ${message}`;
    }
  }
  return result;
}

async function handle(req, res) {
  if (req.method === 'OPTIONS') {
    sendJson(res, 204, {});
    return;
  }

  const url = new URL(req.url || '/', `http://${req.headers.host || '127.0.0.1'}`);
  try {
    if (req.method === 'GET' && url.pathname === '/api/health') {
      sendJson(res, 200, {
        ok: true,
        service: 'cobrander-resolver',
        version: VERSION,
        runtime: 'node',
        sources: sources.size,
        capabilities: ['inspect_sites', 'source_sites', 'home', 'category', 'detail', 'play']
      });
      return;
    }
    if (req.method === 'GET' && url.pathname === '/api/profile') {
      sendJson(res, 200, localProfileSummary());
      return;
    }
    if (req.method === 'POST' && url.pathname === '/api/source/inspect') {
      const payload = await readJson(req);
      sendJson(res, 200, await inspectSource(payload));
      return;
    }
    if (req.method === 'GET' && url.pathname.startsWith('/api/source/') && url.pathname.endsWith('/sites')) {
      const sourceId = decodeURIComponent(url.pathname.slice('/api/source/'.length, -'/sites'.length));
      sendJson(res, 200, await sourceSites(sourceId));
      return;
    }
    const proxyRoute = matchProxyRoute(url.pathname);
    if ((req.method === 'GET' || req.method === 'HEAD') && proxyRoute) {
      await proxyRuntimeUrl(proxyRoute.sourceId, url.searchParams.get('url') || '', req, res);
      return;
    }
    const runtimeRoute = matchRuntimeRoute(url.pathname);
    if (runtimeRoute) {
      const publicBaseUrl = `http://${req.headers.host || '127.0.0.1'}`;
      await proxyRuntimePath(runtimeRoute.sourceId, runtimeRoute.runtimePath, req, res, url.search, publicBaseUrl);
      return;
    }
    const siteRoute = matchSiteRoute(url.pathname);
    if (req.method === 'POST' && siteRoute) {
      const payload = await readJson(req);
      const publicBaseUrl = `http://${req.headers.host || '127.0.0.1'}`;
      sendJson(
        res,
        200,
        await callRuntimeSite(siteRoute.sourceId, siteRoute.siteKey, siteRoute.action, payload, publicBaseUrl)
      );
      return;
    }
    sendError(res, 404, 'Not found');
  } catch (err) {
    sendError(res, 500, err instanceof Error ? err.message : 'Resolver error');
  }
}

const server = http.createServer(handle);

server.once('error', (err) => {
  if (err && err.code === 'EADDRINUSE') {
    console.error(`Port ${PORT} is already in use.`);
    console.error(`Stop the old resolver process, or start with another port: PORT=8794 npm run dev`);
    process.exitCode = 1;
    return;
  }
  throw err;
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Cobrander resolver listening on http://127.0.0.1:${PORT}`);
});
