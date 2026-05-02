import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/theme/app_theme.dart';
import 'presentation/screens/home_gallery_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for local data storage
  await Hive.initFlutter();

  // PhotoManager will handle permissions automatically in the repository
  runApp(const ProviderScope(child: XperiaAiGalleryApp()));
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
