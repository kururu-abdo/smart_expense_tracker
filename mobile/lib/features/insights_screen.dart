import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../core/strings.dart';
import '../core/widgets.dart';
import '../core/theme.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});
  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  Map<String, dynamic>? data;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) setState(() => error = null);
    final c = ref.read(controllerProvider);
    try {
      final result = await c.repository.insights(monthKey(c.month));
      if (mounted) setState(() => data = result);
    } catch (e) {
      if (mounted) setState(() => error = errorCode(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(controllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.t('insights'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                context.s.month(c.month),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              if (error != null)
                ErrorBanner(error!, retry: load)
              else if (data == null)
                const Center(child: CircularProgressIndicator())
              else if (data!['has_data'] != true)
                const EmptyState(
                  title: 'no_activity',
                  detail: 'no_activity_detail',
                )
              else ...[
                Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t(
                          data!['is_projection'] == true
                              ? 'projection'
                              : 'period_total',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.s.money(
                          data!['projected_expense_minor'],
                          c.user!.currency,
                        ),
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.t('projection_note'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Surface(
                  child: Row(
                    children: [
                      const Icon(Icons.insights_outlined),
                      const SizedBox(width: 16),
                      Expanded(child: Text(context.t('daily_average'))),
                      Text(
                        context.s.money(
                          data!['daily_average_minor'],
                          c.user!.currency,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SectionHeading(context.t('breakdown')),
                Surface(
                  child: Column(
                    children: [
                      CategoryRing(c.overview.categories),
                      const SizedBox(height: 20),
                      ...c.overview.categories.entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: categoryColor(e.key),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(context.t(e.key))),
                              Text(
                                context.s.money(e.value, c.user!.currency),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
