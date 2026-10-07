/// プレミアムで追加できる編み目の一覧（追加画面に並ぶ順）。
///
/// 画像は assets/images にあり、新しい記号は tool/generate_stitch_images.py で生成する。
/// 作品データは編み目を日本語名（nameJa）で識別しているので、nameJa は変更・重複させないこと。
const List<Map<String, String>> premiumStitchCatalog = [
  {
    'nameJa': 'うね編み',
    'nameEn': 'Wave Stitch',
    'image': 'assets/images/うね編み.png',
  },
  {
    'nameJa': 'ねじれ細編み目',
    'nameEn': 'Twisted Single Crochet',
    'image': 'assets/images/twisted_single_crochet.png',
  },
  {
    'nameJa': '長編み１目交差',
    'nameEn': 'Double Crochet Cross',
    'image': 'assets/images/長編み１目交差.png',
  },
  {
    'nameJa': 'バック細編み',
    'nameEn': 'Back Single Crochet',
    'image': 'assets/images/back_single_crochet.png',
  },
  {
    'nameJa': '四つ巻き長編み目',
    'nameEn': 'Quadruple Crochet',
    'image': 'assets/images/四つ巻き長編み目.png',
  },
  {
    'nameJa': '三つ巻き長編み目',
    'nameEn': 'Triple Crochet',
    'image': 'assets/images/三つ巻き長編み目.png',
  },
  {
    'nameJa': '中長編み１目交差',
    'nameEn': 'Half Double Crochet Cross',
    'image': 'assets/images/中長編み１目交差.png',
  },
  {
    'nameJa': '長編み３目の玉編み目',
    'nameEn': 'Double Crochet 3 Bobble',
    'image': 'assets/images/長編み３目の玉編み目.png',
  },
  {
    'nameJa': '長編み１目左上３目交差',
    'nameEn': 'Double Crochet Left Cross 3',
    'image': 'assets/images/長編み１目左上３目交差.png',
  },
  {
    'nameJa': '長編み１目右上交差',
    'nameEn': 'Double Crochet Right Cross',
    'image': 'assets/images/長編み１目右上交差.png',
  },
  {
    'nameJa': '長編み１目右上３目交差',
    'nameEn': 'Double Crochet Right Cross 3',
    'image': 'assets/images/長編み１目右上３目交差.png',
  },
  {
    'nameJa': '中長編み３目の玉編み目',
    'nameEn': 'Half Double Crochet 3 Bobble',
    'image': 'assets/images/中長編み３目の玉編み目.png',
  },
  {
    'nameJa': '長々編み５目の玉編み目',
    'nameEn': 'Treble Crochet 5 Bobble',
    'image': 'assets/images/長々編み５目の玉編み目.png',
  },
  {
    'nameJa': '変わり玉編み目＜中長編み3目＞',
    'nameEn': 'Special Bobble Half Double Crochet 3',
    'image': 'assets/images/変わり玉編み目＜中長編み3目＞.png',
  },
  {
    'nameJa': '変わり玉編み目＜長編み3目＞',
    'nameEn': 'Special Bobble Double Crochet 3',
    'image': 'assets/images/変わり玉編み目＜長編み3目＞.png',
  },
  {
    'nameJa': '引き出し玉編み目',
    'nameEn': 'Popcorn Stitch',
    'image': 'assets/images/引き出し玉編み目.png',
  },
  {
    'nameJa': '細こま編み２目編み入れる',
    'nameEn': 'Single Crochet 2 Increase',
    'image': 'assets/images/細こま編み２目編み入れる.png',
  },
  {
    'nameJa': '中長編み５目のパプコーン編み',
    'nameEn': 'Half Double Crochet 5 Popcorn',
    'image': 'assets/images/hdc_5_popcorn.png',
  },
  {
    'nameJa': '長編み５目のパプコーン編み',
    'nameEn': 'Double Crochet 5 Popcorn',
    'image': 'assets/images/dc_5_popcorn.png',
  },
  {
    'nameJa': '長々編み６目のパプコーン編み目',
    'nameEn': 'Treble Crochet 6 Popcorn',
    'image': 'assets/images/tc_6_popcorn.png',
  },
  {
    'nameJa': '細こま編み3目編み入れる',
    'nameEn': 'Single Crochet 3 Increase',
    'image': 'assets/images/細こま編み3目編み入れる.png',
  },
  {
    'nameJa': '長編み3目編み入れる',
    'nameEn': 'Double Crochet 3 Increase',
    'image': 'assets/images/長編み3目編み入れる.png',
  },
  {
    'nameJa': '中長編み2目編み入れる',
    'nameEn': 'Half Double Crochet 2 Increase',
    'image': 'assets/images/中長編み2目編み入れる.png',
  },
  {
    'nameJa': '細こま編み２目一度',
    'nameEn': 'Single Crochet 2 Together',
    'image': 'assets/images/細こま編み２目一度.png',
  },
  {
    'nameJa': '中長編み3目編み入れる',
    'nameEn': 'Half Double Crochet 3 Increase',
    'image': 'assets/images/中長編み3目編み入れる.png',
  },
  {
    'nameJa': '長編み２目編み入れる',
    'nameEn': 'Double Crochet 2 Increase',
    'image': 'assets/images/長編み２目編み入れる.png',
  },
  {
    'nameJa': '中長編み2目一度',
    'nameEn': 'Half Double Crochet 2 Together',
    'image': 'assets/images/中長編み2目一度.png',
  },
  {
    'nameJa': '細こま編み3目一度',
    'nameEn': 'Single Crochet 3 Together',
    'image': 'assets/images/細こま編み3目一度.png',
  },
  {
    'nameJa': '中長編み３目一度',
    'nameEn': 'Half Double Crochet 3 Together',
    'image': 'assets/images/中長編み３目一度.png',
  },
  {
    'nameJa': '長編み２目一度',
    'nameEn': 'Double Crochet 2 Together',
    'image': 'assets/images/長編み２目一度.png',
  },
  {
    'nameJa': '長編み3目一度',
    'nameEn': 'Double Crochet 3 Together',
    'image': 'assets/images/長編み3目一度.png',
  },
  {
    'nameJa': '細編み2目編み入れる',
    'nameEn': 'Single Crochet 2 Increase',
    'image': 'assets/images/細編み2目編み入れる.png',
  },
  {
    'nameJa': '細編み2目一度',
    'nameEn': 'Single Crochet 2 Together',
    'image': 'assets/images/細編み2目一度.png',
  },
  {
    'nameJa': '立ち上がり',
    'nameEn': 'Turning Chain',
    'image': 'assets/images/tachiagari.png',
  },

  // ---- 引き上げ編み ----
  {
    'nameJa': '細編み表引き上げ編み',
    'nameEn': 'Front Post Single Crochet',
    'image': 'assets/images/sc_front_post.png',
  },
  {
    'nameJa': '細編み裏引き上げ編み',
    'nameEn': 'Back Post Single Crochet',
    'image': 'assets/images/sc_back_post.png',
  },
  {
    'nameJa': '中長編み表引き上げ編み',
    'nameEn': 'Front Post Half Double Crochet',
    'image': 'assets/images/hdc_front_post.png',
  },
  {
    'nameJa': '中長編み裏引き上げ編み',
    'nameEn': 'Back Post Half Double Crochet',
    'image': 'assets/images/hdc_back_post.png',
  },
  {
    'nameJa': '長編み表引き上げ編み',
    'nameEn': 'Front Post Double Crochet',
    'image': 'assets/images/dc_front_post.png',
  },
  {
    'nameJa': '長編み裏引き上げ編み',
    'nameEn': 'Back Post Double Crochet',
    'image': 'assets/images/dc_back_post.png',
  },

  // ---- 輪編み（丸く編む編み図）で使うもの ----
  {
    'nameJa': '輪の作り目',
    'nameEn': 'Magic Ring',
    'image': 'assets/images/magic_ring.png',
  },
  {
    'nameJa': 'すじ編み',
    'nameEn': 'Back Loop Single Crochet',
    'image': 'assets/images/うね編み.png',
  },

  // ---- ピコット・松編み・増減 ----
  {
    'nameJa': '鎖3目の引き抜きピコット',
    'nameEn': 'Chain-3 Picot (Slip Stitch)',
    'image': 'assets/images/picot_slip.png',
  },
  {
    'nameJa': '鎖3目の細編みピコット',
    'nameEn': 'Chain-3 Picot (Single Crochet)',
    'image': 'assets/images/picot_sc.png',
  },
  {
    'nameJa': '松編み（長編み5目）',
    'nameEn': 'Double Crochet 5 Shell',
    'image': 'assets/images/dc_5_shell.png',
  },
  {
    'nameJa': '長編み4目編み入れる',
    'nameEn': 'Double Crochet 4 Increase',
    'image': 'assets/images/dc_4_increase.png',
  },
  {
    'nameJa': '長編み4目一度',
    'nameEn': 'Double Crochet 4 Together',
    'image': 'assets/images/dc_4_together.png',
  },

  // ---- 玉編み・交差・クロス・リング ----
  {
    'nameJa': '中長編み2目の玉編み',
    'nameEn': 'Half Double Crochet 2 Bobble',
    'image': 'assets/images/hdc_2_bobble.png',
  },
  {
    'nameJa': '長編み2目の玉編み',
    'nameEn': 'Double Crochet 2 Bobble',
    'image': 'assets/images/dc_2_bobble.png',
  },
  {
    'nameJa': '長々編み１目交差',
    'nameEn': 'Treble Crochet Cross',
    'image': 'assets/images/tc_cross.png',
  },
  {
    'nameJa': '長編み１目左上交差',
    'nameEn': 'Double Crochet Left Cross',
    'image': 'assets/images/dc_left_cross.png',
  },
  {
    'nameJa': '長編みクロス編み',
    'nameEn': 'Double Crochet X-Stitch',
    'image': 'assets/images/dc_x_stitch.png',
  },
  {
    'nameJa': '長々編みクロス編み',
    'nameEn': 'Treble Crochet X-Stitch',
    'image': 'assets/images/tc_x_stitch.png',
  },
  {
    'nameJa': '細編みリング編み',
    'nameEn': 'Single Crochet Loop Stitch',
    'image': 'assets/images/sc_loop.png',
  },
  {
    'nameJa': '長編みリング編み',
    'nameEn': 'Double Crochet Loop Stitch',
    'image': 'assets/images/dc_loop.png',
  },
];

/// 日本語名からプレミアム編み目の画像パスを探す（なければnull）
String? premiumStitchImagePath(String nameJa) {
  for (final stitch in premiumStitchCatalog) {
    if (stitch['nameJa'] == nameJa) return stitch['image'];
  }
  return null;
}
