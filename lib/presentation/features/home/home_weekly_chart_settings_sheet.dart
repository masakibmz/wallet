import 'package:flutter/cupertino.dart';
import 'package:wallet/presentation/theme/qianji_colors.dart';
import 'package:wallet/services/app_preferences_service.dart';

Future<HomeWeeklyChartPrefs?> showHomeWeeklyChartSettingsSheet(
  BuildContext context, {
  required HomeWeeklyChartPrefs initial,
}) {
  return showCupertinoModalPopup<HomeWeeklyChartPrefs>(
    context: context,
    builder: (ctx) => _SettingsSheet(initial: initial),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.initial});

  final HomeWeeklyChartPrefs initial;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late HomeChartDataType _dataType;
  late HomeChartRange _range;

  @override
  void initState() {
    super.initState();
    _dataType = widget.initial.dataType;
    _range = widget.initial.range;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: QianjiColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                '设置',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context),
                child: const Icon(CupertinoIcons.xmark),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('数据类型', style: TextStyle(color: QianjiColors.textSecondary)),
          const SizedBox(height: 8),
          _segment([
            ('支出', HomeChartDataType.expense),
            ('收入', HomeChartDataType.income),
            ('结余', HomeChartDataType.balance),
            ('支出&收入', HomeChartDataType.expenseAndIncome),
          ], _dataType, (v) => setState(() => _dataType = v)),
          const SizedBox(height: 20),
          const Text('显示范围', style: TextStyle(color: QianjiColors.textSecondary)),
          const SizedBox(height: 8),
          _segment([
            ('不显示', HomeChartRange.hidden),
            ('本周', HomeChartRange.thisWeek),
            ('最近七日', HomeChartRange.last7Days),
          ], _range, (v) => setState(() => _range = v)),
          const SizedBox(height: 24),
          CupertinoButton.filled(
            onPressed: () {
              Navigator.pop(
                context,
                HomeWeeklyChartPrefs(dataType: _dataType, range: _range),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _segment<T>(
    List<(String, T)> options,
    T selected,
    ValueChanged<T> onSelect,
  ) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: QianjiColors.chipBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final (label, value) in options)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minSize: 0,
              color: selected == value
                  ? QianjiColors.cardBackground
                  : null,
              borderRadius: BorderRadius.circular(8),
              onPressed: () => onSelect(value),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: selected == value
                      ? QianjiColors.textPrimary
                      : QianjiColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
