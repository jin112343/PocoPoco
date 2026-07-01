import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/crochet_project.dart';
import '../services/storage_service.dart';
import 'crochet_counter_screen.dart';
import 'settings_screen.dart';
import 'upgrade_screen.dart';
import '../services/subscription_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import '../services/pdf_export_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Logger logger = Logger();
  final StorageService _storageService = StorageService();
  List<CrochetProject> _projects = [];
  bool _isLoading = true;
  bool _isProcessing = false; // 非同期処理中フラグ
  bool _hasRequestedTracking = false;
  String? _documentsPath; // ドキュメントディレクトリのキャッシュ

  /// アイコン画像のフルパスを取得（相対パスとフルパスの両方に対応）
  String? _resolveIconImagePath(String? iconImagePath) {
    if (iconImagePath == null) return null;
    // 既にフルパスの場合はファイル存在チェック
    if (iconImagePath.startsWith('/')) {
      if (File(iconImagePath).existsSync()) return iconImagePath;
      // フルパスが無効な場合、ファイル名だけ取り出してドキュメントディレクトリで探す
      final fileName = iconImagePath.split('/').last;
      if (_documentsPath != null) {
        final resolvedPath = '$_documentsPath/$fileName';
        if (File(resolvedPath).existsSync()) return resolvedPath;
      }
      return null;
    }
    // 相対パス（ファイル名のみ）の場合
    if (_documentsPath != null) {
      return '$_documentsPath/$iconImagePath';
    }
    return null;
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

  @override
  void initState() {
    super.initState();
    _initDocumentsPath();
    _loadProjects();
    _showUpdateDialogIfNeeded();
  }

  Future<void> _initDocumentsPath() async {
    final directory = await getApplicationDocumentsDirectory();
    _documentsPath = directory.path;
    // パス取得前に描画されたアイコン画像を再解決するため再描画する
    if (mounted) {
      setState(() {});
    }
  }

  /// カメラ/アルバムから画像を選択してドキュメントディレクトリに保存し、
  /// 保存したファイル名を返す（キャンセル時はnull）
  Future<String?> _pickAndSaveIconImage(
      ImageSource source, String projectId) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image == null) return null;

    // アプリのドキュメントディレクトリに保存
    final directory = await getApplicationDocumentsDirectory();
    _documentsPath = directory.path;
    final fileName =
        'icon_${projectId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedPath = '${directory.path}/$fileName';
    // iOSの一時ファイルを確実に読み取るためにreadAsBytesを使用
    final bytes = await image.readAsBytes();
    await File(savedPath).writeAsBytes(bytes);
    // ファイル名のみ返す（iOSのサンドボックスパス変更対策）
    return fileName;
  }

  /// バージョンごとの更新内容（新バージョンのリリース時にここへ追記する）
  /// キーはpubspec.yamlのバージョン（ビルド番号を除く）と一致させること
  static const Map<String, List<String>> _releaseNotes = {
    '2.0.2': [
      '1. PDFで編み物を共有できる機能の修正',
      '2. カメラで撮ったものをアイコンにできるバグ修正',
      '3. 設定画面でお問い合わせを匿名化（改善案どしどしお待ちしております）',
      '4. iPadのボタン編集のバグ修正',
      '5. 立ち上がり編み目の追加',
    ],
  };

  /// 現在のバージョンの初回起動時にアップデート内容を表示
  Future<void> _showUpdateDialogIfNeeded() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version;
      final notes = _releaseNotes[version];
      // このバージョン向けの更新内容が定義されていなければ何もしない
      if (notes == null) return;

      final updateDialogKey = 'update_dialog_shown_$version';
      final prefs = await SharedPreferences.getInstance();
      final hasShown = prefs.getBool(updateDialogKey) ?? false;
      if (hasShown || !mounted) return;

      // ダイアログ表示前にフラグを保存（表示を確実に1回だけにする）
      await prefs.setBool(updateDialogKey, true);

      // 画面が描画されてからダイアログを表示
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(
              tr('version_update_title', namedArgs: {'version': version}),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final note in notes) ...[
                    Text(note, style: const TextStyle(fontSize: 14)),
                    if (note != notes.last) const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(tr('ok')),
              ),
            ],
          ),
        );
      });
    } catch (e) {
      logger.e('HomeScreen._showUpdateDialogIfNeeded: 更新ダイアログ表示エラー: $e');
    }
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final projects = await _storageService.getProjects();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    } catch (e) {
      logger.e('HomeScreen._loadProjects: プロジェクト読み込みエラー: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showDialog(tr('projects_load_failed'));
    }
  }

  Future<void> _requestTrackingPermission() async {
    if (_hasRequestedTracking) return; // 既に要求済みの場合はスキップ

    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        _hasRequestedTracking = true; // UIに影響しないためsetState不要
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e, stackTrace) {
      logger.e('HomeScreen._requestTrackingPermission: ATT許可リクエストエラー', error: e, stackTrace: stackTrace);
    }
  }

  void _createNewProject() {
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final isPremium = subscriptionProvider.isPremium;
    final isInTrial = subscriptionProvider.isInTrialPeriod && subscriptionProvider.isTrialActive;

    logger.i('HomeScreen._createNewProject: 新規プロジェクト作成 - isPremium: $isPremium, isInTrial: $isInTrial, projectsCount: ${_projects.length}');

    // 新規プロジェクト作成時にATT許可を要求
    _requestTrackingPermission();

    // 無料プラン制限チェック
    // 注意: トライアル期間中はisPremiumがtrueになるため、制限は適用されません
    if (!isPremium && _projects.length >= 3) {
      logger.w('HomeScreen._createNewProject: 保存制限に達しました（無料プラン） - トライアル期間外');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('save_limit_reached')),
          content: Text(tr('save_limit_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('cancel')),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const UpgradeScreen(),
                  ),
                );
              },
              child: Text(tr('upgrade')),
            ),
          ],
        ),
      );
      return;
    }

    logger.i('HomeScreen._createNewProject: 新規プロジェクト作成画面を開きます');
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => const CrochetCounterScreen(),
      ),
    )
        .then((_) {
      // 画面が戻ってきたらプロジェクト一覧を再読み込み
      _loadProjects();
    });
  }

  void _openProject(CrochetProject project) {
    // 既存プロジェクトを開く時にATT許可を要求
    _requestTrackingPermission();
    
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => CrochetCounterScreen(project: project),
      ),
    )
        .then((_) {
      // 画面が戻ってきたらプロジェクト一覧を再読み込み
      _loadProjects();
    });
  }

  void _editProject(CrochetProject project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('edit_project')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(tr('edit_title')),
              onTap: () {
                Navigator.of(context).pop();
                _editProjectTitle(project);
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette),
              title: Text(tr('edit_icon_and_color')),
              onTap: () {
                Navigator.of(context).pop();
                _editProjectIconAndColor(project);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: Text(tr('share_pdf')),
              onTap: () async {
                Navigator.of(context).pop();
                await _exportProjectToPdf(project);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: Text(tr('delete_list')),
              onTap: () {
                Navigator.of(context).pop();
                _deleteProject(project);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('cancel')),
          ),
        ],
      ),
    );
  }

  void _editProjectTitle(CrochetProject project) {
    final TextEditingController controller =
        TextEditingController(text: project.title);
    final subscriptionProvider = context.read<SubscriptionProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('edit_project_name')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: tr('project_name'),
            hintText: tr('project_title_hint'),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty && newTitle != project.title) {
                Navigator.of(dialogContext).pop();

                // プロジェクトを更新
                final updatedProject = project.copyWith(
                  title: newTitle,
                  updatedAt: DateTime.now(),
                );

                final isPremium = subscriptionProvider.isPremium;
                final success = await _storageService
                    .saveProject(updatedProject, isPremium: isPremium);
                if (success) {
                  _loadProjects();
                  if (mounted) {
                    _showDialog(tr('project_name_updated'));
                  }
                } else {
                  if (mounted) {
                    _showDialog(tr('project_name_update_failed'));
                  }
                }
              }
            },
            child: Text(tr('save')),
          ),
        ],
      ),
    );
  }

  void _editProjectIconAndColor(CrochetProject project) {
    final List<Map<String, dynamic>> availableIcons = [
      {'name': 'work', 'icon': Icons.work, 'label': '作業'},
      {'name': 'favorite', 'icon': Icons.favorite, 'label': 'お気に入り'},
      {'name': 'star', 'icon': Icons.star, 'label': '星'},
      {'name': 'home', 'icon': Icons.home, 'label': 'ホーム'},
      {'name': 'person', 'icon': Icons.person, 'label': '人物'},
      {'name': 'pets', 'icon': Icons.pets, 'label': 'ペット'},
      {'name': 'cake', 'icon': Icons.cake, 'label': 'ケーキ'},
      {'name': 'local_florist', 'icon': Icons.local_florist, 'label': '花'},
      {'name': 'music_note', 'icon': Icons.music_note, 'label': '音楽'},
      {'name': 'sports_esports', 'icon': Icons.sports_esports, 'label': 'ゲーム'},
      {'name': 'sports_soccer', 'icon': Icons.sports_soccer, 'label': 'サッカー'},
      {
        'name': 'sports_basketball',
        'icon': Icons.sports_basketball,
        'label': 'バスケ'
      },
      {'name': 'emoji_emotions', 'icon': Icons.emoji_emotions, 'label': '笑顔'},
      {'name': 'celebration', 'icon': Icons.celebration, 'label': 'お祝い'},
      {'name': 'beach_access', 'icon': Icons.beach_access, 'label': 'ビーチ'},
      {'name': 'park', 'icon': Icons.park, 'label': '公園'},
    ];

    final List<Map<String, dynamic>> availableColors = [
      {'name': '0xFFAD1457', 'color': const Color(0xFFAD1457), 'label': 'ピンク'},
      {'name': '0xFF2196F3', 'color': const Color(0xFF2196F3), 'label': '青'},
      {'name': '0xFF4CAF50', 'color': const Color(0xFF4CAF50), 'label': '緑'},
      {'name': '0xFFFF9800', 'color': const Color(0xFFFF9800), 'label': 'オレンジ'},
      {'name': '0xFF9C27B0', 'color': const Color(0xFF9C27B0), 'label': '紫'},
      {'name': '0xFFF44336', 'color': const Color(0xFFF44336), 'label': '赤'},
      {'name': '0xFF607D8B', 'color': const Color(0xFF607D8B), 'label': 'グレー'},
      {'name': '0xFF795548', 'color': const Color(0xFF795548), 'label': '茶色'},
      {'name': '0xFF00BCD4', 'color': const Color(0xFF00BCD4), 'label': '水色'},
      {'name': '0xFFFFEB3B', 'color': const Color(0xFFFFEB3B), 'label': '黄色'},
      {'name': '0xFFE91E63', 'color': const Color(0xFFE91E63), 'label': 'ピンク'},
      {
        'name': '0xFF3F51B5',
        'color': const Color(0xFF3F51B5),
        'label': 'インディゴ'
      },
    ];

    final List<Map<String, dynamic>> availableBackgroundColors = [
      {
        'name': '0xFFF8BBD9',
        'color': const Color(0xFFF8BBD9),
        'label': '薄いピンク'
      },
      {'name': '0xFFE3F2FD', 'color': const Color(0xFFE3F2FD), 'label': '薄い青'},
      {'name': '0xFFE8F5E8', 'color': const Color(0xFFE8F5E8), 'label': '薄い緑'},
      {
        'name': '0xFFFFF3E0',
        'color': const Color(0xFFFFF3E0),
        'label': '薄いオレンジ'
      },
      {'name': '0xFFF3E5F5', 'color': const Color(0xFFF3E5F5), 'label': '薄い紫'},
      {'name': '0xFFFFEBEE', 'color': const Color(0xFFFFEBEE), 'label': '薄い赤'},
      {
        'name': '0xFFF5F5F5',
        'color': const Color(0xFFF5F5F5),
        'label': '薄いグレー'
      },
      {'name': '0xFFEFEBE9', 'color': const Color(0xFFEFEBE9), 'label': '薄い茶色'},
      {'name': '0xFFE0F2F1', 'color': const Color(0xFFE0F2F1), 'label': '薄い水色'},
      {'name': '0xFFFFFDE7', 'color': const Color(0xFFFFFDE7), 'label': '薄い黄色'},
      {'name': '0xFFFCE4EC', 'color': const Color(0xFFFCE4EC), 'label': 'ピンク'},
      {
        'name': '0xFFE8EAF6',
        'color': const Color(0xFFE8EAF6),
        'label': '薄いインディゴ'
      },
    ];

    String selectedIconName = project.iconName;
    String selectedIconColor = project.iconColor;
    String selectedBackgroundColor = project.backgroundColor;
    String? selectedImagePath = project.iconImagePath;

    final subscriptionProvider = context.read<SubscriptionProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          final isDarkMode = Theme.of(dialogContext).brightness == Brightness.dark;
          return AlertDialog(
          title: Text(tr('edit_icon_and_color'),
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // プレビュー
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF3D3D3D) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Builder(builder: (context) {
                          final resolvedPath = _resolveIconImagePath(selectedImagePath);
                          return Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: resolvedPath != null
                                  ? Colors.transparent
                                  : _getBackgroundColor(selectedBackgroundColor),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: resolvedPath != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(25),
                                    child: Image.file(
                                      File(resolvedPath),
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Icon(
                                    _getIconData(selectedIconName),
                                    color: _getIconColor(selectedIconColor),
                                    size: 24,
                                  ),
                          );
                        }),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            project.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 写真選択セクション
                  Text(tr('choose_from_photo'),
                      style: TextStyle(fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // カメラから撮影
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final fileName = await _pickAndSaveIconImage(
                                ImageSource.camera, project.id);
                            // 撮影中にダイアログが閉じられた場合に備えてmountedを確認
                            if (fileName != null && dialogContext.mounted) {
                              setState(() {
                                selectedImagePath = fileName;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDarkMode ? const Color(0xFF3D3D3D) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.camera_alt, size: 32,
                                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600),
                                const SizedBox(height: 4),
                                Text(tr('camera'), style: TextStyle(fontSize: 12,
                                    color: isDarkMode ? Colors.grey.shade300 : null)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // アルバムから選択
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final fileName = await _pickAndSaveIconImage(
                                ImageSource.gallery, project.id);
                            // 選択中にダイアログが閉じられた場合に備えてmountedを確認
                            if (fileName != null && dialogContext.mounted) {
                              setState(() {
                                selectedImagePath = fileName;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDarkMode ? const Color(0xFF3D3D3D) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.photo_library, size: 32,
                                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600),
                                const SizedBox(height: 4),
                                Text(tr('album'), style: TextStyle(fontSize: 12,
                                    color: isDarkMode ? Colors.grey.shade300 : null)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 写真をクリア
                      Expanded(
                        child: InkWell(
                          onTap: selectedImagePath != null ? () {
                            setState(() {
                              selectedImagePath = null;
                            });
                          } : null,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: selectedImagePath != null
                                  ? (isDarkMode ? Colors.red.shade900 : Colors.red.shade50)
                                  : (isDarkMode ? const Color(0xFF3D3D3D) : Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.clear,
                                  size: 32,
                                  color: selectedImagePath != null
                                      ? Colors.red
                                      : (isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tr('clear'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: selectedImagePath != null
                                        ? Colors.red
                                        : (isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // アイコン選択
                  Text(tr('icon'),
                      style: TextStyle(fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: availableIcons.length,
                      itemBuilder: (context, index) {
                        final iconData = availableIcons[index];
                        final isSelected = iconData['name'] == selectedIconName;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              selectedIconName = iconData['name'];
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDarkMode ? const Color(0xFF880E4F) : const Color(0xFFF8BBD9))
                                  : (isDarkMode ? const Color(0xFF3D3D3D) : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(
                                      color: const Color(0xFFAD1457), width: 3)
                                  : null,
                            ),
                            child: Icon(
                              iconData['icon'],
                              color: isSelected
                                  ? (isDarkMode ? Colors.pink.shade200 : const Color(0xFFAD1457))
                                  : (isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600),
                              size: 32,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // アイコンの色選択
                  Text(tr('icon_color'),
                      style: TextStyle(fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 160,
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: availableColors.length,
                      itemBuilder: (context, index) {
                        final colorData = availableColors[index];
                        final isSelected =
                            colorData['name'] == selectedIconColor;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              selectedIconColor = colorData['name'];
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: colorData['color'],
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(color: isDarkMode ? Colors.white : Colors.black, width: 3)
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 背景色選択
                  Text(tr('background_color'),
                      style: TextStyle(fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 160,
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: availableBackgroundColors.length,
                      itemBuilder: (context, index) {
                        final colorData = availableBackgroundColors[index];
                        final isSelected =
                            colorData['name'] == selectedBackgroundColor;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              selectedBackgroundColor = colorData['name'];
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: colorData['color'],
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(color: isDarkMode ? Colors.white : Colors.black, width: 3)
                                  : Border.all(
                                      color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300, width: 1),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(tr('cancel')),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                // プロジェクトを更新
                final updatedProject = project.copyWith(
                  iconName: selectedIconName,
                  iconColor: selectedIconColor,
                  backgroundColor: selectedBackgroundColor,
                  iconImagePath: selectedImagePath,
                  clearIconImagePath: selectedImagePath == null,
                  updatedAt: DateTime.now(),
                );

                final isPremium = subscriptionProvider.isPremium;
                final success = await _storageService
                    .saveProject(updatedProject, isPremium: isPremium);
                if (success) {
                  _loadProjects();
                  if (mounted) {
                    _showDialog(tr('icon_color_updated'));
                  }
                } else {
                  if (mounted) {
                    _showDialog(tr('icon_color_update_failed'));
                  }
                }
              },
              child: Text(tr('save')),
            ),
          ],
        );
        },
      ),
    );
  }

  Color _getBackgroundColor(String colorString) {
    try {
      return Color(int.parse(colorString));
    } catch (e) {
      return const Color(0xFFF8BBD9); // デフォルト背景色
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'favorite':
        return Icons.favorite;
      case 'star':
        return Icons.star;
      case 'home':
        return Icons.home;
      case 'person':
        return Icons.person;
      case 'pets':
        return Icons.pets;
      case 'cake':
        return Icons.cake;
      case 'local_florist':
        return Icons.local_florist;
      case 'music_note':
        return Icons.music_note;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'sports_soccer':
        return Icons.sports_soccer;
      case 'sports_basketball':
        return Icons.sports_basketball;
      case 'emoji_emotions':
        return Icons.emoji_emotions;
      case 'celebration':
        return Icons.celebration;
      case 'beach_access':
        return Icons.beach_access;
      case 'park':
        return Icons.park;
      default:
        return Icons.work;
    }
  }

  Color _getIconColor(String colorString) {
    try {
      return Color(int.parse(colorString));
    } catch (e) {
      return const Color(0xFFAD1457); // デフォルト色
    }
  }

  Future<void> _exportProjectToPdf(CrochetProject project) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await PdfExportService.exportAndShare(project, context);
    } catch (e) {
      logger.e('PDF出力エラー: $e');
      if (mounted) {
        _showDialog(tr('pdf_export_failed', namedArgs: {'error': '$e'}));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _deleteProject(CrochetProject project) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('delete_project_title')),
        content: Text(tr('delete_project_message', namedArgs: {'title': project.title})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();

              setState(() {
                _isProcessing = true;
              });

              try {
                final success = await _storageService.deleteProject(project.id);
                if (success) {
                  _loadProjects();
                  if (mounted) {
                    _showDialog(tr('project_deleted'));
                  }
                } else {
                  if (mounted) {
                    _showDialog(tr('project_delete_failed'));
                  }
                }
              } catch (e) {
                logger.e('削除エラー: $e');
                if (mounted) {
                  _showDialog(tr('project_delete_failed'));
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _isProcessing = false;
                  });
                }
              }
            },
            child: Text(tr('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Scaffold(
      appBar: AppBar(
        title: Text(
          tr('app_title'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFEC407A),
              ),
            )
          : _projects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 80,
                        color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        tr('no_projects'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr('create_new_project'),
                        style: TextStyle(
                          fontSize: 16,
                          color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProjects,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _projects.length,
                    itemBuilder: (context, index) {
                      final project = _projects[index];

                      return Dismissible(
                        key: Key(project.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
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
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(tr('delete_project_title')),
                              content: Text(tr('delete_project_confirm',
                                  namedArgs: {'title': project.title})),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: Text(tr('cancel')),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: Text(tr('delete'),
                                      style: const TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) async {
                          // Dismiss済みウィジェットをツリーに残さないよう、
                          // 先に同期的にリストから削除する（残すとFlutterのアサーションでクラッシュ）
                          setState(() {
                            _projects.removeWhere((p) => p.id == project.id);
                            _isProcessing = true;
                          });

                          try {
                            final success =
                                await _storageService.deleteProject(project.id);
                            if (success) {
                              if (mounted) {
                                _showDialog(tr('project_deleted'));
                              }
                            } else {
                              // 削除に失敗した場合は一覧を再読み込みして復元
                              await _loadProjects();
                              if (mounted) {
                                _showDialog(tr('project_delete_failed'));
                              }
                            }
                          } catch (e) {
                            logger.e('削除エラー: $e');
                            await _loadProjects();
                            if (mounted) {
                              _showDialog(tr('project_delete_failed'));
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isProcessing = false;
                              });
                            }
                          }
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Builder(builder: (context) {
                              final resolvedPath = _resolveIconImagePath(project.iconImagePath);
                              return Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: resolvedPath != null
                                    ? Colors.transparent
                                    : _getBackgroundColor(project.backgroundColor),
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: resolvedPath != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(25),
                                      child: Image.file(
                                        File(resolvedPath),
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(
                                            _getIconData(project.iconName),
                                            color: _getIconColor(project.iconColor),
                                            size: 24,
                                          );
                                        },
                                      ),
                                    )
                                  : Icon(
                                      _getIconData(project.iconName),
                                      color: _getIconColor(project.iconColor),
                                      size: 24,
                                    ),
                              );
                            }),
                            title: Text(
                              project.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  tr('created_date', namedArgs: {
                                    'date':
                                        '${_formatDate(project.createdAt)} ${_formatTime(project.createdAt)}'
                                  }),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                                if (project.updatedAt != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    tr('updated_date', namedArgs: {
                                      'date':
                                          '${_formatDate(project.updatedAt!)} ${_formatTime(project.updatedAt!)}'
                                    }),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  tr('row_stitch_status', namedArgs: {
                                    'row': '${project.currentRow}',
                                    'count': '${project.currentStitchCount}',
                                  }),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editProject(project);
                                }
                              },
                              itemBuilder: (context) {
                                final isDark = Theme.of(context).brightness == Brightness.dark;
                                final iconColor = isDark ? Colors.white : Colors.black;
                                return [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, color: iconColor),
                                        const SizedBox(width: 8),
                                        Text(tr('edit'),
                                            style: TextStyle(color: iconColor)),
                                      ],
                                    ),
                                  ),
                                ];
                              },
                            ),
                            onTap: () => _openProject(project),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewProject,
        backgroundColor: const Color(0xFFEC407A),
        child: const Icon(Icons.add, color: Colors.white),
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
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: Color(0xFFEC407A),
                        strokeWidth: 4,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        tr('processing'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? Colors.white
                              : const Color(0xFF333333),
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
}
