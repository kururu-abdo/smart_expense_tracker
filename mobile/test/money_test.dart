import 'package:flutter_test/flutter_test.dart';
import 'package:masar/core/models.dart';
import 'package:masar/core/repository.dart';

void main() {
  test('Money parses exactly in English, Arabic and Persian', () {
    expect(parseMoney('0.10'), 10);
    expect(parseMoney('0.29'), 29);
    expect(parseMoney('١٨٫٥٠'), 1850);
    expect(parseMoney('۱۸٫۵۰'), 1850);
    expect(parseMoney('100.1'), 10010);
    for (final invalid in ['0', '-5', '1.001', '1,500', 'NaN', '1e5', '']) {
      expect(parseMoney(invalid), isNull, reason: invalid);
    }
  });
  test('Demo edits update totals without creating duplicates', () async {
    final repo = DemoRepository(today: DateTime(2026, 9, 20));
    final before = await repo.overview('2026-09');
    final entry = Expense.draft(
      amount: 10,
      kind: 'expense',
      category: 'other',
      note: 'test',
      date: DateTime(2026, 9, 20),
    );
    await repo.saveExpense(entry);
    await repo.saveExpense(entry);
    final after = await repo.overview('2026-09');
    expect(after.expense, before.expense + 10);
    expect(
      (await repo.transactions(
        '2026-09',
      )).where((e) => e.clientId == entry.clientId).length,
      1,
    );
    expect((await repo.overview('2026-08')).expense, 0);
  });
  test('Free demo cannot create a fourth budget', () async {
    final repo = DemoRepository(today: DateTime(2026, 9, 20));
    await expectLater(
      repo.saveBudget('2026-09', 'bills', 10000),
      throwsA(isA<ApiFailure>()),
    );
    await repo.saveBudget('2026-09', 'food', 20000);
    expect((await repo.budgets('2026-09')).length, 3);
  });
}
