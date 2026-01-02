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
  final Queue<String> _messageQueue = Queue();
  String _currentMessage = "";
  bool _isProcessing = false;

  // Управление прозрачностью для анимации
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();

    // Слушаем входящие сообщения
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

      // 1. Подготовка: ставим текст, прозрачность 0
      setState(() {
        _currentMessage = msg;
        _opacity = 0.0;
      });

      // Техническая пауза
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) break;

      // 2. FADE IN: Появляемся
      setState(() {
        _opacity = 1.0;
      });
      await Future.delayed(const Duration(milliseconds: 500));

      // 3. SHOW: Показываем сообщение (3 сек)
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) break;

      // 4. FADE OUT: Исчезаем
      setState(() {
        _opacity = 0.0;
      });
      await Future.delayed(const Duration(milliseconds: 500));

      // 5. PAUSE: Пауза между сообщениями
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _isProcessing = false;

    // Если очередь пуста - закрываем оверлей
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
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          child: Container(
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
                // ИКОНКА УБРАНА ОТСЮДА
                Flexible(
                  child: Text(
                    _currentMessage,
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
      ),
    );
  }
}