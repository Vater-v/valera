import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';

// Импорты твоих файлов.
// Используем относительные пути (../../) или укажи package:твое_приложение/...
import '../../core/theme/app_colors.dart';
import '../../core/utils/global_keys.dart';

class ToastService {
  // 1. Singleton
  static final ToastService _instance = ToastService._internal();
  factory ToastService() => _instance;
  ToastService._internal();

  // 2. Очередь сообщений и флаг занятости
  final Queue<String> _messageQueue = Queue();
  bool _isShowing = false;
  OverlayEntry? _overlayEntry;

  /// Публичный метод вызова
  void show(String message) {
    _messageQueue.add(message);
    _processQueue();
  }

  /// Внутренняя логика обработки очереди
  void _processQueue() async {
    // Если уже показываем что-то или очередь пуста - выходим
    if (_isShowing || _messageQueue.isEmpty) return;

    _isShowing = true;
    final message = _messageQueue.removeFirst();

    // Создаем и показываем Overlay
    _createOverlay(message);

    // Ждем 3 секунды
    await Future.delayed(const Duration(seconds: 3));

    // Удаляем Overlay
    _removeOverlay();

    _isShowing = false;
    // Рекурсивно вызываем обработку для следующего сообщения
    _processQueue();
  }

  void _createOverlay(String message) {
    // Получаем текущий контекст через импортированный globalKey
    final context = navigatorKey.currentState?.overlay?.context;
    if (context == null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        // Позиционируем внизу экрана
        bottom: 100, // Чуть поднял (было 200), но можешь вернуть как было
        left: 24,
        right: 24,
        child: Material(
          color: Colors.transparent,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary, // Твой цвет
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Вставляем в Overlay через глобальный ключ
    navigatorKey.currentState?.overlay?.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

// Глобальная функция-хелпер
void showToast(String message) {
  ToastService().show(message);
}