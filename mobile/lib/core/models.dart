import 'package:uuid/uuid.dart';

const expenseCategories = [
  'food',
  'groceries',
  'transport',
  'shopping',
  'bills',
  'health',
  'entertainment',
  'other',
];
String monthKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';
String dayKey(DateTime date) =>
    '${monthKey(date)}-${date.day.toString().padLeft(2, '0')}';

/// Parse decimal text without a floating-point round-trip. Supported currencies all have 2 minor digits.
int? parseMoney(String input) {
  var value = input.trim();
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  for (var i = 0; i < 10; i++) {
    value = value.replaceAll(arabic[i], '$i').replaceAll(persian[i], '$i');
  }
  value = value.replaceAll('٫', '.');
  if (!RegExp(r'^\d{1,11}(\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final minor =
      int.parse(parts.first) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return minor > 0 && minor <= 1000000000000 ? minor : null;
}

String decimalMoney(int value) =>
    '${value ~/ 100}.${(value % 100).toString().padLeft(2, '0')}';

class AppUser {
  final String id, name, email, currency, locale;
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.currency,
    required this.locale,
  });
  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: j['id'],
    name: j['name'],
    email: j['email'],
    currency: j['currency'],
    locale: j['locale'],
  );
}

class Expense {
  final String id, clientId, kind, category, note;
  final int amount;
  final DateTime date;
  const Expense({
    required this.id,
    required this.clientId,
    required this.kind,
    required this.category,
    required this.note,
    required this.amount,
    required this.date,
  });
  bool get isIncome => kind == 'income';
  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id: j['id'],
    clientId: j['client_id'],
    kind: j['kind'],
    category: j['category'],
    note: j['note'],
    amount: j['amount_minor'],
    date: DateTime.parse(j['occurred_on']),
  );
  Map<String, dynamic> toJson() => {
    'client_id': clientId,
    'kind': kind,
    'category': category,
    'note': note,
    'amount_minor': amount,
    'occurred_on': dayKey(date),
  };
  factory Expense.draft({
    required int amount,
    required String kind,
    required String category,
    required String note,
    required DateTime date,
    String? clientId,
  }) => Expense(
    id: '',
    clientId: clientId ?? const Uuid().v4(),
    kind: kind,
    category: category,
    note: note,
    amount: amount,
    date: date,
  );
}

class Budget {
  final String id, month, category;
  final int limit, spent;
  const Budget({
    required this.id,
    required this.month,
    required this.category,
    required this.limit,
    required this.spent,
  });
  double get progress => (spent / limit).clamp(0, 1);
  factory Budget.fromJson(Map<String, dynamic> j) => Budget(
    id: j['id'],
    month: j['month'],
    category: j['category'],
    limit: j['limit_minor'],
    spent: j['spent_minor'] ?? 0,
  );
}

class Overview {
  final int income, expense, balance;
  final Map<String, int> categories;
  final List<int> daily;
  const Overview({
    this.income = 0,
    this.expense = 0,
    this.balance = 0,
    this.categories = const {},
    this.daily = const [],
  });
  factory Overview.fromJson(Map<String, dynamic> j) => Overview(
    income: j['income_minor'],
    expense: j['expense_minor'],
    balance: j['balance_minor'],
    categories: Map<String, int>.from(j['categories']),
    daily: List<int>.from(j['daily_minor']),
  );
}

class ApiFailure implements Exception {
  final String code;
  const ApiFailure(this.code);
  @override
  String toString() => code;
}
