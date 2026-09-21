import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Strings {
  final String language;
  const Strings(this.language);
  bool get ar => language == 'ar';
  String t(String key) => _words[key]?[ar ? 1 : 0] ?? key;
  String money(int minor, [String currency = 'SAR']) => NumberFormat.currency(
    locale: ar ? 'ar_SA' : 'en_US',
    symbol: currency == 'SAR' && ar ? 'ر.س' : currency,
    decimalDigits: 2,
  ).format(minor / 100);
  String month(DateTime value) => DateFormat.yMMMM(language).format(value);
  String date(DateTime value) => DateFormat.MMMd(language).format(value);
  static Strings of(BuildContext context) =>
      Localizations.of<Strings>(context, Strings)!;
  static const delegate = _StringsDelegate();
}

class _StringsDelegate extends LocalizationsDelegate<Strings> {
  const _StringsDelegate();
  @override
  bool isSupported(Locale locale) => ['ar', 'en'].contains(locale.languageCode);
  @override
  Future<Strings> load(Locale locale) =>
      SynchronousFuture(Strings(locale.languageCode));
  @override
  bool shouldReload(_StringsDelegate old) => false;
}

extension AppText on BuildContext {
  Strings get s => Strings.of(this);
  String t(String key) => s.t(key);
}

const _words = <String, List<String>>{
  'app': ['Masar', 'مسار'],
  'tagline': ['Make room for what matters.', 'خلّي مساحة للحاجات المهمة.'],
  'auth_title': ['Your money.\nA clearer picture.', 'فلوسك.\nصورة أوضح.'],
  'auth_description': [
    'Small daily habits. A little more freedom.\nMeet your calmer money companion.',
    'عادات يومية بسيطة، وراحة أكبر.\nرفيقك لترتيب المصاريف بكل سهولة.',
  ],
  'welcome': ['Welcome back', 'أهلاً برجعتك'],
  'create_account': ['Create your account', 'أنشئ حسابك'],
  'login': ['Sign in', 'تسجيل الدخول'],
  'signup': ['Create account', 'إنشاء حساب'],
  'email': ['Email address', 'البريد الإلكتروني'],
  'password': ['Password', 'كلمة المرور'],
  'name': ['Your name', 'اسمك'],
  'currency': ['Account currency', 'عملة الحساب'],
  'currency_hint': [
    'All entries use this currency. It stays fixed for this account.',
    'كل العمليات بهذه العملة، وتبقى ثابتة لهذا الحساب.',
  ],
  'new_here': ['New here? Create an account', 'جديد هنا؟ أنشئ حسابك'],
  'have_account': ['Already a member? Sign in', 'عندك حساب؟ سجّل دخولك'],
  'demo_button': ['Explore the demo', 'جرّب النسخة التجريبية'],
  'demo': ['DEMO · SAMPLE DATA', 'تجريبي · بيانات توضيحية'],
  'demo_note': [
    'Changes in the demo reset when you leave.',
    'تتصفّر بيانات التجربة بعد الخروج.',
  ],
  'home': ['Overview', 'الرئيسية'],
  'activity': ['Activity', 'العمليات'],
  'budgets': ['Budgets', 'الميزانيات'],
  'settings': ['Settings', 'الإعدادات'],
  'hello': ['Hello', 'أهلاً'],
  'dashboard_title': [
    'A little clarity.\nA lot more possibility.',
    'وضوح أكتر.\nفرص أكبر.',
  ],
  'month_balance': ['This month’s balance', 'رصيد الشهر'],
  'balance_hint': ['Income minus expenses', 'الدخل ناقص المصروفات'],
  'income': ['Income', 'الدخل'],
  'expense': ['Expense', 'مصروف'],
  'expenses': ['Expenses', 'المصروفات'],
  'spending': ['Spending rhythm', 'حركة المصروفات'],
  'spending_hint': [
    'Your daily spending, at a glance',
    'مصروفاتك اليومية في نظرة',
  ],
  'recent': ['Recent activity', 'آخر العمليات'],
  'see_all': ['See all', 'عرض الكل'],
  'add_expense': ['Add transaction', 'إضافة عملية'],
  'edit_expense': ['Edit transaction', 'تعديل العملية'],
  'amount': ['Amount', 'المبلغ'],
  'category': ['Category', 'التصنيف'],
  'note': ['What was it for?', 'المبلغ ده كان لشنو؟'],
  'date': ['Date', 'التاريخ'],
  'save': ['Save', 'حفظ'],
  'cancel': ['Cancel', 'إلغاء'],
  'delete': ['Delete', 'حذف'],
  'delete_confirm': ['Delete this item?', 'حذف العنصر ده؟'],
  'delete_detail': [
    'This action cannot be undone.',
    'ما بتقدر ترجع العنصر بعد الحذف.',
  ],
  'smart_entry': ['Type it naturally', 'اكتبها بطريقتك'],
  'smart_hint': ['Coffee 18.50 SAR', 'قهوة ١٨٫٥٠ ريال'],
  'suggest': ['Fill details', 'تعبئة التفاصيل'],
  'confirm_suggestion': [
    'Check the suggested details before saving.',
    'راجع التفاصيل المقترحة قبل الحفظ.',
  ],
  'food': ['Food & coffee', 'أكل وقهوة'],
  'groceries': ['Groceries', 'مقاضي'],
  'transport': ['Transport', 'مواصلات'],
  'shopping': ['Shopping', 'تسوق'],
  'bills': ['Bills & rent', 'فواتير وإيجار'],
  'health': ['Health', 'صحة'],
  'entertainment': ['Entertainment', 'ترفيه'],
  'other': ['Other', 'أخرى'],
  'salary': ['Salary', 'راتب'],
  'all': ['All', 'الكل'],
  'search': ['Search your transactions', 'ابحث في عملياتك'],
  'no_activity': ['Your next chapter starts here', 'بدايتك الجديدة من هنا'],
  'no_activity_detail': [
    'Add your first transaction to see your money take shape.',
    'أضف أول عملية عشان تشوف صورة مصروفاتك.',
  ],
  'no_results': ['No matching transactions', 'ما لقينا عمليات مطابقة'],
  'budget_title': ['Give every goal\na little space.', 'خلّي لكل هدف\nمساحة.'],
  'budget_subtitle': [
    'Monthly limits that keep you on your path.',
    'حدود شهرية تساعدك تمشي في مسارك.',
  ],
  'add_budget': ['Set a budget', 'تحديد ميزانية'],
  'edit_budget': ['Edit budget', 'تعديل الميزانية'],
  'monthly_limit': ['Monthly limit', 'الحد الشهري'],
  'remaining': ['left to spend', 'متبقي للصرف'],
  'over_budget': ['over budget', 'فوق الميزانية'],
  'budget_empty': ['A plan makes all the difference', 'الخطة بتعمل فرق'],
  'budget_empty_detail': [
    'Choose a category and a monthly limit to get started.',
    'اختر تصنيف وحدد المبلغ الشهري عشان تبدأ.',
  ],
  'free_limits': [
    'Free includes 3 budgets per month',
    'المجاني يشمل ٣ ميزانيات كل شهر',
  ],
  'breakdown': ['Where it went', 'فلوسك مشت وين؟'],
  'insights': ['Your spending insights', 'تحليل مصروفاتك'],
  'insight_teaser': [
    'See the patterns.\nFind your breathing room.',
    'شوف عاداتك.\nولقّى مساحة للتوفير.',
  ],
  'insight_detail': [
    'Understand your top categories and monthly spending pace with Premium.',
    'اعرف أكبر تصنيفات الصرف وتقدير مصروفات الشهر مع بريميوم.',
  ],
  'projection': ['Estimated month-end spending', 'تقدير مصروفات نهاية الشهر'],
  'period_total': ['Period spending', 'مصروفات الفترة'],
  'daily_average': ['Daily average', 'المتوسط اليومي'],
  'top_category': ['Top spending category', 'أعلى تصنيف صرف'],
  'projection_note': [
    'A simple estimate from your recorded spending so far; actual spending may differ.',
    'تقدير بسيط حسب العمليات المسجلة حتى الآن؛ المصروف الفعلي ممكن يختلف.',
  ],
  'premium': ['Premium', 'بريميوم'],
  'free': ['Free', 'مجاني'],
  'upgrade': ['Explore Premium', 'اكتشف بريميوم'],
  'premium_title': ['More clarity.\nMore control.', 'وضوح أكبر.\nتحكّم أكتر.'],
  'premium_subtitle': [
    'A little upgrade for your everyday.',
    'خطوة صغيرة تفرق في يومك.',
  ],
  'unlimited_budgets': ['Unlimited category budgets', 'ميزانيات لكل التصنيفات'],
  'premium_insights': [
    'Spending patterns & projections',
    'تحليل الصرف والتقديرات',
  ],
  'csv_export': [
    'Export monthly transactions to CSV',
    'تصدير عمليات الشهر بصيغة CSV',
  ],
  'monthly': ['Monthly', 'شهري'],
  'annual': ['Yearly', 'سنوي'],
  'continue': ['Continue', 'متابعة'],
  'restore': ['Restore purchases', 'استعادة المشتريات'],
  'restore_empty': [
    'No active subscription found for this account.',
    'ما لقينا اشتراك نشط للحساب ده.',
  ],
  'premium_active': ['Premium is active', 'بريميوم مفعّل'],
  'purchase_pending': [
    'Purchase received. Use “Refresh subscription” if access is still updating.',
    'تم استلام الشراء. حدّث الاشتراك لو المزايا لسه ما ظهرت.',
  ],
  'renewal': [
    'Subscriptions renew automatically unless canceled through your store account. Price and billing period appear above and on the store confirmation screen.',
    'يتجدد الاشتراك تلقائياً ما لم تلغه من حساب المتجر. السعر وفترة الاشتراك ظاهرين أعلاه وفي شاشة تأكيد المتجر.',
  ],
  'privacy': ['Privacy', 'الخصوصية'],
  'terms': ['Terms', 'الشروط'],
  'billing_unavailable_ui': [
    'Subscriptions will appear when the store is connected.',
    'الاشتراكات حتظهر بعد ربط المتجر.',
  ],
  'demo_purchase': [
    'Sign in to your account to subscribe.',
    'سجّل دخولك بحسابك عشان تشترك.',
  ],
  'appearance': ['Appearance', 'المظهر'],
  'dark_mode': ['Dark mode', 'الوضع الداكن'],
  'language': ['Language', 'اللغة'],
  'account': ['Account', 'الحساب'],
  'subscription': ['Your plan', 'باقتك'],
  'manage_subscription': ['Manage subscription', 'إدارة الاشتراك'],
  'refresh_subscription': ['Refresh subscription', 'تحديث الاشتراك'],
  'export': ['Export this month', 'تصدير الشهر الحالي'],
  'logout': ['Sign out', 'تسجيل الخروج'],
  'delete_account': ['Delete account', 'حذف الحساب'],
  'delete_account_note': [
    'Your expenses and account will be permanently deleted. Cancel any active store subscription separately. Enter your password to confirm.',
    'حيتم حذف حسابك وعملياتك نهائياً. ألغِ اشتراك المتجر النشط بشكل منفصل. أدخل كلمة المرور للتأكيد.',
  ],
  'retry': ['Try again', 'حاول تاني'],
  'loading': ['Getting your space ready…', 'بنجهّز مساحتك…'],
  'required': ['Please fill this in', 'أكمل الحقل ده'],
  'invalid_email': ['Enter a valid email address', 'أدخل بريد إلكتروني صحيح'],
  'password_short': ['Use at least 10 characters', 'استخدم ١٠ أحرف على الأقل'],
  'invalid_amount': [
    'Enter a positive amount with up to 2 decimals',
    'أدخل مبلغ موجب بمنزلتين عشريتين كحد أقصى',
  ],
  'invalid_credentials': [
    'Email or password is incorrect.',
    'البريد أو كلمة المرور غير صحيحة.',
  ],
  'email_unavailable': [
    'This email is already registered. Try signing in.',
    'البريد مسجّل بالفعل. جرّب تسجيل الدخول.',
  ],
  'session_expired': [
    'Your session ended. Please sign in again.',
    'انتهت الجلسة. سجّل دخولك من جديد.',
  ],
  'network_error': [
    'Could not connect. Check your connection and try again.',
    'ما قدرنا نتصل. تأكد من الاتصال وحاول تاني.',
  ],
  'something_wrong': [
    'Something went wrong. Please try again.',
    'حصلت مشكلة. حاول تاني.',
  ],
  'invalid_input': [
    'Please check the details you entered.',
    'راجع البيانات المدخلة.',
  ],
  'premium_required': [
    'This feature is included with Premium.',
    'الميزة دي متاحة مع بريميوم.',
  ],
  'billing_not_configured': [
    'Subscriptions are not available yet.',
    'الاشتراكات غير متاحة حالياً.',
  ],
  'billing_unavailable': [
    'Could not verify your subscription. Please try again.',
    'ما قدرنا نتحقق من الاشتراك. حاول تاني.',
  ],
  'rate_limited': [
    'Too many attempts. Wait a minute and try again.',
    'محاولات كتيرة. انتظر دقيقة وحاول تاني.',
  ],
  'idempotency_conflict': [
    'This entry changed. Close it and try again.',
    'العملية اتغيّرت. اقفلها وحاول تاني.',
  ],
  'budget_conflict': [
    'This budget changed. Refresh and try again.',
    'الميزانية اتغيّرت. حدّث وحاول تاني.',
  ],
  'not_found': [
    'This item is no longer available.',
    'العنصر ده ما متاح حالياً.',
  ],
  'https_required': [
    'A secure server connection is required.',
    'مطلوب اتصال آمن بالخادم.',
  ],
  'invalid_month': ['Choose a valid month.', 'اختر شهر صحيح.'],
  'export_too_large': [
    'This month has too many records for one export.',
    'عمليات الشهر كتيرة على ملف تصدير واحد.',
  ],
  'previous_month': ['Previous month', 'الشهر السابق'],
  'next_month': ['Next month', 'الشهر التالي'],
  'close': ['Close', 'إغلاق'],
  'saved': ['Saved', 'تم الحفظ'],
};
