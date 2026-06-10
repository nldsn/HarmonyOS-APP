import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'

export class HttpTextResponse {
  statusCode: number = 0
  body: string = ''
}

export class HttpClient {
  async getText(url: string, timeoutMs: number = 15000): Promise<HttpTextResponse> {
    let request = http.createHttp()
    try {
      let response = await request.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: timeoutMs,
        readTimeout: timeoutMs,
        expectDataType: http.HttpDataType.STRING,
        header: {
          'User-Agent': 'CobranderTV/1.0 HarmonyOS'
        }
      })
      let result = new HttpTextResponse()
      result.statusCode = response.responseCode
      if (typeof response.result === 'string') {
        result.body = response.result
      } else if (response.result instanceof ArrayBuffer) {
        let decoder = util.TextDecoder.create('utf-8')
        result.body = decoder.decodeToString(new Uint8Array(response.result))
      } else {
        result.body = response.result.toString()
      }
      return result
    } finally {
      request.destroy()
    }
  }

  async postJson(url: string, body: string, timeoutMs: number = 15000): Promise<HttpTextResponse> {
    let request = http.createHttp()
    try {
      let response = await request.request(url, {
        method: http.RequestMethod.POST,
        connectTimeout: timeoutMs,
        readTimeout: timeoutMs,
        expectDataType: http.HttpDataType.STRING,
        header: {
          'Content-Type': 'application/json',
          'User-Agent': 'CobranderTV/1.0 HarmonyOS'
        },
        extraData: body
      })
      let result = new HttpTextResponse()
      result.statusCode = response.responseCode
      if (typeof response.result === 'string') {
        result.body = response.result
      } else if (response.result instanceof ArrayBuffer) {
        let decoder = util.TextDecoder.create('utf-8')
        result.body = decoder.decodeToString(new Uint8Array(response.result))
      } else {
        result.body = response.result.toString()
      }
      return result
    } finally {
      request.destroy()
    }
  }
}
