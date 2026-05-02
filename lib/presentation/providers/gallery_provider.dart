import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../data/repositories/photo_repository_impl.dart';

final galleryProvider = FutureProvider<List<AssetEntity>>((ref) async {
  final repository = ref.read(photoRepositoryProvider);
  return await repository.getRecentPhotos();
});
