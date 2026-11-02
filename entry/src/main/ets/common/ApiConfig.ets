/**
 * 服务端地址配置。
 * 部署信息确定前保持为空，避免把开发机地址或临时端口写进客户端。
 */
export class ApiConfig {
  /** 完整的 API 基础地址，例如部署后的 HTTPS 域名。 */
  static readonly baseUrl: string = 'http://101.37.237.234';

  /** 也可以分别填写主机和端口；baseUrl 为空时才会使用这两项。 */
  static readonly host: string = '';
  static readonly port: string = '';
  static readonly scheme: string = 'https';

  static resolveBaseUrl(): string {
    if (ApiConfig.baseUrl.length > 0) {
      return ApiConfig.baseUrl;
    }
    if (ApiConfig.host.length === 0 || ApiConfig.port.length === 0) {
      return '';
    }
    return `${ApiConfig.scheme}://${ApiConfig.host}:${ApiConfig.port}`;
  }

  static isConfigured(): boolean {
    return ApiConfig.resolveBaseUrl().length > 0;
  }
}
