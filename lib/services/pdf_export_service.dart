import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/crochet_project.dart';
import '../models/crochet_stitch.dart';

class PdfExportService {
  /// プロジェクトをPDFにエクスポートして共有
  static Future<void> exportAndShare(CrochetProject project, BuildContext context) async {
    // iPad/iOS用にsharePositionOriginを設定（async操作前に取得）
    // 画面サイズを取得してセンターに配置
    final screenSize = MediaQuery.of(context).size;
    Rect sharePositionOrigin;

    try {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize && box.size.width > 0 && box.size.height > 0) {
        final position = box.localToGlobal(Offset.zero);
        sharePositionOrigin = position & box.size;
      } else {
        // 画面中央にフォールバック
        sharePositionOrigin = Rect.fromCenter(
          center: Offset(screenSize.width / 2, screenSize.height / 2),
          width: 1,
          height: 1,
        );
      }
    } catch (e) {
      // エラー時は画面中央
      sharePositionOrigin = Rect.fromCenter(
        center: Offset(screenSize.width / 2, screenSize.height / 2),
        width: 1,
        height: 1,
      );
    }

    final pdf = await _generatePdf(project);
    final bytes = await pdf.save();

    // 一時ファイルとして保存
    final dir = await getTemporaryDirectory();
    // ファイル名として使えない文字のみ置換する（\wはASCII限定のため、
    // 日本語タイトルが全て「_」になってしまう問題を回避）
    final safeTitle = project.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final fileName = '${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    // 共有
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: '${project.title} - 編み物記録',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// プロジェクトをPDFとして印刷/プレビュー
  static Future<void> printPdf(CrochetProject project) async {
    final pdf = await _generatePdf(project);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${project.title}_編み物記録',
    );
  }

  /// 日本語フォントをロード（アセット同梱フォントを優先し、
  /// 読み込み失敗時のみGoogle Fontsからのダウンロードにフォールバック）
  static Future<pw.Font> _loadJapaneseFont({required bool bold}) async {
    try {
      final path = bold
          ? 'assets/fonts/NotoSansJP-Bold.ttf'
          : 'assets/fonts/NotoSansJP-Regular.ttf';
      final fontData = await rootBundle.load(path);
      return pw.Font.ttf(fontData);
    } catch (e) {
      // アセットが読めない場合はネットワーク経由（オンライン時のみ成功）
      return bold
          ? await PdfGoogleFonts.notoSansJPBold()
          : await PdfGoogleFonts.notoSansJPRegular();
    }
  }

  /// PDFを生成
  static Future<pw.Document> _generatePdf(CrochetProject project) async {
    final pdf = pw.Document();

    // 日本語フォントをロード（オフラインでも動作するようアセットから）
    final font = await _loadJapaneseFont(bold: false);
    final fontBold = await _loadJapaneseFont(bold: true);

    // アプリアイコンをロード
    final iconData = await rootBundle.load('assets/images/icon_1024.png');
    final iconImage = pw.MemoryImage(iconData.buffer.asUint8List());

    // 編み目履歴を段ごとにグループ化
    final rowGroups = _groupStitchesByRow(project.stitchHistory);

    // 使用されている編み目の画像をプリロード
    final stitchImages = await _loadStitchImages(project);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(project, fontBold, iconImage),
        footer: (context) => _buildFooter(context, font),
        build: (context) => [
          // プロジェクト情報
          _buildProjectInfo(project, font, fontBold),
          pw.SizedBox(height: 20),

          // 編み目パターン
          // 段ごとに個別のウィジェットとして渡す（単一のColumnにまとめると
          // ページ分割できず、段数が多い場合に例外でPDF生成が失敗する）
          if (rowGroups.isNotEmpty) ...[
            pw.Text(
              '編み目パターン',
              style: pw.TextStyle(font: fontBold, fontSize: 16),
            ),
            pw.SizedBox(height: 10),
            ..._buildStitchPatternRows(rowGroups, font, fontBold, stitchImages),
          ],

          // 編み目凡例
          pw.SizedBox(height: 20),
          _buildLegend(project, font, fontBold, stitchImages),
        ],
      ),
    );

    return pdf;
  }

  /// 編み目画像をロード
  static Future<Map<String, pw.ImageProvider>> _loadStitchImages(CrochetProject project) async {
    final images = <String, pw.ImageProvider>{};
    final loadedPaths = <String>{};

    for (final stitch in project.stitchHistory) {
      final stitchData = stitch['stitch'];
      final imagePath = _getStitchImagePath(stitchData);

      if (imagePath != null && imagePath.isNotEmpty && !loadedPaths.contains(imagePath)) {
        loadedPaths.add(imagePath);
        try {
          final imageData = await rootBundle.load(imagePath);
          final imageBytes = imageData.buffer.asUint8List();
          images[imagePath] = pw.MemoryImage(imageBytes);
        } catch (e) {
          // 画像が見つからない場合はスキップ
        }
      }
    }

    return images;
  }

  /// 編み目の画像パスを取得
  static String? _getStitchImagePath(dynamic stitch) {
    if (stitch is CrochetStitch) {
      return stitch.imagePath;
    } else if (stitch is CustomStitch) {
      return stitch.imagePath;
    } else if (stitch is Map) {
      return stitch['imagePath'] as String?;
    }
    return null;
  }

  /// ヘッダーを作成
  static pw.Widget _buildHeader(CrochetProject project, pw.Font fontBold, pw.ImageProvider iconImage) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.pink300, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            project.title,
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 24,
              color: PdfColors.pink800,
            ),
          ),
          pw.Row(
            children: [
              pw.Container(
                width: 20,
                height: 20,
                child: pw.Image(iconImage),
              ),
              pw.SizedBox(width: 6),
              pw.Text(
                '編み物カウンターズ',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 14,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// フッターを作成
  static pw.Widget _buildFooter(pw.Context context, pw.Font font) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'ページ ${context.pageNumber} / ${context.pagesCount}',
        style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600),
      ),
    );
  }

  /// プロジェクト情報を作成
  static pw.Widget _buildProjectInfo(
    CrochetProject project,
    pw.Font font,
    pw.Font fontBold,
  ) {
    String dateFormat(DateTime date) =>
        '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.pink50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text('現在の進捗: ', style: pw.TextStyle(font: font, fontSize: 12)),
              pw.Text(
                '${project.currentRow}段目 ${project.currentStitchCount}目',
                style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.pink800),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '作成日: ${dateFormat(project.createdAt)}',
            style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700),
          ),
          if (project.updatedAt != null)
            pw.Text(
              '更新日: ${dateFormat(project.updatedAt!)}',
              style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700),
            ),
        ],
      ),
    );
  }

  /// 編み目履歴を段ごとにグループ化
  static Map<int, List<Map<String, dynamic>>> _groupStitchesByRow(
    List<Map<String, dynamic>> stitchHistory,
  ) {
    final Map<int, List<Map<String, dynamic>>> groups = {};

    for (final stitch in stitchHistory) {
      final row = stitch['row'] as int? ?? 1;
      groups.putIfAbsent(row, () => []);
      groups[row]!.add(stitch);
    }

    return groups;
  }

  /// 編み目パターンを段ごとのウィジェットリストとして作成
  /// （MultiPageがページをまたいで分割できるようにする）
  static List<pw.Widget> _buildStitchPatternRows(
    Map<int, List<Map<String, dynamic>>> rowGroups,
    pw.Font font,
    pw.Font fontBold,
    Map<String, pw.ImageProvider> stitchImages,
  ) {
    final sortedRows = rowGroups.keys.toList()..sort();

    return sortedRows.map((row) {
        final stitches = rowGroups[row]!;
        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // 段番号
              pw.Container(
                width: 50,
                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.pink100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  '$row段',
                  style: pw.TextStyle(font: fontBold, fontSize: 10),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(width: 10),
              // 編み目
              pw.Expanded(
                child: pw.Wrap(
                  spacing: 2,
                  runSpacing: 2,
                  children: stitches.map((stitch) {
                    final stitchData = stitch['stitch'];
                    return _buildStitchSymbol(stitchData, stitchImages, font);
                  }).toList(),
                ),
              ),
              // 目数
              pw.Container(
                width: 40,
                child: pw.Text(
                  '${stitches.length}目',
                  style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList();
  }

  /// 編み目シンボルを作成（画像またはフォールバックテキスト）
  static pw.Widget _buildStitchSymbol(
    dynamic stitchData,
    Map<String, pw.ImageProvider> stitchImages,
    pw.Font font,
  ) {
    final imagePath = _getStitchImagePath(stitchData);
    final color = _getStitchPdfColor(stitchData);

    // 画像がある場合は画像を表示
    if (imagePath != null && stitchImages.containsKey(imagePath)) {
      return pw.Container(
        width: 18,
        height: 18,
        child: pw.Image(stitchImages[imagePath]!),
      );
    }

    // 画像がない場合はテキストでフォールバック
    final abbr = _getStitchAbbreviation(stitchData);
    return pw.Container(
      width: 18,
      height: 18,
      decoration: pw.BoxDecoration(
        color: color.shade(50),
        border: pw.Border.all(color: color, width: 1),
        borderRadius: pw.BorderRadius.circular(2),
      ),
      alignment: pw.Alignment.center,
      child: pw.Text(
        abbr.substring(0, 1),
        style: pw.TextStyle(font: font, fontSize: 8, color: color),
      ),
    );
  }

  /// 凡例を作成
  static pw.Widget _buildLegend(
    CrochetProject project,
    pw.Font font,
    pw.Font fontBold,
    Map<String, pw.ImageProvider> stitchImages,
  ) {
    // 使用されている編み目を収集（重複を避けるためにimagePathでグループ化）
    final usedStitches = <String, dynamic>{};
    for (final stitch in project.stitchHistory) {
      final stitchData = stitch['stitch'];
      final imagePath = _getStitchImagePath(stitchData) ?? _getStitchName(stitchData);
      if (!usedStitches.containsKey(imagePath)) {
        usedStitches[imagePath] = stitchData;
      }
    }

    if (usedStitches.isEmpty) {
      return pw.SizedBox();
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '凡例',
            style: pw.TextStyle(font: fontBold, fontSize: 14),
          ),
          pw.SizedBox(height: 10),
          pw.Wrap(
            spacing: 15,
            runSpacing: 8,
            children: usedStitches.values.map((stitch) {
              final name = _getStitchName(stitch);

              return pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  _buildStitchSymbol(stitch, stitchImages, font),
                  pw.SizedBox(width: 6),
                  pw.Text(
                    name,
                    style: pw.TextStyle(font: font, fontSize: 10),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 編み目の名前を取得
  static String _getStitchName(dynamic stitch) {
    if (stitch is CrochetStitch) {
      return stitch.nameJa;
    } else if (stitch is CustomStitch) {
      return stitch.nameJa;
    } else if (stitch is Map) {
      return (stitch['nameJa'] ?? stitch['name'] ?? '不明') as String;
    }
    return '不明';
  }

  /// 編み目の略称を取得
  static String _getStitchAbbreviation(dynamic stitch) {
    final name = _getStitchName(stitch);
    // 日本語の場合は最初の1-2文字
    if (name.isNotEmpty) {
      return name.length > 2 ? name.substring(0, 2) : name;
    }
    return '?';
  }

  /// 編み目のPDF色を取得
  static PdfColor _getStitchPdfColor(dynamic stitch) {
    if (stitch is CrochetStitch) {
      return _flutterColorToPdfColor(stitch.color);
    } else if (stitch is CustomStitch) {
      return _flutterColorToPdfColor(stitch.color);
    }
    return PdfColors.grey;
  }

  /// FlutterのColorをPdfColorに変換
  static PdfColor _flutterColorToPdfColor(dynamic color) {
    if (color is int) {
      return PdfColor.fromInt(color);
    }
    // MaterialColorやColorの場合
    try {
      final colorValue = color.value as int;
      return PdfColor.fromInt(colorValue);
    } catch (e) {
      return PdfColors.grey;
    }
  }
}
