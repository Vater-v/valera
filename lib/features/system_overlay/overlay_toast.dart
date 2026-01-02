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
      String msg = event.toString();
      if (event is Map && event['message'] != null) {
        msg = event['message'].toString();
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

      if (_isVisible) {
        setState(() => _isVisible = false);
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (!mounted) break;

      setState(() {
        _currentMessage = msg;
        _isVisible = true;
      });

      // Расчет времени показа
      int durationMs = 2000 + (msg.length * 50);
      if (durationMs > 5000) durationMs = 5000;

      await Future.delayed(Duration(milliseconds: durationMs));
    }

    if (mounted) {
      setState(() => _isVisible = false);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _isProcessing = false;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          AnimatedSlide(
            offset: _isVisible ? const Offset(0, 0) : const Offset(0, 2.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutQuart,
            child: AnimatedOpacity(
              opacity: _isVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: Container(
                margin: const EdgeInsets.only(bottom: 60, left: 32, right: 32),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212).withOpacity(0.92), // Темный фон
                  borderRadius: BorderRadius.circular(50), // Полная капсула
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                ),
                child: Text(
                  _currentMessage.replaceAll("TOAST:", "").replaceAll("", "").trim(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFF2F2F2),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Roboto',
                    height: 1.3,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}