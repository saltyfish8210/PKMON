import 'package:flutter/material.dart';

// PKMon 设计变量
//
// 数值来源：`UI设计稿/design-tokens.json` 与 `开发文档/04_UI设计说明.md` 第 4 节。
//
// 约定：页面里不要写死色值和尺寸，一律引用这里的常量。
// 将来 UI/美术调整视觉，只改这一个文件。

/// 颜色
class AppColors {
  AppColors._();

  /// 主色：主按钮底色、导航高亮、进度条
  static const primary = Color(0xFF2C7A6B);

  /// 主色浅：选中态底色、地图页浅底
  static const primarySoft = Color(0xFFE6F2EF);

  /// 强调色：可用于收集进度高亮等场景（目前暂未用到，先按设计变量预留）
  static const accent = Color(0xFFF5A623);

  /// 主文字
  static const text = Color(0xFF1F2937);

  /// 次文字：副标题、说明、脚注
  static const secondaryText = Color(0xFF6B7280);

  /// 页面底色
  static const page = Color(0xFFF7F8FA);

  /// 卡片 / 浮层底色
  static const surface = Color(0xFFFFFFFF);

  /// 分割线与描边
  static const divider = Color(0xFFE5E7EB);

  /// 错误态底色（答错页面用，本轮预留）
  static const errorSurface = Color(0xFFFFEAE6);

  /// 错误态文字与图标（答错页面用，本轮预留）
  static const errorText = Color(0xFFB44F3C);

  /// 地图示意图专用色（不是设计 token，只是地图贴图配色）
  static const mapGround = Color(0xFFEFF3EA);
  static const mapBuilding = Color(0xFFEFEBDD);
  static const mapWater = Color(0xFFBFDCD6);
  static const mapRoad = Color(0xFFFFFFFF);
  static const mapTree = Color(0xFFCBDCC4);

  /// 网页版：手机壳外面的背景色。仅网页版可见，安卓用不到。
  static const webBackdrop = Color(0xFFE9EEEA);
}

/// 字号（单位 sp）
class AppFontSizes {
  AppFontSizes._();

  /// 页面主标题：PKMon、校园图鉴、我的精灵
  static const pageTitle = 26.0;

  /// 抓捕页精灵名（本轮未用到，预留）
  static const captureTitle = 28.0;

  /// 题干（本轮未用到，预留）
  static const question = 18.0;

  /// 正文、按钮、列表
  static const body = 14.0;

  /// 副标题、说明、脚注、导航文字
  static const secondary = 12.0;
}

/// 间距（单位 dp）
class AppSpacing {
  AppSpacing._();

  /// 基本单位，所有间距都是它的整数倍
  static const base = 4.0;

  /// 地图页底部面板的左右外边距
  static const mapContentSide = 20.0;

  /// 抓捕页卡片的左右外边距（本轮未用到，预留）
  static const captureSide = 24.0;

  /// 卡片内边距
  static const cardPadding = 20.0;

  /// 按钮最小高度
  static const buttonMinHeight = 50.0;

  /// 可点击元素最小热区
  static const iconHitTarget = 48.0;

  /// 底部导航栏高度
  static const navigationHeight = 72.0;

  /// 网页版「手机壳」的宽度。
  /// 取 412 是因为设计稿的参考视口之一就是 412×915（见 design-tokens.json）。
  static const phonePreviewWidth = 412.0;

  /// 网页版「手机壳」的触发阈值：窗口宽于这个值才收起成手机大小。
  /// 比这个窄（比如真的用手机的浏览器打开）就铺满，不加壳。
  static const phonePreviewBreakpoint = 600.0;

  /// 全宽阈值：窗口宽于这个值（投影、桌面窗口）就切到「宽屏居中」布局。
  static const webFullBleedBreakpoint = 900.0;

  /// 宽屏居中的内容宽度：比手机宽、比整屏窄，地图与图鉴都还能看清。
  static const webContentWidth = 620.0;
}

/// 圆角（单位 dp）
class AppRadius {
  AppRadius._();

  /// 按钮
  static const button = 12.0;

  /// 列表卡片、图鉴格子
  static const listCard = 16.0;

  /// 抓捕页卡片（本轮未用到，预留）
  static const captureCard = 20.0;

  /// 胶囊（药丸）形状
  static const pill = 999.0;
}
