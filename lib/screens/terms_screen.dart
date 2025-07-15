import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

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
                '最終更新日：2024年12月',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
