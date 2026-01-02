import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayToastWidget extends StatefulWidget {
  const OverlayToastWidget({super.key});

  @override
  State<OverlayToastWidget> createState() => _OverlayToastWidgetState();
}

class _OverlayToastWidgetState extends State<OverlayToastWidget> {
  final Queue<String> _messageQueue = Queue();
  String _currentMessage = "";
  bool _isVisible = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Слушаем входящие сообщения от сервиса
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (!mounted) return;

      String msg = "";
      if (event is String) {
        msg = event;
      } else if (event is Map && event['message'] != null) {
        msg = event['message'].toString();
      } else {
        msg = event.toString();
      }

      if (msg.isNotEmpty) {
        _messageQueue.add(msg);
        if (!_isProcessing) {
          _processQueue();
        }
      }
    });
  }

  Future<void> _processQueue() async {
    _isProcessing = true;

    while (_messageQueue.isNotEmpty) {
      if (!mounted) break;

      final msg = _messageQueue.removeFirst();

      // Если предыдущее сообщение еще висит (хотя мы скрываем его ниже),
      // делаем небольшую паузу для плавности анимации скрытия
      if (_isVisible) {
        setState(() => _isVisible = false);
        await Future.delayed(const Duration(milliseconds: 150));
      }

      if (!mounted) break;

      // Показываем новое сообщение
      setState(() {
        _currentMessage = msg;
        _isVisible = true;
      });

      // Ждем, пока пользователь прочитает (динамическое время: минимум 2с, максимум 5с)
      // Чем длиннее текст, тем дольше висит
      int durationMs = 2000 + (msg.length * 40);
      if (durationMs > 5000) durationMs = 5000;

      await Future.delayed(Duration(milliseconds: durationMs));

      // Скрываем перед следующим
      if (mounted) {
        setState(() => _isVisible = false);
        // Время на анимацию исчезновения
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    _isProcessing = false;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Мы используем Align/Positioned, чтобы позиционировать тост внизу экрана
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            bottom: _isVisible ? 50 : -150, // Выезжает снизу
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E).withOpacity(0.90), // Темный фон
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFF453A).withOpacity(0.5), // Красная обводка
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Иконка (показываем специальную иконку для хука мишени)
                    if (_currentMessage.startsWith("🎯"))
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Icon(Icons.data_object, color: Color(0xFFFF453A), size: 20),
                      ),
                    Text(
                      _currentMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Roboto',
                        height: 1.3,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}