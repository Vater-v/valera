import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'features/home/home_page.dart';
import 'services/background/service_entry.dart';
import 'services/background/service_init.dart';
import 'core/theme/app_colors.dart';
import 'features/system_overlay/overlay_toast.dart';
import 'core/utils/global_keys.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Уведомления
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }

  // 2. Поверх окон
  if (!await FlutterOverlayWindow.isPermissionGranted()) {
    await FlutterOverlayWindow.requestPermission();
  }

  // 3. Сервис
  await initializeService();

  runApp(const ValeraApp());
}

// --- ENTRY POINT ДЛЯ ОВЕРЛЕЯ (Внешние окна) ---
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      // Тут navigatorKey НЕ НУЖЕН, у оверлея свой отдельный контекст
      home: OverlayToastWidget(),
    ),
  );
}

class ValeraApp extends StatefulWidget {
  const ValeraApp({super.key});

  @override
  State<ValeraApp> createState() => _ValeraAppState();
}

class _ValeraAppState extends State<ValeraApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // !!! ВАЖНО: Подключаем ключ сюда.
      // Без этого ToastService().show(...) внутри приложения выдаст ошибку или ничего не покажет.
      navigatorKey: navigatorKey,

      debugShowCheckedModeBanner: false,
      title: 'Valera Hmuriy',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primaryRed,
      ),
      home: HomePage(),
    );
  }
}