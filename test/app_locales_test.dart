// 対応言語の点検。
//
// - 対応している言語すべてに翻訳ファイルがあり、英語と同じ差し込み（{count} など）を持つこと
// - Flutter 標準の部品（日付の選択、「戻る」など）もその言語で表示できること
// - iOS に届け出ている言語の一覧（Info.plist）と食い違っていないこと

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:poco/l10n/app_locales.dart';
import 'package:poco/l10n/stitch_names.dart';
import 'package:poco/models/crochet_stitch.dart';
import 'package:poco/models/premium_stitches.dart';

Map<String, dynamic> _read(String name) =>
    jsonDecode(File('assets/lang/$name.json').readAsStringSync())
        as Map<String, dynamic>;

final _placeholder = RegExp(r'\{[a-zA-Z_]+\}');

List<String> _placeholders(String text) =>
    _placeholder.allMatches(text).map((m) => m.group(0)!).toList()..sort();

void main() {
  final fileNames = {
    for (final locale in appSupportedLocales)
      AppLangAssetLoader.fileNameFor(locale),
  };

  test('対応している言語すべてに翻訳ファイルがある', () {
    for (final name in fileNames) {
      expect(File('assets/lang/$name.json').existsSync(), isTrue,
          reason: 'assets/lang/$name.json がありません');
    }
    // 逆に、どの言語からも使われないファイルが残っていない
    final onDisk = {
      for (final file in Directory('assets/lang').listSync().whereType<File>())
        if (file.path.endsWith('.json'))
          file.uri.pathSegments.last.replaceAll('.json', ''),
    };
    expect(onDisk.difference(fileNames), isEmpty);
  });

  test('どの言語も、画面で使う文言と差し込みが英語とそろっている', () {
    final english = _read('en');
    // 画面で使っている文言（翻訳の原文）
    final used = (jsonDecode(File('tool/l10n/source_en.json').readAsStringSync())
            as Map<String, dynamic>)
        .keys;
    final problems = <String>[];
    for (final name in fileNames) {
      final data = _read(name);
      for (final key in used) {
        final value = data[key];
        if (value is! String || value.trim().isEmpty) {
          problems.add('$name: $key がありません');
          continue;
        }
        final expected = _placeholders(english[key] as String);
        if (_placeholders(value).join() != expected.join()) {
          problems.add('$name: $key の差し込みが違います（$expected）');
        }
      }
    }
    expect(problems, isEmpty);
  });

  test('編み目の名前が、日本語・英語以外のすべての言語に訳されている', () {
    // 基本の編み目とプレミアムの編み目すべて
    final stitches = [
      for (final stitch in CrochetStitch.values) stitch.nameEn,
      for (final entry in premiumStitchCatalog) entry['nameEn']!,
    ];
    final problems = <String>[];
    for (final name in fileNames.difference({'ja', 'en'})) {
      final data = _read(name);
      for (final nameEn in stitches) {
        final value = data[stitchNameKey(nameEn)];
        if (value is! String || value.trim().isEmpty) {
          problems.add('$name: $nameEn の訳がありません');
        }
      }
    }
    expect(problems, isEmpty);
  });

  test('Flutter 標準の部品も、対応している言語すべてで表示できる', () {
    for (final locale in appSupportedLocales) {
      expect(GlobalMaterialLocalizations.delegate.isSupported(locale), isTrue,
          reason: '$locale: Material');
      expect(GlobalWidgetsLocalizations.delegate.isSupported(locale), isTrue,
          reason: '$locale: Widgets');
      expect(GlobalCupertinoLocalizations.delegate.isSupported(locale), isTrue,
          reason: '$locale: Cupertino');
    }
  });

  testWidgets('右から左へ書く言語は、画面全体が右から左になる', (tester) async {
    for (final code in ['ar', 'he', 'fa', 'ur']) {
      late TextDirection direction;
      await tester.pumpWidget(Localizations(
        locale: Locale(code),
        delegates: GlobalMaterialLocalizations.delegates,
        child: Builder(builder: (context) {
          direction = Directionality.of(context);
          return const SizedBox.shrink();
        }),
      ));
      await tester.pump();
      expect(direction, TextDirection.rtl, reason: code);
    }
  });

  test('地域や文字で分かれる言語は、合うファイルを読む', () {
    String file(Locale locale) => AppLangAssetLoader.fileNameFor(locale);
    expect(file(const Locale('zh')), 'zh');
    expect(file(const Locale('zh', 'CN')), 'zh');
    expect(file(const Locale('zh', 'TW')), 'zh-Hant');
    expect(file(const Locale('zh', 'HK')), 'zh-Hant');
    expect(
        file(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')),
        'zh-Hant');
    expect(
        file(const Locale.fromSubtags(
            languageCode: 'zh', scriptCode: 'Hans', countryCode: 'CN')),
        'zh');
    expect(file(const Locale('pt', 'BR')), 'pt');
    expect(file(const Locale('pt', 'PT')), 'pt-PT');
    expect(file(const Locale('no')), 'nb');
    expect(file(const Locale('fr', 'CA')), 'fr');
  });

  test('iOS に届け出ている言語の一覧が、対応言語と一致している', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final block = RegExp(
            r'<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>',
            dotAll: true)
        .firstMatch(plist);
    expect(block, isNotNull, reason: 'CFBundleLocalizations がありません');
    // 届け出の書き方（pt-BR、zh-Hans など）を、読み込む翻訳ファイルの名前にそろえて比べる
    final declared = RegExp(r'<string>(.*?)</string>')
        .allMatches(block!.group(1)!)
        .map((m) => m.group(1)!.split(RegExp('[-_]')))
        .map((parts) => AppLangAssetLoader.fileNameFor(Locale.fromSubtags(
              languageCode: parts.first,
              scriptCode: parts.skip(1).where((p) => p.length == 4).firstOrNull,
              countryCode:
                  parts.skip(1).where((p) => p.length == 2).firstOrNull,
            )))
        .toSet();
    expect(declared, fileNames);
  });
}
