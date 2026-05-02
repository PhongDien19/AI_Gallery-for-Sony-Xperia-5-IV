import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/theme/app_theme.dart';
import '../providers/gallery_provider.dart';
import 'ai_analyze_screen.dart';

class HomeGalleryScreen extends ConsumerWidget {
  const HomeGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final galleryAsync = ref.watch(galleryProvider);

    return Scaffold(
      backgroundColor: AppTheme.oledBlack,
      appBar: AppBar(
        title: const Text('Xperia AI Gallery', style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1.2)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: galleryAsync.when(
        data: (photos) {
          if (photos.isEmpty) {
            return const Center(child: Text("No photos found."));
          }
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 8.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2.0,
                    crossAxisSpacing: 2.0,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final asset = photos[index];
                      return _PhotoThumbnail(asset: asset);
                    },
                    childCount: photos.length,
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.sonyAccent)),
        error: (err, stack) => Center(child: Text('Error loading gallery: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.sonyAccent,
        onPressed: () {
          // Trigger global AI scan or auto-curate album feature
        },
        child: const Icon(Icons.auto_awesome, color: Colors.white),
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final AssetEntity asset;

  const _PhotoThumbnail({required this.asset});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(color: AppTheme.darkGrey);
        }
        if (snapshot.hasData) {
          return GestureDetector(
            onTap: () {
              // Open AI Analyze Screen for full photo
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AiAnalyzeScreen(asset: asset),
                ),
              );
            },
            child: Hero(
              tag: asset.id,
              child: Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
              ),
            ),
          );
        }
        return Container(color: Colors.grey.shade900);
      },
    );
  }
}
