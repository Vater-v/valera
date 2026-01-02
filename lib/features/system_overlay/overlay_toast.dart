import 'dart:async';
import 'dart:collection'; // Для Queue
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../../core/theme/app_colors.dart';

class OverlayToastWidget extends StatefulWidget {
  const OverlayToastWidget({super.key});

  @override
  State<OverlayToastWidget> createState() => _OverlayToastWidgetState();
}

class _OverlayToastWidgetState extends State<OverlayToastWidget> {
  // Очередь для хранения сообщений
  final Queue<String> _messageQueue = Queue();
  String _currentMessage = "Valera Service";
  bool _isProcessing = false;

  // Таймер нам больше не нужен в явном виде для закрытия,
  // логика закрытия будет в обработчике очереди.

  @override
  void initState() {
    super.initState();

    FlutterOverlayWindow.overlayListener.listen((event) {
      if (!mounted) return;

      String newMessage = "";
      if (event is String) {
        newMessage = event;
      } else if (event is Map && event['message'] != null) {
        newMessage = event['message'].toString();
      } else {
        newMessage = event.toString();
      }

      // 1. Добавляем сообщение в очередь
      _messageQueue.add(newMessage);

      // 2. Если очередь еще не обрабатывается, запускаем процесс
      if (!_isProcessing) {
        _processQueue();
      }
    });
  }

  Future<void> _processQueue() async {
    _isProcessing = true;

    // Пока в очереди есть сообщения
    while (_messageQueue.isNotEmpty) {
      if (!mounted) return;

      // Берем первое сообщение
      final msg = _messageQueue.removeFirst();

      setState(() {
        _currentMessage = msg;
      });

      // Ждем 3 секунды, чтобы пользователь успел прочитать
      await Future.delayed(const Duration(seconds: 3));
    }

    _isProcessing = false;

    // Очередь пуста, закрываем окно
    if (mounted) {
      await FlutterOverlayWindow.closeOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          // Отступ снизу
          margin: const EdgeInsets.only(bottom: 150, left: 16, right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 15,
                offset: const Offset(0, 4),
              )
            ],
            border: Border.all(
                color: AppColors.primaryRed.withOpacity(0.6), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.notifications_active_outlined,
                  color: AppColors.primaryRed, size: 24),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  _currentMessage, // Используем переменную состояния
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}