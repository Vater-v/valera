import 'package:flutter/material.dart';

/// Глобальный ключ навигатора.
/// Позволяет получать доступ к контексту (NavigatorState, Overlay)
/// из любой точки приложения без передачи BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();