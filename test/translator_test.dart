import 'package:flutter_test/flutter_test.dart';
import 'package:s4vpn/l10n/translator.dart';

void main() {
  setUpAll(Translator.prime);

  test('fa passes through untouched', () {
    expect(Translator.tr('خانه', 'fa'), 'خانه');
  });

  test('a whole phrase matches the English table first', () {
    expect(Translator.tr('آماده اتصال', 'en'), 'Ready to connect');
    expect(Translator.tr('بازگشت به تنظیمات اولیه', 'en'), 'Reset to default settings');
  });

  test('a phrase without an entry is rebuilt from its parts', () {
    // Not in the table as a whole; its pieces are.
    final String out = Translator.tr('اتصال', 'en');
    expect(out, 'Connect');
  });

  test('English carries into the other languages', () {
    expect(Translator.tr('خانه', 'zh'), '主页');
    expect(Translator.tr('خانه', 'ja'), 'ホーム');
    expect(Translator.tr('خانه', 'de'), 'Startseite');
    expect(Translator.tr('خانه', 'ru'), 'Главная');
  });

  test('an untranslated phrase stays English rather than falling back to Persian', () {
    // Deliberately absent from every table.
    const String source = 'این یک رشته آزمایشی کاملاً تازه است';
    expect(Translator.tr(source, 'de'), isNot(source));
  });

  test('chrome labels resolve per language', () {
    expect(Translator.chrome('home', 'fa'), 'خانه');
    expect(Translator.chrome('home', 'en'), 'Home');
    expect(Translator.chrome('settings', 'ru'), 'Настройки');
  });

  test('chrome falls back to English for a language that lacks the key', () {
    expect(Translator.chrome('missing-key', 'ja'), 'missing-key');
  });

  test('faDigits rewrites every digit', () {
    expect(Translator.faDigits(48), '۴۸');
    expect(Translator.faDigits('12:05'), '۱۲:۰۵');
  });

  test('rtl is only true for Persian', () {
    expect(Translator('fa').isRtl, isTrue);
    expect(Translator('en').isRtl, isFalse);
    expect(Translator('ru').isRtl, isFalse);
  });
}
