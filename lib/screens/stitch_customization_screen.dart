import 'package:flutter/material.dart';
import '../models/crochet_stitch.dart';

class StitchCustomizationScreen extends StatefulWidget {
  const StitchCustomizationScreen({super.key});

  @override
  State<StitchCustomizationScreen> createState() =>
      _StitchCustomizationScreenState();
}

class _StitchCustomizationScreenState extends State<StitchCustomizationScreen> {
  List<CrochetStitch> _stitches = [
    CrochetStitch.chain,
    CrochetStitch.slipStitch,
    CrochetStitch.singleCrochet,
    CrochetStitch.halfDoubleCrochet,
    CrochetStitch.doubleCrochet,
    CrochetStitch.trebleCrochet,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('編み方ボタン編集'),
        backgroundColor: const Color(0xFFEC407A),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddStitchDialog,
          ),
        ],
      ),
      body: ReorderableListView.builder(
        itemCount: _stitches.length,
        itemBuilder: (context, index) {
          final stitch = _stitches[index];
          return Card(
            key: ValueKey(stitch),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                          stitch.name,
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
              title: Text(stitch.name),
              subtitle: Text(stitch.name),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeStitch(index),
              ),
            ),
          );
        },
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (oldIndex < newIndex) {
              newIndex -= 1;
            }
            final item = _stitches.removeAt(oldIndex);
            _stitches.insert(newIndex, item);
          });
        },
      ),
    );
  }

  void _removeStitch(int index) {
    setState(() {
      _stitches.removeAt(index);
    });
  }

  void _showAddStitchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('編み記号を追加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: '編み方の名前',
                hintText: '例: 長々編み',
              ),
              onChanged: (value) {
                // TODO: 名前の保存
              },
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: '記号',
                hintText: '例: ∧',
              ),
              onChanged: (value) {
                // TODO: 記号の保存
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: カスタム編み記号の追加
              Navigator.of(context).pop();
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }
}
