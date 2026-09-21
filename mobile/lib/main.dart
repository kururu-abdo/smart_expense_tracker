import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/controller.dart';
import 'core/strings.dart';
import 'core/theme.dart';
import 'core/widgets.dart';
import 'features/auth_screen.dart';
import 'features/budgets_screen.dart';
import 'features/dashboard.dart';
import 'features/expense_editor.dart';
import 'features/paywall.dart';
import 'features/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        controllerProvider.overrideWith(
          (ref) => AppController(preferences)..initialize(),
        ),
      ],
      child: const MasarApp(),
    ),
  );
}

class MasarApp extends ConsumerWidget {
  const MasarApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(controllerProvider);
    return MaterialApp(
      key: ValueKey(c.user?.id ?? 'signed-out'),
      title: 'Masar • مسار',
      debugShowCheckedModeBanner: false,
      locale: Locale(c.locale),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        Strings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: appTheme(false, c.locale == 'ar'),
      darkTheme: appTheme(true, c.locale == 'ar'),
      themeMode: c.dark ? ThemeMode.dark : ThemeMode.light,
      home: c.restoring
          ? const _LoadingScreen()
          : c.user == null
          ? const AuthScreen()
          : const AppShell(),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Brand(),
          const SizedBox(height: 30),
          const CircularProgressIndicator(strokeWidth: 2),
          const SizedBox(height: 20),
          Text(context.t('loading')),
        ],
      ),
    ),
  );
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  int tab = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final c = ref.read(controllerProvider);
      if (c.user != null && !c.loading) c.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(controllerProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final labels = ['home', 'activity', 'budgets', 'settings'];
    final icons = [
      Icons.grid_view_rounded,
      Icons.swap_vert_rounded,
      Icons.donut_large_rounded,
      Icons.tune_rounded,
    ];
    final pages = [
      Dashboard(onActivity: () => setState(() => tab = 1)),
      const ActivityScreen(),
      const BudgetsScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: const Padding(
          padding: EdgeInsetsDirectional.only(start: 8),
          child: Brand(),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => openPaywall(context),
            icon: const Icon(Icons.auto_awesome_outlined, size: 17),
            label: Text(context.t(c.premium ? 'premium' : 'upgrade')),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (c.demo)
              Container(
                width: double.infinity,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .07),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  context.t('demo'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Expanded(
              child: Row(
                children: [
                  if (wide)
                    NavigationRail(
                      selectedIndex: tab,
                      labelType: NavigationRailLabelType.all,
                      onDestinationSelected: (index) =>
                          setState(() => tab = index),
                      destinations: List.generate(
                        4,
                        (i) => NavigationRailDestination(
                          icon: Icon(icons[i]),
                          label: Text(context.t(labels[i])),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: AnimatedSwitcher(
                          duration: Duration(
                            milliseconds:
                                MediaQuery.disableAnimationsOf(context)
                                ? 0
                                : 250,
                          ),
                          child: KeyedSubtree(
                            key: ValueKey(tab),
                            child: pages[tab],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: tab == 3
          ? null
          : FloatingActionButton.extended(
              onPressed: () => openExpense(context),
              backgroundColor: ink,
              foregroundColor: lime,
              icon: const Icon(Icons.add),
              label: Text(context.t('add_expense')),
            ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (index) => setState(() => tab = index),
              destinations: List.generate(
                4,
                (i) => NavigationDestination(
                  icon: Icon(icons[i]),
                  label: context.t(labels[i]),
                ),
              ),
            ),
    );
  }
}
