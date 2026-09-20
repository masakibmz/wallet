import 'package:flutter/cupertino.dart';

IconData categoryIconFor(String name, {String? iconName}) {
  final key =
      iconName != null && iconName.isNotEmpty ? iconName : name;
  return switch (key) {
    '餐饮' || '三餐' => CupertinoIcons.square_favorites_alt,
    '交通' => CupertinoIcons.bus,
    '购物' => CupertinoIcons.bag,
    '娱乐' => CupertinoIcons.game_controller,
    '医疗' => CupertinoIcons.heart,
    '住房' => CupertinoIcons.house,
    '通讯' => CupertinoIcons.phone,
    '工资' => CupertinoIcons.money_dollar_circle,
    '奖金' => CupertinoIcons.gift,
    '理财' => CupertinoIcons.chart_bar,
    '其它' || '其他' => CupertinoIcons.ellipsis_circle,
    _ => CupertinoIcons.circle_grid_3x3,
  };
}
