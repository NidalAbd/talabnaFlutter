import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

/// Helper class for handling image and video processing operations
class MediaProcessorHelper {
  /// Processes an image file with optimizations
  /// Returns the path to the processed image file
  static Future<String?> processImage(
    File file, {
    int quality = 85,
    int maxWidthHeight = 1920,
    double maxSizeMB = 10,
  }) async {
    try {
      // Check file size
      final fileSize = await file.length();
      final fileSizeMB = fileSize / (1024 * 1024);

      if (fileSizeMB > maxSizeMB) {
        return null; // File too large
      }

      // Process in compute to avoid UI blocking
      return compute(_processImageIsolate, {
        'path': file.path,
        'quality': quality,
        'maxWidthHeight': maxWidthHeight,
      });
    } catch (e) {
      _logError('Image processing error', e);
      return null;
    }
  }

  /// Worker function for processing images in a separate isolate
  static Future<String?> _processImageIsolate(
      Map<String, dynamic> params) async {
    try {
      final String path = params['path'];
      final int quality = params['quality'];
      final int maxWidthHeight = params['maxWidthHeight'];

      // Read the image file
      final bytes = await File(path).readAsBytes();
      final originalImage = img.decodeImage(bytes);

      if (originalImage == null) return null;

      // Resize if needed (keeping aspect ratio)
      img.Image processedImage;
      if (originalImage.width > maxWidthHeight ||
          originalImage.height > maxWidthHeight) {
        if (originalImage.width > originalImage.height) {
          processedImage = img.copyResize(originalImage, width: maxWidthHeight);
        } else {
          processedImage =
              img.copyResize(originalImage, height: maxWidthHeight);
        }
      } else {
        processedImage = originalImage;
      }

      // Encode to JPEG with specified quality
      final List<int> jpegData =
          img.encodeJpg(processedImage, quality: quality);

      // Get temp directory for saving
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Save the processed image
      await File(outputPath).writeAsBytes(jpegData);
      return outputPath;
    } catch (e) {
      print('Error in image processing isolate: $e');
      return null;
    }
  }

  /// Batch process multiple images
  /// Returns a list of processed image paths
  static Future<List<String>> processImages(
    List<File> files, {
    int quality = 85,
    int maxWidthHeight = 1920,
    double maxSizeMB = 10,
    Function(double)? onProgress,
  }) async {
    final List<String> results = [];

    for (int i = 0; i < files.length; i++) {
      // Update progress
      if (onProgress != null) {
        onProgress(i / files.length);
      }

      // Process the image
      final result = await processImage(
        files[i],
        quality: quality,
        maxWidthHeight: maxWidthHeight,
        maxSizeMB: maxSizeMB,
      );

      if (result != null) {
        results.add(result);
      }
    }

    // Final progress update
    if (onProgress != null) {
      onProgress(1.0);
    }

    return results;
  }

  /// Converts a video file to MP4 format
  /// Returns the path to the converted video file
  static Future<String?> convertVideoToMp4(
    File file, {
    Function(double)? onProgress,
  }) async {
    try {
      // Create output path
      final outputPath = '${file.path.split('.').first}_converted.mp4';
      final completer = Completer<String?>();

      // Default progress update
      onProgress?.call(0.1);

      // Execute FFmpeg command
      await FFmpegKit.executeAsync(
        '-i ${file.path} -c:v copy -c:a copy $outputPath',
        (session) async {
          final returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode)) {
            onProgress?.call(1.0);
            completer.complete(outputPath);
          } else {
            completer.complete(null);
          }
        },
        (log) {
          // Log callback - can be used for detailed logs
          // print('FFmpeg log: ${log.getMessage()}');
        },
        (statistics) {
          // Update progress based on timestamps if available
          if (statistics.getTime() > 0) {
            // We don't know the total duration easily, so just show activity
            onProgress?.call(0.5); // Indicate ongoing process
          }
        },
      );

      return await completer.future;
    } catch (e) {
      _logError('Video conversion error', e);
      return null;
    }
  }

  /// Generates a thumbnail from a video file
  /// Returns the path to the thumbnail image
  static Future<String?> generateVideoThumbnail(
    String videoPath, {
    int maxHeight = 200,
    int quality = 85,
  }) async {
    try {
      // Use VideoCompress to generate a thumbnail
      // Note that VideoCompress returns a File directly
      final thumbnailFile = await VideoCompress.getFileThumbnail(
        videoPath,
        quality: quality, // Quality percentage (0-100)
        position: -1, // -1 means auto-select position (usually at 0s)
      );

      if (thumbnailFile == null) return null;

      // If you need to resize the thumbnail to match the maxHeight parameter
      // (since VideoCompress doesn't have a direct maxHeight parameter)
      if (maxHeight < 200) {
        // Default size from VideoCompress is usually larger
        // Read the thumbnail file
        final bytes = await thumbnailFile.readAsBytes();
        final originalImage = img.decodeImage(bytes);

        if (originalImage != null && originalImage.height > maxHeight) {
          // Resize keeping aspect ratio
          final processedImage = img.copyResize(
            originalImage,
            height: maxHeight,
            interpolation: img.Interpolation.linear,
          );

          // Encode to JPEG with specified quality
          final List<int> jpegData =
              img.encodeJpg(processedImage, quality: quality);

          // Save the resized thumbnail
          await thumbnailFile.writeAsBytes(jpegData);
        }
      }

      return thumbnailFile.path;
    } catch (e) {
      _logError('Thumbnail generation error', e);
      return null;
    }
  }

  /// Processes a video file (checks size, converts if needed, generates thumbnail)
  /// Returns a map with 'videoPath' and 'thumbnailPath'
  static Future<Map<String, String?>?> processVideo(
    File file, {
    double maxSizeMB = 50,
    Function(double)? onProgress,
    Function(String)? onStatusUpdate,
  }) async {
    try {
      onProgress?.call(0.1);
      onStatusUpdate?.call('Checking video size...');

      // Check file size
      final fileSize = await file.length();
      final fileSizeMB = fileSize / (1024 * 1024);

      if (fileSizeMB > maxSizeMB) {
        return null; // File too large
      }

      onProgress?.call(0.2);
      String videoPath = file.path;

      // Convert to MP4 if needed
      if (!file.path.toLowerCase().endsWith('.mp4')) {
        onStatusUpdate?.call('Converting video format...');
        final convertedPath = await convertVideoToMp4(
          file,
          onProgress: (p) {
            // Scale progress within this phase
            onProgress?.call(0.2 + p * 0.6);
          },
        );

        if (convertedPath != null) {
          videoPath = convertedPath;
        } else {
          return null; // Conversion failed
        }
      } else {
        // Skip conversion
        onProgress?.call(0.8);
      }

      // Generate thumbnail
      onStatusUpdate?.call('Generating thumbnail...');
      final thumbnailPath = await generateVideoThumbnail(videoPath);

      if (thumbnailPath == null) {
        return null; // Thumbnail generation failed
      }

      onProgress?.call(1.0);

      return {
        'videoPath': videoPath,
        'thumbnailPath': thumbnailPath,
      };
    } catch (e) {
      _logError('Video processing error', e);
      return null;
    }
  }

  /// Safely delete a file if it exists
  static Future<bool> safelyDeleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      _logError('Error deleting file', e);
      return false;
    }
  }

  /// Log errors with consistent formatting
  static void _logError(String message, dynamic error) {
    if (kDebugMode) {
      print('$message: $error');
    }
  }
}
