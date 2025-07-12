import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';

enum CrochetStitch {
  chain('鎖編み', '鎖編み', 'assets/images/鎖編み.png', Colors.blue, true),
  slipStitch('引き抜き編み', '引き抜き編み', 'assets/images/引き抜き編み.png', Colors.grey, true),
  singleCrochet('細編み', '細編み', 'assets/images/細編み.png', Colors.green, false),
  halfDoubleCrochet(
      '中長編み', '中長編み', 'assets/images/中長編み.png', Colors.orange, false),
  doubleCrochet('長編み', '長編み', 'assets/images/長編み.png', Colors.purple, false),
  trebleCrochet('長々編み', '長々編み', 'assets/images/長々編み.png', Colors.red, false);

  const CrochetStitch(
      this.nameJa, this.nameEn, this.imagePath, this.color, this.isOval);
  final String nameJa;
  final String nameEn;
  final String? imagePath;
  final Color color;
  final bool isOval;

  String get name {
    final locale = PlatformDispatcher.instance.locale.languageCode;
    return locale == 'ja' ? nameJa : nameEn;
  }
}

// カスタム編み目を管理するためのクラス
class CustomStitch {
  final String nameJa;
  final String nameEn;
  final String? imagePath;
  final Color color;
  final bool isOval;

  const CustomStitch({
    required this.nameJa,
    required this.nameEn,
    this.imagePath,
    this.color = Colors.pink,
    this.isOval = false,
  });

  String getName(BuildContext context) {
    final locale = context.locale.languageCode;
    return locale == 'ja' ? nameJa : nameEn;
  }

  // 後方互換性のため残す（ただし英語を返す可能性がある）
  String get name {
    return nameEn;
  }
}
