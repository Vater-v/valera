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
    // Проверяем активность оверлея, если нет - создаем
    bool isActive = await FlutterOverlayWindow.isActive();
    if (!isActive) {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: false,
        height: WindowSize.matchParent,
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.bottomCenter,
        flag: OverlayFlag.clickThrough, // Важно: клики проходят сквозь оверлей в игру
        visibility: NotificationVisibility.visibilityPublic,
      );
      // Небольшая пауза для инициализации окна
      await Future.delayed(const Duration(milliseconds: 300));
    }
    // Отправляем данные в оверлей
    await FlutterOverlayWindow.shareData(message);
  }

  ServerSocket? serverSocket;

  try {
    // Слушаем localhost:11111
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
      await showOverlayNotification("Режим SINK (Логи + Хуки) 🛡️");
    }

    serverSocket.listen((Socket client) async {
      print('Новое подключение: ${client.remoteAddress.address}');

      Socket? remoteSocket;
      bool isConnectedToRemote = false;

      // --- 2. ПОДКЛЮЧЕНИЕ К УДАЛЕННОМУ СЕРВЕРУ (ТОЛЬКО ЕСЛИ НУЖНО) ---
      // Мы подключаемся к удаленному серверу, только если настроен прокси
      if (targetHost != null && targetPort != null) {
        try {
          remoteSocket = await Socket.connect(targetHost, targetPort, timeout: const Duration(seconds: 5));
          isConnectedToRemote = true;
          print('Успешное подключение к удаленному серверу!');

          // Слушаем ответ от удаленного сервера и шлем обратно клиенту (игре)
          remoteSocket.listen(
                (List<int> data) {
              try {
                client.add(data);
                // print('REMOTE -> CLIENT (${data.length} bytes)');
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

      // --- 3. ОБРАБОТКА ДАННЫХ ОТ КЛИЕНТА (ИГРА ИЛИ C++ МОДУЛЬ) ---
      client.listen(
            (List<int> data) {
          // Попытка декодировать сообщение
          String? decodedMessage;
          try {
            decodedMessage = utf8.decode(data, allowMalformed: true).trim();
          } catch (_) {}

          // --- ЛОГИКА ФИЛЬТРАЦИИ ---
          bool isInternalCommand = false;

          if (decodedMessage != null && decodedMessage.isNotEmpty) {
            // 1. КОМАНДА TOAST (Специфично для C++ модуля)
            // Формат C++: TcpClient::Send("TOAST: Текст сообщения");
            if (decodedMessage.startsWith("TOAST:")) {
              isInternalCommand = true; // БЛОКИРУЕМ ОТПРАВКУ НА СЕРВЕР
              final msg = decodedMessage.substring(6).trim(); // Убираем 'TOAST:'
              showOverlayNotification("🔔 $msg");
            }
            // 2. ДАННЫЕ ИЗ ХУКА (JSON с мишенью)
            // Формат C++: TcpClient::Send("🎯 " + json);
            else if (decodedMessage.startsWith("🎯")) {
              // ВАЖНО: Убрали isInternalCommand = true.
              // Теперь пакет пойдет дальше в блок !isInternalCommand и отправится на сервер.

              showOverlayNotification(decodedMessage);
            }
          }

          // --- ПЕРЕСЫЛКА ---
          // Если это НЕ внутренняя команда Valera (TOAST),
          // то это игровой трафик или JSON с мишенью -> шлем на сервер.
          if (!isInternalCommand) {
            if (isConnectedToRemote && remoteSocket != null) {
              try {
                remoteSocket.add(data);
              } catch (e) {
                print("Ошибка отправки на удаленный сервер: $e");
              }
            }

            // --- СНИФФИНГ ОБЫЧНОГО ТРАФИКА ---
            // Пытаемся показать обычные текстовые пакеты, если это не бинарщина
            if (decodedMessage != null) {
              // Исключаем из логов сам JSON хука, чтобы не дублировать (он уже показан выше),
              // либо оставляем как есть. Здесь добавим проверку, чтобы не показывать дважды.
              if (!decodedMessage.startsWith("🎯")) {
                bool isTechnicalLog = decodedMessage.startsWith('🚀') ||
                    decodedMessage.startsWith('📥') ||
                    decodedMessage.startsWith('HEX:') ||
                    decodedMessage.startsWith('TXT:');

                if (!isTechnicalLog && decodedMessage.length > 1) {
                  // Ограничиваем длину вывода обычного трафика
                  String display = decodedMessage.length > 100
                      ? "${decodedMessage.substring(0, 100)}..."
                      : decodedMessage;
                  showOverlayNotification(display);
                }
              }
            }
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