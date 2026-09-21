import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'paywall.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(controllerProvider);
    Future<void> edit([Budget? budget]) => showDialog<void>(
      context: context,
      builder: (_) => BudgetEditor(budget: budget),
    );
    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
        children: [
          Text(
            context.t('budget_title'),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 10),
          Text(context.t('budget_subtitle')),
          const SizedBox(height: 14),
          const MonthPicker(),
          const SizedBox(height: 16),
          if (c.error != null) ErrorBanner(c.error!, retry: c.refresh),
          if (c.loading) const LinearProgressIndicator(minHeight: 2),
          if (!c.premium)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                context.t('free_limits'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ...c.budgets.map((b) {
            final remaining = b.limit - b.spent;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CategoryBadge(b.category),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.t(b.category),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: context.t('edit_budget'),
                          onPressed: () => edit(b),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                        IconButton(
                          tooltip: context.t('delete'),
                          onPressed: () async {
                            if (await confirmDelete(context)) {
                              try {
                                await c.deleteBudget(b.id);
                              } catch (e) {
                                if (context.mounted) showError(context, e);
                              }
                            }
                          },
                          icon: const Icon(Icons.delete_outline, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.s.money(b.spent, c.user!.currency),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Text(
                          '/ ${context.s.money(b.limit, c.user!.currency)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: b.progress),
                      duration: Duration(
                        milliseconds: MediaQuery.disableAnimationsOf(context)
                            ? 0
                            : 650,
                      ),
                      builder: (_, value, child) => ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 9,
                          color: remaining < 0
                              ? Theme.of(context).colorScheme.error
                              : categoryColor(b.category),
                          backgroundColor: categoryColor(
                            b.category,
                          ).withValues(alpha: .15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${context.s.money(remaining.abs(), c.user!.currency)} ${context.t(remaining < 0 ? 'over_budget' : 'remaining')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: remaining < 0
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (c.budgets.isEmpty)
            const EmptyState(
              title: 'budget_empty',
              detail: 'budget_empty_detail',
              icon: Icons.track_changes_outlined,
            ),
          OutlinedButton.icon(
            onPressed: () {
              if (!c.premium && c.budgets.length >= 3) {
                openPaywall(context);
              } else {
                edit();
              }
            },
            icon: const Icon(Icons.add),
            label: Text(context.t('add_budget')),
          ),
        ],
      ),
    );
  }
}

class BudgetEditor extends ConsumerStatefulWidget {
  final Budget? budget;
  const BudgetEditor({super.key, this.budget});
  @override
  ConsumerState<BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends ConsumerState<BudgetEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController amount;
  late String category;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    amount = TextEditingController(
      text: widget.budget == null ? '' : decimalMoney(widget.budget!.limit),
    );
    category = widget.budget?.category ?? 'food';
  }

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      context.t(widget.budget == null ? 'add_budget' : 'edit_budget'),
    ),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error != null) ErrorBanner(error!),
            DropdownButtonFormField<String>(
              initialValue: category,
              isExpanded: true,
              decoration: InputDecoration(labelText: context.t('category')),
              items: expenseCategories
                  .map(
                    (v) =>
                        DropdownMenuItem(value: v, child: Text(context.t(v))),
                  )
                  .toList(),
              onChanged: widget.budget != null
                  ? null
                  : (v) => setState(() => category = v!),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: amount,
              textDirection: TextDirection.ltr,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: context.t('monthly_limit'),
              ),
              validator: (v) => parseMoney(v ?? '') == null
                  ? context.t('invalid_amount')
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: Text(context.t('cancel')),
      ),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                if (!form.currentState!.validate()) return;
                setState(() {
                  busy = true;
                  error = null;
                });
                try {
                  await ref
                      .read(controllerProvider)
                      .saveBudget(category, parseMoney(amount.text)!);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (mounted) {
                    setState(() {
                      error = errorCode(e);
                      busy = false;
                    });
                  }
                }
              },
        child: Text(context.t('save')),
      ),
    ],
  );
}
