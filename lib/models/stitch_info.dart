import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'crochet_stitch.dart';

/// 編み目履歴に入っている編み目から、表示に必要な情報を取り出す。
///
/// 履歴の編み目は保存の経緯によって形が違う:
/// - 基本編み目・読み込み直後のカスタム編み目: [StitchDef]
/// - 編んでいる最中に追加したカスタム編み目: JSON形式の Map
/// - ごく古いデータ: 名前だけの文字列
class StitchInfo {
  const StitchInfo({
    required this.nameJa,
    required this.nameEn,
    this.imagePath,
  });

  final String nameJa;
  final String nameEn;
  final String? imagePath;

  /// 同じ編み目かどうかの判定に使うキー
  String get key => nameJa;

  /// 解釈できない値の場合はnull
  static StitchInfo? of(dynamic stitch) {
    if (stitch is StitchDef) {
      return StitchInfo(
        nameJa: stitch.nameJa,
        nameEn: stitch.nameEn,
        imagePath: stitch.imagePath,
      );
    }
    if (stitch is Map) {
      final name = stitch['name'];
      final rawJa = stitch['nameJa'] ?? name;
      final rawEn = stitch['nameEn'] ?? name;
      final nameJa = rawJa is String ? rawJa : (rawEn is String ? rawEn : null);
      final nameEn = rawEn is String ? rawEn : nameJa;
      if (nameJa == null || nameEn == null) return null;

      final rawPath = stitch['imagePath'];
      final imagePath = (rawPath is String && rawPath.isNotEmpty)
          ? rawPath
          : CustomStitch.lookupImagePath(nameJa);
      return StitchInfo(nameJa: nameJa, nameEn: nameEn, imagePath: imagePath);
    }
    if (stitch is String) {
      for (final basic in CrochetStitch.values) {
        if (basic.nameJa == stitch || basic.nameEn == stitch) {
          return of(basic);
        }
      }
      return StitchInfo(nameJa: stitch, nameEn: stitch);
    }
    return null;
  }

  /// 表示言語に合わせた名前（日本語以外は英語名）
  String displayName(BuildContext context) {
    try {
      return context.locale.languageCode == 'ja' ? nameJa : nameEn;
    } catch (_) {
      return nameJa;
    }
  }
}
