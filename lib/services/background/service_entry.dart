import 'dart:async';
import 'dart:convert'; // ВАЖНО: нужен для обработки потока строк
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

  // --- ФУНКЦИЯ ПОКАЗА ТОСТА ---
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
        // Небольшая задержка для инициализации окна
        await Future.delayed(const Duration(milliseconds: 100));
      }
      await FlutterOverlayWindow.shareData(message);
    } catch (e) {
      print("Overlay error: $e");
    }
  }

  ServerSocket? serverSocket;

  try {
    // Биндимся на локальный адрес, куда стучится C++ (127.0.0.1)
    serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 11111);
    print('✅ LOCAL SERVER STARTED on 11111');

    // Приветственное сообщение
    await showToast("Valera Started 👻");

    serverSocket.listen((Socket client) async {
      Socket? remoteSocket;
      bool isRemoteConnected = false;

      // --- 1. ПОДКЛЮЧЕНИЕ К УДАЛЕННОМУ СЕРВЕРУ (Опционально) ---
      if (targetHost != null && targetPort != null) {
        try {
          remoteSocket = await Socket.connect(targetHost, targetPort, timeout: const Duration(seconds: 3));
          isRemoteConnected = true;
          await showToast("Connected: $targetHost 🟢");

          // Входящие от сервера -> Сразу в игру (клиенту)
          remoteSocket.listen(
                (data) {
              try {
                client.add(data);
              } catch (_) {}
            },
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

      // --- 2. ОБРАБОТКА ДАННЫХ ОТ ИГРЫ (C++ Module) ---
      // Используем цепочку трансформаций для корректного чтения строк
      client
          .cast<List<int>>()
          .transform(utf8.decoder)       // Байти -> Строка
          .transform(const LineSplitter()) // Разбиваем по \n (построчно)
          .listen((String line) {
        String decoded = line.trim();
        if (decoded.isEmpty) return;

        bool forwardToRemote = true;
        String messageToSend = decoded;

        // А) Команда для Оверлея
        if (decoded.startsWith("TOAST:")) {
          final msg = decoded.substring(6).trim();
          showToast(msg);
          forwardToRemote = false; // Локальная команда, на сервер не шлем
        }
        // Б) Перехваченные данные (JSON и прочее)
        else if (decoded.startsWith("🎯")) {
          // Пишем в лог для отладки
          print("HOOK DATA: $decoded");

          // Очищаем от смайлика и лишних пробелов для отправки чистого JSON
          messageToSend = decoded.replaceFirst("🎯", "").trim();
        }

        // В) Фильтр по длине (менее 40 символов не шлем)
        // Это отсечет короткий мусор и пустые JSON, если они есть
        if (messageToSend.length < 40) {
          forwardToRemote = false;
        }

        // Г) Пересылка на удаленный сервер
        if (forwardToRemote && isRemoteConnected && remoteSocket != null) {
          try {
            // Восстанавливаем перенос строки, так как LineSplitter его убрал
            remoteSocket.write("$messageToSend\n");
          } catch (_) {}
        }
      },
        onDone: () {
          remoteSocket?.destroy();
        },
        onError: (_) {
          remoteSocket?.destroy();
        },
      );
    });

  } catch (e) {
    print("Critical Error on port 11111: $e");
    await showToast("Port 11111 Busy! 🤬");
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
    serverSocket?.close();
  });
}