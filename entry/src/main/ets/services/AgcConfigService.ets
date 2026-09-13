export class AgcConfigService {
  static readonly bundleName: string = 'com.wuit.xjh.helpshop';
  static readonly appId: string = '6917610961507066438';
  static readonly appClientId: string = '6917610961507066438';
  static readonly signingSha256: string = 'D3:39:AD:5A:0F:CD:4A:FA:99:8E:F2:AC:C8:FF:23:28:95:D5:34:0E:4E:68:CA:77:0E:65:4F:1F:C3:BB:63:79';
  static readonly lastVerifiedSignedAppSha256: string = 'EE:EA:3A:1D:03:86:04:3E:80:4E:98:1E:0C:38:9C:BB:0C:B0:08:2F:5E:6C:CC:CC:13:AD:BD:6A:E2:D6:91:BA';

  static getCurrentConfigSummary(): string[] {
    return [
      `\u5305\u540d\u5e94\u4e3a ${AgcConfigService.bundleName}`,
      `module.json5 \u7684 app_id \u5e94\u4e3a ${AgcConfigService.appId}`,
      `module.json5 \u7684 client_id \u5e94\u4e3a ${AgcConfigService.appClientId}`,
      `AGC \u4e2d\u914d\u7f6e\u7684 SHA-256 \u5e94\u4e3a ${AgcConfigService.signingSha256}`,
      `\u6700\u8fd1\u4e00\u6b21\u6821\u9a8c\u5230\u5df2\u6253\u5305 HAP \u7684\u5b9e\u9645\u7b7e\u540d SHA-256 \u4e3a ${AgcConfigService.lastVerifiedSignedAppSha256}`
    ];
  }

  static getChecklistItems(): string[] {
    return [
      '\u786e\u8ba4 entry/src/main/module.json5 \u7684 metadata.app_id \u5df2\u914d\u7f6e\uff0c\u4e14\u4e0e AGC \u5e94\u7528 APP ID \u4e00\u81f4',
      '\u786e\u8ba4 entry/src/main/module.json5 \u7684 metadata.client_id \u4f7f\u7528\u7684\u662f\u5e94\u7528\u7ea7 OAuth \u5ba2\u6237\u7aef ID\uff0c\u800c\u4e0d\u662f\u9879\u76ee\u7ea7 Client ID',
      '\u786e\u8ba4 AppScope/app.json5 \u4e2d\u7684 bundleName \u4e0e AGC \u5e94\u7528\u5305\u540d\u5b8c\u5168\u4e00\u81f4',
      '\u786e\u8ba4 AGC \u4e2d\u914d\u7f6e\u7684 SHA-256 \u6307\u7eb9\u4e0e\u5f53\u524d\u7b7e\u540d\u8bc1\u4e66\u5b8c\u5168\u4e00\u81f4',
      '\u5982\u679c\u767b\u5f55\u9875\u4e2d\u663e\u793a\u7684\u5b9e\u9645 HAP \u7b7e\u540d SHA-256 \u4e0e AGC \u4e0d\u4e00\u81f4\uff0c\u9700\u8981\u5230 AGC \u4fee\u6539\u6307\u7eb9\u6216\u66f4\u6362\u7b7e\u540d\u8bc1\u4e66',
      '\u5c06 AGC \u4e0b\u8f7d\u7684\u6700\u65b0 agconnect-services.json \u653e\u5230 entry \u6a21\u5757\u6839\u76ee\u5f55\u540e\u91cd\u65b0\u7f16\u8bd1',
      '\u5728 AGC \u7684 API \u7ba1\u7406\u91cc\u786e\u8ba4\u5df2\u5f00\u542f\u534e\u4e3a\u8d26\u53f7\u670d\u52a1',
      '\u5728 DevEco \u6a21\u62df\u5668\u6216\u771f\u673a\u7684\u7cfb\u7edf\u8bbe\u7f6e\u91cc\u5148\u767b\u5f55\u534e\u4e3a\u8d26\u53f7\u518d\u6d4b\u8bd5',
      '\u5982\u679c\u53ea\u662f\u624b\u673a\u53f7\u6388\u6743\u5931\u8d25\uff0c\u5148\u786e\u8ba4\u534e\u4e3a\u8d26\u53f7\u767b\u5f55\u672c\u8eab\u662f\u5426\u6210\u529f'
    ];
  }

  static getShortHint(errorCode: number): string {
    switch (errorCode) {
      case 1001500001:
        return '\u4f18\u5148\u68c0\u67e5 client_id\u3001\u5305\u540d\u3001SHA-256 \u6307\u7eb9\u548c agconnect-services.json';
      case 1001502001:
        return '\u5148\u5230\u6a21\u62df\u5668\u8bbe\u7f6e\u4e2d\u767b\u5f55\u534e\u4e3a\u8d26\u53f7';
      case 1001502002:
        return '\u5230 AGC API \u7ba1\u7406\u4e2d\u5f00\u542f\u534e\u4e3a\u8d26\u53f7\u670d\u52a1';
      case 1001502003:
        return '\u4e0d\u8981\u4f7f\u7528\u9879\u76ee\u7ea7 Client ID\uff0c\u8981\u4f7f\u7528\u5e94\u7528\u7ea7 OAuth Client ID';
      case 1001502014:
        return '\u5148\u786e\u8ba4\u534e\u4e3a\u8d26\u53f7\u767b\u5f55\u529f\u80fd\u6253\u901a\uff0c\u518d\u5904\u7406\u624b\u673a\u53f7\u6388\u6743';
      default:
        return '\u8bf7\u5bf9\u7167\u767b\u5f55\u9875\u4e2d\u7684\u534e\u4e3a\u914d\u7f6e\u68c0\u67e5\u9879\u9010\u6761\u6392\u67e5';
    }
  }
}
