# Zeus Manhwa — Client ⚡

> واجهة **Zeus Manhwa** — نفس بنية Tachimanga حرفياً: fork من
> [Suwayomi/Tachidesk-Sorayomi](https://github.com/Suwayomi/Tachidesk-Sorayomi) (MPL-2.0)
> بهوية خاصة، متصل بخادم Suwayomi (محلي مدمج 127.0.0.1:4567 أو بعيد).

## الحالة
| البند | القيمة |
|---|---|
| الأساس | Sorayomi `df37f4c` (آخر commit في main) |
| Flutter | **3.32.8 stable** (مثبّت — يتوافق مع إصدارات الحزم) |
| Dart | 3.8.1 |
| Codegen | `build_runner` — **الملفات المولّدة ملتزمة في المستودع** (71 `.g.dart/.freezed.dart` + 31 GraphQL) |
| `dart analyze` | **0 أخطاء** ✅ |
| Web build | ✅ ينجح (`flutter build web`) |
| Bundle ID | `com.zeusmanhwa.app` |
| URL Scheme | `zeusmanhwa://` (+ `mihon://` للتوافق) |

## التثبيتات الحرجة (لا تغيّرها بدون اختبار)
```yaml
# pubspec.yaml → dependency_overrides — سببها:
#   analyzer_plugin 0.12.0 (عبر riverpod_generator → custom_lint_core)
#   يتطلب analyzer <= 7.3 (publiclyExporting2 أزيلت بعدها)
#   و custom_lint_visitor 1.0.0+7.7.0 يتطلب analyzer >= 7.7
#   → الحل الوحيد المتسق: تثبيت الاثنين على 7.3.0
dependency_overrides:
  analyzer: 7.3.0
  custom_lint_visitor: 1.0.0+7.3.0
  # http 1.3.0 BrowserClient (fetch-based) يكسر graphql_flutter 5.2.0-beta.8 على الويب:
  # الطلبات المتوازية على نفس العميل تُجهض بـ "TypeError: network error".
  # 1.2.2 (XHR) هو الإصدار المجرَّب لمنصة الويب (الأندرويد/iOS غير متأثرين).
  http: 1.2.2
```
- Flutter 3.47.x **يكسر** البناء: `flex_color_scheme 8.2.0` (AppBarThemeData split) + `font_awesome_flutter` (IconData final) + `file_picker` FFI على الويب. لذلك 3.32.8.
- الملفات المولّدة ملتزمة عمداً: أي انحراف في pub resolution لن يكسر البناء.

## إعادة توليد الكود (عند تعديل GraphQL/providers/models)
```bash
dart run build_runner build --delete-conflicting-outputs --low-resources-mode
```

## البناء محلياً
```bash
flutter pub get
flutter build web          # معاينة
flutter build apk --release
flutter build ios --release --no-codesign   # يتطلب macOS
```

## CI
`.github/workflows/build.yml` — Web + APK (ubuntu) + iOS unsigned (macOS).

## الترخيص
MPL-2.0 (موروث من Sorayomi/Suwayomi). التعديلات هنا أيضاً MPL-2.0.
هوية Zeus Manhwa (الاسم/الأيقونة/الشعار) ملك خاصة.
