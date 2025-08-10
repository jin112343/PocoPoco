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
  int _stitchCount = 0;
  int _rowNumber = 1;
  CrochetStitch _selectedStitch = CrochetStitch.singleCrochet;
  final List<Map<String, dynamic>> _stitchHistory = [];
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoaded = false;
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  String _projectId = '';
  String _projectTitle = '新しいプロジェクト';
  bool _hasUnsavedChanges = false;
  bool? _wasPremium; // 前回のプレミアム状態を記録
  List<dynamic>? _projectCustomStitches; // プロジェクトの編み目設定
  int _stitchGridKey = 0; // 編み目グリッドのキー更新用

  @override
  void initState() {
    super.initState();
    _loadRewardedAd();
    _loadBannerAd();
    _initializeProject().then((_) async {
      // 初期化完了後に編み目設定を強制再読み込み
      print('初期化完了、編み目設定を強制再読み込み中...');
      await _reloadProjectCustomStitches();

      // さらにグローバル設定も確認
      final globalStitches = await StitchSettingsService.getGlobalStitches();
      print('初期化時のグローバル編み目設定: ${globalStitches.length}個');

      // UIを更新
      if (mounted) {
        setState(() {
          _stitchGridKey++;
        });

        // 少し待ってから再度更新（確実に反映させるため）
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          setState(() {});
        }
      }
    });
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
      print('プレミアム解約を検知しました');
      _resetStitchSettingsToDefault();
    } else if (wasPremium != null && !wasPremium && isPremium) {
      // プレミアムにアップグレードされた場合
      print('プレミアムアップグレードを検知しました');
      _reloadProjectCustomStitches();
    }

    _wasPremium = isPremium;
  }

  void _resetStitchSettingsToDefault() async {
    try {
      print('編み目設定を基本の6つにリセットします');

      // グローバル編み目設定をデフォルトにリセット
      final defaultStitches = StitchSettingsService.getDefaultStitches();
      await StitchSettingsService.saveGlobalStitches(defaultStitches);

      // プロジェクトの編み目設定もリセット
      if (widget.project != null) {
        final updatedProject = CrochetProject(
          id: widget.project!.id,
          title: widget.project!.title,
          createdAt: widget.project!.createdAt,
          updatedAt: DateTime.now(),
          stitchHistory: widget.project!.stitchHistory,
          currentRow: widget.project!.currentRow,
          currentStitchCount: widget.project!.currentStitchCount,
          iconName: widget.project!.iconName,
          iconColor: widget.project!.iconColor,
          backgroundColor: widget.project!.backgroundColor,
          customStitches: [], // カスタム編み目をクリア
        );

        final isPremium = context.read<SubscriptionProvider>().isPremium;
        await _storageService.saveProject(updatedProject, isPremium: isPremium);
      }

      print('編み目設定のリセットが完了しました');

      // UIを更新
      setState(() {
        // 編み目ボタンを再構築
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('プレミアム解約により編み目設定を基本に戻しました'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      print('編み目設定リセットエラー: $e');
    }
  }

  Future<void> _initializeProject() async {
    try {
      print('=== プロジェクト初期化開始 ===');

      if (widget.project != null) {
        // 既存のプロジェクトを読み込み
        final project = widget.project!;
        print('既存プロジェクトを読み込み: ${project.title}');
        _projectId = project.id;
        _projectTitle = project.title;
        _stitchCount = project.currentStitchCount;
        _rowNumber = project.currentRow;
        _stitchHistory.clear();
        _stitchHistory.addAll(project.stitchHistory);
        _projectCustomStitches = project.customStitches;
        _hasUnsavedChanges = false; // 既存プロジェクトは変更なしとして初期化
        print('プロジェクト読み込み完了: ${_stitchHistory.length}件の履歴');
        print('プロジェクトの編み目設定: ${_projectCustomStitches?.length}個');
      } else {
        // 新しい編みものを作成
        _projectId = _storageService.generateProjectId();
        _projectTitle = '新しい編みもの';
        // 新規プロジェクトは必ず基本6つから開始
        _projectCustomStitches = StitchSettingsService.getDefaultStitches();
        _hasUnsavedChanges = false; // 新規プロジェクトは変更なしとして初期化
        print(
            '新規編みもの作成: $_projectId, 基本編み目設定: ${_projectCustomStitches?.length}個');
        print('生成されたプロジェクトID: $_projectId');
      }

      // 最終的な編み目設定の確認
      print('最終的な編み目設定: ${_projectCustomStitches?.length}個');
      if (_projectCustomStitches != null) {
        for (int i = 0; i < _projectCustomStitches!.length; i++) {
          final stitch = _projectCustomStitches![i];
          if (stitch is CrochetStitch) {
            print('  $i: ${(stitch as CrochetStitch).name} (CrochetStitch)');
          } else if (stitch is CustomStitch) {
            print('  $i: ${(stitch as CustomStitch).name} (CustomStitch)');
          } else {
            print('  $i: 不明な型 (${stitch.runtimeType})');
          }
        }
      }

      // 初期化時の編み目設定詳細ログ
      print('初期化時の編み目設定詳細:');
      if (_projectCustomStitches != null) {
        for (int i = 0; i < _projectCustomStitches!.length; i++) {
          final stitch = _projectCustomStitches![i];
          if (stitch is CrochetStitch) {
            print('  $i: ${(stitch as CrochetStitch).name} (CrochetStitch)');
          } else if (stitch is CustomStitch) {
            print('  $i: ${(stitch as CustomStitch).name} (CustomStitch)');
          } else {
            print('  $i: 不明な型 (${stitch.runtimeType})');
          }
        }
      }

      print('✅ プロジェクト初期化完了');
    } catch (e) {
      print('❌ プロジェクト初期化エラー: $e');
      // エラーが発生した場合は新規プロジェクトとして初期化
      _projectId = _storageService.generateProjectId();
      _projectTitle = '新しい編みもの';
      _stitchCount = 0;
      _rowNumber = 1;
      _stitchHistory.clear();
      _projectCustomStitches = StitchSettingsService.getDefaultStitches();
      _hasUnsavedChanges = false;
    }
  }

  // プロジェクト固有の編み目設定を再読み込み
  Future<void> _reloadProjectCustomStitches() async {
    try {
      print('=== 編み目設定再読み込み開始 ===');

      if (widget.project != null) {
        // 既存プロジェクトの場合は保存された設定を再読み込み
        final updatedProject = await _storageService.getProjects();
        final currentProject = updatedProject.firstWhere(
          (p) => p.id == widget.project!.id,
          orElse: () => widget.project!,
        );
        _projectCustomStitches = currentProject.customStitches;
        print('プロジェクト固有の編み目設定を再読み込み: ${_projectCustomStitches?.length}個');
      } else {
        // 新規プロジェクトの場合は基本6つの編み目を使用
        _projectCustomStitches = StitchSettingsService.getDefaultStitches();
        print('新規プロジェクト用の基本編み目設定を使用: ${_projectCustomStitches?.length}個');
      }

      // 読み込まれた編み目設定の詳細ログ
      print('読み込まれた編み目設定の詳細:');
      if (_projectCustomStitches != null) {
        for (int i = 0; i < _projectCustomStitches!.length; i++) {
          final stitch = _projectCustomStitches![i];
          if (stitch is CrochetStitch) {
            print('  $i: ${(stitch as CrochetStitch).name} (CrochetStitch)');
          } else if (stitch is CustomStitch) {
            print('  $i: ${(stitch as CustomStitch).name} (CustomStitch)');
          } else {
            print('  $i: 不明な型 (${stitch.runtimeType})');
          }
        }
      }

      // プロジェクト固有の編み目設定が空の場合は、基本6つの編み目を使用
      if (_projectCustomStitches == null || _projectCustomStitches!.isEmpty) {
        print('プロジェクト固有の編み目設定が空のため、基本6つの編み目を使用します');
        _projectCustomStitches = StitchSettingsService.getDefaultStitches();
        print('基本編み目設定を使用: ${_projectCustomStitches?.length}個');
      }

      if (mounted) {
        setState(() {
          _stitchGridKey++; // キーを更新してウィジェットを強制的に再構築
        });
        print('✅ UI更新完了');

        // 少し待ってから再度更新（確実に反映させるため）
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          setState(() {});
          print('✅ 二重UI更新完了');
        }
      }
    } catch (e) {
      print('❌ 編み目設定再読み込みエラー: $e');
    }
  }

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

  void _addStitch(dynamic stitch) {
    try {
      setState(() {
        _stitchCount++;

        // stitchの型に応じて履歴に保存する情報を決定
        Map<String, dynamic> historyItem = {
          'row': _rowNumber,
          'position': _stitchCount,
          'timestamp': DateTime.now(),
        };

        if (stitch is CrochetStitch) {
          historyItem['stitch'] = stitch;
        } else if (stitch is CustomStitch) {
          // CustomStitchの場合は必要な情報をすべて保存
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
          // その他の型の場合はそのまま保存
          historyItem['stitch'] = stitch;
        }

        _stitchHistory.add(historyItem);
        _hasUnsavedChanges = true;
      });

      String stitchName = '';
      if (stitch is CrochetStitch) {
        stitchName = stitch.name;
      } else if (stitch is CustomStitch) {
        stitchName = stitch.name;
      } else {
        stitchName = stitch.toString();
      }

      _logger
          .i('addStitch: $stitchNameを追加しました。段: $_rowNumber, 位置: $_stitchCount');
    } catch (e, stackTrace) {
      _logger.e('関数名: _addStitch, '
          'パラメータ: stitch=$stitch, '
          '例外内容: $e, '
          'スタックトレース: $stackTrace');
    }
  }

  void _removeLastStitch() {
    try {
      if (_stitchCount > 0) {
        setState(() {
          _stitchCount--;
          if (_stitchHistory.isNotEmpty) {
            _stitchHistory.removeLast();
          }
          _hasUnsavedChanges = true;
        });
        _logger.i('removeLastStitch: 最後の編み目を削除しました。現在の値: $_stitchCount');
      }
    } catch (e, stackTrace) {
      _logger.e('関数名: _removeLastStitch, '
          'パラメータ: なし, '
          '例外内容: $e, '
          'スタックトレース: $stackTrace');
    }
  }

  void _completeRow() {
    try {
      if (_stitchCount > 0) {
        setState(() {
          _rowNumber++;
          _stitchCount = 0;
          // 段完成時に空の段を履歴に追加して表示
          _stitchHistory.add({
            'stitch': _selectedStitch,
            'row': _rowNumber,
            'position': 0, // 0は段開始を示す
            'timestamp': DateTime.now(),
            'isRowStart': true, // 段開始フラグ
          });
          _hasUnsavedChanges = true;
        });

        _logger.i('completeRow: 段を完成しました。新しい段: $_rowNumber');
      }
    } catch (e, stackTrace) {
      _logger.e('関数名: _completeRow, '
          'パラメータ: なし, '
          '例外内容: $e, '
          'スタックトレース: $stackTrace');
    }
  }

  void _resetAll() {
    try {
      setState(() {
        _stitchCount = 0;
        _rowNumber = 1;
        _stitchHistory.clear();
        _hasUnsavedChanges = true;
      });
      _logger.i('resetAll: すべてをリセットしました');
    } catch (e, stackTrace) {
      _logger.e('関数名: _resetAll, '
          'パラメータ: なし, '
          '例外内容: $e, '
          'スタックトレース: $stackTrace');
    }
  }

  void _removeRow(int rowNumber) {
    try {
      setState(() {
        // 指定された段の編み目をすべて削除
        _stitchHistory.removeWhere((stitch) => stitch['row'] == rowNumber);
        _stitchCount = _getCurrentStitchCount();
      });
      _hasUnsavedChanges = true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$rowNumber段目を削除しました'),
          backgroundColor: Colors.orange,
        ),
      );

      _logger.i('removeRow: $rowNumber段目を削除しました');
    } catch (e, stackTrace) {
      _logger.e('関数名: _removeRow, '
          'パラメータ: rowNumber=$rowNumber, '
          '例外内容: $e, '
          'スタックトレース: $stackTrace');
    }
  }

  void _showRewardedAdAndReset() {
    final isPremium = context.read<SubscriptionProvider>().isPremium;
    if (isPremium) {
      _resetAll();
      return;
    }

    // ユーザーに動画広告を見るかどうか確認
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('watch_ad_reset_title')),
        content: Text(tr('watch_ad_reset_message')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetAll(); // 動画広告なしでリセット
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

  // リセット用の報酬広告を表示するメソッド
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
          // 報酬を付与
        },
      );
    } else {
      _resetAll();
    }
  }

  Future<String?> _editProjectTitle() async {
    final TextEditingController controller =
        TextEditingController(text: _projectTitle);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('edit_stitch_buttons')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: tr('edit_stitch_buttons'),
            hintText: '例: マフラー', // TODO: 各言語追加可
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

    return result;
  }

  Future<bool> _saveProject() async {
    // タイトルがデフォルトの場合でも保存を許可（戻るボタンからの呼び出しの場合は既にタイトル編集済み）
    // 保存ボタンからの呼び出しの場合のみタイトル編集を促す
    if (_projectTitle == '新しい編みもの' || _projectTitle.isEmpty) {
      // 戻るボタンからの呼び出しの場合はタイトル編集をスキップ
      // 保存ボタンからの呼び出しの場合のみタイトル編集を促す
      // この部分は戻るボタンの処理で既に処理済みなので、ここでは何もしない
    }

    try {
      print('=== CrochetCounterScreen: プロジェクト保存開始 ===');

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
        customStitches:
            _projectCustomStitches ?? widget.project?.customStitches ?? [],
      );

      print(
          'プロジェクト作成完了: ${project.title}, ID: ${project.id}, 履歴数: ${project.stitchHistory.length}');
      print(
          'プロジェクト詳細: widget.project=${widget.project != null ? "存在" : "null"}');

      final isPremium = context.read<SubscriptionProvider>().isPremium;
      print('=== プレミアム状態確認 ===');
      print('保存時のプレミアム状態: $isPremium');
      print('保存するプロジェクト: ${project.title}, ID: ${project.id}');

      final success =
          await _storageService.saveProject(project, isPremium: isPremium);
      print('保存結果: $success');

      if (success) {
        setState(() {
          _hasUnsavedChanges = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('save') + ' ' + tr('ok')),
            backgroundColor: Colors.green,
          ),
        );
        return true;
      } else {
        if (!isPremium) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('save_limit_message')),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
    } catch (e) {
      print('保存エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('save') + ' ' + tr('premium_only_message')),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  // 保存成功後に動画広告を見るかどうかユーザーに確認するメソッド
  void _showRewardedAdAfterSave() {
    final isPremium = context.read<SubscriptionProvider>().isPremium;
    if (isPremium) {
      // プレミアムユーザーは動画広告を再生しない
      return;
    }

    // ユーザーに動画広告を見るかどうか確認
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

  // 報酬広告を表示するメソッド（ユーザーが選択した場合のみ）
  void _showRewardedAd() {
    if (_isRewardedAdLoaded && _rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadRewardedAd(); // 次の動画広告を読み込み
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadRewardedAd(); // 次の動画広告を読み込み
        },
      );
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          // 報酬を付与
          print('動画広告報酬を付与');
        },
      );
    } else {
      print('動画広告が読み込まれていません');
    }
  }

  Future<bool> _showSaveDialog() async {
    // 変更がない場合は直接戻る
    if (!_hasUnsavedChanges) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(tr('save')),
        content: Text(tr('save') + '?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(true);
              await _saveProject();
            },
            child: Text(tr('save')),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  int _getCurrentRow() {
    if (_stitchHistory.isEmpty) return 0;
    return _stitchHistory.last['row'] as int;
  }

  int _getCurrentStitchCount() {
    if (_stitchHistory.isEmpty) return 0;
    return _stitchHistory.where((stitch) => stitch['position'] != 0).length;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _showSaveDialog,
      child: Scaffold(
        backgroundColor: const Color(0xFFFCE4EC),
        appBar: AppBar(
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
            onPressed: () async {
              print('戻るボタンが押されました');
              // 変更がない場合は直接戻る
              if (!_hasUnsavedChanges) {
                print('変更なし、直接戻る');
                Navigator.of(context).pop();
                return;
              }

              print('変更あり、保存確認ダイアログを表示');
              // 変更がある場合は保存確認ダイアログを表示
              final result = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: const Text('変更を保存'),
                  content: const Text('変更を保存しますか？'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        print('保存しないを選択');
                        Navigator.of(context).pop(false);
                      },
                      child: const Text('保存しない'),
                    ),
                    TextButton(
                      onPressed: () {
                        print('保存を選択');
                        Navigator.of(context).pop(true);
                      },
                      child: const Text('保存'),
                    ),
                  ],
                ),
              );

              print('ダイアログ結果: $result');

              if (result == true) {
                print('保存処理開始');
                // 保存を選択した場合
                if (_projectTitle == '新しい編みもの' || _projectTitle.isEmpty) {
                  print('タイトル編集開始');
                  final titleResult = await _editProjectTitle();
                  if (titleResult == null) {
                    print('タイトル編集キャンセル');
                    return;
                  }
                  print('タイトル編集完了: $titleResult');
                }

                print('保存処理実行');
                final saveSuccess = await _saveProject();
                if (saveSuccess) {
                  print('保存成功、動画広告を再生してからホーム画面に遷移');
                  // 保存成功後に動画広告を再生
                  _showRewardedAdAfterSave();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const HomeScreen(),
                    ),
                    (route) => false,
                  );
                }
              } else if (result == false) {
                print('保存しない、直接戻る');
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () async {
                final result = await _saveProject();
                if (result) {
                  // 保存成功後に動画広告を再生
                  _showRewardedAdAfterSave();
                  // 保存成功後はリセットせず、成功メッセージのみ表示
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(tr('save') + ' ' + tr('ok')),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () async {
                // 現在のプロジェクト情報を保存
                final currentProject = widget.project;

                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(
                      // プロジェクト画面からの設定であることを示すフラグ
                      isFromProject: true,
                      currentProject: currentProject,
                    ),
                  ),
                );

                // 設定画面から戻った時に、編み目設定が変更された場合は再読み込み
                if (result == true) {
                  print('設定画面から戻りました。編み目設定を再読み込みします。');

                  // 少し待ってから再読み込み（保存処理の完了を待つ）
                  await Future.delayed(const Duration(milliseconds: 500));

                  // プロジェクトを再読み込み
                  if (currentProject != null) {
                    final updatedProjects = await _storageService.getProjects();
                    final updatedProject = updatedProjects.firstWhere(
                      (p) => p.id == currentProject.id,
                      orElse: () => currentProject,
                    );

                    // プロジェクトの編み目設定を更新
                    _projectCustomStitches = updatedProject.customStitches;
                    print(
                        '更新されたプロジェクトの編み目設定: ${_projectCustomStitches?.length}個');

                    // 編み目設定の詳細をログ出力
                    if (_projectCustomStitches != null) {
                      for (int i = 0; i < _projectCustomStitches!.length; i++) {
                        final stitch = _projectCustomStitches![i];
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
                    }
                  }

                  // UIを更新
                  if (mounted) {
                    setState(() {
                      _stitchGridKey++;
                    });

                    // 少し待ってから再度更新（確実に反映させるため）
                    await Future.delayed(const Duration(milliseconds: 200));
                    if (mounted) {
                      setState(() {});
                    }
                  }
                }
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 編み目履歴をトップに配置（面積をさらに調整）
              Expanded(
                flex: 1,
                child: StitchHistorySection(
                  stitchHistory: _stitchHistory,
                  currentStitches: _projectCustomStitches ??
                      widget.project?.customStitches ??
                      StitchSettingsService.getDefaultStitches(),
                  onRowTap: (rowNumber) {
                    // 履歴の段目がタップされた時の処理
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$rowNumber段目に移動しました'),
                        duration: const Duration(milliseconds: 500),
                        backgroundColor: const Color(0xFFAD1457),
                      ),
                    );
                  },
                  onRowCompleted: (rowNumber) {
                    // 段が完成した時の処理（ポップアップなし）
                  },
                  onStitchRemoved: (rowNumber) {
                    // 段が削除された時の処理
                    _removeRow(rowNumber);
                  },
                  currentRow: _getCurrentRow(),
                  currentStitchCount: _getCurrentStitchCount(),
                ),
              ),
              const SizedBox(height: 10),
              // 編み方を選択から下を固定配置
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    StitchPatternGrid(
                      key: ValueKey(
                          'stitch_pattern_grid_${_projectCustomStitches?.length ?? 0}_${_projectCustomStitches?.hashCode ?? 0}_$_stitchGridKey'),
                      selectedStitch: _selectedStitch,
                      onStitchSelected: (stitch) {
                        setState(() {
                          _selectedStitch = stitch;
                        });
                      },
                      onStitchAdded: _addStitch,
                      projectStitches: _projectCustomStitches ??
                          widget.project?.customStitches,
                      onStitchSettingsChanged: () async {
                        print('CrochetCounterScreen: 編み目設定が変更されました');

                        // プロジェクト固有の編み目設定を再読み込み
                        await _reloadProjectCustomStitches();

                        // 編み目設定が変更されたことを通知（緑のポップアップを防ぐため削除）
                        // ScaffoldMessenger.of(context).showSnackBar(
                        //   const SnackBar(
                        //     content: Text('編み目設定を更新しました'),
                        //     backgroundColor: Colors.green,
                        //   ),
                        // );
                      },
                      onProjectStitchesChanged: (newStitches) async {
                        print('CrochetCounterScreen: プロジェクト固有の編み目設定が変更されました');
                        print('新しい編み目数: ${newStitches.length}');
                        print('新しい編み目リスト:');
                        for (int i = 0; i < newStitches.length; i++) {
                          final stitch = newStitches[i];
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

                        // プロジェクト固有の編み目設定を更新
                        _projectCustomStitches = List.from(newStitches);

                        // プロジェクトが存在する場合は保存
                        if (widget.project != null) {
                          try {
                            // 既存のプロジェクトを更新
                            final updatedProject = widget.project!.copyWith(
                              customStitches: _projectCustomStitches,
                              updatedAt: DateTime.now(),
                            );
                            final isPremium =
                                context.read<SubscriptionProvider>().isPremium;
                            final success = await _storageService.saveProject(
                                updatedProject,
                                isPremium: isPremium);
                            if (success) {
                              print('✅ プロジェクト固有の編み目設定を保存しました');
                            } else {
                              print('❌ プロジェクト固有の編み目設定の保存に失敗しました');
                            }
                          } catch (e) {
                            print('❌ プロジェクト固有の編み目設定の保存に失敗しました: $e');
                          }
                        }

                        // UIを強制的に更新
                        if (mounted) {
                          setState(() {
                            _stitchGridKey++;
                          });

                          // 少し待ってから再度更新（確実に反映させるため）
                          await Future.delayed(
                              const Duration(milliseconds: 100));
                          if (mounted) {
                            setState(() {});
                          }

                          // さらに少し待ってから最終確認
                          await Future.delayed(
                              const Duration(milliseconds: 200));
                          if (mounted) {
                            setState(() {});
                            print('✅ 編み目設定変更後のUI更新完了');
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    ControlButtons(
                      onRemoveStitch: _removeLastStitch,
                      onCompleteRow: _completeRow,
                      onReset: _resetAll,
                      canRemoveStitch: _stitchCount > 0,
                      canCompleteRow: _stitchCount > 0,
                    ),
                  ],
                ),
              ),
              // バナー広告を一番下に固定配置（プレミアムでない場合のみ表示）
              if (!context.watch<SubscriptionProvider>().isPremium &&
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

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }
}
