import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  /// Хелпер для отправки сообщений в оверлей
  Future<void> showOverlayNotification(String message) async {
    // Проверяем, активно ли окно
    bool isActive = await FlutterOverlayWindow.isActive();

    if (!isActive) {
      // Если окно не активно, создаем его
      await FlutterOverlayWindow.showOverlay(
        enableDrag: false,
        height: 500, // Высота области (не самого виджета, а контейнера)
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.bottomCenter,
        flag: OverlayFlag.focusPointer, // Пропускаем клики мимо
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.none,
      );

      // ВАЖНО: Даем небольшую паузу (250мс), чтобы изолят оверлея успел подняться
      // перед тем, как мы отправим в него данные.
      await Future.delayed(const Duration(milliseconds: 250));
    }

    // Отправляем сообщение. Благодаря очереди в OverlayToastWidget,
    // оно встанет в очередь, а не перезапишет предыдущее.
    await FlutterOverlayWindow.shareData(message);
  }

  ServerSocket? serverSocket;

  try {
    // Пытаемся занять порт
    serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 11111);

    print('TCP Сервер успешно запущен на порту 11111');

    // Обновляем системное уведомление (шторка)
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Valera Hmuriy',
        content: 'Сервер активен (Port: 11111) 🚀',
      );
    }

    // ВАЖНО: Делаем паузу перед отправкой уведомления об успехе.
    // Это нужно, чтобы оверлей, вызванный из UI (HomePage), точно успел загрузиться.
    await Future.delayed(const Duration(milliseconds: 500));

    await showOverlayNotification("Сервер запущен! Порт 11111 🟢");

    // Логика работы с клиентами
    serverSocket.listen((Socket client) {
      print('Новый клиент: ${client.remoteAddress.address}');

      client.listen(
            (List<int> data) {
          final message = String.fromCharCodes(data).trim();
          print('Получено: $message');

          // Отправляем входящее сообщение в тост
          showOverlayNotification("Получено: $message 📩");
        },
        onError: (e) => client.close(),
        onDone: () => client.close(),
      );
    });
  } on SocketException catch (e) {
    // ОШИБКА СОКЕТА (например, порт занят)
    print('Ошибка сокета: $e');
    String errorMsg = "Ошибка запуска сервера ⚠️";

    // Проверка кодов ошибок (98 или 48 обычно означают EADDRINUSE)
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

    // Опционально: можно убить сервис, если старт не удался
    // service.stopSelf();
  } catch (e) {
    // Любая другая ошибка
    await showOverlayNotification("Неведомая ошибка: $e 💀");
  }

  // Слушаем команду остановки из UI (кнопка "ВЫКЛЮЧИТЬ")
  service.on('stopService').listen((event) async {
    await serverSocket?.close();

    // Обновляем уведомление перед закрытием
    //await showOverlayNotification("Сервис остановлен 🛑");

    // Даем 2 секунды, чтобы тост успел появиться и отработать в очереди,
    // прежде чем процесс умрет
    await Future.delayed(const Duration(seconds: 2));

    service.stopSelf();
  });
}