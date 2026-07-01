import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// 編み目定義の共通インターフェース
/// 基本編み目（CrochetStitch enum）とカスタム編み目（CustomStitch）の
/// 両方が実装する。型チェックの重複（is CrochetStitch || is CustomStitch）を
/// 避けるために使用する。
abstract interface class StitchDef {
  String get nameJa;
  String get nameEn;
  String? get imagePath;
  Color get color;
  bool get isOval;
  String getName(BuildContext context);
}

enum CrochetStitch implements StitchDef {
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
  @override
  final String nameJa;
  @override
  final String nameEn;
  @override
  final String? imagePath;
  @override
  final Color color;
  @override
  final bool isOval;

  // BuildContextを使った名前取得（推奨）
  @override
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
class CustomStitch implements StitchDef {
  @override
  final String nameJa;
  @override
  final String nameEn;
  @override
  final String? imagePath;
  @override
  final Color color;
  @override
  final bool isOval;

  // 編み目名から画像パスを復元するためのマッピング
  static const Map<String, String> _knownImagePaths = {
    'うね編み': 'assets/images/うね編み.png',
    'ねじれ細編み目': 'assets/images/twisted_single_crochet.png',
    '長編み１目交差': 'assets/images/長編み１目交差.png',
    'バック細編み': 'assets/images/back_single_crochet.png',
    '四つ巻き長編み目': 'assets/images/四つ巻き長編み目.png',
    '三つ巻き長編み目': 'assets/images/三つ巻き長編み目.png',
    '中長編み１目交差': 'assets/images/中長編み１目交差.png',
    '長編み３目の玉編み目': 'assets/images/長編み３目の玉編み目.png',
    '長編み１目左上３目交差': 'assets/images/長編み１目左上３目交差.png',
    '長編み１目右上交差': 'assets/images/長編み１目右上交差.png',
    '長編み１目右上３目交差': 'assets/images/長編み１目右上３目交差.png',
    '中長編み３目の玉編み目': 'assets/images/中長編み３目の玉編み目.png',
    '長々編み５目の玉編み目': 'assets/images/長々編み５目の玉編み目.png',
    '変わり玉編み目＜中長編み3目＞': 'assets/images/変わり玉編み目＜中長編み3目＞.png',
    '変わり玉編み目＜長編み3目＞': 'assets/images/変わり玉編み目＜長編み3目＞.png',
    '引き出し玉編み目': 'assets/images/引き出し玉編み目.png',
    '細こま編み２目編み入れる': 'assets/images/細こま編み２目編み入れる.png',
    '中長編み５目のパプコーン編み': 'assets/images/hdc_5_popcorn.png',
    '長編み５目のパプコーン編み': 'assets/images/dc_5_popcorn.png',
    '長々編み６目のパプコーン編み目': 'assets/images/tc_6_popcorn.png',
    '細こま編み3目編み入れる': 'assets/images/細こま編み3目編み入れる.png',
    '長編み3目編み入れる': 'assets/images/長編み3目編み入れる.png',
    '中長編み2目編み入れる': 'assets/images/中長編み2目編み入れる.png',
    '細こま編み２目一度': 'assets/images/細こま編み２目一度.png',
    '中長編み3目編み入れる': 'assets/images/中長編み3目編み入れる.png',
    '長編み２目編み入れる': 'assets/images/長編み２目編み入れる.png',
    '中長編み2目一度': 'assets/images/中長編み2目一度.png',
    '細こま編み3目一度': 'assets/images/細こま編み3目一度.png',
    '中長編み３目一度': 'assets/images/中長編み３目一度.png',
    '長編み２目一度': 'assets/images/長編み２目一度.png',
    '長編み3目一度': 'assets/images/長編み3目一度.png',
    '細編み2目編み入れる': 'assets/images/細編み2目編み入れる.png',
    '細編み2目一度': 'assets/images/細編み2目一度.png',
    '立ち上がり': 'assets/images/tachiagari.png',
  };

  // 日本語名から画像パスを検索
  static String? lookupImagePath(String nameJa) {
    return _knownImagePaths[nameJa];
  }

  const CustomStitch({
    required this.nameJa,
    required this.nameEn,
    this.imagePath,
    this.color = Colors.pink,
    this.isOval = false,
  });

  @override
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
      'imagePath': imagePath,
      'color': color.toARGB32(),
      'isOval': isOval,
    };
  }

  // JSONから復元用メソッド
  factory CustomStitch.fromJson(Map<String, dynamic> json) {
    // imagePathが空文字列の場合はnullとして扱う
    final imagePathRaw = json['imagePath'] as String?;
    var imagePath = (imagePathRaw == null || imagePathRaw.isEmpty)
        ? null
        : imagePathRaw;

    final nameJa = json['nameJa'] as String? ?? json['name'] as String;

    // imagePathがnullの場合、編み目名から画像パスを復元
    imagePath ??= lookupImagePath(nameJa);

    return CustomStitch(
      nameJa: nameJa,
      nameEn: json['nameEn'] as String? ?? json['name'] as String,
      imagePath: imagePath,
      color: Color(json['color'] as int),
      isOval: json['isOval'] as bool? ?? false,
    );
  }
}
