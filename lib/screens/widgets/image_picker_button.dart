import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:talabna/blocs/service_post/service_post_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_event.dart';
import 'package:video_compress/video_compress.dart';

import '../../app_theme.dart';
import '../../data/models/photos.dart';
import '../../provider/language.dart';
import '../../utils/constants.dart';

class ImagePickerButton extends StatefulWidget {
  final Function(List<Photo>?) onImagesPicked;
  final ValueNotifier<List<Photo>?> initialPhotosNotifier;
  final int maxImages;
  final bool deleteApi;

  const ImagePickerButton({
    super.key,
    required this.onImagesPicked,
    required this.initialPhotosNotifier,
    required this.maxImages,
    required this.deleteApi,
  });

  @override
  ImagePickerButtonState createState() => ImagePickerButtonState();
}

class ImagePickerButtonState extends State<ImagePickerButton> {
  final Language _language = Language();
  List<Photo> _pickedImages = [];
  List<String?> _localMedia = [];
  final List<String> _thumbnails = [];
  bool _processing = false;
  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(0.0);

  bool get isProcessing => _processing;

  Future<String?> convertVideoToMp4FromOutside(File file) {
    return convertVideoToMp4(file);
  }

  @override
  void initState() {
    super.initState();
    widget.initialPhotosNotifier.addListener(() {
      if (!mounted) return; // Check if widget is still mounted

      if (widget.initialPhotosNotifier.value != null) {
        setState(() {
          _pickedImages = widget.initialPhotosNotifier.value!.map((photo) {
            final url = photo.src?.replaceAll('${Constants.apiBaseUrl}/', '');
            return Photo(
              id: photo.id,
              src: url,
              isVideo: photo.isVideo,
            );
          }).toList();

          // Initialize _localMedia with null values for API media
          _localMedia =
          List<String?>.filled(_pickedImages.length, null, growable: true);

          // Generate thumbnails for API videos
          _generateThumbnailsForApiVideos();
        });
      }
    });
  }


  String _getProperUrl(String? src) {
    if (src == null) return '';

    // Check if it's a local file path
    if (src.startsWith('/') || src.startsWith('file://')) {
      return src;
    }

    // Check if it's already a full URL
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return src;
    }

    // Otherwise, construct the full URL
    return '${Constants.apiBaseUrl}/$src';
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    try {
      final List<XFile> imageFiles =
          await picker.pickMultiImage(imageQuality: 50);

      if (imageFiles.isEmpty) {
        // User cancelled selection
        return;
      }

      if (_pickedImages.length + imageFiles.length > widget.maxImages) {
        _showMaxImagesSnackBar(widget.maxImages);
        return;
      }

      setState(() {
        _processing = true;
      });

      List<Photo> newImages = [];
      List<String?> newLocalPaths = [];

      for (XFile file in imageFiles) {
        final String imagePath = file.path;
        final img.Image? compressedImage =
            await _compressImage(File(imagePath));

        if (compressedImage != null) {
          final String? jpegPath = await _convertToJPEG(compressedImage);
          if (jpegPath != null) {
            newImages.add(Photo(
              src: jpegPath,
              isVideo: false,
            ));
            newLocalPaths.add(jpegPath);
          }
        }
      }

      setState(() {
        _pickedImages.addAll(newImages);
        _localMedia.addAll(newLocalPaths);
      });

      _submitLocalImages();
    } catch (e) {
      print('Error processing images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing images: $e')),
      );
    } finally {
      setState(() {
        _processing = false;
      });
    }
  }

  Future<void> _pickVideo() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile =
          await picker.pickVideo(source: ImageSource.gallery);

      if (pickedFile == null) {
        // User cancelled selection
        return;
      }

      if (_pickedImages.length + 1 > widget.maxImages) {
        _showMaxImagesSnackBar(widget.maxImages);
        return;
      }

      setState(() {
        _processing = true;
        _progressNotifier.value = 0.1; // Start progress
      });

      File file = File(pickedFile.path);
      String videoPath = file.path;
      print('Original video path: $videoPath');

      setState(() {
        _progressNotifier.value = 0.3; // Update progress
      });

      if (!file.path.toLowerCase().endsWith('.mp4')) {
        final convertedPath = await convertVideoToMp4(file);
        if (convertedPath != null) {
          videoPath = convertedPath;
          print('Converted video path: $videoPath');
        } else {
          throw Exception('Failed to convert video');
        }
      }

      setState(() {
        _progressNotifier.value = 0.7; // Update progress
      });

      final thumbnailPath = await _generateVideoThumbnail(videoPath);
      if (thumbnailPath == null) {
        throw Exception('Failed to generate thumbnail');
      }

      // Explicitly set isVideo to true
      final videoPhoto = Photo(
        src: videoPath,
        isVideo: true,
      );

      print('Adding video: ${videoPhoto.src}, isVideo: ${videoPhoto.isVideo}');

      if (!mounted) return; // Check mounted status before final setState
      setState(() {
        _pickedImages.add(videoPhoto);
        _localMedia.add(thumbnailPath);
        _thumbnails.add(thumbnailPath);
        _progressNotifier.value = 1.0;
      });

      _submitLocalImages();
    } catch (e) {
      print('Error processing video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing video: $e')),
      );
    } finally {
      setState(() {
        _processing = false;
      });
    }
  }

  void _submitLocalImages() {
    if (!mounted) return; // Add mounted check

    final List<Photo> updatedImages = [];

    for (int i = 0; i < _pickedImages.length; i++) {
      final photo = _pickedImages[i];
      if (photo.id != null) {
        // API media
        updatedImages.add(photo);
      } else {
        // Local media - use the source path directly
        updatedImages.add(Photo(
          src: photo.src,
          isVideo: photo.isVideo,
        ));
      }
    }

    widget.onImagesPicked(updatedImages);
  }

  void _removeImage(int index) async {
    final Photo photo = _pickedImages[index];
    final String? localPath = _localMedia[index];

    if (localPath != null) {
      // Handle local file deletion
      if (photo.isVideo ?? false) {
        // Delete thumbnail
        final File thumbnailFile = File(localPath);
        if (thumbnailFile.existsSync()) {
          await thumbnailFile.delete();
        }
        // Delete video file
        final File videoFile = File(photo.src ?? '');
        if (videoFile.existsSync()) {
          await videoFile.delete();
        }
        _thumbnails.remove(localPath);
      } else {
        // Delete local image
        final File localFile = File(localPath);
        if (localFile.existsSync()) {
          await localFile.delete();
        }
      }
    } else if (widget.deleteApi && photo.id != null) {
      // Handle API deletion
      context.read<ServicePostBloc>().add(
            DeleteServicePostImageEvent(servicePostImageId: photo.id!),
          );
    }

    setState(() {
      _pickedImages.removeAt(index);
      _localMedia.removeAt(index);
    });

    // Submit updated list
    _submitLocalImages();
  }

  List<Photo> getLocalImages() {
    // Return all images, both from API and locally added
    print('Retrieving local images: ${_pickedImages.length}');
    for (int i = 0; i < _pickedImages.length; i++) {
      final photo = _pickedImages[i];
      final isLocal = photo.id == null && photo.src != null;
      final isVideo = photo.isVideo ?? false;

      // Use Dart's min function from dart:math
      final displaySrc = photo.src != null
          ? '${photo.src!.substring(0, math.min(20, photo.src!.length))}...'
          : 'null';

      print(
          'Image $i: id=${photo.id}, isLocal=$isLocal, isVideo=$isVideo, src=$displaySrc');
    }
    return _pickedImages;
  }

  Future<img.Image?> _compressImage(File file) async {
    final img.Image? originalImage = img.decodeImage(await file.readAsBytes());
    if (originalImage != null) {
      const int maxSize = 1024 * 1024; // 1 MB
      final int originalSize = await file.length();
      if (originalSize > maxSize) {
        final img.Image compressedImage =
            img.copyResize(originalImage, width: 1920);
        final double compressionRatio = maxSize / originalSize;
        final List<int> compressedImageData = img.encodeJpg(
          compressedImage,
          quality: (compressionRatio * 100).toInt(),
        );
        await _saveImageToFile(
          compressedImageData,
          '${file.path}_compressed.jpg',
        );
        return compressedImage;
      } else {
        return originalImage;
      }
    }
    return null;
  }

  Future<String?> _convertToJPEG(img.Image image) async {
    final List<int> jpegData = img.encodeJpg(image);
    final String jpegPath = await _saveImageToFile(
      jpegData,
      '${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    return jpegPath;
  }

  Future<String> _saveImageToFile(List<int> imageData, String filePath) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String tempPath = tempDir.path;
    final File imageFile = File('$tempPath/$filePath');
    await imageFile.writeAsBytes(imageData);
    return imageFile.path;
  }

  Future<void> _showMaxImagesSnackBar(int maxImages) async {
    final snackBar = SnackBar(
      content: Text(_language.tMaxImagesLimitText(maxImages)),
      action: SnackBarAction(
        label: _language.tOkText(),
        onPressed: () {},
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_pickedImages.isNotEmpty)
                Container(
                  height: 120,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _pickedImages.length,
                    itemBuilder: (context, index) {
                      final photo = _pickedImages[index];
                      final localPath = _localMedia[index];

                      return Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _processing
                                  ? const Center(
                                      child: CircularProgressIndicator())
                                  : _buildMediaPreview(photo, localPath),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  iconSize: 18,
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.close,
                                      color: Colors.white),
                                  onPressed: () => _removeImage(index),
                                ),
                              ),
                            ),
                            if (photo.isVideo ?? false)
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    Icons.videocam,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              if (_pickedImages.length < widget.maxImages)
                InkWell(
                  onTap: _pickMedia,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDarkMode ? AppTheme.lightPrimaryColor : AppTheme.darkPrimaryColor,
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 40,
                          color: isDarkMode ? AppTheme.lightPrimaryColor : AppTheme.darkPrimaryColor,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _language.tAddMediaText(),
                          style: TextStyle(
                            color: isDarkMode ? AppTheme.lightPrimaryColor : AppTheme.darkPrimaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _language.tRemainingImagesText(
                              widget.maxImages - _pickedImages.length),
                          style: TextStyle(
                            color: isDarkMode ? AppTheme.lightPrimaryColor : AppTheme.darkPrimaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_processing)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    children: [
                      ValueListenableBuilder<double>(
                          valueListenable: _progressNotifier,
                          builder: (context, value, child) {
                            return LinearProgressIndicator(
                              value: value,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).primaryColor,
                              ),
                            );
                          }),
                      const SizedBox(height: 8),
                      Text(
                        _language.tProcessingMediaText(),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _pickMedia() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.lightBackgroundColor,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _language.tAddMediaText(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.image_outlined,
                      color: Colors.blue,
                    ),
                  ),
                  title: Text(_language.tChoosePhotosText()),
                  subtitle: Text(_language.tSelectFromGalleryText()),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImages();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.videocam_outlined,
                      color: Colors.purple,
                    ),
                  ),
                  title: Text(_language.tChooseVideoText()),
                  subtitle: Text(_language.tSelectFromGalleryText()),
                  onTap: () {
                    Navigator.pop(context);
                    _pickVideo();
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMediaPreview(Photo photo, String? localPath) {
    final bool isVideo = photo.isVideo ?? false;
    final bool isLocalFile = photo.src?.startsWith('/') ?? false;
    final bool isApiFile = photo.id != null;

    if (isVideo) {
      Widget thumbnailWidget;
      if (localPath != null) {
        // For both API and local videos, use the thumbnail
        thumbnailWidget = Image.file(
          File(localPath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('Error loading video thumbnail: $error');
            return Container(
              color: Colors.grey[200],
              child: const Icon(Icons.video_library, size: 40),
            );
          },
        );
      } else {
        thumbnailWidget = Container(
          color: Colors.grey[200],
          child: const Icon(Icons.video_library, size: 40),
        );
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          thumbnailWidget,
          const Center(
            child: Icon(
              Icons.play_circle_outline,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      );
    }

    // For local images
    if (isLocalFile) {
      return Image.file(
        File(photo.src!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading local image: $error');
          return Container(
            color: Colors.grey[200],
            child: const Icon(Icons.error),
          );
        },
      );
    }

    // For API images
    if (isApiFile) {
      final String url = _getProperUrl(photo.src);
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[200],
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (context, url, error) {
          print('Error loading API image: $error');
          return Container(
            color: Colors.grey[200],
            child: const Icon(Icons.error),
          );
        },
      );
    }

    return Container(
      color: Colors.grey[200],
      child: const Icon(Icons.error),
    );
  }

  Future<String?> _generateVideoThumbnail(String path) async {
    try {
      print('Starting thumbnail generation for: $path'); // Debug print

      // Use VideoCompress to generate thumbnail
      final thumbnailFile = await VideoCompress.getFileThumbnail(
        path,
        quality: 50, // Adjust quality as needed
        position: -1, // -1 means auto-select position
      );

      if (thumbnailFile == null) {
        print('Thumbnail generation returned null');
        return null;
      }

      print('Thumbnail saved to: ${thumbnailFile.path}'); // Debug print
      return thumbnailFile.path;
    } catch (e) {
      print('Error in thumbnail generation: $e'); // Debug print
      return null;
    }
  }

  Future<String?> convertVideoToMp4(File file) async {
    final outputPath = '${file.path.split('.').first}.mp4';
    final session = await FFmpegKit.executeAsync(
        '-i ${file.path} -c:v copy -c:a copy $outputPath');
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      if (kDebugMode) {
        print("Video converted successfully: $outputPath");
      }
      return outputPath;
    } else {
      if (kDebugMode) {
        print("Video conversion failed");
      }
      return null;
    }
  }

  // Generate thumbnails for API videos
  Future<void> _generateThumbnailsForApiVideos() async {
    for (int i = 0; i < _pickedImages.length; i++) {
      final photo = _pickedImages[i];
      if (photo.isVideo ?? false) {
        final String videoUrl = _getProperUrl(photo.src);
        try {
          // For remote videos, we need to download them first
          final tempDir = await getTemporaryDirectory();
          final tempVideoPath =
              '${tempDir.path}/temp_video_${DateTime.now().millisecondsSinceEpoch}_$i.mp4';

          // Download the video file using http package
          // You need to add this import: import 'package:http/http.dart' as http;
          final http.Client client = http.Client();
          final http.Response response = await client.get(Uri.parse(videoUrl));
          if (response.statusCode == 200) {
            await File(tempVideoPath).writeAsBytes(response.bodyBytes);

            // Now generate thumbnail from the downloaded file
            final thumbnailFile = await VideoCompress.getFileThumbnail(
              tempVideoPath,
              quality: 50,
              position: -1,
            );

            if (thumbnailFile != null) {
              setState(() {
                _localMedia[i] = thumbnailFile.path;
              });
            }

            // Clean up - delete the temporary video file
            await File(tempVideoPath).delete();
          } else {
            print('Failed to download video: HTTP ${response.statusCode}');
          }
          client.close();
        } catch (e) {
          print('Error generating thumbnail for API video: $e');
        }
      }
    }
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;

  DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const double dashWidth = 5;
    const double dashSpace = 5;
    double distance = 0;

    Path path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    Path dashPath = Path();

    for (PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
