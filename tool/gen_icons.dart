// Buat ikon peluncur, logo, dan favicon dari satu gambar sumber.
// Jalankan: dart run tool/gen_icons.dart
import 'dart:io';
import 'package:image/image.dart' as img;

const src = 'assets/logo_new.webp';

Future<void> main() async {
  final s = img.decodeImage(await File(src).readAsBytes());
  if (s == null) {
    stderr.writeln('Gagal membaca $src');
    exit(1);
  }
  final side = s.width > s.height ? s.width : s.height;
  final square = img.Image(width: side, height: side, numChannels: 4);
  img.compositeImage(square, s,
      dstX: ((side - s.width) / 2).round(), dstY: ((side - s.height) / 2).round());

  img.Image fit(int size, double scale) {
    final canvas = img.Image(width: size, height: size, numChannels: 4);
    final t = (size * scale).round();
    final r = img.copyResize(square, width: t, height: t, interpolation: img.Interpolation.cubic);
    img.compositeImage(canvas, r,
        dstX: ((size - t) / 2).round(), dstY: ((size - t) / 2).round());
    return canvas;
  }

  Future<void> write(String path, img.Image im) async {
    await File(path).create(recursive: true);
    await File(path).writeAsBytes(img.encodePng(im));
    stdout.writeln('  $path ${im.width}x${im.height}');
  }

  const res = 'android/app/src/main/res';
  const dens = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};
  for (final e in dens.entries) {
    await write('$res/mipmap-${e.key}/ic_launcher.png', fit((48 * e.value).round(), 0.92));
    await write('$res/mipmap-${e.key}/ic_launcher_foreground.png', fit((108 * e.value).round(), 0.68));
  }
  await write('assets/logo.png', fit(1024, 1.0));
  await write('docs/logo.png', fit(512, 1.0));
  await write('docs/favicon.png', fit(256, 1.0));
}
