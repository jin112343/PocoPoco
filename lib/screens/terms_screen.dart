import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('terms')),
        backgroundColor: Color(0xFFEC407A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('terms'),
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                '利用規約（EULA）\n\n'
                'このアプリをご利用いただく前に、以下の利用規約をよくお読みください。\n\n'
                '1. 利用条件\n'
                '・本アプリは個人利用を目的としています。\n'
                '・商用利用は禁止されています。\n'
                '・著作権は開発者に帰属します。\n\n'
                '2. サブスクリプション\n'
                '・月額プラン：300円/月（自動更新）\n'
                '・年間プラン：3000円/年（自動更新、月額250円相当）\n'
                '・サブスクリプションはApp Storeの設定からキャンセルできます。\n'
                '・キャンセルしない限り、自動的に更新されます。\n\n'
                '3. 免責事項\n'
                '・本アプリの利用によるいかなる損害も開発者は責任を負いません。\n'
                '・アプリの機能は予告なく変更される場合があります。\n\n'
                '4. プライバシー\n'
                '・個人情報の収集は行いません。\n'
                '・広告表示や分析のために一部データが外部サービスに送信される場合があります。\n\n'
                '5. 準拠法\n'
                '・本規約は日本法に準拠します。\n\n'
                'ご利用をもって本規約に同意したものとみなします。\n\n'
                '最終更新日：2025年7月19日\n\n'
                '---\n'
                'App Store Connect要件対応情報：\n'
                '・サブスクリプションタイトル：プレミアムプラン\n'
                '・サブスクリプション期間：月額または年間\n'
                '・サブスクリプション価格：月額300円、年間3000円\n'
                '・利用規約への機能的なリンク：アプリ内に実装済み\n'
                '・プライバシーポリシーへの機能的なリンク：アプリ内に実装済み',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 24),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final Uri url = Uri.parse('https://jinpost.wordpress.com/2025/07/13/%e5%88%a9%e7%94%a8%e8%a6%8f%e7%b4%84-%e7%b7%a8%e3%81%bf%e7%89%a9%e3%82%ab%e3%82%a6%e3%83%b3%e3%82%bf%e3%83%bcpocopoco/');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('リンクを開けませんでした')),
                      );
                    }
                  },
                  icon: Icon(Icons.open_in_new),
                  label: Text('Web版利用規約を開く'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFEC407A),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
