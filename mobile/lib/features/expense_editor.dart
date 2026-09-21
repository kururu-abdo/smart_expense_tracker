import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

Future<void> openExpense(BuildContext context, [Expense? expense]) =>
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ExpenseEditor(expense: expense)));

class ExpenseEditor extends ConsumerStatefulWidget {
  final Expense? expense;
  const ExpenseEditor({super.key, this.expense});
  @override
  ConsumerState<ExpenseEditor> createState() => _ExpenseEditorState();
}

class _ExpenseEditorState extends ConsumerState<ExpenseEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController amount, note;
  final smart = TextEditingController();
  late String kind, category, clientId;
  late DateTime date;
  bool busy = false, parsing = false, suggested = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    amount = TextEditingController(
      text: e == null ? '' : decimalMoney(e.amount),
    );
    note = TextEditingController(text: e?.note ?? '');
    kind = e?.kind ?? 'expense';
    category = e?.category ?? 'food';
    date = e?.date ?? DateTime.now();
    clientId = e?.clientId ?? const Uuid().v4();
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    smart.dispose();
    super.dispose();
  }

  Future<void> parse() async {
    if (smart.text.trim().isEmpty) return;
    setState(() {
      parsing = true;
      error = null;
    });
    try {
      final result = await ref
          .read(controllerProvider)
          .repository
          .parse(smart.text.trim());
      if (!mounted) return;
      setState(() {
        if (result['amount_minor'] != null) {
          amount.text = decimalMoney(result['amount_minor']);
        }
        category = result['category'];
        kind = result['kind'];
        note.text = smart.text.trim();
        suggested = true;
      });
    } catch (e) {
      if (mounted) setState(() => error = errorCode(e));
    } finally {
      if (mounted) setState(() => parsing = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final expense = Expense(
        id: widget.expense?.id ?? '',
        clientId: clientId,
        kind: kind,
        category: category,
        note: note.text.trim(),
        amount: parseMoney(amount.text)!,
        date: date,
      );
      await ref.read(controllerProvider).saveExpense(expense);
      HapticFeedback.lightImpact();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = errorCode(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(controllerProvider);
    final categories = kind == 'income'
        ? ['salary', 'other']
        : expenseCategories;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.t(widget.expense == null ? 'add_expense' : 'edit_expense'),
        ),
        actions: [
          if (widget.expense != null)
            IconButton(
              tooltip: context.t('delete'),
              onPressed: busy
                  ? null
                  : () async {
                      if (await confirmDelete(context)) {
                        setState(() => busy = true);
                        try {
                          await c.deleteExpense(widget.expense!.id);
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            showError(context, e);
                            setState(() => busy = false);
                          }
                        }
                      }
                    },
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Form(
              key: form,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (error != null) ErrorBanner(error!),
                  if (widget.expense == null)
                    Surface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.auto_awesome_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                context.t('smart_entry'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: smart,
                            maxLength: 240,
                            decoration: InputDecoration(
                              hintText: context.t('smart_hint'),
                              counterText: '',
                            ),
                            onSubmitted: (_) => parse(),
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton(
                              onPressed: parsing ? null : parse,
                              child: parsing
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(context.t('suggest')),
                            ),
                          ),
                          if (suggested)
                            Text(
                              context.t('confirm_suggestion'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 22),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'expense',
                        label: Text(context.t('expense')),
                        icon: const Icon(Icons.arrow_outward),
                      ),
                      ButtonSegment(
                        value: 'income',
                        label: Text(context.t('income')),
                        icon: const Icon(Icons.south_west),
                      ),
                    ],
                    selected: {kind},
                    onSelectionChanged: (v) => setState(() {
                      kind = v.first;
                      category = kind == 'income' ? 'salary' : 'food';
                    }),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: amount,
                    autofocus: widget.expense != null,
                    textDirection: TextDirection.ltr,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: Theme.of(context).textTheme.headlineLarge,
                    decoration: InputDecoration(
                      labelText: context.t('amount'),
                      suffixText: c.user?.currency,
                    ),
                    validator: (v) => parseMoney(v ?? '') == null
                        ? context.t('invalid_amount')
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.t('category'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories
                        .map(
                          (v) => ChoiceChip(
                            label: Text(context.t(v)),
                            avatar: Icon(categoryIcon(v), size: 18),
                            selected: category == v,
                            onSelected: (_) => setState(() => category = v),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: note,
                    maxLength: 240,
                    maxLines: 2,
                    decoration: InputDecoration(labelText: context.t('note')),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(context.t('date')),
                    subtitle: Text(context.s.date(date)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => date = picked);
                    },
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: busy || parsing ? null : save,
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(context.t('save')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
