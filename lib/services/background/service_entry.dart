import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Не забудьте этот импорт!

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // --- 1. ЗАГРУЗКА НАСТРОЕК (IP:PORT) ---
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

  print("Configured Target: $targetHost:$targetPort");

  /// Хелпер для отправки сообщений в оверлей
  Future<void> showOverlayNotification(String message) async {
    bool isActive = await FlutterOverlayWindow.isActive();

    if (!isActive) {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: false,
        height: 500,
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.bottomCenter,
        flag: OverlayFlag.focusPointer,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.none,
      );
      await Future.delayed(const Duration(milliseconds: 300));
    }
    await FlutterOverlayWindow.shareData(message);
  }

  ServerSocket? serverSocket;

  try {
    // Слушаем localhost:11111 (Game подключается сюда)
    serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 11111);
    print('TCP Прокси-сервер запущен на порту 11111');

    if (service is AndroidServiceInstance) {
      String statusText = 'Сервер активен (Port: 11111)';
      if (targetHost != null) {
        statusText += ' -> $targetHost:$targetPort';
      }

      service.setForegroundNotificationInfo(
        title: 'Valera Hmuriy',
        content: statusText,
      );
    }

    await Future.delayed(const Duration(milliseconds: 500));

    if (targetHost != null && targetPort != null) {
      await showOverlayNotification("Режим PROXY: $targetHost:$targetPort 🚀");
    } else {
      await showOverlayNotification("Режим SINK (нет форвардинга) ⚠️");
    }

    serverSocket.listen((Socket client) async {
      print('Новый клиент (Игра): ${client.remoteAddress.address}');

      Socket? remoteSocket;
      bool isConnectedToRemote = false;

      // --- 2. ПОДКЛЮЧЕНИЕ К УДАЛЕННОМУ СЕРВЕРУ (Python Backend) ---
      if (targetHost != null && targetPort != null) {
        try {
          remoteSocket = await Socket.connect(targetHost, targetPort, timeout: const Duration(seconds: 5));
          isConnectedToRemote = true;
          print('Успешное подключение к удаленному серверу!');

          // Слушаем ответ от удаленного сервера и шлем обратно клиенту (игре)
          remoteSocket.listen(
                (List<int> data) {
              // Пересылаем ответ игре
              try {
                client.add(data);
                print('REMOTE -> CLIENT (${data.length} bytes)');
              } catch (e) {
                print('Ошибка отправки клиенту: $e');
              }
            },
            onDone: () {
              print("Удаленный сервер закрыл соединение");
              client.destroy();
            },
            onError: (e) {
              print("Ошибка удаленного сокета: $e");
              client.destroy();
            },
          );

        } catch (e) {
          print("Не удалось подключиться к целевому серверу: $e");
          showOverlayNotification("Ошибка подключения к серверу! 🔌");
        }
      }

      // --- 3. ОБРАБОТКА ДАННЫХ ОТ КЛИЕНТА ---
      client.listen(
            (List<int> data) {
          // А) Пересылаем на удаленный сервер (если подключен)
          if (isConnectedToRemote && remoteSocket != null) {
            try {
              remoteSocket.add(data);
            } catch (e) {
              print("Ошибка отправки на удаленный сервер: $e");
            }
          }

          // Б) Логика "Валеры" (Сниффинг и Тосты)
          // Пытаемся декодировать, чтобы показать сообщение пользователю
          try {
            final rawMessage = utf8.decode(data).trim();
            print('CLIENT -> PROXY: $rawMessage');

            // Фильтрация технических логов
            bool isTechnicalLog = rawMessage.startsWith('🚀') ||
                rawMessage.startsWith('📥') ||
                rawMessage.startsWith('HEX:') ||
                rawMessage.startsWith('TXT:');

            if (!isTechnicalLog) {
              showOverlayNotification(rawMessage);
            }
          } catch (e) {
            // Если пришли бинарные данные, которые не декодируются в UTF8,
            // просто игнорируем их для тостов, но они уже улетели на сервер выше.
          }
        },
        onError: (e) {
          print("Ошибка клиента: $e");
          remoteSocket?.destroy();
        },
        onDone: () {
          print("Клиент отключился");
          remoteSocket?.destroy();
        },
      );
    });
  } on SocketException catch (e) {
    print('Ошибка сокета: $e');
    await showOverlayNotification("Порт 11111 занят! 🤬");
  } catch (e) {
    await showOverlayNotification("Критическая ошибка: $e 💀");
  }

  service.on('stopService').listen((event) async {
    await serverSocket?.close();
    service.stopSelf();
  });
}