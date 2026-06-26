import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'image_compressor.dart';
import 'app_paths.dart';
import 'log_manager.dart';

/// 缩略图管理器
/// 负责缩略图的生成、存储、缓存和管理
class ThumbnailManager {
  static final ThumbnailManager _instance = ThumbnailManager._internal();
  factory ThumbnailManager() => _instance;
  ThumbnailManager._internal();

  // 缓存目录
  Directory? _cacheDir;

  // 内存缓存
  final Map<String, Uint8List> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // 缓存配置
  static const int maxMemoryCacheSize = 100; // 最大内存缓存数量
  static const Duration cacheExpiration = Duration(hours: 24); // 缓存过期时间

  /// 获取缓存目录
  Future<Directory> get cacheDir async {
    final existing = _cacheDir;
    if (existing != null) return existing;

    try {
      // 使用应用数据目录
      final cachePath = AppPaths.thumbnailCacheDirectory;
      final dir = Directory(cachePath);
      _cacheDir = dir;

      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      // 如果AppPaths未初始化，回退到文档目录
      LogManager.e('ThumbnailManager', '缩略图缓存目录初始化失败，使用文档目录', error: e);
      final appDocDir = await getApplicationDocumentsDirectory();
      final dir = Directory(path.join(appDocDir.path, 'thumbnails'));
      _cacheDir = dir;

      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }

    final result = _cacheDir;
    if (result == null) {
      throw StateError('缩略图缓存目录初始化失败');
    }
    return result;
  }

  /// 生成缩略图并缓存
  /// [imageData] 原始图片数据
  /// [key] 缓存键（通常是图片的哈希值或ID）
  /// [size] 缩略图尺寸
  /// [quality] 压缩质量
  Future<Uint8List> generateAndCacheThumbnail(
    Uint8List imageData, {
    String? key,
    int size = ImageCompressor.maxThumbnailSize,
    int quality = ImageCompressor.thumbnailQuality,
  }) async {
    try {
      // 如果没有提供key，生成一个基于图片内容的哈希值
      final cacheKey = key ?? _generateImageHash(imageData);

      // 检查内存缓存
      final cachedData = _memoryCache[cacheKey];
      if (cachedData != null) {
        final timestamp = _cacheTimestamps[cacheKey];
        if (timestamp != null &&
            DateTime.now().difference(timestamp) < cacheExpiration) {
          return cachedData;
        } else {
          // 缓存已过期，移除
          _memoryCache.remove(cacheKey);
          _cacheTimestamps.remove(cacheKey);
        }
      }

      // 检查文件缓存
      final cachedThumbnail = await _getCachedThumbnail(cacheKey);
      if (cachedThumbnail != null) {
        // 更新内存缓存
        _addToMemoryCache(cacheKey, cachedThumbnail);

        return cachedThumbnail;
      }

      // 生成新的缩略图

      final thumbnail = await ImageCompressor.generateThumbnail(
        imageData,
        maxSize: size,
        quality: quality,
      );

      // 缓存缩略图
      await _cacheThumbnail(cacheKey, thumbnail);
      _addToMemoryCache(cacheKey, thumbnail);

      return thumbnail;
    } catch (e) {
      LogManager.e('ThumbnailManager', '生成缩略图失败', error: e);
      rethrow;
    }
  }

  /// 批量生成缩略图
  /// [images] 图片数据列表
  /// [keys] 对应的缓存键列表
  Future<List<Uint8List>> generateBatchThumbnails(
    List<Uint8List> images, {
    List<String>? keys,
    int size = ImageCompressor.maxThumbnailSize,
    int quality = ImageCompressor.thumbnailQuality,
  }) async {
    final results = <Uint8List>[];

    for (int i = 0; i < images.length; i++) {
      try {
        final key = keys != null && i < keys.length ? keys[i] : null;
        final thumbnail = await generateAndCacheThumbnail(
          images[i],
          key: key,
          size: size,
          quality: quality,
        );
        results.add(thumbnail);
      } catch (e) {
        LogManager.e('ThumbnailManager', '生成第 $i 个缩略图失败', error: e);
        // 添加一个空的缩略图作为占位符
        results.add(Uint8List(0));
      }
    }

    return results;
  }

  /// 从缓存获取缩略图
  /// [key] 缓存键
  Future<Uint8List?> getCachedThumbnail(String key) async {
    // 检查内存缓存
    if (_memoryCache.containsKey(key)) {
      final timestamp = _cacheTimestamps[key];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < cacheExpiration) {
        return _memoryCache[key];
      } else {
        // 缓存已过期，移除
        _memoryCache.remove(key);
        _cacheTimestamps.remove(key);
      }
    }

    // 检查文件缓存
    return await _getCachedThumbnail(key);
  }

  /// 清除缓存
  Future<void> clearCache() async {
    // 清除内存缓存
    _memoryCache.clear();
    _cacheTimestamps.clear();

    // 清除文件缓存
    try {
      final dir = await cacheDir;
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create();
      }
    } catch (e) {
      LogManager.e('ThumbnailManager', '清除文件缓存失败', error: e);
    }
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStats() {
    final now = DateTime.now();
    int expiredCount = 0;

    for (final timestamp in _cacheTimestamps.values) {
      if (now.difference(timestamp) >= cacheExpiration) {
        expiredCount++;
      }
    }

    return {
      'memoryCacheSize': _memoryCache.length,
      'maxMemoryCacheSize': maxMemoryCacheSize,
      'expiredCount': expiredCount,
      'cacheExpiration': cacheExpiration.inHours,
    };
  }

  /// 预加载缩略图
  /// [keys] 要预加载的缓存键列表
  Future<void> preloadThumbnails(List<String> keys) async {
    for (final key in keys) {
      try {
        // 尝试从缓存获取，如果不存在则会在下次访问时生成
        await getCachedThumbnail(key);
      } catch (e) {
        LogManager.e('ThumbnailManager', '预加载缩略图失败: $key, 错误', error: e);
      }
    }
  }

  /// 生成图片哈希值
  String _generateImageHash(Uint8List imageData) {
    final hash = sha256.convert(imageData);
    return hash.toString();
  }

  /// 添加缩略图到内存缓存
  void _addToMemoryCache(String key, Uint8List thumbnail) {
    // 如果缓存已满，移除最旧的条目
    if (_memoryCache.length >= maxMemoryCacheSize) {
      String? oldestKey;
      DateTime? oldestTime;

      for (final entry in _cacheTimestamps.entries) {
        if (oldestTime == null || entry.value.isBefore(oldestTime)) {
          oldestTime = entry.value;
          oldestKey = entry.key;
        }
      }

      if (oldestKey != null) {
        _memoryCache.remove(oldestKey);
        _cacheTimestamps.remove(oldestKey);
      }
    }

    _memoryCache[key] = thumbnail;
    _cacheTimestamps[key] = DateTime.now();
  }

  /// 从文件缓存获取缩略图
  Future<Uint8List?> _getCachedThumbnail(String key) async {
    try {
      final dir = await cacheDir;
      final file = File(path.join(dir.path, '$key.thumb'));

      if (await file.exists()) {
        final data = await file.readAsBytes();

        // 检查文件是否过期
        final stat = await file.stat();
        if (DateTime.now().difference(stat.modified) < cacheExpiration) {
          return data;
        } else {
          // 文件已过期，删除
          await file.delete();
        }
      }
    } catch (e) {
      LogManager.e('ThumbnailManager', '读取缓存缩略图失败', error: e);
    }

    return null;
  }

  /// 缓存缩略图到文件
  Future<void> _cacheThumbnail(String key, Uint8List thumbnail) async {
    try {
      final dir = await cacheDir;
      final file = File(path.join(dir.path, '$key.thumb'));
      await file.writeAsBytes(thumbnail);
    } catch (e) {
      LogManager.e('ThumbnailManager', '缓存缩略图失败', error: e);
    }
  }
}

/// 缩略图配置
class ThumbnailConfig {
  final int size;
  final int quality;
  final int maxFileSize;
  final bool enableCache;
  final Duration cacheExpiration;

  const ThumbnailConfig({
    this.size = ImageCompressor.maxThumbnailSize,
    this.quality = ImageCompressor.thumbnailQuality,
    this.maxFileSize = ImageCompressor.maxThumbnailSize,
    this.enableCache = true,
    this.cacheExpiration = const Duration(hours: 24),
  });

  /// 小尺寸缩略图配置
  static const ThumbnailConfig small = ThumbnailConfig(
    size: 50,
    quality: 60,
    maxFileSize: 25 * 1024, // 25KB
  );

  /// 中等尺寸缩略图配置
  static const ThumbnailConfig medium = ThumbnailConfig(
    size: 100,
    quality: 70,
    maxFileSize: 50 * 1024, // 50KB
  );

  /// 大尺寸缩略图配置
  static const ThumbnailConfig large = ThumbnailConfig(
    size: 150,
    quality: 80,
    maxFileSize: 75 * 1024, // 75KB
  );
}
