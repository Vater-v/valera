import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isOn = false;
  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      _ipController.text = prefs.getString('saved_ip_port') ?? '';
    });
    FlutterBackgroundService().isRunning().then((v) => setState(() => isOn = v));
  }

  void _toggle() async {
    if (!await FlutterOverlayWindow.isPermissionGranted()) {
      await FlutterOverlayWindow.requestPermission();
      return;
    }

    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke("stopService");
      setState(() => isOn = false);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_ip_port', _ipController.text);

      service.startService();
      setState(() => isOn = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Темная тема по умолчанию для минимализма
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(primary: Colors.white),
      ),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "VALERA HMURIY",
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
                const SizedBox(height: 40),

                // Простое поле ввода
                TextField(
                  controller: _ipController,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: "IP:PORT",
                    hintStyle: TextStyle(color: Colors.grey),
                    border: UnderlineInputBorder(),
                    isDense: true,
                  ),
                ),

                const SizedBox(height: 40),

                // Простая кнопка
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: TextButton(
                    onPressed: _toggle,
                    style: TextButton.styleFrom(
                      backgroundColor: isOn ? Colors.red.shade900 : Colors.white,
                      foregroundColor: isOn ? Colors.white : Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: Text(
                      isOn ? "STOP SERVICE" : "START SERVICE",
                      style: const TextStyle(fontWeight: FontWeight.bold),
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