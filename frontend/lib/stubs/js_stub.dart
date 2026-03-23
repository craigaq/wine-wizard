/// Stub for dart:js on non-web platforms (Android, iOS, desktop).
/// Provides a no-op [context] so js.context.callMethod() compiles but does
/// nothing — the Web Audio chime is silently skipped on mobile.
final context = _JsStubContext();

class _JsStubContext {
  void callMethod(String method, [List<dynamic>? args]) {
    // No-op on non-web platforms.
  }
}
