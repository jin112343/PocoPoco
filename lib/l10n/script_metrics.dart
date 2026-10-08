import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

// 上下に記号が付いて、欧文や日本語より行の高さが必要な文字を使う言語
const Set<String> _tallScriptLanguages = {
  'hi', 'mr', 'ne', 'bn', 'gu', 'pa', 'or', 'ta', 'te', 'kn', 'ml', 'si', //
  'th', 'lo', 'ar', 'fa', 'ur', 'am',
};

// その中でも特に背の高い文字（ビルマ文字・クメール文字）
const Set<String> _veryTallScriptLanguages = {'my', 'km'};

/// 表示言語の文字に合わせた行の高さ（文字サイズに対する倍率）。
///
/// 行数を決めて高さを確保している欄（編み目の名前など）で使う。
/// [base] は欧文・日本語での倍率で、背の高い文字の言語ではその分だけ広げる。
double scriptLineHeight(BuildContext context, double base) {
  final String language;
  try {
    language = context.locale.languageCode;
  } catch (_) {
    return base;
  }
  if (_veryTallScriptLanguages.contains(language)) return base * 1.4;
  if (_tallScriptLanguages.contains(language)) return base * 1.2;
  return base;
}
