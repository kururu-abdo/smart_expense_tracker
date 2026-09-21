import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/controller.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'expense_editor.dart';
import 'paywall.dart';
import 'insights_screen.dart';

class Dashboard extends ConsumerWidget {
  final VoidCallback onActivity;
  const Dashboard({super.key, required this.onActivity});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(controllerProvider);
    final currency = c.user?.currency ?? 'SAR';
    final balance = Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: ink,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.t('month_balance'),
                  style: const TextStyle(
                    color: Color(0xFFC5D6CD),
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: lime,
                  size: 21,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          TweenAnimationBuilder<double>(
            key: ValueKey(c.overview.balance),
            tween: Tween(begin: 0, end: c.overview.balance.toDouble()),
            duration: Duration(
              milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 700,
            ),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                context.s.money(value.round(), currency),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 37,
                  letterSpacing: -1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            context.t('balance_hint'),
            style: const TextStyle(color: Color(0xFFAEC9BB), fontSize: 11),
          ),
          const SizedBox(height: 24),
          Container(height: 1, color: Colors.white.withValues(alpha: .12)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: context.t('income'),
                  value: context.s.money(c.overview.income, currency),
                  incoming: true,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _SummaryMetric(
                  label: context.t('expenses'),
                  value: context.s.money(c.overview.expense, currency),
                  incoming: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    final chart = Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('spending'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            context.t('spending_hint'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          SpendingChart(c.overview.daily),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:
                [
                      '1',
                      '10',
                      '20',
                      '${c.overview.daily.isEmpty ? 30 : c.overview.daily.length}',
                    ]
                    .map(
                      (v) => Text(
                        v,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
    final recent = Surface(
      child: Column(
        children: [
          SectionHeading(
            context.t('recent'),
            action: TextButton(
              onPressed: onActivity,
              child: Text(context.t('see_all')),
            ),
          ),
          if (c.expenses.isEmpty)
            EmptyState(
              title: 'no_activity',
              detail: 'no_activity_detail',
              action: FilledButton(
                onPressed: () => openExpense(context),
                child: Text(context.t('add_expense')),
              ),
            )
          else
            ...c.expenses
                .take(4)
                .map(
                  (e) =>
                      TransactionTile(e, onTap: () => openExpense(context, e)),
                ),
        ],
      ),
    );
    final insights = Surface(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF264337)
          : const Color(0xFFE5EDDA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_outlined, color: emerald, size: 28),
          const SizedBox(height: 16),
          Text(
            context.t('insight_teaser'),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 10),
          Text(context.t('insight_detail')),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () => c.premium
                ? Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InsightsScreen()),
                  )
                : openPaywall(context),
            icon: Icon(
              c.premium
                  ? Icons.insights_outlined
                  : Icons.workspace_premium_outlined,
            ),
            label: Text(context.t(c.premium ? 'insights' : 'upgrade')),
          ),
        ],
      ),
    );
    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 108),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${context.t('hello')}, ${c.user?.name.split(' ').first ?? ''}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              CircleAvatar(
                backgroundColor: lime,
                child: Text(
                  (c.user?.name ?? 'M').characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.t('dashboard_title'),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: MonthPicker(),
          ),
          const SizedBox(height: 14),
          if (c.error != null) ErrorBanner(c.error!, retry: c.refresh),
          if (c.loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth > 720
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            balance,
                            const SizedBox(height: 20),
                            recent,
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          children: [
                            chart,
                            const SizedBox(height: 20),
                            insights,
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      balance,
                      const SizedBox(height: 20),
                      chart,
                      const SizedBox(height: 20),
                      recent,
                      const SizedBox(height: 20),
                      insights,
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label, value;
  final bool incoming;
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.incoming,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          incoming ? Icons.south_west : Icons.north_east,
          size: 17,
          color: incoming ? lime : const Color(0xFFF1C7AE),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFFC5D6CD)),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});
  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  String query = '', filter = 'all';
  @override
  Widget build(BuildContext context) {
    final c = ref.watch(controllerProvider);
    final rows = c.expenses
        .where(
          (e) =>
              (filter == 'all' || e.kind == filter) &&
              '${e.note} ${context.t(e.category)}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
        children: [
          Text(
            context.t('activity'),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          const MonthPicker(),
          const SizedBox(height: 18),
          if (c.error != null) ErrorBanner(c.error!, retry: c.refresh),
          TextField(
            decoration: InputDecoration(
              hintText: context.t('search'),
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: ['all', 'expense', 'income']
                .map(
                  (v) => ChoiceChip(
                    label: Text(context.t(v)),
                    selected: filter == v,
                    onSelected: (_) => setState(() => filter = v),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          if (c.loading) const LinearProgressIndicator(minHeight: 2),
          if (rows.isEmpty)
            EmptyState(
              title: query.isEmpty ? 'no_activity' : 'no_results',
              detail: 'no_activity_detail',
            )
          else
            Surface(
              child: Column(
                children: rows
                    .map(
                      (e) => TransactionTile(
                        e,
                        onTap: () => openExpense(context, e),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
