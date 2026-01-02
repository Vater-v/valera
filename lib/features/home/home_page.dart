import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../../core/theme/app_colors.dart';

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isOn = false;
  bool isInputValid = false;
  final TextEditingController _ipController = TextEditingController();
  static const String _ipKey = 'saved_ip_port';

  @override
  void initState() {
    super.initState();
    _loadIpData();
    _checkServiceStatus();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final bool status = await FlutterOverlayWindow.isPermissionGranted();
    if (!status) {
      await FlutterOverlayWindow.requestPermission();
    }
  }

  void _checkServiceStatus() async {
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    if (mounted) setState(() => isOn = isRunning);
  }

  // --- ЛОГИКА ВКЛЮЧЕНИЯ/ВЫКЛЮЧЕНИЯ ---
  void _toggleService() async {
    // 1. Проверяем права на оверлей перед запуском
    if (!await FlutterOverlayWindow.isPermissionGranted()) {
      await FlutterOverlayWindow.requestPermission();
      return;
    }

    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();

    if (isRunning) {
      // ОСТАНОВКА
      service.invoke("stopService");
      setState(() => isOn = false);

      // Показываем Toast об остановке
      await _showOverlayNotification("Сервис остановлен 🛑");
    } else {
      // ЗАПУСК
      service.startService();
      setState(() => isOn = true);

      // Показываем Toast об успешном запуске
      await _showOverlayNotification("Сервис успешно запущен! 🚀");
    }
  }

  // Вызов оверлея
  Future<void> _showOverlayNotification(String message) async {
    bool isActive = await FlutterOverlayWindow.isActive();

    if (isActive) {
      // Если окно уже висит - обновляем текст
      await FlutterOverlayWindow.shareData(message);
    } else {
      // Если окна нет - создаем
      await FlutterOverlayWindow.showOverlay(
        enableDrag: false,
        flag: OverlayFlag.clickThrough,
        alignment: OverlayAlignment.bottomCenter,
        height: WindowSize.matchParent, // Используем matchParent чтобы margin отработал корректно
        width: WindowSize.matchParent,
        visibility: NotificationVisibility.visibilityPublic,
        overlayContent: message,
      );

      // Небольшая задержка, чтобы виджет успел построиться
      await Future.delayed(const Duration(milliseconds: 100));
      await FlutterOverlayWindow.shareData(message);
    }
  }

  void _checkValidation(String value) {
    setState(() => isInputValid = value.isNotEmpty);
  }

  Future<void> _loadIpData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedText = prefs.getString(_ipKey) ?? '';
    setState(() {
      _ipController.text = savedText;
      _checkValidation(savedText);
    });
  }

  Future<void> _saveIpData(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ipKey, value);
    _checkValidation(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Valera Hmuriy",
                  style: TextStyle(
                      fontSize: 24,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _ipController,
                  onChanged: _saveIpData,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: "IP:Port",
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isInputValid ? _toggleService : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOn
                          ? AppColors.primaryRed
                          : AppColors.surfaceLight,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      isOn ? "ВЫКЛЮЧИТЬ" : "ВКЛЮЧИТЬ",
                      style: TextStyle(
                          color: isInputValid
                              ? AppColors.textPrimary
                              : AppColors.textDisabled,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}