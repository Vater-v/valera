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

  // --- НАСТРОЙКИ ---
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

  // --- ПРОСТОЙ ТОСТ ---
  Future<void> showToast(String message) async {
    try {
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
        await Future.delayed(const Duration(milliseconds: 100));
      }
      await FlutterOverlayWindow.shareData(message);
    } catch (e) {
      print("Overlay error: $e");
    }
  }

  ServerSocket? serverSocket;

  try {
    serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 11111);
    print('✅ LOCAL: 11111');

    // Показываем статус при старте, чтобы понимать, что сервис жив
    await showToast("Valera Started 👻");

    serverSocket.listen((Socket client) async {
      Socket? remoteSocket;
      bool isRemoteConnected = false;

      // --- ПОДКЛЮЧЕНИЕ К БЭКЕНДУ ---
      if (targetHost != null && targetPort != null) {
        try {
          remoteSocket = await Socket.connect(targetHost, targetPort, timeout: const Duration(seconds: 3));
          isRemoteConnected = true;
          await showToast("Connected: $targetHost 🟢");

          // БЭКЕНД -> ИГРА
          remoteSocket.listen(
                (data) => client.add(data),
            onDone: () {
              client.destroy();
              showToast("Server Disconnected 🔴");
            },
            onError: (_) => client.destroy(),
          );
        } catch (e) {
          await showToast("Connection Failed ❌");
        }
      }

      // --- ИГРА -> БЭКЕНД (С ФИЛЬТРАЦИЕЙ) ---
      client.listen(
            (List<int> data) {
          bool forwardToRemote = true;

          // Пробуем найти команду TOAST
          try {
            final String decoded = utf8.decode(data, allowMalformed: true).trim();

            // ТОЛЬКО ЭТО попадает в оверлей
            if (decoded.startsWith("TOAST:")) {
              final msg = decoded.substring(6).trim();
              showToast(msg);
              forwardToRemote = false; // Внутренняя команда, не шлем на сервер
            }
          } catch (_) {}

          // Весь остальной трафик (JSON, бинарщина) - молча на сервер
          if (forwardToRemote && isRemoteConnected && remoteSocket != null) {
            try {
              remoteSocket.add(data);
            } catch (_) {}
          }
        },
        onDone: () => remoteSocket?.destroy(),
        onError: (_) => remoteSocket?.destroy(),
      );
    });

  } catch (e) {
    await showToast("Port 11111 Busy! 🤬");
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
    serverSocket?.close();
  });
}