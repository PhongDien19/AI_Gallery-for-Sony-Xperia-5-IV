import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  return PhotoRepositoryImpl();
});

abstract class PhotoRepository {
  Future<List<AssetEntity>> getRecentPhotos({int page = 0, int limit = 80});
  Future<List<AssetPathEntity>> getAlbums();
}

class PhotoRepositoryImpl implements PhotoRepository {
  @override
  Future<List<AssetEntity>> getRecentPhotos({int page = 0, int limit = 80}) async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    debugPrint('PhotoManager PermissionState: $ps');
    
    if (!ps.isAuth) {
      throw Exception('Quyền truy cập ảnh bị từ chối ($ps).');
    }

    // Get the albums
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: false, // Check all albums, not just "Recent"
    );
    
    debugPrint('Total AssetPaths found: ${paths.length}');
    for (var path in paths) {
      final assetCount = await path.assetCountAsync;
      debugPrint('Album: ${path.name}, Assets: $assetCount');
    }

    if (paths.isEmpty) {
      debugPrint('No paths found. If on Android 14+, you might need to select photos first.');
      return [];
    }

    // Use the first path (usually "Recent" or "All")
    final AssetPathEntity recentAlbum = paths.first;
    final List<AssetEntity> photos = await recentAlbum.getAssetListPaged(
      page: page,
      size: limit,
    );
    
    debugPrint('Photos fetched from ${recentAlbum.name}: ${photos.length}');
    return photos;
  }

  @override
  Future<List<AssetPathEntity>> getAlbums() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) return [];

    return await PhotoManager.getAssetPathList(type: RequestType.image);
  }
}
