import 'package:flutter/material.dart';
import 'stitch_customization_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        backgroundColor: const Color(0xFFEC407A),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            color: Colors.pink.shade50,
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'アップグレード（課金機能）',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.pink,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '・編み方ボタンを自由に編集できます\n・広告が永久に非表示になります',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('編み方ボタン編集'),
            subtitle: const Text('ボタンの並べ替え・削除・追加'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const StitchCustomizationScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('お問い合わせ'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('利用規約'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('プライバシーポリシー'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('言語設定'),
            onTap: () {},
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: const [
                Text(
                  'アプリバージョン',
                  style: TextStyle(color: Colors.grey),
                ),
                SizedBox(height: 4),
                Text(
                  'v1.0.0',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
