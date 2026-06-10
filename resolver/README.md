# Cobrander Resolver

Remote resolver service for HarmonyOS client.

## Run

```bash
npm run dev
```

Default port: `8787`.

When debugging on a real HarmonyOS device, use the LAN IP of the computer
running this service, for example:

```text
http://192.168.0.166:8787
```

After changing resolver code, restart this Node process before testing again.

## API

- `GET /api/health`
- `POST /api/source/inspect`
- `GET /api/source/{sourceId}/sites`

Example:

```bash
curl -X POST http://127.0.0.1:8787/api/source/inspect \
  -H "Content-Type: application/json" \
  -d "{\"url\":\"http://wexfnw:wexfnw@cat.xn--4kq62z5rby2qupq9ub.top/index.js.md5\"}"
```

`/api/source/inspect` downloads and identifies the source. For Mira/Cat Node
server bundles, it also tries to start the remote runtime and include `sites`
directly in the response.

If the app needs to reload the site list later, call:

```bash
curl http://127.0.0.1:8787/api/source/source_0f1e0001001628d2/sites
```
