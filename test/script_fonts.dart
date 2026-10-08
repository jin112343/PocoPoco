// テストで各言語の文字を実際の幅・形で描くためのフォント。
//
// Flutter のテストは、フォントを読み込まないとすべての文字を正方形で描く。
// 見切れの点検やストア用の画像では実際の文字幅が必要なので、
// このMacのシステムフォントを文字の種類ごとに読み込んで使う。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:poco/l10n/app_locales.dart';

const _sys = '/System/Library/Fonts';

/// 欧文・キリル文字・ギリシャ文字など（iOS の標準フォントと同じ系統）
const String scriptTextFamily = 'ShotText';

/// 日本語（アプリに同梱している NotoSansJP）
const String scriptJapaneseFamily = 'ShotJP';

const _fontFiles = <String, List<String>>{
  scriptTextFamily: ['$_sys/SFNS.ttf'],
  'ShotKR': ['$_sys/AppleSDGothicNeo.ttc'],
  'ShotSC': ['$_sys/Hiragino Sans GB.ttc'],
  'ShotTC': ['$_sys/STHeiti Medium.ttc'],
  'ShotThai': ['$_sys/ThonburiUI.ttc'],
  'ShotArabic': ['$_sys/SFArabic.ttf'],
  'ShotHebrew': ['$_sys/SFHebrew.ttf'],
  'ShotDeva': ['$_sys/Kohinoor.ttc'],
  'ShotBangla': ['$_sys/KohinoorBangla.ttc'],
  'ShotGujarati': ['$_sys/KohinoorGujarati.ttc'],
  'ShotTelugu': ['$_sys/KohinoorTelugu.ttc'],
  'ShotKannada': ['$_sys/NotoSansKannada.ttc'],
  'ShotOriya': ['$_sys/NotoSansOriya.ttc'],
  'ShotGurmukhi': ['$_sys/Supplemental/Gurmukhi MN.ttc'],
  'ShotTamil': ['$_sys/Supplemental/Tamil MN.ttc'],
  'ShotMalayalam': ['$_sys/Supplemental/Malayalam MN.ttc'],
  'ShotSinhala': ['$_sys/Supplemental/Sinhala MN.ttc'],
  'ShotMyanmar': ['$_sys/NotoSansMyanmar.ttc'],
  'ShotKhmer': ['$_sys/Supplemental/Khmer MN.ttc'],
  'ShotLao': ['$_sys/Supplemental/Lao MN.ttc'],
  'ShotArmenian': ['$_sys/SFArmenian.ttf'],
  'ShotGeorgian': ['$_sys/SFGeorgian.ttf'],
  'ShotEthiopic': ['$_sys/Supplemental/KefaIII.ttf'],
  'ShotUnicode': ['$_sys/Supplemental/Arial Unicode.ttf'],
};

/// 文字の種類ごとのフォントを読み込む（setUpAll で1度呼ぶ）
Future<void> loadScriptFonts() async {
  Future<void> load(String family, List<Future<ByteData>> fonts) async {
    final loader = FontLoader(family);
    fonts.forEach(loader.addFont);
    await loader.load();
  }

  Future<ByteData> file(String path) async =>
      ByteData.view(Uint8List.fromList(await File(path).readAsBytes()).buffer);

  for (final entry in _fontFiles.entries) {
    await load(entry.key, [for (final path in entry.value) file(path)]);
  }
  await load(scriptJapaneseFamily, [
    rootBundle.load('assets/fonts/NotoSansJP-Regular.ttf'),
    rootBundle.load('assets/fonts/NotoSansJP-Bold.ttf'),
  ]);
  await load(
      'MaterialIcons', [rootBundle.load('fonts/MaterialIcons-Regular.otf')]);
}

/// 言語に合わせた代替フォントの順番（漢字は言語ごとに字形が違うので、その言語のものを先に）
List<String> scriptFontFallbackFor(Locale locale) {
  final cjk = switch (AppLangAssetLoader.fileNameFor(locale)) {
    'ja' => ['ShotJP', 'ShotSC', 'ShotKR'],
    'ko' => ['ShotKR', 'ShotJP', 'ShotSC'],
    'zh' => ['ShotSC', 'ShotJP', 'ShotKR'],
    'zh-Hant' => ['ShotTC', 'ShotJP', 'ShotKR'],
    _ => ['ShotJP', 'ShotSC', 'ShotKR'],
  };
  return [
    ...cjk,
    for (final family in _fontFiles.keys)
      if (!const {scriptTextFamily, 'ShotKR', 'ShotSC', 'ShotTC', 'ShotUnicode'}
          .contains(family))
        family,
    'ShotUnicode',
  ];
}
