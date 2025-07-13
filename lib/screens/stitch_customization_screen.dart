import 'package:flutter/material.dart';
import '../models/crochet_stitch.dart';
import '../services/stitch_settings_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../services/subscription_provider.dart';
import 'dart:ui' as ui;

class StitchCustomizationScreen extends StatefulWidget {
  final List<dynamic>? projectStitches; // プロジェクト固有の編み目設定
  final Function(List<dynamic>)?
      onProjectStitchesChanged; // プロジェクト固有の編み目設定が変更された時のコールバック

  const StitchCustomizationScreen({
    super.key,
    this.projectStitches,
    this.onProjectStitchesChanged,
  });

  @override
  State<StitchCustomizationScreen> createState() =>
      _StitchCustomizationScreenState();
}

class _StitchCustomizationScreenState extends State<StitchCustomizationScreen> {
  List<dynamic> _stitches = [];
  bool? _wasPremium; // 前回のプレミアム状態を記録

  // 編み目選択用の状態管理
  Set<CrochetStitch> _selectedBasicStitches = {};
  Set<Map<String, String>> _selectedPremiumStitches = {};

  @override
  void initState() {
    super.initState();
    _loadStitches();
  }

  @override
  void didUpdateWidget(StitchCustomizationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('StitchCustomizationScreen: didUpdateWidget called');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkPremiumStatusChange();
  }

  void _checkPremiumStatusChange() {
    final isPremium = context.read<SubscriptionProvider>().isPremium;
    final wasPremium = _wasPremium;

    if (wasPremium != null && wasPremium && !isPremium) {
      // プレミアムから解約された場合
      print('StitchCustomizationScreen: プレミアム解約を検知しました');
      _resetToDefaultStitches();
    } else if (wasPremium != null && !wasPremium && isPremium) {
      // プレミアムにアップグレードされた場合
      print('StitchCustomizationScreen: プレミアムアップグレードを検知しました');
      _loadStitches(); // 編み目設定を再読み込み
    }

    _wasPremium = isPremium;
  }

  void _resetToDefaultStitches() async {
    try {
      print('編み目カスタマイズ画面: 基本編み目にリセットします');

      final defaultStitches = StitchSettingsService.getDefaultStitches();
      await StitchSettingsService.saveGlobalStitches(defaultStitches);

      setState(() {
        _stitches = defaultStitches;
      });

      print('編み目カスタマイズ画面: リセット完了');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('プレミアム解約により基本編み目に戻しました'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      print('編み目カスタマイズ画面リセットエラー: $e');
    }
  }

  Future<void> _loadStitches() async {
    try {
      print('StitchCustomizationScreen: 編み目設定を読み込み中...');

      // プロジェクト固有の編み目設定がある場合はそれを使用、なければグローバル設定を使用
      if (widget.projectStitches != null &&
          widget.projectStitches!.isNotEmpty) {
        _stitches = List.from(widget.projectStitches!);
        print(
            'StitchCustomizationScreen: プロジェクト固有の編み目設定を使用: ${_stitches.length}個');
      } else {
        final globalStitches = await StitchSettingsService.getGlobalStitches();
        _stitches = List.from(globalStitches);
        print('StitchCustomizationScreen: グローバル編み目設定を使用: ${_stitches.length}個');
      }

      print('StitchCustomizationScreen: 読み込まれた編み目数: ${_stitches.length}');
      setState(() {
        // setStateは不要（_stitchesは既に更新済み）
      });
      print('StitchCustomizationScreen: 編み目リストを更新しました');
    } catch (e) {
      print('編み目設定読み込みエラー: $e');
      setState(() {
        _stitches = StitchSettingsService.getDefaultStitches();
      });
    }
  }

  // 表示用の編み目リスト（最大6つまで表示）
  List<dynamic> get _displayStitches {
    return _stitches.take(6).toList();
  }

  // プレミアム編み目のリスト
  final List<Map<String, String>> _premiumStitches = [
    {
      'nameJa': 'うね編み',
      'nameEn': 'Wave Stitch',
      'image': 'assets/images/うね編み.png'
    },
    {
      'nameJa': 'ねじれ細編み目',
      'nameEn': 'Twisted Single Crochet',
      'image': 'assets/images/ねじれ細編み目.png'
    },
    {
      'nameJa': '長編み１目交差',
      'nameEn': 'Double Crochet Cross',
      'image': 'assets/images/長編み１目交差.png'
    },
    {
      'nameJa': 'バック細編み',
      'nameEn': 'Back Single Crochet',
      'image': 'assets/images/バック細編み.png'
    },
    {
      'nameJa': '四つ巻き長編み目',
      'nameEn': 'Quadruple Crochet',
      'image': 'assets/images/四つ巻き長編み目.png'
    },
    {
      'nameJa': '三つ巻き長編み目',
      'nameEn': 'Triple Crochet',
      'image': 'assets/images/三つ巻き長編み目.png'
    },
    {
      'nameJa': '中長編み１目交差',
      'nameEn': 'Half Double Crochet Cross',
      'image': 'assets/images/中長編み１目交差.png'
    },
    {
      'nameJa': '長編み３目の玉編み目',
      'nameEn': 'Double Crochet 3 Bobble',
      'image': 'assets/images/長編み３目の玉編み目.png'
    },
    {
      'nameJa': '長編み１目左上３目交差',
      'nameEn': 'Double Crochet Left Cross 3',
      'image': 'assets/images/長編み１目左上３目交差.png'
    },
    {
      'nameJa': '長編み１目右上交差',
      'nameEn': 'Double Crochet Right Cross',
      'image': 'assets/images/長編み１目右上交差.png'
    },
    {
      'nameJa': '長編み１目右上３目交差',
      'nameEn': 'Double Crochet Right Cross 3',
      'image': 'assets/images/長編み１目右上３目交差.png'
    },
    {
      'nameJa': '中長編み３目の玉編み目',
      'nameEn': 'Half Double Crochet 3 Bobble',
      'image': 'assets/images/中長編み３目の玉編み目.png'
    },
    {
      'nameJa': '長々編み５目の玉編み目',
      'nameEn': 'Treble Crochet 5 Bobble',
      'image': 'assets/images/長々編み５目の玉編み目.png'
    },
    {
      'nameJa': '変わり玉編み目＜中長編み3目＞',
      'nameEn': 'Special Bobble Half Double Crochet 3',
      'image': 'assets/images/変わり玉編み目＜中長編み3目＞.png'
    },
    {
      'nameJa': '変わり玉編み目＜長編み3目＞',
      'nameEn': 'Special Bobble Double Crochet 3',
      'image': 'assets/images/変わり玉編み目＜長編み3目＞.png'
    },
    {
      'nameJa': '引き出し玉編み目',
      'nameEn': 'Popcorn Stitch',
      'image': 'assets/images/引き出し玉編み目.png'
    },
    {
      'nameJa': '細こま編み２目編み入れる',
      'nameEn': 'Single Crochet 2 Increase',
      'image': 'assets/images/細こま編み２目編み入れる.png'
    },
    {
      'nameJa': '中長編み５目のパプコーン編み',
      'nameEn': 'Half Double Crochet 5 Popcorn',
      'image': 'assets/images/中長編み５目のパプコーン編み.png'
    },
    {
      'nameJa': '長編み５目のパプコーン編み',
      'nameEn': 'Double Crochet 5 Popcorn',
      'image': 'assets/images/長編み５目のパプコーン編み.png'
    },
    {
      'nameJa': '長々編み６目のパプコーン編み目',
      'nameEn': 'Treble Crochet 6 Popcorn',
      'image': 'assets/images/長々編み６目のパプコーン編み目.png'
    },
    {
      'nameJa': '細こま編み3目編み入れる',
      'nameEn': 'Single Crochet 3 Increase',
      'image': 'assets/images/細こま編み3目編み入れる.png'
    },
    {
      'nameJa': '長編み3目編み入れる',
      'nameEn': 'Double Crochet 3 Increase',
      'image': 'assets/images/長編み3目編み入れる.png'
    },
    {
      'nameJa': '中長編み2目編み入れる',
      'nameEn': 'Half Double Crochet 2 Increase',
      'image': 'assets/images/中長編み2目編み入れる.png'
    },
    {
      'nameJa': '細こま編み２目一度',
      'nameEn': 'Single Crochet 2 Together',
      'image': 'assets/images/細こま編み２目一度.png'
    },
    {
      'nameJa': '中長編み3目編み入れる',
      'nameEn': 'Half Double Crochet 3 Increase',
      'image': 'assets/images/中長編み3目編み入れる.png'
    },
    {
      'nameJa': '長編み２目編み入れる',
      'nameEn': 'Double Crochet 2 Increase',
      'image': 'assets/images/長編み２目編み入れる.png'
    },
    {
      'nameJa': '中長編み2目一度',
      'nameEn': 'Half Double Crochet 2 Together',
      'image': 'assets/images/中長編み2目一度.png'
    },
    {
      'nameJa': '細こま編み3目一度',
      'nameEn': 'Single Crochet 3 Together',
      'image': 'assets/images/細こま編み3目一度.png'
    },
    {
      'nameJa': '中長編み３目一度',
      'nameEn': 'Half Double Crochet 3 Together',
      'image': 'assets/images/中長編み３目一度.png'
    },
    {
      'nameJa': '長編み２目一度',
      'nameEn': 'Double Crochet 2 Together',
      'image': 'assets/images/長編み２目一度.png'
    },
    {
      'nameJa': '長編み3目一度',
      'nameEn': 'Double Crochet 3 Together',
      'image': 'assets/images/長編み3目一度.png'
    },
  ];

  String _getStitchName(dynamic stitch) {
    final locale = context.locale.languageCode;

    if (stitch is CrochetStitch) {
      return locale == 'ja' ? stitch.nameJa : stitch.nameEn;
    } else if (stitch is CustomStitch) {
      return stitch.getName(context);
    } else if (stitch is Map<String, String>) {
      return locale == 'ja' ? stitch['nameJa']! : stitch['nameEn']!;
    } else {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
        'StitchCustomizationScreen: build called, _stitches.length = ${_stitches.length}');
    print('StitchCustomizationScreen: 現在の編み目リスト（表示名付き）:');
    for (int i = 0; i < _stitches.length; i++) {
      final stitch = _stitches[i];
      final displayName = _getStitchName(stitch);
      if (stitch is CrochetStitch) {
        print(
            '  $i: ${(stitch as CrochetStitch).name} (CrochetStitch) -> 表示名: $displayName');
      } else if (stitch is CustomStitch) {
        print(
            '  $i: ${(stitch as CustomStitch).name} (CustomStitch) -> 表示名: $displayName');
      } else {
        print('  $i: 不明な型 (${stitch.runtimeType}) -> 表示名: $displayName');
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('edit_stitch_buttons')),
        backgroundColor: const Color(0xFFEC407A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            print('StitchCustomizationScreen: 戻るボタンが押されました');

            // プロジェクト固有の編み目設定を保存
            if (widget.onProjectStitchesChanged != null) {
              print('StitchCustomizationScreen: プロジェクト固有の編み目設定を保存します');
              try {
                await widget.onProjectStitchesChanged!(_stitches);
                print('StitchCustomizationScreen: プロジェクト固有の編み目設定の保存完了');

                // 保存完了を確認するためのログ
                print('保存された編み目設定:');
                for (int i = 0; i < _stitches.length; i++) {
                  final stitch = _stitches[i];
                  if (stitch is CrochetStitch) {
                    print(
                        '  $i: ${(stitch as CrochetStitch).name} (CrochetStitch)');
                  } else if (stitch is CustomStitch) {
                    print(
                        '  $i: ${(stitch as CustomStitch).name} (CustomStitch)');
                  } else {
                    print('  $i: 不明な型 (${stitch.runtimeType})');
                  }
                }
              } catch (e) {
                print(
                    'StitchCustomizationScreen: プロジェクト固有の編み目設定の保存に失敗しました: $e');
              }
            }

            print('StitchCustomizationScreen: 保存完了、画面を閉じます');
            // 変更があったことを通知して戻る
            Navigator.of(context).pop(true);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddStitchDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // 編み目リスト（スライド削除・並び替え機能付き）
          Expanded(
            child: ReorderableListView.builder(
              itemCount: _stitches.length,
              itemBuilder: (context, index) {
                final stitch = _stitches[index];
                final isCustomStitch = stitch is CustomStitch;
                return Dismissible(
                  key: ValueKey(stitch),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  onDismissed: (direction) {
                    _removeStitch(index);
                  },
                  child: Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Center(
                          child: stitch.imagePath != null
                              ? Image.asset(
                                  stitch.imagePath!,
                                  width: 24,
                                  height: 24,
                                )
                              : Text(
                                  _getStitchName(stitch),
                                  style: const TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                      title: Text(_getStitchName(stitch)),
                      subtitle: Text(isCustomStitch
                          ? tr('premium_stitch')
                          : tr('basic_stitch')),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 並び替え用のドラッグハンドル
                          Icon(
                            Icons.drag_handle,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 8),
                          // 削除ボタン
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              _removeStitch(index);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              onReorder: (oldIndex, newIndex) async {
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final item = _stitches.removeAt(oldIndex);
                  _stitches.insert(newIndex, item);
                });
                await _saveGlobalStitches();
                // 変更は即座に保存するが、画面は閉じない
              },
            ),
          ),
        ],
      ),
    );
  }

  void _removeStitch(int index) async {
    setState(() {
      _stitches.removeAt(index);
    });
    await _saveGlobalStitches();
    // 変更は即座に保存するが、画面は閉じない
  }

  Future<void> _saveGlobalStitches() async {
    try {
      print('=== 編み目設定保存開始 ===');
      print('保存する編み目リスト:');
      for (int i = 0; i < _stitches.length; i++) {
        final stitch = _stitches[i];
        print('  $i: ${_getStitchName(stitch)} (${stitch.runtimeType})');
      }

      // プロジェクト固有の編み目設定がある場合は、プロジェクト固有の設定として保存
      if (widget.projectStitches != null) {
        print('プロジェクト固有の編み目設定として保存します');

        // プロジェクト固有の編み目設定を更新
        if (widget.onProjectStitchesChanged != null) {
          print('プロジェクト固有の編み目設定を更新します');
          try {
            await widget.onProjectStitchesChanged!(_stitches);
            print('✅ プロジェクト固有の編み目設定を保存しました');
          } catch (e) {
            print('❌ プロジェクト固有の編み目設定の保存に失敗しました: $e');
          }
        }
      } else {
        // グローバル設定として保存
        print('グローバル編み目設定として保存します');
        final success =
            await StitchSettingsService.saveGlobalStitches(_stitches);
        if (success) {
          print('✅ グローバル編み目設定を保存しました');
        } else {
          print('❌ グローバル編み目設定の保存に失敗しました');
        }
      }

      // 保存成功後にUIを強制的に更新
      if (mounted) {
        setState(() {});
      }

      // 保存後の確認用ログ
      if (widget.projectStitches != null) {
        print('保存後の確認 - プロジェクト固有の編み目数: ${_stitches.length}');
        for (int i = 0; i < _stitches.length; i++) {
          final stitch = _stitches[i];
          print('  $i: ${_getStitchName(stitch)} (${stitch.runtimeType})');
        }
      } else {
        final savedStitches = await StitchSettingsService.getGlobalStitches();
        print('保存後の確認 - 読み込まれた編み目数: ${savedStitches.length}');
        for (int i = 0; i < savedStitches.length; i++) {
          final stitch = savedStitches[i];
          print('  $i: ${_getStitchName(stitch)} (${stitch.runtimeType})');
        }
      }

      // 少し待ってから再度確認
      await Future.delayed(const Duration(milliseconds: 200));
      if (widget.projectStitches != null) {
        print('最終確認 - プロジェクト固有の編み目数: ${_stitches.length}');
      } else {
        final finalCheck = await StitchSettingsService.getGlobalStitches();
        print('最終確認 - 保存された編み目数: ${finalCheck.length}');
      }
    } catch (e) {
      print('❌ 編み目設定保存エラー: $e');
    }
  }

  void _showAddStitchDialog() {
    // 選択状態をリセット
    _selectedBasicStitches.clear();
    _selectedPremiumStitches.clear();

    // 現在の編み目リストに含まれていない編み目を取得
    final currentStitchNames = _stitches.map((s) => _getStitchName(s)).toSet();
    final availableBasicStitches = CrochetStitch.values
        .where((stitch) => !currentStitchNames.contains(_getStitchName(stitch)))
        .toList();
    final availablePremiumStitches = _premiumStitches
        .where((stitch) => !currentStitchNames.contains(_getStitchName(stitch)))
        .toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tr('edit_stitch_buttons')),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                // 基本編み目セクション
                if (availableBasicStitches.isNotEmpty) ...[
                  Text(
                    '基本編み目',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 1,
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: availableBasicStitches.length,
                      itemBuilder: (context, index) {
                        final stitch = availableBasicStitches[index];
                        final isSelected =
                            _selectedBasicStitches.contains(stitch);
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              if (isSelected) {
                                _selectedBasicStitches.remove(stitch);
                              } else {
                                _selectedBasicStitches.add(stitch);
                              }
                            });
                          },
                          child: Card(
                            elevation: 2,
                            color: isSelected ? Colors.blue.shade50 : null,
                            child: Stack(
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        child: stitch.imagePath != null
                                            ? Image.asset(
                                                stitch.imagePath!,
                                                fit: BoxFit.contain,
                                              )
                                            : Text(
                                                _getStitchName(stitch)
                                                    .substring(0, 1),
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: stitch.color,
                                                ),
                                              ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Text(
                                        _getStitchName(stitch),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (isSelected)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // プレミアム編み目セクション
                if (availablePremiumStitches.isNotEmpty) ...[
                  Text(
                    tr('select_premium_stitch'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.pink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 2,
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: availablePremiumStitches.length,
                      itemBuilder: (context, index) {
                        final stitch = availablePremiumStitches[index];
                        final isSelected =
                            _selectedPremiumStitches.contains(stitch);
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              if (isSelected) {
                                _selectedPremiumStitches.remove(stitch);
                              } else {
                                _selectedPremiumStitches.add(stitch);
                              }
                            });
                          },
                          child: Card(
                            elevation: 2,
                            color: isSelected ? Colors.pink.shade50 : null,
                            child: Stack(
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        child: Image.asset(
                                          stitch['image']!,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Text(
                                        _getStitchName(stitch),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (isSelected)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.pink,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                // 利用可能な編み目がない場合
                if (availableBasicStitches.isEmpty &&
                    availablePremiumStitches.isEmpty) ...[
                  const Expanded(
                    child: Center(
                      child: Text(
                        '追加できる編み目がありません',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                _addSelectedStitches();
                Navigator.of(context).pop();
              },
              child: Text(
                  '追加 (${_selectedBasicStitches.length + _selectedPremiumStitches.length})'),
            ),
          ],
        ),
      ),
    );
  }

  void _addSelectedStitches() async {
    // 基本編み目の制限チェック
    final currentBasicStitches =
        _stitches.where((s) => s is CrochetStitch).length;
    final newBasicStitches = _selectedBasicStitches.length;
    if (currentBasicStitches + newBasicStitches > 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('基本編み目は6つまでしか追加できません'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 選択された編み目を追加
    for (var stitch in _selectedBasicStitches) {
      _stitches.add(stitch);
    }

    // プレミアム編み目をカスタム編み目として追加
    for (var stitchData in _selectedPremiumStitches) {
      final customStitch = CustomStitch(
        nameJa: stitchData['nameJa']!,
        nameEn: stitchData['nameEn']!,
        imagePath: stitchData['image'],
      );
      _stitches.add(customStitch);
    }

    await _saveGlobalStitches();
  }
}
