import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/theme/app_theme.dart';
import 'presentation/screens/home_gallery_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for local data storage
  await Hive.initFlutter();
  
  // Request storage permissions early for a gallery app
  await _requestPermissions();

  runApp(const ProviderScope(child: XperiaAiGalleryApp()));
}

Future<void> _requestPermissions() async {
  // Request photos and videos permission (Android 13+)
  if (await Permission.photos.isDenied) {
    await Permission.photos.request();
  }
}

class XperiaAiGalleryApp extends StatelessWidget {
  const XperiaAiGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xperia AI Gallery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme, // Xperia OLED optimized dark theme
      home: const HomeGalleryScreen(),
    );
  }
}
