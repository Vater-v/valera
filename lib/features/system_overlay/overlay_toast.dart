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
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (!mounted) return;
      String msg = (event is Map ? event['message'] : event).toString();

      if (msg.isNotEmpty) {
        _messageQueue.add(msg);
        if (!_isProcessing) _processQueue();
      }
    });
  }

  Future<void> _processQueue() async {
    _isProcessing = true;
    while (_messageQueue.isNotEmpty) {
      if (!mounted) break;

      setState(() {
        _currentMessage = _messageQueue.removeFirst();
        _isVisible = true;
      });

      // Читаем: 2 секунды минимум + немного на длину
      await Future.delayed(Duration(milliseconds: 2000 + (_currentMessage.length * 40)));

      if (!mounted) break;
      setState(() => _isVisible = false);
      await Future.delayed(const Duration(milliseconds: 150)); // Короткая пауза между сообщениями
    }
    _isProcessing = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.only(bottom: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF000000).withOpacity(0.85), // Просто черный полупрозрачный
            borderRadius: BorderRadius.circular(8), // Слегка скругленный
          ),
          child: Text(
            _currentMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              decoration: TextDecoration.none,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}