import 'dart:async';
import 'dart:convert'; // ВАЖНО: нужно для utf8
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

      // Пауза, чтобы оверлей и анимация успели инициализироваться
      await Future.delayed(const Duration(milliseconds: 300));
    }

    await FlutterOverlayWindow.shareData(message);
  }

  ServerSocket? serverSocket;

  try {
    serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 11111);
    print('TCP Сервер успешно запущен на порту 11111');

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Valera Hmuriy',
        content: 'Сервер активен (Port: 11111) 🚀',
      );
    }

    await Future.delayed(const Duration(milliseconds: 500));
    await showOverlayNotification("Сервер запущен! Порт 11111 🟢");

    serverSocket.listen((Socket client) {
      print('Новый клиент: ${client.remoteAddress.address}');

      client.listen(
            (List<int> data) {
          // ИСПРАВЛЕНИЕ: Декодируем байты как UTF-8, чтобы смайлики работали
          final message = utf8.decode(data).trim();
          print('Получено: $message');

          showOverlayNotification("Получено: $message 📩");
        },
        onError: (e) => client.close(),
        onDone: () => client.close(),
      );
    });
  } on SocketException catch (e) {
    print('Ошибка сокета: $e');
    String errorMsg = "Ошибка запуска сервера ⚠️";

    if (e.osError != null &&
        (e.osError!.errorCode == 98 || e.osError!.errorCode == 48)) {
      errorMsg = "Порт 11111 занят! Хуйня вышла 🤬";
    }

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Valera Error',
        content: errorMsg,
      );
    }

    await showOverlayNotification(errorMsg);
  } catch (e) {
    await showOverlayNotification("Неведомая ошибка: $e 💀");
  }

  service.on('stopService').listen((event) async {
    await serverSocket?.close();
    await Future.delayed(const Duration(seconds: 2));
    service.stopSelf();
  });
}