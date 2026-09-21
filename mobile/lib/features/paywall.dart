import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/billing.dart';
import '../core/controller.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

Future<void> openPaywall(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const PaywallScreen()),
);

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});
  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  List<Package> packages = [];
  Package? selected;
  bool loading = true, busy = false;
  String? message;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final c = ref.read(controllerProvider);
    if (c.demo || !c.billing.available) {
      setState(() {
        loading = false;
        message = c.demo ? 'demo_purchase' : 'billing_unavailable_ui';
      });
      return;
    }
    try {
      final available = await c.billing.offerings(c.user!.id);
      if (!mounted) return;
      setState(() {
        packages = available;
        selected = available.firstOrNull;
        if (available.isEmpty || !c.billing.legalConfigured) {
          message = 'billing_unavailable_ui';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => message = e is PlatformException
              ? 'billing_unavailable'
              : errorCode(e),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> transact({bool restore = false}) async {
    final c = ref.read(controllerProvider);
    setState(() {
      busy = true;
      message = null;
    });
    var storeCompleted = false;
    try {
      if (restore) {
        await c.billing.restore(c.user!.id);
      } else {
        await c.billing.purchase(c.user!.id, selected!);
      }
      storeCompleted = true;
      final active = await c.syncBilling();
      if (!mounted) return;
      setState(
        () => message = active
            ? 'premium_active'
            : restore
            ? 'restore_empty'
            : 'purchase_pending',
      );
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) !=
              PurchasesErrorCode.purchaseCancelledError &&
          mounted) {
        setState(() => message = 'billing_unavailable');
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => message = storeCompleted && !restore
              ? 'purchase_pending'
              : errorCode(e),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(controllerProvider);
    return Scaffold(
      appBar: AppBar(
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 20),
            child: Chip(
              label: Text(context.t('premium')),
              avatar: const Icon(Icons.auto_awesome, size: 16),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: lime,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: const Icon(Icons.spa_outlined, size: 45, color: ink),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  context.t('premium_title'),
                  style: Theme.of(
                    context,
                  ).textTheme.headlineLarge?.copyWith(fontSize: 40),
                ),
                const SizedBox(height: 12),
                Text(context.t('premium_subtitle')),
                const SizedBox(height: 28),
                ...['unlimited_budgets', 'premium_insights', 'csv_export'].map(
                  (key) => Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            context.t(key),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (loading) const Center(child: CircularProgressIndicator()),
                ...packages.map((p) {
                  final active = selected?.identifier == p.identifier;
                  final label = p.packageType == PackageType.annual
                      ? context.t('annual')
                      : p.packageType == PackageType.monthly
                      ? context.t('monthly')
                      : p.storeProduct.title;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: busy ? null : () => setState(() => selected = p),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: active
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: .08)
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              active
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              p.storeProduct.priceString,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      context.t(message!),
                      textAlign: TextAlign.center,
                    ),
                  ),
                FilledButton(
                  onPressed:
                      busy ||
                          loading ||
                          selected == null ||
                          c.demo ||
                          !c.billing.legalConfigured ||
                          c.premium
                      ? null
                      : () => transact(),
                  child: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          context.t(c.premium ? 'premium_active' : 'continue'),
                        ),
                ),
                TextButton(
                  onPressed: busy || c.demo || !c.billing.available
                      ? null
                      : () => transact(restore: true),
                  child: Text(context.t('restore')),
                ),
                const SizedBox(height: 12),
                Text(
                  context.t('renewal'),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  children: [
                    for (final link in {
                      'privacy': BillingService.privacyUrl,
                      'terms': BillingService.termsUrl,
                    }.entries)
                      if (Uri.tryParse(link.value)?.scheme == 'https')
                        TextButton(
                          onPressed: () async {
                            if (!await launchUrl(
                                  Uri.parse(link.value),
                                  mode: LaunchMode.externalApplication,
                                ) &&
                                context.mounted) {
                              showError(context, Exception());
                            }
                          },
                          child: Text(context.t(link.key)),
                        ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
