import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'services/storage/storage_service.dart';
import 'services/storage/app_database.dart';
import 'services/agent/skills/skill_manager.dart';
import 'services/rag/rag_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation — support portrait + landscape
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Init core services
  await AppDatabase.instance.init();
  await StorageService.instance.init();

  // Init async services in background
  SkillManager.instance.initialize().catchError((_) {});
  RagService.instance.initializeMiniLM().catchError((_) {});

  runApp(const ProviderScope(child: DevPilotApp()));
}

class DevPilotApp extends StatelessWidget {
  const DevPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DevPilot Edge',
      debugShowCheckedModeBanner: false,
      // Always use dark theme — the premium OLED dark experience
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
    );
  }
}
