import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'controllers/detection_ctrl.dart';
import 'screens/home_screen.dart';
import 'services/detection_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShelfScannerApp());
}

class ShelfScannerApp extends StatelessWidget {
  const ShelfScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Shelf Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      // App-wide controller: lives for the whole app, loads the AI models once.
      initialBinding: BindingsBuilder(() {
        Get.put(DetectionCtrl(DetectionService()), permanent: true);
      }),
      home: const HomeScreen(),
    );
  }
}
