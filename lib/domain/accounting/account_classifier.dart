import 'package:wallet/domain/enums/app_enums.dart';

enum AccountNature {
  asset,
  liability,
}

abstract final class AccountClassifier {
  static AccountNature natureOf(AccountCategory category) {
    switch (category) {
      case AccountCategory.creditCard:
      case AccountCategory.huabei:
      case AccountCategory.jdBaitiao:
      case AccountCategory.otherCredit:
        return AccountNature.liability;
      default:
        return AccountNature.asset;
    }
  }

  static bool isLiability(AccountCategory category) =>
      natureOf(category) == AccountNature.liability;
}
