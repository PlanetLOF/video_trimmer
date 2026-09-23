import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'timecode.dart';
import 'platform_util.dart';

/// Computes the default output container for a video file, taking into
/// account the PCM audio flag that forces the output to MKV.
String defaultOutputExtension(String inputPath, {required bool hasPcmAudio}) {
  var ext = p.extension(inputPath).replaceAll('.', '').toLowerCase();
  switch (ext) {
    case 'mkv':
    case 'mkv3':
      ext = 'mkv';
    case 'webm':
      ext = 'webm';
    case 'avi':
      ext = 'avi';
    case 'mov':
    case 'm4v':
    case 'mp4':
      ext = 'mp4';
    case 'ogv':
    case 'ogg':
      ext = 'ogv';
    default:
      ext = 'mp4';
  }
  if (ext == 'mp4' && hasPcmAudio) {
    ext = 'mkv';
  }
  return ext;
}

/// Builds the intelligent default filename for the trimmed video.
///
/// The returned name is `<stem> (<start> - <end>).<ext>`, using the output
/// container computed by [defaultOutputExtension]. The start and end entry
/// texts are normalized – parsed and reformatted, then the trailing
/// fractional zeros are stripped – before being embedded in the name.
String suggestedOutputFilename(
  String inputPath, {
  required bool hasPcmAudio,
  required String start,
  required String end,
}) {
  final stem = p.basenameWithoutExtension(inputPath);
  final ext = defaultOutputExtension(inputPath, hasPcmAudio: hasPcmAudio);

  String normalize(String time) {
    final ms = timestamp(time);
    if (ms == null) {
      return time;
    }
    return timeForFilename(timeToEntryText(Duration(milliseconds: ms)));
  }

  final startText = normalize(start);
  final endText = normalize(end);
  return PlatformUtil.sanitizeFileName(
    '$stem ($startText - $endText).$ext',
  );
}

/// Shows the native save dialog with a suggested filename and initial
/// directory. Returns the chosen path, or `null` when the user cancels.
Future<String?> showSaveDialog(
  BuildContext context, {
  required String inputPath,
  required bool hasPcmAudio,
  required String start,
  required String end,
}) async {
  final suggestedName = suggestedOutputFilename(
    inputPath,
    hasPcmAudio: hasPcmAudio,
    start: start,
    end: end,
  );
  final initialDirectory = File(inputPath).parent.path;
  final location = await getSaveLocation(
    suggestedName: suggestedName,
    initialDirectory: initialDirectory,
  );
  if (location == null) {
    return null;
  }
  return location.path;
}
