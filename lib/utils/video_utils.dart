
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:talabna/utils/video_utils.dart'; // Create this utility class to handle video conversion

// Add this utility class to a new file called video_utils.dart
// ============================================================

class VideoUtils {
  // Check if the file is a video file
  static bool isVideoFile(String path) {
    // Check by extension first
    final ext = p.extension(path).toLowerCase();
    if (['.mp4', '.mov', '.avi', '.wmv', '.mkv', '.flv', '.webm'].contains(ext)) {
      return true;
    }

    // Fall back to MIME type check
    final mimeType = lookupMimeType(path);
    return mimeType != null && mimeType.startsWith('video/');
  }
  // Get the correct MIME type for a file
  static String getMimeType(String path) {
    final mimeType = lookupMimeType(path);
    if (mimeType == null) {
      // Guess based on extension
      final ext = p.extension(path).toLowerCase();
      switch (ext) {
        case '.mp4':
          return 'video/mp4';
        case '.mov':
          return 'video/quicktime';
        case '.jpg':
        case '.jpeg':
          return 'image/jpeg';
        case '.png':
          return 'image/png';
        case '.gif':
          return 'image/gif';
        default:
          return 'application/octet-stream';
      }
    }
    return mimeType;
  }

  // Process a file for upload, handling video files appropriately
  static Future<http.MultipartFile?> prepareFileForUpload(
      File file,
      String fieldName,
      ) async {
    try {
      if (!await file.exists()) {
        print('File does not exist: ${file.path}');
        return null;
      }

      final bytes = await file.readAsBytes();
      final mimeType = getMimeType(file.path);

      // Force video/mp4 MIME type for all video files to avoid DASH parsing issues
      final correctedMimeType = mimeType.startsWith('video/')
          ? 'video/mp4'
          : mimeType;

      print('Processing file: ${file.path} with MIME type: $correctedMimeType');

      return http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: p.basename(file.path),
        contentType: MediaType.parse(correctedMimeType),
      );
    } catch (e) {
      print('Error preparing file for upload: $e');
      return null;
    }
  }


  // Ensure MP4 extension
  static String ensureMp4Extension(String path) {
    if (path.toLowerCase().endsWith('.mp4')) {
      return path;
    }

    final ext = p.extension(path);
    if (ext.isNotEmpty) {
      // Replace existing extension with .mp4
      return path.substring(0, path.length - ext.length) + '.mp4';
    } else {
      // Add .mp4 if no extension
      return path + '.mp4';
    }
  }

  // Process a media file for upload, handling both images and videos properly
  static Future<http.MultipartFile?> prepareMediaForUpload(
      File file,
      String fieldName, {
        bool? isVideoOverride,
      }) async {
    if (!await file.exists()) {
      print('VideoUtils: File does not exist: ${file.path}');
      return null;
    }

    try {
      final path = file.path;

      // Determine if this is a video file
      final bool isVideo = isVideoOverride ?? isVideoFile(path);

      // Print diagnostic info
      print('VideoUtils: Processing ${isVideo ? "video" : "image"}: $path');

      // Get file bytes
      final bytes = await file.readAsBytes();

      // Determine MIME type based on file type
      final String mimeType;
      if (isVideo) {
        // Always use video/mp4 for videos
        mimeType = 'video/mp4';
      } else {
        // For images, use the detected MIME type or fallback to JPEG
        mimeType = lookupMimeType(path) ?? 'image/jpeg';
      }

      // Determine filename
      String filename = p.basename(path);
      if (isVideo && !filename.toLowerCase().endsWith('.mp4')) {
        // Ensure MP4 extension for video files
        final basename = p.basenameWithoutExtension(path);
        filename = '$basename.mp4';
      }

      print('VideoUtils: Creating MultipartFile for $filename with type $mimeType');

      // Create the multipart file with the correct MIME type
      return http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      );
    } catch (e) {
      print('VideoUtils: Error preparing media for upload: $e');
      return null;
    }
  }

  // Process a batch of media files
  static Future<List<http.MultipartFile>> prepareMediaBatch(
      List<String> paths,
      String fieldName,
      Map<String, bool> isVideoMap,
      ) async {
    final List<http.MultipartFile> files = [];

    for (final path in paths) {
      final file = File(path);
      final isVideo = isVideoMap[path] ?? isVideoFile(path);

      final multipartFile = await prepareMediaForUpload(
        file,
        fieldName,
        isVideoOverride: isVideo,
      );

      if (multipartFile != null) {
        files.add(multipartFile);
      }
    }

    return files;
  }

  // Clean a video URL for playback
  static String prepareVideoUrl(String url) {
    // If URL contains query parameters, remove them
    if (url.contains('?')) {
      url = url.split('?')[0];
    }

    // Ensure MP4 extension for playback
    if (!url.toLowerCase().endsWith('.mp4')) {
      url = ensureMp4Extension(url);
    }

    return url;
  }
}