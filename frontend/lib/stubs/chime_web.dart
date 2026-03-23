// Web implementation — calls the JavaScript playMagicChime() function.
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void playMagicChime() => js.context.callMethod('playMagicChime');
