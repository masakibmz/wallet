class DefaultCategorySpec {
  const DefaultCategorySpec({
    required this.name,
    this.iconName,
    this.children = const [],
    this.isSystem = false,
    this.isDeletable = true,
  });

  final String name;
  final String? iconName;
  final List<DefaultCategorySpec> children;
  final bool isSystem;
  final bool isDeletable;
}

abstract final class DefaultCategories {
  static const otherExpenseName = '其他';
  static const otherIncomeName = '其他';

  static const expenseRoots = <DefaultCategorySpec>[
    DefaultCategorySpec(
      name: '餐饮',
      iconName: 'fork_knife',
      children: [
        DefaultCategorySpec(name: '早餐'),
        DefaultCategorySpec(name: '午餐'),
        DefaultCategorySpec(name: '晚餐'),
        DefaultCategorySpec(name: '零食'),
      ],
    ),
    DefaultCategorySpec(name: '购物', iconName: 'bag'),
    DefaultCategorySpec(name: '交通', iconName: 'car'),
    DefaultCategorySpec(name: '居住', iconName: 'house'),
    DefaultCategorySpec(name: '娱乐', iconName: 'gamecontroller'),
    DefaultCategorySpec(name: '医疗', iconName: 'heart'),
    DefaultCategorySpec(
      name: otherExpenseName,
      iconName: 'ellipsis_circle',
      isSystem: true,
      isDeletable: false,
    ),
  ];

  static const incomeRoots = <DefaultCategorySpec>[
    DefaultCategorySpec(name: '工资', iconName: 'money_dollar'),
    DefaultCategorySpec(name: '理财', iconName: 'chart_line'),
    DefaultCategorySpec(name: '兼职', iconName: 'briefcase'),
    DefaultCategorySpec(
      name: otherIncomeName,
      iconName: 'ellipsis_circle',
      isSystem: true,
      isDeletable: false,
    ),
  ];
}
