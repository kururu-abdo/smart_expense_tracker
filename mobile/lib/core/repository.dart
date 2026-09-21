import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import 'api.dart';
import 'models.dart';

abstract class ExpenseRepository {
  Future<List<Expense>> transactions(String month);
  Future<Overview> overview(String month);
  Future<List<Budget>> budgets(String month);
  Future<bool> premium();
  Future<void> saveExpense(Expense expense);
  Future<void> deleteExpense(String id);
  Future<void> saveBudget(String month, String category, int limit);
  Future<void> deleteBudget(String id);
  Future<Map<String, dynamic>> parse(String text);
  Future<Map<String, dynamic>> insights(String month);
  Future<String> export(String month);
}

class RemoteRepository extends ExpenseRepository {
  final Api api;
  RemoteRepository(this.api);
  @override
  Future<List<Expense>> transactions(String month) async {
    final rows = <Expense>[];
    while (true) {
      final data = await api.request(
        'GET',
        '/transactions',
        query: {'month': month, 'offset': rows.length, 'limit': 200},
      );
      final batch = (data['items'] as List)
          .map((j) => Expense.fromJson(j))
          .toList();
      rows.addAll(batch);
      if (batch.isEmpty || rows.length >= data['total']) break;
    }
    return rows;
  }

  @override
  Future<Overview> overview(String month) async => Overview.fromJson(
    await api.request('GET', '/overview', query: {'month': month}),
  );
  @override
  Future<List<Budget>> budgets(String month) async =>
      ((await api.request('GET', '/budgets', query: {'month': month})) as List)
          .map((j) => Budget.fromJson(j))
          .toList();
  @override
  Future<bool> premium() async =>
      (await api.request('GET', '/billing/status'))['premium'] == true;
  @override
  Future<void> saveExpense(Expense expense) async {
    await api.request(
      expense.id.isEmpty ? 'POST' : 'PUT',
      expense.id.isEmpty ? '/transactions' : '/transactions/${expense.id}',
      data: expense.toJson(),
    );
  }

  @override
  Future<void> deleteExpense(String id) async {
    await api.request('DELETE', '/transactions/$id');
  }

  @override
  Future<void> saveBudget(String month, String category, int limit) async {
    await api.request(
      'PUT',
      '/budgets',
      data: {'month': month, 'category': category, 'limit_minor': limit},
    );
  }

  @override
  Future<void> deleteBudget(String id) async {
    await api.request('DELETE', '/budgets/$id');
  }

  @override
  Future<Map<String, dynamic>> parse(String text) async =>
      Map<String, dynamic>.from(
        await api.request('POST', '/smart/parse', data: {'text': text}),
      );
  @override
  Future<Map<String, dynamic>> insights(String month) async =>
      Map<String, dynamic>.from(
        await api.request('GET', '/insights', query: {'month': month}),
      );
  @override
  Future<String> export(String month) async =>
      await api.request(
            'GET',
            '/export.csv',
            query: {'month': month},
            text: true,
          )
          as String;
}

/// An explicitly labeled in-memory sandbox. Demo records never enter a real account.
class DemoRepository extends ExpenseRepository {
  final List<Expense> _rows = [];
  final List<Budget> _budgets = [];
  DemoRepository({DateTime? today}) {
    final now = today ?? DateTime.now();
    void add(
      String note,
      String category,
      int amount,
      int day, {
      bool income = false,
    }) {
      final id = const Uuid().v4();
      _rows.add(
        Expense(
          id: id,
          clientId: id,
          kind: income ? 'income' : 'expense',
          category: category,
          note: note,
          amount: amount,
          date: DateTime(now.year, now.month, math.min(day, now.day)),
        ),
      );
    }

    add('Monthly salary • الراتب', 'salary', 1250000, 1, income: true);
    add('Apartment • إيجار الشقة', 'bills', 320000, 2);
    add('Weekly groceries • بقالة', 'groceries', 28650, 5);
    add('Lunch with friends • غداء', 'food', 14500, 9);
    add('New sneakers • حذاء', 'shopping', 34900, 11);
    add('Fuel • بنزين', 'transport', 12500, 13);
    add('Cinema • سينما', 'entertainment', 7500, 15);
    add('Morning coffee • قهوة', 'food', 1850, now.day);
    for (final entry in {
      'food': 80000,
      'groceries': 120000,
      'transport': 60000,
    }.entries) {
      _budgets.add(
        Budget(
          id: const Uuid().v4(),
          month: monthKey(now),
          category: entry.key,
          limit: entry.value,
          spent: 0,
        ),
      );
    }
  }
  @override
  Future<List<Expense>> transactions(String month) async =>
      _rows.where((r) => monthKey(r.date) == month).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  @override
  Future<Overview> overview(String month) async {
    final rows = await transactions(month);
    final start = DateTime.parse('$month-01');
    final daily = List.filled(DateTime(start.year, start.month + 1, 0).day, 0);
    final categories = <String, int>{};
    var income = 0, expense = 0;
    for (final row in rows) {
      if (row.isIncome) {
        income += row.amount;
      } else {
        expense += row.amount;
        categories.update(
          row.category,
          (v) => v + row.amount,
          ifAbsent: () => row.amount,
        );
        daily[row.date.day - 1] += row.amount;
      }
    }
    return Overview(
      income: income,
      expense: expense,
      balance: income - expense,
      categories: categories,
      daily: daily,
    );
  }

  @override
  Future<List<Budget>> budgets(String month) async {
    final sums = (await overview(month)).categories;
    return _budgets
        .where((b) => b.month == month)
        .map(
          (b) => Budget(
            id: b.id,
            month: b.month,
            category: b.category,
            limit: b.limit,
            spent: sums[b.category] ?? 0,
          ),
        )
        .toList();
  }

  @override
  Future<bool> premium() async => false;
  @override
  Future<void> saveExpense(Expense expense) async {
    _rows.removeWhere(
      (e) => e.id == expense.id || e.clientId == expense.clientId,
    );
    _rows.add(
      Expense(
        id: expense.id.isEmpty ? const Uuid().v4() : expense.id,
        clientId: expense.clientId,
        kind: expense.kind,
        category: expense.category,
        note: expense.note,
        amount: expense.amount,
        date: expense.date,
      ),
    );
  }

  @override
  Future<void> deleteExpense(String id) async {
    _rows.removeWhere((e) => e.id == id);
  }

  @override
  Future<void> saveBudget(String month, String category, int limit) async {
    final exists = _budgets.any(
      (b) => b.month == month && b.category == category,
    );
    if (!exists && _budgets.where((b) => b.month == month).length >= 3) {
      throw const ApiFailure('premium_required');
    }
    _budgets.removeWhere((b) => b.month == month && b.category == category);
    _budgets.add(
      Budget(
        id: const Uuid().v4(),
        month: month,
        category: category,
        limit: limit,
        spent: 0,
      ),
    );
  }

  @override
  Future<void> deleteBudget(String id) async {
    _budgets.removeWhere((b) => b.id == id);
  }

  @override
  Future<Map<String, dynamic>> parse(String text) async {
    var normalized = text;
    for (var i = 0; i < 10; i++) {
      normalized = normalized.replaceAll('٠١٢٣٤٥٦٧٨٩'[i], '$i');
    }
    normalized = normalized.replaceAll('٫', '.');
    final amounts = RegExp(r'\d+(?:\.\d+)?').allMatches(normalized).toList();
    final words = {
      'food': ['coffee', 'lunch', 'قهوة', 'مطعم'],
      'transport': ['taxi', 'fuel', 'تاكسي', 'بنزين'],
      'groceries': ['grocery', 'بقالة'],
      'salary': ['salary', 'راتب'],
    };
    final category =
        words.entries
            .where((e) => e.value.any((w) => text.toLowerCase().contains(w)))
            .map((e) => e.key)
            .firstOrNull ??
        'other';
    return {
      'amount_minor':
          amounts.length == 1 && !RegExp(r'[-,٬]').hasMatch(normalized)
          ? parseMoney(amounts.single.group(0)!)
          : null,
      'category': category,
      'kind': category == 'salary' ? 'income' : 'expense',
    };
  }

  @override
  Future<Map<String, dynamic>> insights(String month) async =>
      throw const ApiFailure('premium_required');
  @override
  Future<String> export(String month) async =>
      throw const ApiFailure('premium_required');
}
