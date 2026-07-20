import 'dart:io';

/// 将文本先完整写入同目录临时文件，再替换目标文件。
class AtomicFileWriter {
  static const String backupSuffix = '.bak';
  static const String temporarySuffix = '.tmp';

  static Future<void> write(File target, String contents) async {
    final temporary = File('${target.path}$temporarySuffix');
    final backup = File('${target.path}$backupSuffix');

    try {
      await temporary.writeAsString(contents, flush: true);
      if (await target.exists()) {
        await target.copy(backup.path);
      }
      await temporary.rename(target.path);
    } catch (_) {
      if (await temporary.exists()) {
        await temporary.delete();
      }
      rethrow;
    }
  }
}
