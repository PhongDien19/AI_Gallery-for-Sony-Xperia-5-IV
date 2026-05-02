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
    if (!ps.isAuth) {
      return [];
    }

    // Get the "Recent" album
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
    );

    if (paths.isEmpty) return [];

    final AssetPathEntity recentAlbum = paths.first;
    // Fetch photos with pagination
    final List<AssetEntity> photos = await recentAlbum.getAssetListPaged(
      page: page,
      size: limit,
    );

    return photos;
  }

  @override
  Future<List<AssetPathEntity>> getAlbums() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) return [];

    return await PhotoManager.getAssetPathList(type: RequestType.image);
  }
}
