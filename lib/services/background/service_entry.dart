import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // --- 1. ЗАГРУЗКА НАСТРОЕК ---
  final prefs = await SharedPreferences.getInstance();
  final String? savedIpPort = prefs.getString('saved_ip_port');
  String? targetHost;
  int? targetPort;

  if (savedIpPort != null && savedIpPort.contains(':')) {
    final parts = savedIpPort.split(':');
    if (parts.length == 2) {
      targetHost = parts[0];
      targetPort = int.tryParse(parts[1]);
    }
  }

  /// Хелпер для отправки сообщений в оверлей
  Future<void> showOverlayNotification(String message) async {
    bool isActive = await FlutterOverlayWindow.isActive();
    if (!isActive) {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: false,
        height: WindowSize.matchParent,
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.bottomCenter,
        flag: OverlayFlag.clickThrough,
        visibility: NotificationVisibility.visibilityPublic,
      );
      await Future.delayed(const Duration(milliseconds: 200));
    }
    await FlutterOverlayWindow.shareData(message);
  }

  ServerSocket? serverSocket;

  try {
    serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 11111);

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Valera Service',
        content: 'Active on 11111',
      );
    }

    await Future.delayed(const Duration(milliseconds: 500));
    // Приветственное сообщение
    await showOverlayNotification("TOAST: Valera Ready 🚀");

    serverSocket.listen((Socket client) async {
      Socket? remoteSocket;
      bool isConnectedToRemote = false;

      // --- 2. ПРОКСИ (ЕСЛИ НАСТРОЕН) ---
      if (targetHost != null && targetPort != null) {
        try {
          remoteSocket = await Socket.connect(targetHost, targetPort, timeout: const Duration(seconds: 3));
          isConnectedToRemote = true;

          remoteSocket.listen(
                (List<int> data) {
              try { client.add(data); } catch (_) {}
            },
            onDone: () { client.destroy(); },
            onError: (e) { client.destroy(); },
          );
        } catch (e) {
          // Ошибки подключения тоже можно слать как TOAST, если нужно
          // showOverlayNotification("TOAST: Proxy Error");
        }
      }

      // --- 3. ОБРАБОТКА ДАННЫХ ---
      client.listen(
            (List<int> data) {
          String? decodedMessage;
          try {
            decodedMessage = utf8.decode(data, allowMalformed: true).trim();
          } catch (_) {}

          bool isInternalCommand = false;

          if (decodedMessage != null && decodedMessage.isNotEmpty) {

            // 1. ТОЛЬКО TOAST ПОПАДАЕТ В ОВЕРЛЕЙ
            if (decodedMessage.startsWith("TOAST:")) {
              isInternalCommand = true;
              final msg = decodedMessage.substring(6).trim();
              showOverlayNotification(msg);
            }
            // 2. ХУКИ (🎯) ГЛУШИМ (не показываем, не шлем на сервер)
            else if (decodedMessage.startsWith("🎯")) {
              isInternalCommand = true;
              // Тут пусто -> просто игнорируем
            }
          }

          // Пересылка трафика (если это не Toast и не Хук)
          if (!isInternalCommand && isConnectedToRemote && remoteSocket != null) {
            try {
              remoteSocket.add(data);
            } catch (_) {}
          }
        },
        onError: (e) { remoteSocket?.destroy(); },
        onDone: () { remoteSocket?.destroy(); },
      );
    });
  } catch (e) {
    print("Error: $e");
  }

  service.on('stopService').listen((event) async {
    await serverSocket?.close();
    service.stopSelf();
  });
}