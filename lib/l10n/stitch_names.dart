import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

final RegExp _notKeyChar = RegExp(r'[^a-z0-9]+');
final RegExp _edgeUnderscore = RegExp(r'^_+|_+$');

/// 編み目の英語名から、翻訳ファイルのキーを作る（例: "Chain Stitch" → "sn_chain_stitch"）。
///
/// tool/l10n/extract_stitch_names.py と同じ規則。
String stitchNameKey(String nameEn) {
  final slug = nameEn
      .toLowerCase()
      .replaceAll(_notKeyChar, '_')
      .replaceAll(_edgeUnderscore, '');
  return 'sn_$slug';
}

/// 表示言語に合わせた編み目の名前。
///
/// 日本語は [nameJa]、英語は [nameEn]、それ以外はその言語の訳を返す。
/// 訳の無い編み目（利用者が自分で付けた名前など）は [nameEn] のまま返す。
String localizedStitchName(
  BuildContext context, {
  required String nameJa,
  required String nameEn,
}) {
  final String language;
  try {
    language = context.locale.languageCode;
  } catch (_) {
    // EasyLocalization がまだ初期化されていない場合は日本語を返す
    return nameJa;
  }
  if (language == 'ja') return nameJa;
  if (language == 'en') return nameEn;
  final key = stitchNameKey(nameEn);
  if (key == 'sn_' || !trExists(key)) return nameEn;
  return tr(key);
}
