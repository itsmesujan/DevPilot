import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'services/storage/storage_service.dart';
import 'services/storage/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait + portrait-up on phones
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Init core services before UI
  await AppDatabase.instance.init();
  await StorageService.instance.init();

  runApp(const ProviderScope(child: DevPilotApp()));
}

class DevPilotApp extends ConsumerWidget {
  const DevPilotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = StorageService.instance.darkMode;
    return MaterialApp.router(
      title: 'DevPilot Edge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: appRouter,
    );
  }
}
