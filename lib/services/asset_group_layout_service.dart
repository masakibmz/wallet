import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:wallet/domain/entities/account.dart';
import 'package:wallet/domain/enums/app_enums.dart';

class AssetGroupEntry {
  const AssetGroupEntry({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  static AssetGroupEntry fromJson(Map<String, dynamic> json) {
    return AssetGroupEntry(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}

class AssetGroupLayout {
  const AssetGroupLayout({
    required this.groups,
    required this.accountToGroupId,
  });

  final List<AssetGroupEntry> groups;
  final Map<String, String> accountToGroupId;

  Map<String, dynamic> toJson() => {
        'groups': groups.map((g) => g.toJson()).toList(),
        'accountToGroupId': accountToGroupId,
      };

  static AssetGroupLayout fromJson(Map<String, dynamic> json) {
    final groupsRaw = json['groups'] as List<dynamic>? ?? [];
    final mapRaw = json['accountToGroupId'] as Map<String, dynamic>? ?? {};
    return AssetGroupLayout(
      groups: groupsRaw
          .map((e) => AssetGroupEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      accountToGroupId: mapRaw.map(
        (key, value) => MapEntry(key, value as String),
      ),
    );
  }

  AssetGroupLayout copyWith({
    List<AssetGroupEntry>? groups,
    Map<String, String>? accountToGroupId,
  }) {
    return AssetGroupLayout(
      groups: groups ?? this.groups,
      accountToGroupId: accountToGroupId ?? this.accountToGroupId,
    );
  }
}

class AssetGroupLayoutService {
  AssetGroupLayoutService(this._prefs);

  final SharedPreferences _prefs;
  static const _uuid = Uuid();
  static const _keyPrefix = 'asset_group_layout_v1_';

  Future<AssetGroupLayout> loadOrDefault({
    required String ledgerId,
    required List<Account> accounts,
  }) async {
    final raw = _prefs.getString('$_keyPrefix$ledgerId');
    if (raw != null) {
      return AssetGroupLayout.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    }
    return _defaultLayout(accounts);
  }

  Future<void> save(String ledgerId, AssetGroupLayout layout) async {
    await _prefs.setString(
      '$_keyPrefix$ledgerId',
      jsonEncode(layout.toJson()),
    );
  }

  AssetGroupLayout _defaultLayout(List<Account> accounts) {
    final bucket = <String, List<Account>>{};
    for (final a in accounts) {
      if (a.isHidden) {
        continue;
      }
      final key = _categoryGroupName(a.category);
      bucket.putIfAbsent(key, () => []).add(a);
    }
    final groups = <AssetGroupEntry>[];
    final assign = <String, String>{};
    for (final entry in bucket.entries) {
      final id = _uuid.v4();
      groups.add(AssetGroupEntry(id: id, name: entry.key));
      for (final a in entry.value) {
        assign[a.id] = id;
      }
    }
    return AssetGroupLayout(groups: groups, accountToGroupId: assign);
  }

  String _categoryGroupName(AccountCategory category) {
    return switch (category) {
      AccountCategory.cash => '现金',
      AccountCategory.bank => '银行卡',
      AccountCategory.alipay ||
      AccountCategory.wechat ||
      AccountCategory.qqWallet =>
        '第三方支付',
      AccountCategory.creditCard ||
      AccountCategory.huabei ||
      AccountCategory.jdBaitiao ||
      AccountCategory.otherCredit =>
        '信用卡',
      _ => '其它',
    };
  }

  static Future<AssetGroupLayoutService> open() async {
    final prefs = await SharedPreferences.getInstance();
    return AssetGroupLayoutService(prefs);
  }
}

Map<String, List<Account>> groupAccountsByLayout(
  List<Account> accounts,
  AssetGroupLayout layout,
) {
  final groupMap = {for (final g in layout.groups) g.id: g.name};
  final result = <String, List<Account>>{};
  for (final g in layout.groups) {
    result[g.name] = [];
  }
  for (final a in accounts) {
    if (a.isHidden) {
      continue;
    }
    final gid = layout.accountToGroupId[a.id];
    final name = gid == null ? '其它' : (groupMap[gid] ?? '其它');
    result.putIfAbsent(name, () => []).add(a);
  }
  for (final list in result.values) {
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }
  return result;
}
