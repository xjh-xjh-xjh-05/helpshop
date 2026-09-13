import { Address, ProductCandidate } from '../models/ShoppingModels';

export const MOCK_PRODUCTS: ProductCandidate[] = [
  {
    id: 'shoe-001',
    platform: '京东',
    name: '轻便软底老人健步鞋',
    price: 189,
    rating: 4.8,
    sales: 23500,
    shopName: '安心步行旗舰店',
    description: '软底防滑，鞋面透气，适合日常散步。',
    tags: ['鞋', '不累脚', '防滑', '老人'],
    recommendScore: 0
  },
  {
    id: 'shoe-002',
    platform: '淘宝',
    name: '防滑减震休闲鞋',
    price: 159,
    rating: 4.6,
    sales: 18800,
    shopName: '舒适鞋仓',
    description: '减震鞋垫，脚背空间宽，适合脚宽人群。',
    tags: ['鞋', '舒适', '减震', '宽脚'],
    recommendScore: 0
  },
  {
    id: 'shoe-003',
    platform: '拼多多',
    name: '经济款软底散步鞋',
    price: 99,
    rating: 4.4,
    sales: 42000,
    shopName: '惠民鞋业',
    description: '价格实惠，基础防滑，适合短距离出门。',
    tags: ['鞋', '便宜', '软底', '散步'],
    recommendScore: 0
  },
  {
    id: 'shoe-004',
    platform: '京东',
    name: '足弓支撑健步鞋',
    price: 259,
    rating: 4.9,
    sales: 9600,
    shopName: '康足生活馆',
    description: '足弓支撑更稳定，适合长时间步行。',
    tags: ['鞋', '足弓', '不累脚', '稳定'],
    recommendScore: 0
  },
  {
    id: 'bp-001',
    platform: '京东',
    name: '家用上臂式血压计',
    price: 229,
    rating: 4.8,
    sales: 31000,
    shopName: '康养医疗器械',
    description: '大屏显示，语音播报，适合老人居家测量。',
    tags: ['血压计', '上臂式', '语音', '老人'],
    recommendScore: 0
  },
  {
    id: 'bp-002',
    platform: '淘宝',
    name: '智能语音血压仪',
    price: 199,
    rating: 4.7,
    sales: 16000,
    shopName: '家庭健康优选',
    description: '一键测量，语音提示，配有收纳袋。',
    tags: ['血压计', '智能', '语音'],
    recommendScore: 0
  },
  {
    id: 'bp-003',
    platform: '拼多多',
    name: '基础款电子血压计',
    price: 128,
    rating: 4.3,
    sales: 52000,
    shopName: '惠康器械',
    description: '基础测量功能，字体清晰，性价比高。',
    tags: ['血压计', '便宜', '电子'],
    recommendScore: 0
  },
  {
    id: 'milk-001',
    platform: '京东',
    name: '高钙无糖中老年奶粉',
    price: 168,
    rating: 4.8,
    sales: 28400,
    shopName: '营养生活旗舰店',
    description: '无蔗糖配方，添加钙和维生素D。',
    tags: ['奶粉', '高钙', '无糖', '中老年'],
    recommendScore: 0
  },
  {
    id: 'milk-002',
    platform: '淘宝',
    name: '中老年益生元奶粉',
    price: 149,
    rating: 4.6,
    sales: 17500,
    shopName: '每日营养馆',
    description: '含益生元，口味清淡，适合日常补充。',
    tags: ['奶粉', '益生元', '中老年'],
    recommendScore: 0
  },
  {
    id: 'milk-003',
    platform: '拼多多',
    name: '实惠装高钙奶粉',
    price: 109,
    rating: 4.4,
    sales: 39000,
    shopName: '健康补给站',
    description: '家庭实惠装，基础营养配方。',
    tags: ['奶粉', '高钙', '便宜'],
    recommendScore: 0
  },
  {
    id: 'phone-001',
    platform: '京东',
    name: '大按键老人手机',
    price: 299,
    rating: 4.7,
    sales: 12800,
    shopName: '银发数码',
    description: '大字体、大音量、长续航，支持一键拨号。',
    tags: ['手机', '老人', '大按键', '长续航'],
    recommendScore: 0
  },
  {
    id: 'phone-002',
    platform: '淘宝',
    name: '智能老人机',
    price: 399,
    rating: 4.5,
    sales: 8500,
    shopName: '亲情通信',
    description: '简洁桌面，支持视频通话和定位。',
    tags: ['手机', '老人', '智能', '视频'],
    recommendScore: 0
  },
  {
    id: 'lamp-001',
    platform: '京东',
    name: '护眼阅读台灯',
    price: 139,
    rating: 4.8,
    sales: 22000,
    shopName: '明亮家居',
    description: '无频闪，亮度可调，适合夜间阅读。',
    tags: ['台灯', '护眼', '阅读'],
    recommendScore: 0
  },
  {
    id: 'lamp-002',
    platform: '淘宝',
    name: '触控调光护眼灯',
    price: 99,
    rating: 4.5,
    sales: 15000,
    shopName: '温暖小家',
    description: '三档亮度，操作简单，价格友好。',
    tags: ['台灯', '护眼', '便宜'],
    recommendScore: 0
  },
  {
    id: 'rice-001',
    platform: '京东',
    name: '五常大米5kg',
    price: 79,
    rating: 4.9,
    sales: 68000,
    shopName: '东北粮仓',
    description: '口感软糯，适合家庭日常主食。',
    tags: ['大米', '五常', '主食'],
    recommendScore: 0
  },
  {
    id: 'rice-002',
    platform: '拼多多',
    name: '东北珍珠米10斤',
    price: 59,
    rating: 4.5,
    sales: 83000,
    shopName: '实惠粮油',
    description: '大包装实惠款，适合日常囤货。',
    tags: ['大米', '便宜', '东北'],
    recommendScore: 0
  },
  {
    id: 'medicine-001',
    platform: '京东健康',
    name: '家用分药盒',
    price: 29,
    rating: 4.8,
    sales: 33000,
    shopName: '健康照护专营',
    description: '一周分格，早中晚标记清楚。',
    tags: ['药盒', '分药', '老人'],
    recommendScore: 0
  },
  {
    id: 'cart-001',
    platform: '淘宝',
    name: '折叠买菜小推车',
    price: 89,
    rating: 4.6,
    sales: 21000,
    shopName: '便民生活馆',
    description: '轻便可折叠，轮子顺滑，适合买菜。',
    tags: ['推车', '买菜', '折叠'],
    recommendScore: 0
  },
  {
    id: 'heater-001',
    platform: '京东',
    name: '安全恒温暖脚器',
    price: 129,
    rating: 4.7,
    sales: 11800,
    shopName: '冬日暖家',
    description: '恒温防烫，操作简单，冬天暖脚。',
    tags: ['暖脚器', '恒温', '安全'],
    recommendScore: 0
  },
  {
    id: 'blanket-001',
    platform: '淘宝',
    name: '加厚保暖毛毯',
    price: 119,
    rating: 4.6,
    sales: 26000,
    shopName: '舒睡家纺',
    description: '柔软亲肤，厚实保暖，适合秋冬。',
    tags: ['毛毯', '保暖', '加厚'],
    recommendScore: 0
  }
];

export const MOCK_ADDRESSES: Address[] = [
  {
    id: 'addr-001',
    receiver: '徐叔叔',
    phone: '138****6688',
    detail: '上海市浦东新区康桥镇安心小区 12 号楼 302 室',
    isDefault: true
  },
  {
    id: 'addr-002',
    receiver: '徐阿姨',
    phone: '136****8899',
    detail: '上海市闵行区银龄花园 8 号楼 501 室',
    isDefault: false
  }
];

export const SAMPLE_QUERIES: string[] = [
  '我想买一双不累脚的鞋',
  '帮我看看家用血压计',
  '买一罐中老年无糖奶粉',
  '老人用的大按键手机',
  '想买个护眼台灯'
];
