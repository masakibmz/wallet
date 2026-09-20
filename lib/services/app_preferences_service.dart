import 'package:shared_preferences/shared_preferences.dart';

enum AppLaunchMode {
  home,
  addTransaction,
}

enum HomeChartDataType {
  expense,
  income,
  balance,
  expenseAndIncome,
}

enum HomeChartRange {
  hidden,
  thisWeek,
  last7Days,
}

class HomeWeeklyChartPrefs {
  const HomeWeeklyChartPrefs({
    this.dataType = HomeChartDataType.expenseAndIncome,
    this.range = HomeChartRange.thisWeek,
  });

  final HomeChartDataType dataType;
  final HomeChartRange range;

  HomeWeeklyChartPrefs copyWith({
    HomeChartDataType? dataType,
    HomeChartRange? range,
  }) {
    return HomeWeeklyChartPrefs(
      dataType: dataType ?? this.dataType,
      range: range ?? this.range,
    );
  }
}

class AppPreferencesService {
  AppPreferencesService(this._prefs);

  final SharedPreferences _prefs;

  static const _launchModeKey = 'app_launch_mode';
  static const _appLockKey = 'app_lock_enabled';
  static const _chartDataTypeKey = 'home_chart_data_type';
  static const _chartRangeKey = 'home_chart_range';
  static const _categoryAccountPrefix = 'last_account_';

  AppLaunchMode get launchMode {
    final raw = _prefs.getString(_launchModeKey);
    return raw == 'add' ? AppLaunchMode.addTransaction : AppLaunchMode.home;
  }

  Future<void> setLaunchMode(AppLaunchMode mode) async {
    await _prefs.setString(
      _launchModeKey,
      mode == AppLaunchMode.addTransaction ? 'add' : 'home',
    );
  }

  bool get appLockEnabled => _prefs.getBool(_appLockKey) ?? false;

  Future<void> setAppLockEnabled(bool value) async {
    await _prefs.setBool(_appLockKey, value);
  }

  HomeWeeklyChartPrefs get homeWeeklyChartPrefs {
    final typeRaw = _prefs.getString(_chartDataTypeKey);
    final rangeRaw = _prefs.getString(_chartRangeKey);
    return HomeWeeklyChartPrefs(
      dataType: _parseChartDataType(typeRaw),
      range: _parseChartRange(rangeRaw),
    );
  }

  Future<void> setHomeWeeklyChartPrefs(HomeWeeklyChartPrefs prefs) async {
    await _prefs.setString(_chartDataTypeKey, prefs.dataType.name);
    await _prefs.setString(_chartRangeKey, prefs.range.name);
  }

  static HomeChartDataType _parseChartDataType(String? raw) {
    return HomeChartDataType.values.asNameMap()[raw] ??
        HomeChartDataType.expenseAndIncome;
  }

  static HomeChartRange _parseChartRange(String? raw) {
    return HomeChartRange.values.asNameMap()[raw] ?? HomeChartRange.thisWeek;
  }

  String? getLastAccountForCategory(String ledgerId, String categoryId) {
    return _prefs.getString('$_categoryAccountPrefix${ledgerId}_$categoryId');
  }

  Future<void> setLastAccountForCategory({
    required String ledgerId,
    required String categoryId,
    required String accountId,
  }) async {
    await _prefs.setString(
      '$_categoryAccountPrefix${ledgerId}_$categoryId',
      accountId,
    );
  }

  static Future<AppPreferencesService> open() async {
    final prefs = await SharedPreferences.getInstance();
    return AppPreferencesService(prefs);
  }
}
