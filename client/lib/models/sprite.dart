/// 图片资源路径。集中放一处，改路径不用满项目找。
class AppAssets {
  AppAssets._();

  /// 攻城狮立绘。源图是仓库根目录的 攻城狮.jpg —— 它没有透明通道、四周还有黑边，
  /// 已用 `tool/make_sprite.py` 裁边 + 抠白底转成 PNG。**加新精灵时照这个流程走**，
  /// 之后把文件丢进 assets/sprites/ 即可，pubspec 里用的是目录写法，不用改。
  /// 旧立绘银杏书灵保留在 展示材料/UI设计稿/资源/银杏书灵.png。
  static const siegeLion = 'assets/sprites/siege_lion.png';

  /// 自习任务演示用的占位精灵（非正式美术资源）。
  static const spiritPlaceholder = 'assets/sprites/spirit_placeholder.png';
}

/// 图鉴里的一格。
///
/// **为什么格子要写死在客户端**：后端目前只返回「有没有捕获到攻城狮」
/// 这一个布尔值（`demo/state` 的 `captured`），不返回精灵列表。
/// 所以三个格子的编号和地点先由客户端定。
/// 将来后端能返回列表了，把 [dexSlots] 换成接口数据即可，界面不用改。
class DexSlot {
  const DexSlot({
    required this.id,
    required this.name,
    required this.location,
    this.assetPath,
  });

  /// 编号，如 `001`
  final String id;

  /// 名称。未解锁的格子显示「未解锁」
  final String name;

  /// 所属地点，格子下面那行
  final String location;

  /// 立绘。还没做的精灵是 null（显示锁图标）
  final String? assetPath;

  /// 带 No. 前缀的编号，如 `No.001`
  String get displayId => 'No.$id';
}

/// 图鉴的三个格子。对应设计稿 `05-图鉴.png` 的 `1 / 3`。
///
/// 后端 `totalSpecies` 目前固定是 3，和这里的长度一致。
/// 正式版计划扩充到 8–12 种（见 `03_软件需求说明书.md` PR-02）。
const List<DexSlot> dexSlots = [
  DexSlot(
    id: '001',
    name: '攻城狮',
    location: '图书馆',
    assetPath: AppAssets.siegeLion,
  ),
  DexSlot(id: '002', name: '未解锁', location: '湖畔 · 待开发'),
  DexSlot(id: '003', name: '未解锁', location: '跑道 · 待开发'),
];

/// 第 1 格（攻城狮）在图鉴里的下标。
/// 捕获状态是全局一个布尔值，只有这一格会亮。
const int siegeLionSlotIndex = 0;

/// 捕获地点的详细描述，背包和详情弹窗里显示。
const String siegeLionLocationDetail = '图书馆入口（模拟）';
