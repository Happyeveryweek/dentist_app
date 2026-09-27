import 'package:dentist_app_windows/features/patients/widgets/single_material_editor.dart';
import 'package:dentist_app_windows/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('5 张图片按张和阶段推进进度', () {
    expect(
      MaterialImageSaveProgress.value(
        finishedImages: 1,
        totalImages: 5,
        phaseFraction: MaterialImageSaveProgress.compressFraction,
      ),
      0.2,
    );
    expect(
      MaterialImageSaveProgress.value(
        finishedImages: 1,
        totalImages: 5,
        phaseFraction: MaterialImageSaveProgress.thumbnailFraction,
      ),
      closeTo(0.32, 0.0001),
    );
    expect(
      MaterialImageSaveProgress.value(
        finishedImages: 1,
        totalImages: 5,
        phaseFraction: MaterialImageSaveProgress.writeFraction,
      ),
      closeTo(0.36, 0.0001),
    );
    expect(
      MaterialImageSaveProgress.value(
        finishedImages: 2,
        totalImages: 5,
        phaseFraction: MaterialImageSaveProgress.compressFraction,
      ),
      0.4,
    );
  });

  test('单张图片在三个阶段分别停在 0、0.6、0.8，完成后为 1', () {
    expect(
      MaterialImageSaveProgress.value(
        finishedImages: 0,
        totalImages: 1,
        phaseFraction: MaterialImageSaveProgress.compressFraction,
      ),
      0,
    );
    expect(
      MaterialImageSaveProgress.value(
        finishedImages: 0,
        totalImages: 1,
        phaseFraction: MaterialImageSaveProgress.thumbnailFraction,
      ),
      0.6,
    );
    expect(
      MaterialImageSaveProgress.value(
        finishedImages: 0,
        totalImages: 1,
        phaseFraction: MaterialImageSaveProgress.writeFraction,
      ),
      0.8,
    );
    expect(
      MaterialImageSaveProgress.value(
        finishedImages: 1,
        totalImages: 1,
        phaseFraction: MaterialImageSaveProgress.compressFraction,
      ),
      1,
    );
    expect(
      MaterialImageSaveProgress.value(
        finishedImages: 0,
        totalImages: 0,
        phaseFraction: MaterialImageSaveProgress.compressFraction,
      ),
      0,
    );
  });

  testWidgets('保存进度显示张数、文件名、阶段和进度条', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: MaterialImageSaveProgressBanner(
            current: 2,
            total: 5,
            fileName: 'IMG_2031.jpg',
            phase: MaterialImageSaveProgress.compressingLabel,
            value: 0.2,
          ),
        ),
      ),
    );

    expect(find.text('正在处理 2/5'), findsOneWidget);
    expect(find.text('IMG_2031.jpg · 压缩中'), findsOneWidget);
    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, 0.2);
  });
}
