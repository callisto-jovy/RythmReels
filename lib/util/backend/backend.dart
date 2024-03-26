import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'ffmpeg_util.dart';

const String kCuttingRunnable = 'cutter.exe';

Future<File> initBackend() async {
  // TODO: This is NOT the way...

  // Move the file out of the assets bundle, so that the temp folder may be shared.
  // TODO: Would be better, if the backend had a argument which would set the temp folder
  // maybe pass a env??
  final File file = File('cutter.exe');

  // final bool exists = await file.exists();

  // TODO: Sanity check. Also, check the file version and override when a new version comes.
  // For now: Just always override
  // if (exists && await file.length() > 0) {
  //  return file;
  //}

  // write byte data into the applications document directory.
  final ByteData byteData = await rootBundle.load('assets/cutter.exe');

  return await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
}

Stream<String> runCutting(
    {required String audioPath, required String outputPath, required String videosPath, required List<double> beatTimes, File? imageOverlay}) async* {
  final List<String> beats = [];
  for (final double value in beatTimes) {
    beats.add('--beat');
    beats.add('${value / 1000}'); // Program expects the timestamps in seconds
  }

  // Load the cutter from the root bundle
  final File backend = await initBackend();

  final Process process = await Process.start(
    backend.path,
    [
      '--audio',
      audioPath,
      '--videos',
      videosPath,
      '--output',
      outputPath,
      if (await FFMpegHelper.instance.isFFMpegPresent()) ...['--ffmpeg', FFMpegHelper.instance.ffmpegBinDirectory!],
      if (imageOverlay != null) ...['--image_overlay', imageOverlay.path], // love dart for allowing spreads like this :)
      ...beats
    ],
  );

  //print(['--audio', audioPath, '--videos', videosPath, '--output', outputPath, ...beats].join(" "));

  //process.stdout.transform(utf8.decoder).forEach(print);
  //process.stderr.transform(utf8.decoder).forEach(print);

  yield* process.stdout.transform(utf8.decoder);

  // Potential error log.
  final List<String> errorLog = await process.stderr.transform(utf8.decoder).asyncMap((event) => 'Error: $event').toList();

  for (final String error in errorLog) {
    yield 'Error: $error';
  }

  // process exited non-successful
  if (await process.exitCode != 0) {
    throw Exception('Cutting process was not successful. Please check the output logs.');
  }
}
