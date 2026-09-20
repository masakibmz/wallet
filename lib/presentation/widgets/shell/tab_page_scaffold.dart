import 'package:flutter/cupertino.dart';
import 'package:wallet/presentation/widgets/liquid_glass/native_liquid_glass.dart';

class TabPageScaffold extends StatelessWidget {
  const TabPageScaffold({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.footer = 'Phase 2 · 本地 SQLite 实时数据',
    this.extraSections = const [],
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String footer;
  final List<Widget> extraSections;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        trailing: actionLabel != null && onAction != null
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onAction,
                child: Text(actionLabel!),
              )
            : null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            NativeLiquidGlass(
              borderRadius: 20,
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .textStyle
                          .copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      footer,
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .tabLabelTextStyle
                          .copyWith(
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                          ),
                    ),
                  ],
                ),
              ),
            ),
            ...extraSections,
          ],
        ),
      ),
    );
  }
}
