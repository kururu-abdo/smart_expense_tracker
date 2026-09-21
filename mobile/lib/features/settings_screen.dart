import 'dart:convert';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../core/strings.dart';
import '../core/widgets.dart';
import 'paywall.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool busy = false;
  Future<void> action(Future<void> Function() callback) async {
    setState(() => busy = true);
    try {
      await callback();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(controllerProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      children: [
        Text(
          context.t('settings'),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 24),
        Surface(
          child: Row(
            children: [
              const CircleAvatar(
                radius: 27,
                child: Icon(Icons.person_outline, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.user?.name ?? '',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      c.user?.email ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      c.user?.currency ?? '',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        SectionHeading(context.t('appearance')),
        Surface(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              SwitchListTile(
                title: Text(context.t('dark_mode')),
                secondary: const Icon(Icons.dark_mode_outlined),
                value: c.dark,
                onChanged: c.setDark,
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(context.t('language')),
                trailing: DropdownButton<String>(
                  value: c.locale,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'ar', child: Text('العربية')),
                  ],
                  onChanged: (v) => c.setLocale(v!),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        SectionHeading(context.t('subscription')),
        Surface(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: Text(context.t(c.premium ? 'premium' : 'free')),
                subtitle: Text(
                  context.t(c.premium ? 'premium_active' : 'free_limits'),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openPaywall(context),
              ),
              ListTile(
                enabled: !busy && !c.demo,
                leading: const Icon(Icons.refresh),
                title: Text(context.t('refresh_subscription')),
                onTap: () => action(() async {
                  final active = await c.syncBilling();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.t(
                            active ? 'premium_active' : 'restore_empty',
                          ),
                        ),
                      ),
                    );
                  }
                }),
              ),
              ListTile(
                enabled: !busy && !c.demo,
                leading: const Icon(Icons.open_in_new),
                title: Text(context.t('manage_subscription')),
                onTap: () => action(() async {
                  final url = await c.billing.managementUrl(c.user!.id);
                  if (url == null) throw const ApiFailure('restore_empty');
                  if (!await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  )) {
                    throw const ApiFailure('billing_unavailable');
                  }
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        SectionHeading(context.t('account')),
        Surface(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              ListTile(
                enabled: !busy,
                leading: const Icon(Icons.file_download_outlined),
                title: Text(context.t('export')),
                subtitle: Text(context.s.month(c.month)),
                trailing: c.premium
                    ? null
                    : const Icon(Icons.lock_outline, size: 18),
                onTap: () {
                  if (!c.premium) {
                    openPaywall(context);
                    return;
                  }
                  action(() async {
                    final csv = await c.repository.export(monthKey(c.month));
                    final name = 'masar-${monthKey(c.month)}.csv';
                    final file = XFile.fromData(
                      Uint8List.fromList(utf8.encode(csv)),
                      name: name,
                      mimeType: 'text/csv',
                    );
                    // Native mobile uses the share sheet; supported web browsers offer file sharing or download.
                    if (!context.mounted) return;
                    final box = context.findRenderObject() as RenderBox?;
                    final origin = box == null
                        ? const Rect.fromLTWH(0, 0, 100, 100)
                        : box.localToGlobal(Offset.zero) & box.size;
                    await SharePlus.instance.share(
                      ShareParams(
                        files: [file],
                        fileNameOverrides: [name],
                        sharePositionOrigin: origin,
                      ),
                    );
                  });
                },
              ),
              ListTile(
                enabled: !busy,
                leading: const Icon(Icons.logout),
                title: Text(context.t('logout')),
                onTap: () => action(c.logout),
              ),
              ListTile(
                enabled: !busy,
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  context.t('delete_account'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => const DeleteAccountDialog(),
                ),
              ),
            ],
          ),
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
        const SizedBox(height: 28),
        if (c.demo)
          Text(
            context.t('demo_note'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 8),
        const Center(child: Text('Masar 1.0', style: TextStyle(fontSize: 12))),
      ],
    );
  }
}

class DeleteAccountDialog extends ConsumerStatefulWidget {
  const DeleteAccountDialog({super.key});
  @override
  ConsumerState<DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  final password = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.t('delete_account')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.t('delete_account_note')),
          const SizedBox(height: 18),
          if (error != null) ErrorBanner(error!),
          TextField(
            controller: password,
            obscureText: true,
            decoration: InputDecoration(labelText: context.t('password')),
          ),
        ],
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
                setState(() => busy = true);
                try {
                  await ref
                      .read(controllerProvider)
                      .deleteAccount(password.text);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (mounted) {
                    setState(() {
                      busy = false;
                      error = errorCode(e);
                    });
                  }
                }
              },
        child: Text(context.t('delete_account')),
      ),
    ],
  );
}
