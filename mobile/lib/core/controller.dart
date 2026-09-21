import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'billing.dart';
import 'models.dart';
import 'repository.dart';

final controllerProvider = ChangeNotifierProvider<AppController>(
  (ref) => throw UnimplementedError('Override at bootstrap'),
);

class AppController extends ChangeNotifier {
  final SharedPreferences preferences;
  final Api api;
  final BillingService billing;
  late ExpenseRepository repository;
  AppUser? user;
  String locale = 'en';
  bool dark = false,
      restoring = true,
      loading = false,
      demo = false,
      premium = false;
  String? error;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  Overview overview = const Overview();
  List<Expense> expenses = [];
  List<Budget> budgets = [];
  int _generation = 0;
  AppController(
    this.preferences, {
    Api? apiClient,
    BillingService? billingService,
  }) : api = apiClient ?? Api(),
       billing = billingService ?? BillingService() {
    repository = RemoteRepository(api);
    locale = preferences.getString('locale') ?? 'en';
    dark = preferences.getBool('dark') ?? false;
  }

  Future<void> initialize() async {
    restoring = true;
    error = null;
    notifyListeners();
    try {
      await api.restore();
      if (api.accessToken != null) {
        user = AppUser.fromJson(await api.request('GET', '/auth/me'));
        await refresh();
      }
    } catch (e) {
      error = errorCode(e);
    }
    restoring = false;
    notifyListeners();
  }

  Future<void> authenticate({
    required String email,
    required String password,
    String? name,
    String currency = 'SAR',
  }) async {
    final data = await api.request(
      'POST',
      name == null ? '/auth/login' : '/auth/register',
      auth: false,
      data: {
        'email': email,
        'password': password,
        if (name != null) ...{
          'name': name,
          'currency': currency,
          'locale': locale,
        },
      },
    );
    await api.saveTokens(Map<String, dynamic>.from(data));
    user = AppUser.fromJson(data['user']);
    demo = false;
    repository = RemoteRepository(api);
    await refresh();
  }

  Future<void> startDemo({DateTime? today}) async {
    user = const AppUser(
      id: 'demo',
      name: 'Alex',
      email: 'demo@example.com',
      currency: 'SAR',
      locale: 'en',
    );
    demo = true;
    restoring = false;
    if (today != null) month = DateTime(today.year, today.month);
    repository = DemoRepository(today: today);
    await refresh();
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    final selectedMonth = monthKey(month);
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        repository.transactions(selectedMonth),
        repository.overview(selectedMonth),
        repository.budgets(selectedMonth),
        repository.premium(),
      ]);
      if (generation != _generation) return;
      expenses = results[0] as List<Expense>;
      overview = results[1] as Overview;
      budgets = results[2] as List<Budget>;
      premium = results[3] as bool;
    } catch (e) {
      if (generation != _generation) return;
      error = errorCode(e);
      if (error == 'session_expired') {
        await api.clear();
        user = null;
      }
    }
    if (generation == _generation) {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> changeMonth(int offset) async {
    month = DateTime(month.year, month.month + offset);
    expenses = [];
    overview = const Overview();
    budgets = [];
    await refresh();
  }

  Future<void> setLocale(String value) async {
    locale = value;
    await preferences.setString('locale', value);
    notifyListeners();
  }

  Future<void> setDark(bool value) async {
    dark = value;
    await preferences.setBool('dark', value);
    notifyListeners();
  }

  Future<void> saveExpense(Expense expense) async {
    await repository.saveExpense(expense);
    await refresh();
  }

  Future<void> deleteExpense(String id) async {
    await repository.deleteExpense(id);
    await refresh();
  }

  Future<void> saveBudget(String category, int limit) async {
    await repository.saveBudget(monthKey(month), category, limit);
    await refresh();
  }

  Future<void> deleteBudget(String id) async {
    await repository.deleteBudget(id);
    await refresh();
  }

  Future<bool> syncBilling() async {
    final data = await api.request('POST', '/billing/sync');
    premium = data['premium'] == true;
    notifyListeners();
    return premium;
  }

  Future<void> logout() async {
    if (!demo && api.refreshToken != null) {
      try {
        await api.request(
          'POST',
          '/auth/logout',
          data: {'refresh_token': api.refreshToken},
        );
      } catch (_) {
        /* Local logout still clears credentials when offline. */
      }
    }
    await api.clear();
    try {
      await billing.logout();
    } catch (_) {
      /* Next identify binds the SDK to the authenticated UUID. */
    }
    _generation++;
    user = null;
    demo = false;
    premium = false;
    error = null;
    expenses = [];
    budgets = [];
    overview = const Overview();
    notifyListeners();
  }

  Future<void> deleteAccount(String password) async {
    if (!demo) {
      await api.request('DELETE', '/auth/me', data: {'password': password});
    }
    await logout();
  }
}

String errorCode(Object error) =>
    error is ApiFailure ? error.code : 'something_wrong';
