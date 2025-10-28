import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

enum CrochetStitch {
  chain('鎖編み', 'Chain Stitch', 'assets/images/鎖編み.png', Colors.blue, true),
  slipStitch(
      '引き抜き編み', 'Slip Stitch', 'assets/images/引き抜き編み.png', Colors.grey, true),
  singleCrochet(
      '細編み', 'Single Crochet', 'assets/images/細編み.png', Colors.green, false),
  halfDoubleCrochet('中長編み', 'Half Double Crochet', 'assets/images/中長編み.png',
      Colors.orange, false),
  doubleCrochet(
      '長編み', 'Double Crochet', 'assets/images/長編み.png', Colors.purple, false),
  trebleCrochet(
      '長々編み', 'Treble Crochet', 'assets/images/長々編み.png', Colors.red, false);

  const CrochetStitch(
      this.nameJa, this.nameEn, this.imagePath, this.color, this.isOval);
  final String nameJa;
  final String nameEn;
  final String? imagePath;
  final Color color;
  final bool isOval;

  // BuildContextを使った名前取得（推奨）
  String getName(BuildContext context) {
    try {
      final locale = context.locale.languageCode;
      return locale == 'ja' ? nameJa : nameEn;
    } catch (e) {
      // EasyLocalizationがまだ初期化されていない場合は日本語をデフォルトで返す
      return nameJa;
    }
  }

  // 後方互換性のため残す（デフォルトで日本語を返す）
  String get name => nameJa;
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

  // 後方互換性のため残す（デフォルトで日本語を返す）
  String get name {
    return nameJa;
  }

  // JSON変換用メソッド
  Map<String, dynamic> toJson() {
    return {
      'type': 'custom',
      'name': nameEn,
      'nameJa': nameJa,
      'nameEn': nameEn,
      'imagePath': imagePath ?? '',
      'color': color.toARGB32(),
      'isOval': isOval,
    };
  }

  // JSONから復元用メソッド
  factory CustomStitch.fromJson(Map<String, dynamic> json) {
    return CustomStitch(
      nameJa: json['nameJa'] as String? ?? json['name'] as String,
      nameEn: json['nameEn'] as String? ?? json['name'] as String,
      imagePath: json['imagePath'] as String?,
      color: Color(json['color'] as int),
      isOval: json['isOval'] as bool? ?? false,
    );
  }
}
