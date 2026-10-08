import 'package:flutter/material.dart';
import '../l10n/stitch_names.dart';
import '../models/crochet_stitch.dart';
import '../models/premium_stitches.dart';
import '../widgets/stitch_choice_tile.dart';
import '../widgets/auto_scroll_text.dart';
import '../services/stitch_settings_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../services/subscription_provider.dart';
import '../widgets/cat_loading.dart';

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkPremiumStatusChange();
  }

  void _checkPremiumStatusChange() {
    final isPremium = context.read<SubscriptionProvider>().isPremium;
    final wasPremium = _wasPremium;

    if (wasPremium != null && wasPremium && !isPremium) {
      // プレミアムから解約された場合は編集をやめて閉じる。
      // 保存済みのボタン設定は書き換えない（再加入・購入復元で元に戻せるようにする）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(false);
      });
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
              child: Text(tr('ok')),
            ),
          ],
        ),
      );
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

      if (!mounted) return;
      setState(() {
        // setStateでUIを更新
      });
    } catch (e) {
      debugPrint('編み目の読み込みに失敗: $e');
      if (!mounted) return;
      setState(() {
        _stitches = StitchSettingsService.getDefaultStitches();
      });
    }
  }

  // プレミアム編み目のリスト
  final List<Map<String, String>> _premiumStitches = premiumStitchCatalog;

  String _getStitchName(dynamic stitch) {
    try {
      if (stitch is CrochetStitch) {
        return stitch.getName(context);
      } else if (stitch is CustomStitch) {
        return stitch.getName(context);
      } else if (stitch is Map<String, String>) {
        return localizedStitchName(context,
            nameJa: stitch['nameJa']!, nameEn: stitch['nameEn']!);
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
            title: AutoScrollText(tr('edit_stitch_buttons')),
            backgroundColor: const Color(0xFFEC407A),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _isProcessing
                  ? null
                  : () async {
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
                          _showDialog(tr('stitch_settings_save_failed'));
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
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
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
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: Builder(
                            builder: (context) {
                              final isDarkMode = Theme.of(context).brightness ==
                                  Brightness.dark;
                              return Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? const Color(0xFF3D3D3D)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: isDarkMode
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade300),
                                ),
                                child: Center(
                                  child: stitch.imagePath != null
                                      ? Image.asset(
                                          stitch.imagePath!,
                                          width: 24,
                                          height: 24,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Text(
                                              _getStitchName(stitch)
                                                  .substring(0, 1),
                                              style:
                                                  const TextStyle(fontSize: 16),
                                            );
                                          },
                                        )
                                      : Text(
                                          _getStitchName(stitch)
                                              .substring(0, 1),
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
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
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
                        _showDialog(tr('reorder_save_failed'));
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
        if (_isProcessing) CatLoadingOverlay(message: tr('processing')),
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
        _showDialog(tr('delete_save_failed'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// 編み目設定を保存する。失敗時は例外を伝播させ、呼び出し側でエラー表示する
  /// （ここで握りつぶすと呼び出し側の「保存に失敗しました」表示が機能しない）
  Future<void> _saveGlobalStitches() async {
    // プロジェクト固有の編み目設定がある場合は、プロジェクト固有の設定として保存
    if (widget.projectStitches != null) {
      // プロジェクト固有の編み目設定を更新
      if (widget.onProjectStitchesChanged != null) {
        await widget.onProjectStitchesChanged!(_stitches);
      }
    } else {
      // グローバル設定として保存
      await StitchSettingsService.saveGlobalStitches(_stitches);
    }

    // 保存成功後にUIを更新
    if (mounted) {
      setState(() {});
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
          final screenSize = MediaQuery.of(context).size;
          final isTablet = screenSize.width >= 600;

          // 画面の幅を広く使って、名前の欄をできるだけ確保する
          final dialogWidth = isTablet
              ? (screenSize.width * 0.7).clamp(400.0, 800.0)
              : screenSize.width;
          final dialogHeight = isTablet
              ? (screenSize.height * 0.6).clamp(400.0, 700.0)
              : screenSize.height * 0.7;

          Widget sectionTitle(String text, Color color) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 10),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              );

          SliverGridDelegate gridDelegate(double width) =>
              SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: StitchChoiceTile.columnsFor(context, width),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                mainAxisExtent: StitchChoiceTile.heightFor(context),
              );

          final basicColor = isDarkMode ? Colors.blue[300]! : Colors.blue;
          final premiumColor = isDarkMode ? Colors.pink[300]! : Colors.pink;

          return AlertDialog(
            backgroundColor: isDarkMode ? const Color(0xFF2D2D2D) : null,
            insetPadding: EdgeInsets.symmetric(
                horizontal: isTablet ? 40 : 16, vertical: 24),
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            title: Text(tr('edit_stitch_buttons')),
            content: SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: availableBasicStitches.isEmpty &&
                      availablePremiumStitches.isEmpty
                  // 利用可能な編み目がない場合
                  ? Center(
                      child: Text(
                        tr('no_stitches_available'),
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) => Scrollbar(
                        thumbVisibility: true,
                        thickness: 6,
                        radius: const Radius.circular(3),
                        // 基本とプレミアムを1つの一覧にまとめて、途中で切れずに続けて見られるようにする
                        child: CustomScrollView(
                          key: const ValueKey('add_stitch_list'),
                          primary: true,
                          slivers: [
                            if (availableBasicStitches.isNotEmpty) ...[
                              sectionTitle(tr('basic_stitch'), basicColor),
                              SliverPadding(
                                padding: const EdgeInsets.only(
                                    right: 10, bottom: 16),
                                sliver: SliverGrid.builder(
                                  gridDelegate:
                                      gridDelegate(constraints.maxWidth - 10),
                                  itemCount: availableBasicStitches.length,
                                  itemBuilder: (context, index) {
                                    final stitch =
                                        availableBasicStitches[index];
                                    final isSelected =
                                        _selectedBasicStitches.contains(stitch);
                                    return StitchChoiceTile(
                                      name: _getStitchName(stitch),
                                      imagePath: stitch.imagePath,
                                      selected: isSelected,
                                      accentColor: basicColor,
                                      onTap: () {
                                        setDialogState(() {
                                          if (isSelected) {
                                            _selectedBasicStitches
                                                .remove(stitch);
                                          } else {
                                            _selectedBasicStitches.add(stitch);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                            if (availablePremiumStitches.isNotEmpty) ...[
                              sectionTitle(
                                  tr('select_premium_stitch'), premiumColor),
                              SliverPadding(
                                padding:
                                    const EdgeInsets.only(right: 10, bottom: 8),
                                sliver: SliverGrid.builder(
                                  gridDelegate:
                                      gridDelegate(constraints.maxWidth - 10),
                                  itemCount: availablePremiumStitches.length,
                                  itemBuilder: (context, index) {
                                    final stitch =
                                        availablePremiumStitches[index];
                                    final isSelected = _selectedPremiumStitches
                                        .contains(stitch);
                                    return StitchChoiceTile(
                                      name: _getStitchName(stitch),
                                      imagePath: stitch['image'],
                                      selected: isSelected,
                                      accentColor: premiumColor,
                                      onTap: () {
                                        setDialogState(() {
                                          if (isSelected) {
                                            _selectedPremiumStitches
                                                .remove(stitch);
                                          } else {
                                            _selectedPremiumStitches
                                                .add(stitch);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(tr('cancel')),
              ),
              ElevatedButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  // 追加に成功した場合のみダイアログを閉じる
                  // （先にpopすると上限警告ダイアログの方が閉じられてしまう）
                  final success = await _addSelectedStitches();
                  if (success && context.mounted) {
                    navigator.pop();
                  }
                },
                child: Text(tr('add_with_count', namedArgs: {
                  'count':
                      '${_selectedBasicStitches.length + _selectedPremiumStitches.length}'
                })),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _addSelectedStitches() async {
    // 基本編み目の制限チェック
    final currentBasicStitches = _stitches.whereType<CrochetStitch>().length;
    final newBasicStitches = _selectedBasicStitches.length;
    if (currentBasicStitches + newBasicStitches > 6) {
      _showDialog(tr('basic_stitch_limit'));
      return false;
    }

    if (_isProcessing) return false;

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
      return true;
    } catch (e) {
      debugPrint('編み目追加エラー: $e');
      if (mounted) {
        _showDialog(tr('stitch_add_failed'));
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}
