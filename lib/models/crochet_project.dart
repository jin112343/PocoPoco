import '../models/crochet_stitch.dart';
import 'package:flutter/material.dart';

class CrochetProject {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<Map<String, dynamic>> stitchHistory;
  final int currentRow;
  final int currentStitchCount;
  final String iconName;
  final String iconColor;
  final String backgroundColor;
  final List<dynamic> customStitches; // プロジェクト固有の編み目設定

  CrochetProject({
    required this.id,
    required this.title,
    required this.createdAt,
    this.updatedAt,
    required this.stitchHistory,
    required this.currentRow,
    required this.currentStitchCount,
    this.iconName = 'work',
    this.iconColor = '0xFF000000',
    this.backgroundColor = '0xFFFFFFFF',
    this.customStitches = const [], // デフォルトは空
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'stitchHistory': stitchHistory.map((stitch) {
        final stitchData = Map<String, dynamic>.from(stitch);
        // CrochetStitchオブジェクトを文字列に変換
        if (stitchData['stitch'] is CrochetStitch) {
          stitchData['stitch'] = (stitchData['stitch'] as CrochetStitch).name;
        }
        // DateTimeオブジェクトを文字列に変換
        if (stitchData['timestamp'] is DateTime) {
          stitchData['timestamp'] =
              (stitchData['timestamp'] as DateTime).toIso8601String();
        }
        return stitchData;
      }).toList(),
      'currentRow': currentRow,
      'currentStitchCount': currentStitchCount,
      'iconName': iconName,
      'iconColor': iconColor,
      'backgroundColor': backgroundColor,
      'customStitches': customStitches
          .map((stitch) {
            try {
              if (stitch is CrochetStitch) {
                return {
                  'type': 'enum',
                  'name': stitch.name,
                };
              } else if (stitch is CustomStitch) {
                // CustomStitchのtoJsonメソッドを使用
                return stitch.toJson();
              } else {
                print('不明な編み目タイプ: ${stitch.runtimeType}');
                // 不明な型の場合はデフォルトのCrochetStitchとして扱う
                return {
                  'type': 'enum',
                  'name': 'singleCrochet',
                };
              }
            } catch (e) {
              print('編み目JSON変換エラー: $e');
              print('エラーが発生した編み目の型: ${stitch.runtimeType}');
              // エラーが発生した場合はデフォルトのCrochetStitchとして扱う
              return {
                'type': 'enum',
                'name': 'singleCrochet',
              };
            }
          })
          .where((item) => item != null)
          .toList(),
    };
  }

  factory CrochetProject.fromJson(Map<String, dynamic> json) {
    return CrochetProject(
      id: json['id'],
      title: json['title'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      stitchHistory: (json['stitchHistory'] as List).map((stitchJson) {
        final stitchData = Map<String, dynamic>.from(stitchJson);

        // stitchの復元処理
        if (stitchData['stitch'] is String) {
          // 文字列の場合はCrochetStitchとして復元
          final stitchName = stitchData['stitch'] as String;
          try {
            stitchData['stitch'] = CrochetStitch.values.firstWhere(
              (stitch) => stitch.name == stitchName,
              orElse: () => CrochetStitch.singleCrochet,
            );
          } catch (e) {
            print('CrochetStitch変換エラー: $stitchName, エラー: $e');
            stitchData['stitch'] = CrochetStitch.singleCrochet;
          }
        } else if (stitchData['stitch'] is Map<String, dynamic>) {
          // Mapの場合はCustomStitchとして復元
          final stitchMap = stitchData['stitch'] as Map<String, dynamic>;
          if (stitchMap['type'] == 'custom') {
            stitchData['stitch'] = CustomStitch(
              nameJa:
                  stitchMap['nameJa'] as String? ?? stitchMap['name'] as String,
              nameEn:
                  stitchMap['nameEn'] as String? ?? stitchMap['name'] as String,
              imagePath: stitchMap['imagePath'] as String?,
              color: Color(stitchMap['color'] as int),
              isOval: stitchMap['isOval'] as bool? ?? false,
            );
          } else {
            // 不明な型の場合はCrochetStitchとして復元
            stitchData['stitch'] = CrochetStitch.singleCrochet;
          }
        }

        // 文字列からDateTimeオブジェクトに変換
        if (stitchData['timestamp'] is String) {
          try {
            stitchData['timestamp'] =
                DateTime.parse(stitchData['timestamp'] as String);
          } catch (e) {
            print('DateTime変換エラー: ${stitchData['timestamp']}, エラー: $e');
            stitchData['timestamp'] = DateTime.now();
          }
        }
        return stitchData;
      }).toList(),
      currentRow: json['currentRow'],
      currentStitchCount: json['currentStitchCount'],
      iconName: json['iconName'] ?? 'work',
      iconColor: json['iconColor'] ?? '0xFF000000',
      backgroundColor: json['backgroundColor'] ?? '0xFFFFFFFF',
      customStitches: (json['customStitches'] as List? ?? []).map((stitchJson) {
        final stitchData = Map<String, dynamic>.from(stitchJson);
        if (stitchData['type'] == 'enum') {
          final stitchName = stitchData['name'] as String;
          try {
            return CrochetStitch.values.firstWhere(
              (stitch) => stitch.name == stitchName,
              orElse: () => CrochetStitch.singleCrochet,
            );
          } catch (e) {
            print('CrochetStitch変換エラー: $stitchName, エラー: $e');
            return CrochetStitch.singleCrochet;
          }
        } else if (stitchData['type'] == 'custom') {
          // CustomStitch.fromJsonメソッドを使用
          return CustomStitch.fromJson(stitchData);
        }
        return CrochetStitch.singleCrochet; // デフォルト
      }).toList(),
    );
  }

  CrochetProject copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Map<String, dynamic>>? stitchHistory,
    int? currentRow,
    int? currentStitchCount,
    String? iconName,
    String? iconColor,
    String? backgroundColor,
    List<dynamic>? customStitches,
  }) {
    return CrochetProject(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      stitchHistory: stitchHistory ?? this.stitchHistory,
      currentRow: currentRow ?? this.currentRow,
      currentStitchCount: currentStitchCount ?? this.currentStitchCount,
      iconName: iconName ?? this.iconName,
      iconColor: iconColor ?? this.iconColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      customStitches: customStitches ?? this.customStitches,
    );
  }
}
