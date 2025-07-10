import 'package:flutter/material.dart';

enum CrochetStitch {
  chain('鎖編み', 'assets/images/chain.png', Colors.blue, true),
  slipStitch('引き抜き編み', 'assets/images/slip_stitch.png', Colors.grey, true),
  singleCrochet('細編み', 'assets/images/single_crochet.png', Colors.green, false),
  halfDoubleCrochet(
      '中長編み', 'assets/images/half_double_crochet.png', Colors.orange, false),
  doubleCrochet(
      '長編み', 'assets/images/double_crochet.png', Colors.purple, false),
  trebleCrochet('長々編み', 'assets/images/treble_crochet.png', Colors.red, false),
  singleCrochetIncrease('細編み増やし目', null, Colors.teal, false),
  halfDoubleCrochetIncrease('中長編み増やし目', null, Colors.deepOrange, false),
  doubleCrochetIncrease('長編み増やし目', null, Colors.indigo, false),
  trebleCrochetIncrease('長々編み増やし目', null, Colors.brown, false);

  const CrochetStitch(this.name, this.imagePath, this.color, this.isOval);
  final String name;
  final String? imagePath;
  final Color color;
  final bool isOval;
}
