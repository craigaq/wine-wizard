import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/age_gate_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/quiz_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const CellarSageApp());
}

enum _AppStage { ageGate, onboarding, quiz }

class CellarSageApp extends StatefulWidget {
  const CellarSageApp({super.key});

  @override
  State<CellarSageApp> createState() => _CellarSageAppState();
}

class _CellarSageAppState extends State<CellarSageApp> {
  _AppStage _stage = _AppStage.ageGate;

  void _advance() {
    setState(() {
      _stage = _AppStage.values[_stage.index + 1];
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cellar Sage',
      debugShowCheckedModeBanner: false,
      theme: WwTheme.dark(),
      darkTheme: WwTheme.dark(),
      themeMode: ThemeMode.dark,
      home: switch (_stage) {
        _AppStage.ageGate => AgeGateScreen(onConfirmed: _advance),
        _AppStage.onboarding => OnboardingScreen(onComplete: _advance),
        _AppStage.quiz => const QuizScreen(),
      },
    );
  }
}
