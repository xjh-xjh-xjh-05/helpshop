export enum BackendMode {
  LocalMock = 'local_mock',
  RemoteApi = 'remote_api'
}

export enum AgentMode {
  Native = 'native',
  Copilot = 'copilot'
}

export class AppConfig {
  static readonly backendMode: BackendMode = BackendMode.RemoteApi;

  static readonly remoteBackendBaseUrl: string = 'http://10.80.35.138:8000';

  static readonly agentMode: AgentMode = AgentMode.Copilot;

  static readonly requestTimeoutMs: number = 3000;
}

export class CopilotConfig {
  static readonly baseUrl: string = 'https://api.deepseek.com/v1';
  static readonly apiKey: string = 'sk-f39175d8dd2d4b4aafd3a3f2f551ea2d';
  static readonly model: string = 'deepseek-v4-flash';
  static readonly systemPrompt: string =
    '你是银发智购助手。你的任务是帮助老人或子女完成商品搜索、比价、地址确认和支付前准备。' +
    '如果需要商品、比价或地址信息，优先调用已注册的前端工具，不要凭空编造商品。';
}

export class HuaweiPayConfig {
  static readonly appId: string = '1992956668018718912';
  static readonly mercNo: string = '300000000000000';
  static readonly authId: string = 'auth_demo_001';
  static readonly callbackUrl: string = 'https://your-server.com/api/payments/huawei-callback';
  static readonly useServerPreOrder: boolean = true;
}

export class PddApiConfig {
  static readonly clientId: string = 'b76647e424384c898e130788ca690e45';
  static readonly clientSecret: string = '13100d1ebfb3e7003488ea6d0181b6caf5f5a5fa';
  static readonly pid: string = '44594836_317003711';
  static readonly baseUrl: string = 'https://gw-api.pinduoduo.com/api/router';
  static readonly enabled: boolean = true;
}

export class WanbangApiConfig {
  static readonly apiKey: string = 't8772115694';
  static readonly apiSecret: string = '5694e53d';
  static readonly baseUrl: string = 'https://api-gw.onebound.cn';
  static readonly enabled: boolean = false;
  static readonly platforms: string[] = ['taobao', 'jd', 'pdd'];
  static readonly categoryMap: Record<string, Record<string, string>> = {
    'taobao': {
      '健康保健': '血压计 按摩器 足浴盆 血糖仪 制氧机 理疗仪 护膝 护腰 养生壶 体温计 艾灸 拔罐 助听器 轮椅 拐杖 雾化器 健康 保健',
      '食品营养': '牛奶 奶粉 麦片 蜂蜜 红枣 枸杞 核桃 杂粮 糕点 豆奶 营养 维生素 零食 水果',
      '居家生活': '保温杯 收纳 清洁 防滑垫 坐垫 被子 枕头 电热水壶 风扇 暖脚 拖把 纸巾 厨具 锅 灯',
      '鞋服出行': '老人鞋 防滑鞋 棉服 外套 冲锋衣 围巾 手套 棉鞋 运动鞋 加绒 保暖 中老年 女装',
      '母婴': '奶粉 纸尿裤 辅食 童装 玩具',
      '数码家电': '手机 平板 电视 洗衣机 冰箱 空调 耳机',
      '美妆个护': '面膜 洗面奶 防晒 洗发水 沐浴露 牙膏'
    },
    'jd': {
      '健康保健': '血压计 按摩器 足浴盆 血糖仪 制氧机 理疗仪 护膝 护腰 养生壶 体温计 艾灸 拔罐 助听器 轮椅 拐杖 雾化器',
      '食品营养': '牛奶 奶粉 麦片 蜂蜜 红枣 枸杞 核桃 杂粮 糕点 豆奶 营养 维生素',
      '居家生活': '保温杯 收纳 清洁 防滑垫 坐垫 被子 枕头 电热水壶 风扇 暖脚 拖把 纸巾 厨具',
      '鞋服出行': '老人鞋 防滑鞋 棉服 外套 冲锋衣 围巾 手套 棉鞋 运动鞋 加绒 保暖 中老年 女装',
      '母婴': '奶粉 纸尿裤 辅食 童装 玩具',
      '数码家电': '手机 平板 电视 洗衣机 冰箱 空调 耳机',
      '美妆个护': '面膜 洗面奶 防晒 洗发水 沐浴露 牙膏'
    },
    'pdd': {
      '健康保健': '血压计 按摩器 足浴盆 血糖仪 制氧机 理疗仪 护膝 护腰 养生壶 体温计 艾灸 拔罐 助听器 轮椅 拐杖 雾化器',
      '食品营养': '牛奶 奶粉 麦片 蜂蜜 红枣 枸杞 核桃 杂粮 糕点 豆奶 营养 维生素',
      '居家生活': '保温杯 收纳 清洁 防滑垫 坐垫 被子 枕头 电热水壶 风扇 暖脚 拖把 纸巾 厨具',
      '鞋服出行': '老人鞋 防滑鞋 棉服 外套 冲锋衣 围巾 手套 棉鞋 运动鞋 加绒 保暖 中老年 女装',
      '母婴': '奶粉 纸尿裤 辅食 童装 玩具',
      '数码家电': '手机 平板 电视 洗衣机 冰箱 空调 耳机',
      '美妆个护': '面膜 洗面奶 防晒 洗发水 沐浴露 牙膏'
    }
  };
}
