import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ruya/l10n/app_localizations.dart';
import 'package:ruya/services/bag_service.dart';
import 'package:ruya/services/feedback_service.dart';

List<String> defaultBagItems(AppLocalizations l10n) => [
      l10n.bag_itemPads,
      l10n.bag_itemUnderwear,
      l10n.bag_itemPainkiller,
      l10n.bag_itemWipes,
      l10n.bag_itemChocolate,
    ];

/// Checklist the user fills in the days before her period.
class BagScreen extends StatefulWidget {
  const BagScreen({super.key});

  @override
  State<BagScreen> createState() => _BagScreenState();
}

class _BagScreenState extends State<BagScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(BagService bag) {
    bag.add(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bag = context.watch<BagService>();
    final theme = Theme.of(context);
    final items = bag.items ?? const <String>[];
    final allSet = items.isNotEmpty && bag.doneCount == items.length;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bag_title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(l10n.bag_hint, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            allSet ? l10n.bag_allSet : l10n.bag_ready(bag.doneCount, items.length),
            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 8),
          for (final item in items)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                item,
                style: bag.isChecked(item) ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
              ),
              value: bag.isChecked(item),
              onChanged: (_) {
                context.read<FeedbackService>().select();
                bag.toggle(item);
              },
              secondary: IconButton(
                icon: const Icon(Icons.close),
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                onPressed: () => bag.remove(item),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            maxLength: BagService.maxLength,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _add(bag),
            decoration: InputDecoration(
              labelText: l10n.bag_add,
              suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: () => _add(bag)),
            ),
          ),
        ],
      ),
    );
  }
}
