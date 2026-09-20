import 'package:wallet/domain/enums/app_enums.dart';

class AccountTypeOption {
  const AccountTypeOption({
    required this.category,
    required this.label,
  });

  final AccountCategory category;
  final String label;
}

class AccountTypeSection {
  const AccountTypeSection({
    required this.title,
    required this.options,
  });

  final String title;
  final List<AccountTypeOption> options;
}

const accountTypeSections = [
  AccountTypeSection(
    title: '资金账户',
    options: [
      AccountTypeOption(category: AccountCategory.cash, label: '现金'),
      AccountTypeOption(category: AccountCategory.wechat, label: '微信'),
      AccountTypeOption(category: AccountCategory.alipay, label: '支付宝'),
      AccountTypeOption(category: AccountCategory.bank, label: '银行卡'),
      AccountTypeOption(category: AccountCategory.qqWallet, label: 'QQ钱包'),
      AccountTypeOption(category: AccountCategory.otherFund, label: '其它'),
    ],
  ),
  AccountTypeSection(
    title: '信用卡账户',
    options: [
      AccountTypeOption(
        category: AccountCategory.creditCard,
        label: '信用卡',
      ),
      AccountTypeOption(category: AccountCategory.huabei, label: '花呗'),
      AccountTypeOption(category: AccountCategory.jdBaitiao, label: '京东白条'),
      AccountTypeOption(
        category: AccountCategory.otherCredit,
        label: '其它信用',
      ),
    ],
  ),
  AccountTypeSection(
    title: '充值账户',
    options: [
      AccountTypeOption(
        category: AccountCategory.phoneTopUp,
        label: '话费',
      ),
      AccountTypeOption(
        category: AccountCategory.transitCard,
        label: '交通卡',
      ),
      AccountTypeOption(category: AccountCategory.mealCard, label: '饭卡'),
      AccountTypeOption(category: AccountCategory.deposit, label: '押金'),
      AccountTypeOption(
        category: AccountCategory.otherPrepaid,
        label: '其它充值',
      ),
    ],
  ),
];

String accountCategoryLabel(AccountCategory category) {
  for (final section in accountTypeSections) {
    for (final opt in section.options) {
      if (opt.category == category) {
        return opt.label;
      }
    }
  }
  return '其它';
}
