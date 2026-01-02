import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../../core/theme/app_colors.dart'; // Убедись, что путь к цветам верный

class OverlayToastWidget extends StatefulWidget {
  const OverlayToastWidget({super.key});

  @override
  State<OverlayToastWidget> createState() => _OverlayToastWidgetState();
}

class _OverlayToastWidgetState extends State<OverlayToastWidget> {
  final Queue<String> _messageQueue = Queue();
  String _currentMessage = "";
  bool _isProcessing = false;
  double _opacity = 0.0;

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

      // Добавляем в очередь
      _messageQueue.add(newMessage);

      if (!_isProcessing) {
        _processQueue();
      }
    });
  }

  Future<void> _processQueue() async {
    _isProcessing = true;

    while (_messageQueue.isNotEmpty) {
      if (!mounted) break;

      final msg = _messageQueue.removeFirst();

      // Сброс состояния
      setState(() {
        _currentMessage = msg;
        _opacity = 0.0;
      });
      await Future.delayed(const Duration(milliseconds: 50));

      // FADE IN (Появление)
      if (mounted) setState(() => _opacity = 1.0);
      await Future.delayed(const Duration(milliseconds: 300)); // Быстрое появление

      // SHOW (Показ)
      // Держим сообщение 2.5 секунды, чтобы успеть прочитать
      await Future.delayed(const Duration(milliseconds: 2500));

      if (!mounted) break;

      // FADE OUT (Исчезновение)
      if (mounted) setState(() => _opacity = 0.0);
      await Future.delayed(const Duration(milliseconds: 300));

      // Небольшая пауза перед следующим сообщением
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _isProcessing = false;

    // Не закрываем оверлей полностью, чтобы он был готов принять новые сообщения мгновенно
    // Но можно и закрыть: await FlutterOverlayWindow.closeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: Container(
            // Отступ снизу, чтобы не перекрывать навигационную панель игры
            margin: const EdgeInsets.only(bottom: 120, left: 20, right: 20),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E).withOpacity(0.95), // Почти черный фон
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFFF453A).withOpacity(0.8), // Красная обводка Valera
                  width: 1.5
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Text(
              _currentMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        ),
      ),
    );
  }
}