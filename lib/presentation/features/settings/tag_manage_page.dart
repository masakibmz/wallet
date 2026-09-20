import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet/application/providers/database_providers.dart';
import 'package:wallet/application/providers/ledger_data_providers.dart';

class TagManagePage extends ConsumerStatefulWidget {
  const TagManagePage({super.key});

  @override
  ConsumerState<TagManagePage> createState() => _TagManagePageState();
}

class _TagManagePageState extends ConsumerState<TagManagePage> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add(String ledgerId) async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      return;
    }
    await ref.read(tagRepositoryProvider).createTag(
          ledgerId: ledgerId,
          name: name,
        );
    _name.clear();
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(currentLedgerProvider);
    if (ledger == null) {
      return const CupertinoPageScaffold(
        child: Center(child: Text('无账本')),
      );
    }
    final tags = ref.watch(tagsForLedgerProvider(ledger.id));

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('标签')),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: _name,
                      placeholder: '#标签名',
                    ),
                  ),
                  CupertinoButton(
                    onPressed: () => _add(ledger.id),
                    child: const Text('添加'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: tags.when(
                data: (list) => ListView(
                  children: [
                    CupertinoListSection.insetGrouped(
                      children: [
                        for (final t in list)
                          CupertinoListTile(
                            title: Text('#${t.name}'),
                            trailing: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => ref
                                  .read(tagRepositoryProvider)
                                  .softDelete(t.id),
                              child: const Icon(
                                CupertinoIcons.trash,
                                size: 18,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                loading: () =>
                    const Center(child: CupertinoActivityIndicator()),
                error: (e, _) => Center(child: Text('$e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
