import 'package:flutter/material.dart';
import '../models/crochet_stitch.dart';
import '../services/stitch_settings_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../services/subscription_provider.dart';

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
  bool _isProcessing = false; // 非同期処理中フラグ

  // 編み目選択用の状態管理
  final Set<CrochetStitch> _selectedBasicStitches = {};
  final Set<Map<String, String>> _selectedPremiumStitches = {};

  @override
  void initState() {
    super.initState();
    _loadStitches();
  }

  @override
  void didUpdateWidget(StitchCustomizationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
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
      _resetToDefaultStitches();
    } else if (wasPremium != null && !wasPremium && isPremium) {
      // プレミアムにアップグレードされた場合
      _loadStitches(); // 編み目設定を再読み込み
    }

    _wasPremium = isPremium;
  }

  /// ダイアログ表示のヘルパー
  void _showDialog(String message) {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _resetToDefaultStitches() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final defaultStitches = StitchSettingsService.getDefaultStitches();
      await StitchSettingsService.saveGlobalStitches(defaultStitches);

      setState(() {
        _stitches = defaultStitches;
      });

      if (mounted) {
        _showDialog('プレミアム解約により基本編み目に戻しました');
      }
    } catch (e) {
      debugPrint('編み目のリセットに失敗: $e');
      if (mounted) {
        _showDialog('編み目のリセットに失敗しました');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _loadStitches() async {
    try {
      // プロジェクト固有の編み目設定がある場合はそれを使用、なければグローバル設定を使用
      if (widget.projectStitches != null &&
          widget.projectStitches!.isNotEmpty) {
        _stitches = List.from(widget.projectStitches!);
      } else {
        final globalStitches = await StitchSettingsService.getGlobalStitches();
        _stitches = List.from(globalStitches);
      }

      setState(() {
        // setStateでUIを更新
      });
    } catch (e) {
      debugPrint('編み目の読み込みに失敗: $e');
      setState(() {
        _stitches = StitchSettingsService.getDefaultStitches();
      });
    }
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
      'image': 'assets/images/ねじれ細編み目.png'
    },
    {
      'nameJa': '長編み１目交差',
      'nameEn': 'Double Crochet Cross',
      'image': 'assets/images/長編み１目交差.png'
    },
    {
      'nameJa': 'バック細編み',
      'nameEn': 'Back Single Crochet',
      'image': 'assets/images/バック細編み.png'
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
      'image': 'assets/images/中長編み５目のパプコーン編み.png'
    },
    {
      'nameJa': '長編み５目のパプコーン編み',
      'nameEn': 'Double Crochet 5 Popcorn',
      'image': 'assets/images/長編み５目のパプコーン編み.png'
    },
    {
      'nameJa': '長々編み６目のパプコーン編み目',
      'nameEn': 'Treble Crochet 6 Popcorn',
      'image': 'assets/images/長々編み６目のパプコーン編み目.png'
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
    try {
      if (stitch is CrochetStitch) {
        return stitch.getName(context);
      } else if (stitch is CustomStitch) {
        return stitch.getName(context);
      } else if (stitch is Map<String, String>) {
        final locale = context.locale.languageCode;
        return locale == 'ja' ? stitch['nameJa']! : stitch['nameEn']!;
      } else {
        return 'Unknown';
      }
    } catch (e) {
      // エラー時は日本語名を返す
      if (stitch is CrochetStitch) {
        return stitch.nameJa;
      } else if (stitch is CustomStitch) {
        return stitch.nameJa;
      }
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
        title: Text(tr('edit_stitch_buttons')),
        backgroundColor: const Color(0xFFEC407A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isProcessing ? null : () async {
            if (_isProcessing) return;

            setState(() {
              _isProcessing = true;
            });

            try {
              // 非同期処理の前にNavigatorへの参照を保存
              final navigator = Navigator.of(context);

              // プロジェクト固有の編み目設定を保存
              if (widget.onProjectStitchesChanged != null) {
                await widget.onProjectStitchesChanged!(_stitches);
              }

              // 変更があったことを通知して戻る
              if (mounted) {
                navigator.pop(true);
              }
            } catch (e) {
              debugPrint('編み目設定の保存に失敗: $e');
              if (mounted) {
                _showDialog('編み目設定の保存に失敗しました');
              }
            } finally {
              if (mounted) {
                setState(() {
                  _isProcessing = false;
                });
              }
            }
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
                      leading: Builder(
                        builder: (context) {
                          final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                          return Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isDarkMode ? const Color(0xFF3D3D3D) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300),
                            ),
                            child: Center(
                              child: stitch.imagePath != null
                                  ? Image.asset(
                                      stitch.imagePath!,
                                      width: 24,
                                      height: 24,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Text(
                                          _getStitchName(stitch).substring(0, 1),
                                          style: const TextStyle(fontSize: 16),
                                        );
                                      },
                                    )
                                  : Text(
                                      _getStitchName(stitch),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                            ),
                          );
                        },
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
                if (_isProcessing) return;

                setState(() {
                  _isProcessing = true;
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final item = _stitches.removeAt(oldIndex);
                  _stitches.insert(newIndex, item);
                });

                try {
                  await _saveGlobalStitches();
                } catch (e) {
                  debugPrint('並び替え保存エラー: $e');
                  if (mounted) {
                    _showDialog('並び替えの保存に失敗しました');
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      _isProcessing = false;
                    });
                  }
                }
              },
            ),
          ),
        ],
      ),
        ),
        // ローディングオーバーレイ
        if (_isProcessing)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: Center(
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFFEC407A),
                        strokeWidth: 4,
                      ),
                      SizedBox(height: 24),
                      Text(
                        '処理中...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _removeStitch(int index) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _stitches.removeAt(index);
    });

    try {
      await _saveGlobalStitches();
    } catch (e) {
      debugPrint('削除保存エラー: $e');
      if (mounted) {
        _showDialog('削除の保存に失敗しました');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _saveGlobalStitches() async {
    try {
      // プロジェクト固有の編み目設定がある場合は、プロジェクト固有の設定として保存
      if (widget.projectStitches != null) {
        // プロジェクト固有の編み目設定を更新
        if (widget.onProjectStitchesChanged != null) {
          try {
            await widget.onProjectStitchesChanged!(_stitches);
          } catch (e) {
            debugPrint('プロジェクト編み目設定の保存に失敗: $e');
          }
        }
      } else {
        // グローバル設定として保存
        await StitchSettingsService.saveGlobalStitches(_stitches);
      }

      // 保存成功後にUIを強制的に更新
      if (mounted) {
        setState(() {});
      }

      // 少し待ってから再度確認
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (e) {
      debugPrint('編み目設定の保存に失敗: $e');
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
      barrierDismissible: false, // ダイアログの外側をタップしても閉じないようにする
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;
          final screenWidth = MediaQuery.of(context).size.width;
          final screenHeight = MediaQuery.of(context).size.height;
          final isTablet = screenWidth >= 600;

          // iPadなどのタブレットでは、より適切なサイズとカラム数を設定
          final dialogWidth = isTablet
              ? (screenWidth * 0.7).clamp(400.0, 800.0)
              : screenWidth * 0.9;
          final dialogHeight = isTablet
              ? (screenHeight * 0.6).clamp(400.0, 700.0)
              : screenHeight * 0.7;
          final crossAxisCount = isTablet ? 5 : 3;
          final childAspectRatio = isTablet ? 0.85 : 0.9;
          final fontSize = isTablet ? 11.0 : 9.0;
          final imageSize = isTablet ? 50.0 : 40.0;

          return AlertDialog(
            backgroundColor: isDarkMode ? const Color(0xFF2D2D2D) : null,
            title: Text(tr('edit_stitch_buttons')),
            content: SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: Column(
                children: [
                  // 基本編み目セクション
                  if (availableBasicStitches.isNotEmpty) ...[
                    Text(
                      '基本編み目',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.blue[300] : Colors.blue,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 1,
                    child: Scrollbar(
                      thumbVisibility: true,
                      thickness: 6,
                      radius: const Radius.circular(3),
                      child: GridView.builder(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: childAspectRatio,
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
                            color: isSelected
                                ? (isDarkMode ? Colors.blue.shade900 : Colors.blue.shade50)
                                : (isDarkMode ? const Color(0xFF3D3D3D) : null),
                            child: Stack(
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      height: imageSize,
                                      padding: const EdgeInsets.all(4),
                                      child: stitch.imagePath != null
                                          ? Image.asset(
                                              stitch.imagePath!,
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Center(
                                                  child: Text(
                                                    _getStitchName(stitch).substring(0, 1),
                                                    style: TextStyle(
                                                      fontSize: isTablet ? 18 : 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: stitch.color,
                                                    ),
                                                  ),
                                                );
                                              },
                                            )
                                          : Center(
                                              child: Text(
                                                _getStitchName(stitch)
                                                    .substring(0, 1),
                                                style: TextStyle(
                                                  fontSize: isTablet ? 18 : 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: stitch.color,
                                                ),
                                              ),
                                            ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      child: Text(
                                        _getStitchName(stitch),
                                        style: TextStyle(
                                          fontSize: fontSize,
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
                      color: isDarkMode ? Colors.pink[300] : Colors.pink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 2,
                    child: Scrollbar(
                      thumbVisibility: true,
                      thickness: 6,
                      radius: const Radius.circular(3),
                      child: GridView.builder(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: childAspectRatio,
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
                            color: isSelected
                                ? (isDarkMode ? Colors.pink.shade900 : Colors.pink.shade50)
                                : (isDarkMode ? const Color(0xFF3D3D3D) : null),
                            child: Stack(
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      height: imageSize,
                                      padding: const EdgeInsets.all(4),
                                      child: Image.asset(
                                        stitch['image']!,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Center(
                                            child: Text(
                                              _getStitchName(stitch).substring(0, 1),
                                              style: TextStyle(
                                                fontSize: isTablet ? 18 : 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      child: Text(
                                        _getStitchName(stitch),
                                        style: TextStyle(
                                          fontSize: fontSize,
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
        );
        },
      ),
    );
  }

  void _addSelectedStitches() async {
    // 基本編み目の制限チェック
    final currentBasicStitches =
        _stitches.whereType<CrochetStitch>().length;
    final newBasicStitches = _selectedBasicStitches.length;
    if (currentBasicStitches + newBasicStitches > 6) {
      _showDialog('基本編み目は6つまでしか追加できません');
      return;
    }

    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
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
    } catch (e) {
      debugPrint('編み目追加エラー: $e');
      if (mounted) {
        _showDialog('編み目の追加に失敗しました');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}
