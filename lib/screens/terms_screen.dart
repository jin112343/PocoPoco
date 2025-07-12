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
                'このアプリをご利用いただく前に、以下の利用規約をよくお読みください。\n\n・本アプリは個人利用を目的としています。\n・著作権は開発者に帰属します。\n・本アプリの利用によるいかなる損害も開発者は責任を負いません。\n・内容は予告なく変更される場合があります。\n\nご利用をもって本規約に同意したものとみなします。',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
