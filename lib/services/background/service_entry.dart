import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

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

      // Пауза для инициализации движка оверлея
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Отправляем данные в OverlayToastWidget
    await FlutterOverlayWindow.shareData(message);
  }

  ServerSocket? serverSocket;

  try {
    // Слушаем только localhost (безопасность), порт 11111
    serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 11111);
    print('TCP Сервер успешно запущен на порту 11111');

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Valera Hmuriy',
        content: 'Сервер активен (Port: 11111) 🚀',
      );
    }

    // Уведомление при старте самого сервиса
    await Future.delayed(const Duration(milliseconds: 500));
    // Это сообщение системное, его показываем в тосте
    //await showOverlayNotification("Сервер запущен! Жду игру... 🟢");

    serverSocket.listen((Socket client) {
      print('Новый клиент (Игра): ${client.remoteAddress.address}');

      client.listen(
            (List<int> data) {
          // 1. Декодируем входящие байты
          final rawMessage = utf8.decode(data).trim();

          // 2. Всегда пишем в консоль (Logcat/Debug Console) всё подряд
          // Это нужно, чтобы ты видел технические логи (OUT_JSON, HEX и т.д.)
          print('TCP IN: $rawMessage');

          // 3. ФИЛЬТРАЦИЯ ДЛЯ ТОСТОВ
          // В C++ мы пометили технические логи эмодзи 🚀 (исходящие) и 📥 (входящие).
          // Сообщения "Инъекция успешна" и т.д. идут без этих префиксов (или с другими).

          bool isTechnicalLog = rawMessage.startsWith('🚀') || // Исходящие JSON
              rawMessage.startsWith('📥') || // Входящие байты
              rawMessage.startsWith('HEX:') ||
              rawMessage.startsWith('TXT:');

          if (isTechnicalLog) {
            // Это технический лог -> в оверлей НЕ отправляем.
            // Мы его уже вывели в print выше.
            return;
          }

          // 4. Если это НЕ технический лог, показываем пользователю Toast
          showOverlayNotification(rawMessage);
        },
        onError: (e) {
          print("Ошибка клиента: $e");
          client.close();
        },
        onDone: () {
          print("Клиент отключился");
          client.close();
        },
      );
    });
  } on SocketException catch (e) {
    print('Ошибка сокета: $e');
    String errorMsg = "Ошибка порта 11111 ⚠️";

    if (e.osError != null &&
        (e.osError!.errorCode == 98 || e.osError!.errorCode == 48)) {
      errorMsg = "Порт 11111 занят! Перезагрузи мобилу 🤬";
    }

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Valera Error',
        content: errorMsg,
      );
    }

    await showOverlayNotification(errorMsg);
  } catch (e) {
    await showOverlayNotification("Критическая ошибка: $e 💀");
  }

  service.on('stopService').listen((event) async {
    await serverSocket?.close();
    await Future.delayed(const Duration(seconds: 2));
    service.stopSelf();
  });
}