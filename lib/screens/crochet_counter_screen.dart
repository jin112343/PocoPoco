import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../models/crochet_stitch.dart';
import '../models/crochet_project.dart';
import '../services/storage_service.dart';
import '../services/stitch_settings_service.dart';
import '../widgets/stitch_pattern_grid.dart';
import '../widgets/stitch_history_section.dart';
import '../widgets/control_buttons.dart';
import 'settings_screen.dart';
import 'home_screen.dart';
import 'stitch_customization_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../services/subscription_provider.dart';
import 'package:easy_localization/easy_localization.dart';

class CrochetCounterScreen extends StatefulWidget {
  final CrochetProject? project;

  const CrochetCounterScreen({super.key, this.project});

  @override
  State<CrochetCounterScreen> createState() => _CrochetCounterScreenState();
}

class _CrochetCounterScreenState extends State<CrochetCounterScreen> {
  final Logger _logger = Logger();
  final StorageService _storageService = StorageService();

  // 状態管理の最適化
  int _stitchCount = 0;
  int _rowNumber = 1;
  CrochetStitch _selectedStitch = CrochetStitch.singleCrochet;
  final List<Map<String, dynamic>> _stitchHistory = [];

  // 広告関連
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoaded = false;
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  // プロジェクト関連
  String _projectId = '';
  String _projectTitle = '新しいプロジェクト';
  bool _hasUnsavedChanges = false;

  // パフォーマンス最適化のためのキャッシュ
  bool? _wasPremium;
  List<dynamic>? _cachedProjectStitches;
  int? _cachedProjectStitchesHash;
  List<dynamic>? _defaultStitches;

  // 処理状態管理
  bool _isRemovingRow = false;
  bool _isInitializing = false;
  bool _isSaving = false;

  // サブスクリプション状態のキャッシュ
  SubscriptionProvider? _subscriptionProvider;

  @override
  void initState() {
    super.initState();
    _initializeOptimized();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeSubscriptionProvider();
    _checkPremiumStatusChangeOptimized();
  }

  /// 最適化されたサブスクリプションプロバイダーの初期化
  void _initializeSubscriptionProvider() {
    if (_subscriptionProvider == null) {
      _subscriptionProvider = context.read<SubscriptionProvider>();
      _loadRewardedAd();
      _loadBannerAd();
    }
  }

  /// 最適化されたプレミアム状態変更チェック
  void _checkPremiumStatusChangeOptimized() {
    final isPremium = _subscriptionProvider?.isPremium ?? false;
    final wasPremium = _wasPremium;

    // 状態に変化がある場合のみ処理
    if (wasPremium != null && wasPremium != isPremium) {
      if (wasPremium && !isPremium) {
        _logger.i('プレミアム解約を検知');
        _resetStitchSettingsToDefaultOptimized();
      } else if (!wasPremium && isPremium) {
        _logger.i('プレミアムアップグレードを検知');
        _reloadProjectCustomStitchesOptimized();
      }
    }

    _wasPremium = isPremium;
  }

  /// 最適化された初期化処理
  Future<void> _initializeOptimized() async {
    if (_isInitializing) return;

    try {
      _isInitializing = true;
      _logger.i('最適化された初期化開始');

      if (widget.project != null) {
        await _loadExistingProject(widget.project!);
      } else {
        _initializeNewProject();
      }

      // 編み目設定の初期化（一度だけ）
      await _initializeStitchSettings();

      _logger.i('最適化された初期化完了');
    } catch (e, stackTrace) {
      _logger.e('初期化エラー', error: e, stackTrace: stackTrace);
      _initializeNewProject(); // フォールバック
    } finally {
      _isInitializing = false;
    }
  }

  /// 既存プロジェクトの読み込み（最適化版）
  Future<void> _loadExistingProject(CrochetProject project) async {
    _projectId = project.id;
    _projectTitle = project.title;
    _stitchCount = project.currentStitchCount;
    _rowNumber = project.currentRow;
    _stitchHistory.clear();
    _stitchHistory.addAll(project.stitchHistory);
    _cachedProjectStitches = project.customStitches;
    _hasUnsavedChanges = false;

    _logger.i('既存プロジェクト読み込み完了: ${project.title}');
  }

  /// 新規プロジェクトの初期化
  void _initializeNewProject() {
    _projectId = _storageService.generateProjectId();
    _projectTitle = '新しい編みもの';
    _stitchCount = 0;
    _rowNumber = 1;
    _stitchHistory.clear();
    _cachedProjectStitches = null; // 遅延初期化
    _hasUnsavedChanges = false;

    _logger.i('新規プロジェクト初期化完了');
  }

  /// 編み目設定の初期化（最適化版）
  Future<void> _initializeStitchSettings() async {
    try {
      if (_cachedProjectStitches == null) {
        if (widget.project?.customStitches?.isNotEmpty == true) {
          _cachedProjectStitches = widget.project!.customStitches;
        } else {
          _cachedProjectStitches = StitchSettingsService.getDefaultStitches();
        }
      }

      // ハッシュ値を計算してキャッシュ
      _cachedProjectStitchesHash = _calculateStitchesHash(_cachedProjectStitches!);

      _logger.i('編み目設定初期化完了: ${_cachedProjectStitches!.length}個');
    } catch (e) {
      _logger.e('編み目設定初期化エラー: $e');
      _cachedProjectStitches = StitchSettingsService.getDefaultStitches();
      _cachedProjectStitchesHash = _calculateStitchesHash(_cachedProjectStitches!);
    }
  }

  /// 編み目リストのハッシュ値計算
  int _calculateStitchesHash(List<dynamic> stitches) {
    return Object.hashAll(stitches.map((s) {
      if (s is CrochetStitch) {
        return s.name;
      } else if (s is CustomStitch) {
        return '${s.name}_${s.color.value}';
      }
      return s.toString();
    }));
  }

  /// 編み目設定のリセット（最適化版）
  Future<void> _resetStitchSettingsToDefaultOptimized() async {
    try {
      _logger.i('編み目設定を基本設定にリセット');

      final defaultStitches = StitchSettingsService.getDefaultStitches();
      final newHash = _calculateStitchesHash(defaultStitches);

      // ハッシュが同じ場合は処理をスキップ
      if (_cachedProjectStitchesHash == newHash) {
        _logger.d('編み目設定に変更なし、リセットをスキップ');
        return;
      }

      // グローバル設定の更新
      await StitchSettingsService.saveGlobalStitches(defaultStitches);

      // プロジェクト設定の更新
      if (widget.project != null) {
        await _updateProjectStitches(defaultStitches);
      }

      // キャッシュの更新
      _cachedProjectStitches = defaultStitches;
      _cachedProjectStitchesHash = newHash;

      if (mounted) {
        setState(() {}); // 一度だけ更新
        _showSnackBar('編み目設定を基本に戻しました', Colors.orange);
      }
    } catch (e) {
      _logger.e('編み目設定リセットエラー: $e');
    }
  }

  /// プロジェクト編み目設定の再読み込み（最適化版）
  Future<void> _reloadProjectCustomStitchesOptimized() async {
    try {
      _logger.i('編み目設定再読み込み開始');

      List<dynamic> newStitches;
      if (widget.project != null) {
        final updatedProjects = await _storageService.getProjects();
        final currentProject = updatedProjects.firstWhere(
              (p) => p.id == widget.project!.id,
          orElse: () => widget.project!,
        );
        newStitches = currentProject.customStitches ?? StitchSettingsService.getDefaultStitches();
      } else {
        newStitches = StitchSettingsService.getDefaultStitches();
      }

      final newHash = _calculateStitchesHash(newStitches);

      // ハッシュが同じ場合は処理をスキップ
      if (_cachedProjectStitchesHash == newHash) {
        _logger.d('編み目設定に変更なし、再読み込みをスキップ');
        return;
      }

      // キャッシュの更新
      _cachedProjectStitches = newStitches;
      _cachedProjectStitchesHash = newHash;

      _logger.i('編み目設定再読み込み完了: ${newStitches.length}個');

      if (mounted) {
        setState(() {}); // 一度だけ更新
      }
    } catch (e) {
      _logger.e('編み目設定再読み込みエラー: $e');
    }
  }

  /// 段削除処理（最適化版）
  Future<void> _removeRowOptimized(int rowNumber) async {
    if (_isRemovingRow) {
      _logger.w('段削除処理中、重複削除をスキップ: $rowNumber段目');
      return;
    }

    final stopwatch = Stopwatch()..start();

    try {
      _isRemovingRow = true;
      _logger.i('段削除開始: $rowNumber段目');

      // 削除対象の存在確認
      if (!_stitchHistory.any((stitch) => stitch['row'] == rowNumber)) {
        _logger.w('削除対象の段が見つかりません: $rowNumber段目');
        return;
      }

      // UI更新を一度だけ実行
      setState(() {
        // 指定された段の編み目をすべて削除
        _stitchHistory.removeWhere((stitch) => stitch['row'] == rowNumber);

        // 段数を効率的に振り直し
        _renumberRowsSequentiallyOptimized();

        // 現在の段数と編み目数を再計算
        if (_stitchHistory.isNotEmpty) {
          _rowNumber = _getCurrentRow();
          // 現在の段の編み目数を正確に計算
          _stitchCount = _stitchHistory
              .where((stitch) => stitch['row'] == _rowNumber && stitch['position'] != 0)
              .length;
        } else {
          _rowNumber = 0;
          _stitchCount = 0;
        }
      });

      _hasUnsavedChanges = true;

      // 段削除後の追加のUI更新を確実に実行
      if (mounted) {
        // 強制的に再ビルドを促す
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // 段削除後の編み目数を再計算
            if (_stitchHistory.isNotEmpty) {
              _stitchCount = _stitchHistory
                  .where((stitch) => stitch['row'] == _rowNumber && stitch['position'] != 0)
                  .length;
            } else {
              _stitchCount = 0;
            }
            
            setState(() {});
            // 段削除後の状態を確実に更新
            _logger.d('段削除後の状態更新: 段数=$_rowNumber, 編み目数=$_stitchCount');
          }
        });
      }

      // 成功通知
      if (mounted) {
        _showSnackBar('$rowNumber段目を削除しました', Colors.orange);
      }

      _logger.i('段削除完了: $rowNumber段目');
    } catch (e, stackTrace) {
      _logger.e('段削除エラー', error: e, stackTrace: stackTrace);
    } finally {
      _isRemovingRow = false;
      stopwatch.stop();
      _logger.d('段削除処理時間: ${stopwatch.elapsedMilliseconds}ms');
    }
  }

  /// 段数振り直し処理（最適化版）
  void _renumberRowsSequentiallyOptimized() {
    if (_stitchHistory.isEmpty) return;

    try {
      // 段ごとにグループ化（効率的なアルゴリズム）
      final Map<int, List<Map<String, dynamic>>> groupedByRow = {};
      for (final stitch in _stitchHistory) {
        final row = stitch['row'] as int;
        (groupedByRow[row] ??= []).add(stitch);
      }

      // 段数を1から順番に振り直す
      final sortedRows = groupedByRow.keys.toList()..sort();
      int newRowNumber = 1;
      bool hasChanges = false;

      for (final oldRowNumber in sortedRows) {
        if (oldRowNumber != newRowNumber) {
          final stitchesInRow = groupedByRow[oldRowNumber]!;
          for (final stitch in stitchesInRow) {
            stitch['row'] = newRowNumber;
            hasChanges = true;
          }
        }
        newRowNumber++;
      }

      if (hasChanges) {
        _logger.i('段数の振り直しが完了しました');
      }
    } catch (e) {
      _logger.e('段数振り直しエラー: $e');
    }
  }

  /// 現在の編み目設定を取得（最適化版）
  List<dynamic> _getCurrentStitchesOptimized() {
    // キャッシュされた編み目設定を返す
    if (_cachedProjectStitches != null) {
      return _cachedProjectStitches!;
    }

    // 遅延初期化
    if (_defaultStitches == null) {
      _defaultStitches = StitchSettingsService.getDefaultStitches();
    }
    return _defaultStitches!;
  }

  /// プロジェクト編み目設定の更新（最適化版）
  Future<void> _updateProjectStitches(List<dynamic> newStitches) async {
    if (widget.project == null) return;

    try {
      final updatedProject = widget.project!.copyWith(
        customStitches: newStitches,
        updatedAt: DateTime.now(),
      );

      final isPremium = _subscriptionProvider?.isPremium ?? false;
      final success = await _storageService.saveProject(updatedProject, isPremium: isPremium);

      if (success) {
        _logger.i('プロジェクト編み目設定更新完了');
      } else {
        _logger.e('プロジェクト編み目設定更新失敗');
      }
    } catch (e) {
      _logger.e('プロジェクト編み目設定更新エラー: $e');
    }
  }

  /// 保存処理（最適化版）
  Future<bool> _saveProjectOptimized() async {
    if (_isSaving) {
      _logger.w('保存処理中、重複保存をスキップ');
      return false;
    }

    try {
      _isSaving = true;
      _logger.i('プロジェクト保存開始');

      final project = CrochetProject(
        id: _projectId,
        title: _projectTitle,
        createdAt: widget.project?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        stitchHistory: _stitchHistory,
        currentRow: _getCurrentRow(),
        currentStitchCount: _getCurrentStitchCount(),
        iconName: widget.project?.iconName ?? 'work',
        iconColor: widget.project?.iconColor ?? '0xFF000000',
        backgroundColor: widget.project?.backgroundColor ?? '0xFFFFFFFF',
        customStitches: _cachedProjectStitches ?? [],
      );

      final isPremium = _subscriptionProvider?.isPremium ?? false;
      final success = await _storageService.saveProject(project, isPremium: isPremium);

      if (success) {
        setState(() {
          _hasUnsavedChanges = false;
        });
        _showSnackBar('保存完了', Colors.green);
        return true;
      } else {
        if (!isPremium) {
          _showSnackBar('保存制限に達しました', Colors.red);
        }
        return false;
      }
    } catch (e) {
      _logger.e('保存エラー: $e');
      _showSnackBar('保存に失敗しました', Colors.red);
      return false;
    } finally {
      _isSaving = false;
    }
  }

  /// スナックバー表示のヘルパー
  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 編み目追加処理
  void _addStitch(dynamic stitch) {
    try {
      setState(() {
        // 現在の段の編み目数を正確に計算
        final currentRowStitches = _stitchHistory
            .where((stitch) => stitch['row'] == _rowNumber && stitch['position'] != 0)
            .length;
        
        // 次の編み目の位置を計算
        _stitchCount = currentRowStitches + 1;

        Map<String, dynamic> historyItem = {
          'row': _rowNumber,
          'position': _stitchCount,
          'timestamp': DateTime.now(),
        };

        if (stitch is CrochetStitch) {
          historyItem['stitch'] = stitch;
        } else if (stitch is CustomStitch) {
          historyItem['stitch'] = {
            'type': 'custom',
            'name': stitch.name,
            'nameJa': stitch.nameJa,
            'nameEn': stitch.nameEn,
            'imagePath': stitch.imagePath,
            'color': stitch.color.value,
            'isOval': stitch.isOval,
          };
        } else {
          historyItem['stitch'] = stitch;
        }

        _stitchHistory.add(historyItem);
        _hasUnsavedChanges = true;
      });

      _logger.i('編み目追加: 段$_rowNumber, 位置$_stitchCount');
    } catch (e, stackTrace) {
      _logger.e('編み目追加エラー', error: e, stackTrace: stackTrace);
    }
  }

  /// 最後の編み目削除
  void _removeLastStitch() {
    try {
      if (_stitchHistory.isNotEmpty) {
        setState(() {
          final lastStitch = _stitchHistory.last;

          if (lastStitch['isRowStart'] == true) {
            _stitchHistory.removeLast();
            _renumberRowsSequentiallyOptimized();
            _rowNumber = _getCurrentRow();
            // 現在の段の編み目数を正確に計算
            _stitchCount = _stitchHistory
                .where((stitch) => stitch['row'] == _rowNumber && stitch['position'] != 0)
                .length;
          } else {
            _stitchHistory.removeLast();
            // 現在の段の編み目数を正確に計算
            _stitchCount = _stitchHistory
                .where((stitch) => stitch['row'] == _rowNumber && stitch['position'] != 0)
                .length;
          }

          _hasUnsavedChanges = true;
        });
        _logger.i('最後の編み目削除完了: 段$_rowNumber, 編み目数$_stitchCount');
      }
    } catch (e, stackTrace) {
      _logger.e('最後の編み目削除エラー', error: e, stackTrace: stackTrace);
    }
  }

  /// 段完成処理
  void _completeRow() {
    try {
      if (_stitchCount > 0) {
        setState(() {
          int maxRow = 0;
          if (_stitchHistory.isNotEmpty) {
            maxRow = _stitchHistory.map((e) => e['row'] as int).reduce((a, b) => a > b ? a : b);
          }

          _rowNumber = maxRow + 1;
          // 新しい段の編み目数を0にリセット
          _stitchCount = 0;

          _stitchHistory.add({
            'stitch': _selectedStitch,
            'row': _rowNumber,
            'position': 0,
            'timestamp': DateTime.now(),
            'isRowStart': true,
          });
          _hasUnsavedChanges = true;
        });

        _logger.i('段完成: $_rowNumber段目, 編み目数: $_stitchCount');
      }
    } catch (e, stackTrace) {
      _logger.e('段完成エラー', error: e, stackTrace: stackTrace);
    }
  }

  /// リセット処理
  void _resetAll() {
    try {
      setState(() {
        _stitchCount = 0;
        _rowNumber = 1;
        _stitchHistory.clear();
        _hasUnsavedChanges = true;
      });
      _logger.i('リセット完了');
    } catch (e, stackTrace) {
      _logger.e('リセットエラー', error: e, stackTrace: stackTrace);
    }
  }

  /// 現在の段数取得
  int _getCurrentRow() {
    if (_stitchHistory.isEmpty) return 0;
    try {
      return _stitchHistory.last['row'] as int;
    } catch (e) {
      _logger.e('現在段数取得エラー: $e');
      return 0;
    }
  }

  /// 現在の編み目数取得
  int _getCurrentStitchCount() {
    if (_stitchHistory.isEmpty) return 0;
    try {
      return _stitchHistory.where((stitch) => stitch['position'] != 0).length;
    } catch (e) {
      _logger.e('現在編み目数取得エラー: $e');
      return 0;
    }
  }

  /// 広告読み込み
  void _loadRewardedAd() {
    final adUnitId = Platform.isAndroid
        ? 'ca-app-pub-1187210314934709/4892788853'
        : 'ca-app-pub-1187210314934709/8887874189';
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _rewardedAd = ad;
            _isRewardedAdLoaded = true;
          });
        },
        onAdFailedToLoad: (error) {
          setState(() {
            _rewardedAd = null;
            _isRewardedAdLoaded = false;
          });
        },
      ),
    );
  }

  void _loadBannerAd() {
    final adUnitId = Platform.isAndroid
        ? 'ca-app-pub-1187210314934709/2203046337'
        : 'ca-app-pub-1187210314934709/2458197200';
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          setState(() {
            _isBannerAdLoaded = false;
          });
        },
      ),
    );
    _bannerAd!.load();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _showSaveDialogOptimized,
      child: Scaffold(
        backgroundColor: const Color(0xFFFCE4EC),
        appBar: _buildAppBar(),
        body: SafeArea(
          child: Column(
            children: [
              // 編み目履歴
              Expanded(
                flex: 1,
                child: StitchHistorySection(
                  stitchHistory: _stitchHistory,
                  currentStitches: _getCurrentStitchesOptimized(),
                  onRowTap: (rowNumber) {
                    _showSnackBar('$rowNumber段目に移動しました', const Color(0xFFAD1457));
                  },
                  onRowCompleted: (rowNumber) {
                    // 段完成時の処理
                  },
                  onStitchRemoved: (rowNumber) async {
                    await _removeRowOptimized(rowNumber);
                  },
                  currentRow: _getCurrentRow(),
                  currentStitchCount: _getCurrentStitchCount(),
                ),
              ),
              const SizedBox(height: 10),

              // 編み目パターンとコントロール
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // 最適化されたStitchPatternGrid
                    StitchPatternGrid(
                      key: ValueKey('optimized_${_cachedProjectStitchesHash ?? 0}'),
                      selectedStitch: _selectedStitch,
                      onStitchSelected: (stitch) {
                        setState(() {
                          _selectedStitch = stitch;
                        });
                      },
                      onStitchAdded: _addStitch,
                      projectStitches: _getCurrentStitchesOptimized(),
                      onStitchSettingsChanged: () async {
                        await _reloadProjectCustomStitchesOptimized();
                      },
                      onProjectStitchesChanged: (newStitches) async {
                        await _updateProjectStitchesOptimized(newStitches);
                      },
                    ),
                    const SizedBox(height: 20),
                    ControlButtons(
                      onRemoveStitch: _removeLastStitch,
                      onCompleteRow: _completeRow,
                      onReset: _resetAll,
                      canRemoveStitch: _stitchHistory.isNotEmpty,
                      canCompleteRow: _stitchCount > 0,
                    ),
                  ],
                ),
              ),

              // バナー広告
              if (!(_subscriptionProvider?.isPremium ?? false) &&
                  _isBannerAdLoaded &&
                  _bannerAd != null)
                Container(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// AppBarの構築
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: GestureDetector(
        onTap: _editProjectTitle,
        child: Text(
          _projectTitle.isEmpty ? tr('app_title') : _projectTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      backgroundColor: const Color(0xFFEC407A),
      centerTitle: true,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _handleBackButtonOptimized,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.save),
          onPressed: _isSaving ? null : () async {
            final result = await _saveProjectOptimized();
            if (result) {
              _showRewardedAdAfterSave();
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: _navigateToSettings,
        ),
      ],
    );
  }

  /// プロジェクト編み目設定の最適化された更新
  Future<void> _updateProjectStitchesOptimized(List<dynamic> newStitches) async {
    try {
      final newHash = _calculateStitchesHash(newStitches);

      // ハッシュが同じ場合は処理をスキップ
      if (_cachedProjectStitchesHash == newHash) {
        _logger.d('プロジェクト編み目設定に変更なし、更新をスキップ');
        return;
      }

      _logger.i('プロジェクト編み目設定更新開始: ${newStitches.length}個');

      // キャッシュを更新
      _cachedProjectStitches = List.from(newStitches);
      _cachedProjectStitchesHash = newHash;

      // プロジェクトが存在する場合は保存
      if (widget.project != null) {
        await _updateProjectStitches(newStitches);
      }

      // UI更新（一度だけ）
      if (mounted) {
        setState(() {});
        _logger.i('プロジェクト編み目設定更新完了');
      }
    } catch (e) {
      _logger.e('プロジェクト編み目設定更新エラー: $e');
    }
  }

  /// 戻るボタンの最適化された処理
  Future<void> _handleBackButtonOptimized() async {
    _logger.d('戻るボタン押下');

    if (!_hasUnsavedChanges) {
      _logger.d('変更なし、直接戻る');
      Navigator.of(context).pop();
      return;
    }

    final result = await _showSaveDialogOptimized();
    if (result == true) {
      if (_projectTitle == '新しい編みもの' || _projectTitle.isEmpty) {
        final titleResult = await _editProjectTitle();
        if (titleResult == null) return;
      }

      final saveSuccess = await _saveProjectOptimized();
      if (saveSuccess) {
        _showRewardedAdAfterSave();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
        );
      }
    } else if (result == false) {
      Navigator.of(context).pop();
    }
  }

  /// 最適化された保存ダイアログ
  Future<bool> _showSaveDialogOptimized() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('変更を保存'),
        content: const Text('変更を保存しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('保存しない'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    
    // nullの場合はfalse（保存しない）として扱う
    return result ?? false;
  }

  /// プロジェクトタイトル編集
  Future<String?> _editProjectTitle() async {
    final TextEditingController controller = TextEditingController(text: _projectTitle);

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('edit_stitch_buttons')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: tr('edit_stitch_buttons'),
            hintText: '例: マフラー',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                Navigator.of(context).pop(newTitle);
                setState(() {
                  _projectTitle = newTitle;
                  _hasUnsavedChanges = true;
                });
              }
            },
            child: Text(tr('save')),
          ),
        ],
      ),
    );
  }

  /// 設定画面への遷移（最適化版）
  Future<void> _navigateToSettings() async {
    final currentProject = widget.project;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          isFromProject: true,
          currentProject: currentProject,
        ),
      ),
    );

    // 設定画面から戻った時の処理（最適化）
    if (result == true && mounted) {
      _logger.i('設定画面から戻りました、編み目設定を確認');

      // 少し待ってから再読み込み
      await Future.delayed(const Duration(milliseconds: 300));
      await _reloadProjectCustomStitchesOptimized();
    }
  }

  /// 保存後の報酬広告表示
  void _showRewardedAdAfterSave() {
    final isPremium = _subscriptionProvider?.isPremium ?? false;
    if (isPremium) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('watch_ad_title')),
        content: Text(tr('watch_ad_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('no_thanks')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showRewardedAd();
            },
            child: Text(tr('watch_ad')),
          ),
        ],
      ),
    );
  }

  /// 報酬広告の表示
  void _showRewardedAd() {
    if (_isRewardedAdLoaded && _rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadRewardedAd();
        },
      );
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          _logger.i('報酬広告視聴完了');
        },
      );
    }
  }

  /// リセット時の報酬広告表示
  void _showRewardedAdAndReset() {
    final isPremium = _subscriptionProvider?.isPremium ?? false;
    if (isPremium) {
      _resetAll();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('watch_ad_reset_title')),
        content: Text(tr('watch_ad_reset_message')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetAll();
            },
            child: Text(tr('no_thanks')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showRewardedAdForReset();
            },
            child: Text(tr('watch_ad')),
          ),
        ],
      ),
    );
  }

  /// リセット用報酬広告の表示
  void _showRewardedAdForReset() {
    if (_isRewardedAdLoaded && _rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _resetAll();
          _loadRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _resetAll();
          _loadRewardedAd();
        },
      );
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          // 報酬付与
        },
      );
    } else {
      _resetAll();
    }
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }
}