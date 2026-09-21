import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'controller.dart';
import 'models.dart';
import 'strings.dart';
import 'theme.dart';

class Brand extends StatelessWidget {
  final bool light;
  const Brand({super.key, this.light = false});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          color: light ? lime : ink,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.ssid_chart_rounded,
          size: 24,
          color: light ? ink : lime,
        ),
      ),
      const SizedBox(width: 9),
      Text(
        context.t('app'),
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
          color: light ? Colors.white : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      const SizedBox(width: 6),
      Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          color: light ? lime : emerald,
          shape: BoxShape.circle,
        ),
      ),
    ],
  );
}

class Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(25),
    ),
    child: child,
  );
}

class Enter extends StatelessWidget {
  final Widget child;
  const Enter({super.key, required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 500,
    ),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 18 * (1 - value)),
        child: child,
      ),
    ),
    child: child,
  );
}

class MonthPicker extends ConsumerWidget {
  const MonthPicker({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(controllerProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: context.t('previous_month'),
          onPressed: c.loading ? null : () => c.changeMonth(-1),
          icon: Icon(context.s.ar ? Icons.chevron_right : Icons.chevron_left),
        ),
        Flexible(
          child: Text(
            context.s.month(c.month),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          tooltip: context.t('next_month'),
          onPressed: c.loading ? null : () => c.changeMonth(1),
          icon: Icon(context.s.ar ? Icons.chevron_left : Icons.chevron_right),
        ),
      ],
    );
  }
}

class SectionHeading extends StatelessWidget {
  final String title;
  final Widget? action;
  const SectionHeading(this.title, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (action != null) action!,
      ],
    ),
  );
}

class CategoryBadge extends StatelessWidget {
  final String category;
  const CategoryBadge(this.category, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(
      color: categoryColor(category).withValues(alpha: .3),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Icon(
      categoryIcon(category),
      size: 23,
      color: Theme.of(context).colorScheme.onSurface,
    ),
  );
}

class TransactionTile extends ConsumerWidget {
  final Expense expense;
  final VoidCallback? onTap;
  const TransactionTile(this.expense, {super.key, this.onTap});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(controllerProvider).user?.currency ?? 'SAR';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 3),
        child: Row(
          children: [
            CategoryBadge(expense.category),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.note.isEmpty
                        ? context.t(expense.category)
                        : expense.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${context.t(expense.category)} · ${context.s.date(expense.date)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${expense.isIncome ? '+' : '−'}${context.s.money(expense.amount, currency)}',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: expense.isIncome
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title, detail;
  final IconData icon;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.title,
    required this.detail,
    this.icon = Icons.spa_outlined,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 36,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          context.t(title),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          context.t(detail),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (action != null) ...[const SizedBox(height: 18), action!],
      ],
    ),
  );
}

class ErrorBanner extends StatelessWidget {
  final String code;
  final VoidCallback? retry;
  const ErrorBanner(this.code, {super.key, this.retry});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Expanded(child: Text(context.t(code))),
        if (retry != null)
          TextButton(onPressed: retry, child: Text(context.t('retry'))),
      ],
    ),
  );
}

void showError(BuildContext context, Object error) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(context.t(errorCode(error)))));

Future<bool> confirmDelete(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('delete_confirm')),
        content: Text(ctx.t('delete_detail')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('delete')),
          ),
        ],
      ),
    ) ??
    false;

class SpendingChart extends StatelessWidget {
  final List<int> daily;
  const SpendingChart(this.daily, {super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: context.t('spending_hint'),
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 800,
      ),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox(
        height: 125,
        width: double.infinity,
        child: CustomPaint(
          painter: _Bars(
            daily,
            value,
            Theme.of(context).colorScheme.primary,
            Theme.of(context).dividerColor.withValues(alpha: .15),
          ),
        ),
      ),
    ),
  );
}

class _Bars extends CustomPainter {
  final List<int> data;
  final double progress;
  final Color color, grid;
  _Bars(this.data, this.progress, this.color, this.grid);
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 4; i++) {
      final y = i * size.height / 3;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = grid
          ..strokeWidth = 1,
      );
    }
    if (data.isEmpty) return;
    final peak = math.max(1, data.reduce(math.max));
    final slot = size.width / data.length;
    for (var i = 0; i < data.length; i++) {
      final height = math.max(
        3.0,
        data[i] / peak * (size.height - 12) * progress,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            i * slot + slot * .2,
            size.height - height,
            slot * .6,
            height,
          ),
          const Radius.circular(5),
        ),
        Paint()
          ..color = data[i] == peak
              ? color
              : color.withValues(alpha: data[i] == 0 ? .08 : .4),
      );
    }
  }

  @override
  bool shouldRepaint(_Bars oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.progress != progress ||
      oldDelegate.color != color;
}

class CategoryRing extends StatelessWidget {
  final Map<String, int> categories;
  const CategoryRing(this.categories, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 130,
    height: 130,
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 750,
      ),
      builder: (_, value, child) => CustomPaint(
        painter: _Ring(categories, value),
        child: Center(
          child: Icon(
            Icons.pie_chart_outline_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 32,
          ),
        ),
      ),
    ),
  );
}

class _Ring extends CustomPainter {
  final Map<String, int> data;
  final double progress;
  _Ring(this.data, this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final total = data.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return;
    var angle = -math.pi / 2;
    final rect = Rect.fromLTWH(11, 11, size.width - 22, size.height - 22);
    for (final item in data.entries) {
      final sweep = item.value / total * math.pi * 2 * progress;
      canvas.drawArc(
        rect,
        angle + .02,
        math.max(0, sweep - .04),
        false,
        Paint()
          ..color = categoryColor(item.key)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.butt,
      );
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(_Ring old) => old.data != data || old.progress != progress;
}
