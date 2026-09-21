import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/controller.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  bool signup = false, busy = false, obscure = true;
  String currency = 'SAR';
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(controllerProvider)
          .authenticate(
            email: email.text.trim(),
            password: password.text,
            name: signup ? name.text.trim() : null,
            currency: currency,
          );
    } catch (e) {
      if (mounted) setState(() => error = errorCode(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(controllerProvider);
    final hero = Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: ink,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Brand(light: true),
          const SizedBox(height: 38),
          Text(
            context.t('auth_title'),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontSize: 38,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            context.t('auth_description'),
            style: const TextStyle(color: Color(0xFFC1D3C9), height: 1.7),
          ),
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: lime,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const Icon(Icons.spa_outlined, color: ink, size: 35),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    context.t('tagline'),
                    style: const TextStyle(
                      color: ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final fields = Form(
      key: form,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.t(signup ? 'create_account' : 'welcome'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => c.setLocale(c.locale == 'ar' ? 'en' : 'ar'),
                  child: Text(c.locale == 'ar' ? 'English' : 'العربية'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (error != null || c.error != null)
              ErrorBanner(
                error ?? c.error!,
                retry: c.error != null ? c.initialize : null,
              ),
            if (signup) ...[
              TextFormField(
                controller: name,
                maxLength: 80,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: InputDecoration(
                  labelText: context.t('name'),
                  counterText: '',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? context.t('required')
                    : null,
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: context.t('email'),
                prefixIcon: const Icon(Icons.alternate_email),
              ),
              validator: (v) =>
                  v == null ||
                      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())
                  ? context.t('invalid_email')
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: password,
              obscureText: obscure,
              maxLength: 128,
              autofillHints: [
                signup ? AutofillHints.newPassword : AutofillHints.password,
              ],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                if (!busy) submit();
              },
              decoration: InputDecoration(
                labelText: context.t('password'),
                counterText: '',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: context.t('password'),
                  onPressed: () => setState(() => obscure = !obscure),
                  icon: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (v) => v == null || v.isEmpty
                  ? context.t('required')
                  : signup && v.length < 10
                  ? context.t('password_short')
                  : null,
            ),
            if (signup) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: currency,
                decoration: InputDecoration(labelText: context.t('currency')),
                items: ['SAR', 'USD', 'AED', 'EGP']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => currency = v!),
              ),
              const SizedBox(height: 8),
              Text(
                context.t('currency_hint'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : submit,
              child: busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.t(signup ? 'signup' : 'login')),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      signup = !signup;
                      error = null;
                    }),
              child: Text(context.t(signup ? 'have_account' : 'new_here')),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : c.startDemo,
              icon: const Icon(Icons.explore_outlined),
              label: Text(context.t('demo_button')),
            ),
          ],
        ),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: LayoutBuilder(
                builder: (context, constraints) => Enter(
                  child: constraints.maxWidth > 750
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: hero),
                            const SizedBox(width: 48),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: fields,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [hero, const SizedBox(height: 30), fields],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
