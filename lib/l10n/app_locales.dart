import 'dart:convert';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';

/// アプリが対応している言語。
///
/// 端末の言語設定に合うものを上から順に探して使う（アプリ内に言語の切り替えはない）。
/// 地域や文字の種類で訳が分かれる言語（ポルトガル語・中国語）は、
/// 細かい指定のものを先に並べる。
const List<Locale> appSupportedLocales = [
  Locale('ja'),
  Locale('en'),
  Locale('ko'),
  Locale('es'),
  Locale('de'),
  Locale('fr'),
  Locale('it'),
  Locale('pt', 'PT'),
  Locale('pt'),
  Locale('ca'),
  Locale('nl'),
  Locale('ro'),
  Locale('tr'),
  Locale('id'),
  Locale('ru'),
  Locale('uk'),
  Locale('pl'),
  Locale('cs'),
  Locale('sk'),
  Locale('hr'),
  Locale('sl'),
  Locale('hu'),
  Locale('el'),
  Locale('sv'),
  Locale('da'),
  Locale('nb'),
  Locale('no'),
  Locale('fi'),
  Locale('ms'),
  Locale('vi'),
  Locale('th'),
  Locale('he'),
  Locale('ar'),
  // 繁体字（台湾・香港・マカオ、または文字の指定が繁体字）を先に、それ以外は簡体字
  Locale('zh', 'TW'),
  Locale('zh', 'HK'),
  Locale('zh', 'MO'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  Locale('zh'),
  Locale('hi'),
  Locale('bn'),
  Locale('gu'),
  Locale('kn'),
  Locale('ml'),
  Locale('mr'),
  Locale('or'),
  Locale('pa'),
  Locale('ta'),
  Locale('te'),
  Locale('ur'),
  Locale('fa'),
  Locale('ne'),
  Locale('si'),
  Locale('my'),
  Locale('af'),
  Locale('sq'),
  Locale('az'),
  Locale('be'),
  Locale('bg'),
  Locale('et'),
  Locale('eu'),
  Locale('fil'),
  Locale('gl'),
  Locale('hy'),
  Locale('is'),
  Locale('ka'),
  Locale('kk'),
  Locale('km'),
  Locale('ky'),
  Locale('lo'),
  Locale('lt'),
  Locale('lv'),
  Locale('mk'),
  Locale('mn'),
  Locale('sr'),
  Locale('sw'),
  Locale('zu'),
  Locale('am'),
];

/// 端末の言語が対応外の時と、訳のない文言に使う言語
const Locale appFallbackLocale = Locale('en');

/// 翻訳ファイル（assets/lang/<名前>.json）の読み込み。
///
/// 地域違いの言語を同じファイルにまとめるため、言語ごとの読み込み先を決める。
class AppLangAssetLoader extends AssetLoader {
  const AppLangAssetLoader();

  /// [locale] の翻訳が入っているファイルの名前（拡張子なし）
  static String fileNameFor(Locale locale) {
    switch (locale.languageCode) {
      case 'zh':
        final traditional = locale.scriptCode == 'Hant' ||
            const {'TW', 'HK', 'MO'}.contains(locale.countryCode);
        return traditional ? 'zh-Hant' : 'zh';
      case 'pt':
        return locale.countryCode == 'PT' ? 'pt-PT' : 'pt';
      case 'no':
        // ノルウェー語は書き言葉のブークモール（nb）を使う
        return 'nb';
      default:
        return locale.languageCode;
    }
  }

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    try {
      final text =
          await rootBundle.loadString('$path/${fileNameFor(locale)}.json');
      return json.decode(text) as Map<String, dynamic>;
    } catch (_) {
      // 訳のファイルが無い・読めない言語でも起動できるよう、英語で表示する
      final text = await rootBundle
          .loadString('$path/${fileNameFor(appFallbackLocale)}.json');
      return json.decode(text) as Map<String, dynamic>;
    }
  }
}
