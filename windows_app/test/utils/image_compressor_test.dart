import 'dart:io';

import 'package:dentist_app_windows/utils/image_compressor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('material_image_compress_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('材料图片在后台压缩后长边不超过 1024，小图不放大', () async {
    final largeFile = File('${tempDir.path}/large.png');
    await largeFile.writeAsBytes(
      img.encodePng(img.Image(width: 1200, height: 800)),
    );
    final largeResult = await ImageCompressor.compressImageFile(largeFile);
    final largeImage = img.decodeJpg(largeResult.compressedBytes);

    expect(largeResult.imageType, 'png');
    expect(largeImage, isNotNull);
    expect(largeImage!.width, lessThanOrEqualTo(1024));
    expect(largeImage.height, lessThanOrEqualTo(1024));
    expect(
      largeImage.width > largeImage.height
          ? largeImage.width
          : largeImage.height,
      1024,
    );

    final smallFile = File('${tempDir.path}/small.jpg');
    await smallFile.writeAsBytes(
      img.encodeJpg(img.Image(width: 100, height: 80)),
    );
    final smallResult = await ImageCompressor.compressImageFile(smallFile);
    final smallImage = img.decodeJpg(smallResult.compressedBytes);

    expect(smallResult.imageType, 'jpg');
    expect(smallImage?.width, 100);
    expect(smallImage?.height, 80);
  });

  test('缩略图长边不超过 200', () async {
    final source = img.encodeJpg(img.Image(width: 1024, height: 683));
    final thumbnail = await ImageCompressor.generateThumbnail(source);
    final decoded = img.decodeJpg(thumbnail);

    expect(decoded, isNotNull);
    expect(decoded!.width, lessThanOrEqualTo(200));
    expect(decoded.height, lessThanOrEqualTo(200));
    expect(
      decoded.width > decoded.height ? decoded.width : decoded.height,
      ImageCompressor.maxThumbnailSize,
    );
  });

  test('无法解码的材料图片会失败', () async {
    final file = File('${tempDir.path}/bad.jpg');
    await file.writeAsBytes(const [1, 2, 3, 4]);

    expect(
      ImageCompressor.compressImageFile(file),
      throwsA(isA<RangeError>()),
    );
  });
}
