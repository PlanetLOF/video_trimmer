import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

const _videoTypeGroup = XTypeGroup(
  label: 'Video files',
  extensions: [
    '3gp',
    'asf',
    'avi',
    'divx',
    'flv',
    'mkv',
    'mkv3',
    'mka',
    'mov',
    'mp4',
    'mpg',
    'mpeg',
    'm4v',
    'mts',
    'm2ts',
    'mxf',
    'ogv',
    'ogm',
    'ts',
    'webm',
    'wmv',
    'vivo',
  ],
);

/// Shows the native file picker and returns the selected local path, or null.
Future<String?> openVideoFile(BuildContext context) async {
  final file = await openFile(acceptedTypeGroups: [_videoTypeGroup]);
  if (file == null) {
    return null;
  }
  return file.path;
}