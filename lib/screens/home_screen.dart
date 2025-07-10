import 'package:flutter/material.dart';
import '../models/crochet_project.dart';
import '../services/storage_service.dart';
import 'crochet_counter_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storageService = StorageService();
  List<CrochetProject> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final projects = await _storageService.getProjects();
      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('プロジェクトの読み込みに失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _createNewProject() {
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
        title: const Text('編みものを編集'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('タイトルを編集'),
              onTap: () {
                Navigator.of(context).pop();
                _editProjectTitle(project);
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('アイコンと色を編集'),
              onTap: () {
                Navigator.of(context).pop();
                _editProjectIconAndColor(project);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('リストの削除'),
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
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }

  void _editProjectTitle(CrochetProject project) {
    final TextEditingController controller =
        TextEditingController(text: project.title);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('編みもの名を編集'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '編みもの名',
            hintText: '例: マフラー',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty && newTitle != project.title) {
                Navigator.of(context).pop();

                // プロジェクトを更新
                final updatedProject = project.copyWith(
                  title: newTitle,
                  updatedAt: DateTime.now(),
                );

                final success =
                    await _storageService.saveProject(updatedProject);
                if (success) {
                  _loadProjects();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('編みもの名を更新しました'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('編みもの名の更新に失敗しました'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('保存'),
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

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('アイコンと色を編集'),
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
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _getBackgroundColor(selectedBackgroundColor),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Icon(
                            _getIconData(selectedIconName),
                            color: _getIconColor(selectedIconColor),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            project.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // アイコン選択
                  const Text('アイコン',
                      style: TextStyle(fontWeight: FontWeight.bold)),
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
                                  ? const Color(0xFFF8BBD9)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(
                                      color: const Color(0xFFAD1457), width: 3)
                                  : null,
                            ),
                            child: Icon(
                              iconData['icon'],
                              color: isSelected
                                  ? const Color(0xFFAD1457)
                                  : Colors.grey.shade600,
                              size: 32,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // アイコンの色選択
                  const Text('アイコンの色',
                      style: TextStyle(fontWeight: FontWeight.bold)),
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
                                  ? Border.all(color: Colors.black, width: 3)
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 背景色選択
                  const Text('背景色',
                      style: TextStyle(fontWeight: FontWeight.bold)),
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
                                  ? Border.all(color: Colors.black, width: 3)
                                  : Border.all(
                                      color: Colors.grey.shade300, width: 1),
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();

                // プロジェクトを更新
                final updatedProject = project.copyWith(
                  iconName: selectedIconName,
                  iconColor: selectedIconColor,
                  backgroundColor: selectedBackgroundColor,
                  updatedAt: DateTime.now(),
                );

                final success =
                    await _storageService.saveProject(updatedProject);
                if (success) {
                  _loadProjects();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('アイコンと色を更新しました'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('アイコンと色の更新に失敗しました'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
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

  void _deleteProject(CrochetProject project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('編みものを削除'),
        content: Text('「${project.title}」を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await _storageService.deleteProject(project.id);
              if (success) {
                _loadProjects();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('編みものを削除しました'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('編みものの削除に失敗しました'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('削除', style: TextStyle(color: Colors.red)),
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
    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC),
      appBar: AppBar(
        title: const Text(
          'かぎ針編みカウンター',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFEC407A),
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
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'プロジェクトがありません',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '新しい編みものを作成して\n編み物を始めましょう',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade500,
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
                      final lastModified =
                          project.updatedAt ?? project.createdAt;

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
                              title: const Text('編みものを削除'),
                              content: Text('「${project.title}」を削除しますか？'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('キャンセル'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('削除',
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) async {
                          final success =
                              await _storageService.deleteProject(project.id);
                          if (success) {
                            _loadProjects();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('編みものを削除しました'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('編みものの削除に失敗しました'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: _getBackgroundColor(
                                    project.backgroundColor),
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Icon(
                                _getIconData(project.iconName),
                                color: _getIconColor(project.iconColor),
                                size: 24,
                              ),
                            ),
                            title: Text(
                              project.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  '作成日: ${_formatDate(project.createdAt)} ${_formatTime(project.createdAt)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                if (project.updatedAt != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '更新日: ${_formatDate(project.updatedAt!)} ${_formatTime(project.updatedAt!)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  '${project.currentRow}段目 ${project.currentStitchCount}目',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) {
                                if (value == 'delete') {
                                  _editProject(project);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text('編集',
                                          style: TextStyle(color: Colors.blue)),
                                    ],
                                  ),
                                ),
                              ],
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
    );
  }
}
