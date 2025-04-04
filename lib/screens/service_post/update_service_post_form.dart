import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:talabna/blocs/service_post/service_post_bloc.dart';
import 'package:talabna/blocs/service_post/service_post_event.dart';
import 'package:talabna/blocs/service_post/service_post_state.dart';
import 'package:talabna/data/models/categories.dart';
import 'package:talabna/data/models/service_post.dart';
import 'package:talabna/screens/interaction_widget/point_balance.dart';
import 'package:talabna/screens/widgets/category_dropdown.dart';
import 'package:talabna/screens/widgets/error_widget.dart';
import 'package:talabna/screens/widgets/image_picker_button.dart';
import 'package:talabna/screens/widgets/subcategory_dropdown.dart';
import 'package:talabna/screens/widgets/success_widget.dart';

import '../../data/models/photos.dart';
import '../../data/models/user.dart';
import '../../provider/language.dart';

class UpdatePostScreen extends StatefulWidget {
  final int userId;
  final int servicePostId;
  final ServicePost servicePost;
  final User user;

  const UpdatePostScreen({
    super.key,
    required this.userId,
    required this.servicePostId,
    required this.servicePost,
    required this.user,
  });

  @override
  _UpdatePostScreenState createState() => _UpdatePostScreenState();
}

class _UpdatePostScreenState extends State<UpdatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey<ImagePickerButtonState> _imagePickerButtonKey =
      GlobalKey<ImagePickerButtonState>();
  final Language _language = Language();
  final PageController _pageController = PageController();
  late final ValueNotifier<List<Photo>> _photosNotifier;

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _typeController;
  late final String _selectedPriceCurrency;

  Category? _selectedCategory;
  SubCategory? _selectedSubCategory;
  List<Photo>? _pickedImages;
  bool _isLoading = false;
  bool _isFormDirty = false;
  int _currentStep = 0;

  final List<Map<String, dynamic>> _steps = [
    {'title': 'الصور', 'icon': Icons.image},
    {'title': 'التفاصيل', 'icon': Icons.description},
    {'title': 'الفئة', 'icon': Icons.category},
    {'title': 'السعر', 'icon': Icons.monetization_on},
  ];

  @override
  void initState() {
    super.initState();
    _photosNotifier = ValueNotifier(widget.servicePost.photos ?? []);
    _initializeData();
  }

  void _initializeData() {
    final post = widget.servicePost;

    // Initialize controllers
    _titleController = TextEditingController(text: post.title);
    _descriptionController = TextEditingController(text: post.description);
    _priceController =
        TextEditingController(text: post.price?.toString() ?? '0');
    _typeController = TextEditingController(text: post.type ?? 'عرض');

    // Add listeners after setting initial values
    _titleController.addListener(_markFormDirty);
    _descriptionController.addListener(_markFormDirty);
    _priceController.addListener(_markFormDirty);

    // Initialize state variables
    _selectedCategory = post.category;
    _selectedSubCategory = post.subCategory;

    // Initialize photos with a direct copy
    if (post.photos != null && post.photos!.isNotEmpty) {
      _pickedImages = List<Photo>.from(post.photos!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _photosNotifier.value = List<Photo>.from(post.photos!);
      });
    }
  }

  void _markFormDirty() {
    if (!mounted) return;
    Future.microtask(() {
      if (!_isFormDirty) {
        setState(() => _isFormDirty = true);
      }
    });
  }
  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Images
        return true;
      case 1: // Details
        if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
          return false;
        }
        if (_descriptionController.text.length < 80) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_language.getLanguage() == 'ar'
                  ? 'يجب أن يكون الوصف ٨٠ حرف على الأقل'
                  : 'Description must be at least 80 characters'),
            ),
          );
          return false;
        }
        return true;
      case 2: // Category
        return _selectedCategory != null && _selectedSubCategory != null;
      case 3: // Price
        if (_selectedCategory?.id == 7) return true;
        final price = double.tryParse(_priceController.text) ?? 0;
        return price > 0;
      default:
        return true;
    }
  }

  Widget _buildStepIndicator() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentStep + 1) / _steps.length,
            backgroundColor: Colors.grey[200],
            valueColor:
                AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          ),
          const SizedBox(height: 16),
          _buildStepsList(),
        ],
      ),
    );
  }

  Widget _buildStepsList() {
    return Expanded(
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _steps.length,
        itemBuilder: (context, index) {
          final step = _steps[index];
          final isActive = _currentStep == index;
          final isCompleted = index < _currentStep;

          return Container(
            width: 80,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? Theme.of(context).primaryColor
                        : isCompleted
                            ? Colors.green
                            : Colors.grey[300],
                  ),
                  child: Icon(
                    step['icon'] as IconData,
                    color: isActive || isCompleted ? Colors.white : Colors.grey,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step['title'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isActive ? Theme.of(context).primaryColor : Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageSection() {
    return SingleChildScrollView(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _language.tImageText(),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ImagePickerButton(
                key: _imagePickerButtonKey,
                onImagesPicked: (photos) {
                  if (photos != null) {
                    setState(() {
                      _pickedImages = List<Photo>.from(photos);
                      _photosNotifier.value = photos;
                      _markFormDirty();
                    });
                  }
                },
                initialPhotosNotifier: _photosNotifier,
                maxImages: 4,
                deleteApi: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return SingleChildScrollView(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                textDirection: TextDirection.rtl,
                maxLength: 14,
                decoration: InputDecoration(
                  labelText: _language.tTitleText(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) =>
                    (value?.isEmpty ?? true) ? _language.tRequiredText() : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLength: 5000,
                textDirection: TextDirection.rtl,
                minLines: 1,
                maxLines: 10,
                decoration: InputDecoration(
                  labelText: _language.tDescriptionText(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  helperText: _language.getLanguage() == 'ar'
                      ? 'يجب أن يكون الوصف ٨٠ حرف على الأقل (${_descriptionController.text.length}/80)'
                      : 'Description must be at least 80 characters (${_descriptionController.text.length}/80)',
                  helperStyle: TextStyle(
                    color: _descriptionController.text.length < 80 ? Colors.red : Colors.green,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return _language.tRequiredText();
                  }
                  if (value.length < 80) {
                    return _language.getLanguage() == 'ar'
                        ? 'يجب أن يكون الوصف ٨٠ حرف على الأقل'
                        : 'Description must be at least 80 characters';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _markFormDirty();
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    return SingleChildScrollView(
        child: Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CategoriesDropdown(
              onCategorySelected: (newCategory) {
                if (!mounted) return;
                Future.microtask(() {
                  setState(() {
                    _selectedCategory = newCategory;
                    // Only reset subcategory if category changed
                    if (newCategory.id != widget.servicePost.category?.id) {
                      _selectedSubCategory = null;
                    }
                    _markFormDirty();
                  });
                });
              },
              language: _language.toString(),
              initialValue: widget.servicePost.category,
              // Set this to true to hide categories 6 and 7 in update screen
              hideServicePostCategories: true,
            ),
            const SizedBox(height: 16),
            SubCategoriesDropdown(
              selectedCategory:
                  _selectedCategory ?? widget.servicePost.category,
              onSubCategorySelected: (newSubCategory) {
                if (!mounted) return;
                Future.microtask(() {
                  setState(() {
                    _selectedSubCategory = newSubCategory;
                    _markFormDirty();
                  });
                });
              },
              initialValue: widget.servicePost.subCategory,
              selectedSubCategory:
                  _selectedSubCategory ?? widget.servicePost.subCategory,
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildPriceSection() {
    return SingleChildScrollView(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedCategory?.id != 7) ...[
                TextFormField(
                  controller: _priceController,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: _language.tPriceText(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return _language.tRequiredText();
                    }
                    if (double.tryParse(value!) == null) {
                      return _language.tInvalidNumberText();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.grey),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _language.tCurrencyText(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.user.country!.currencyCode.toString(),
                          style: const TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Type Dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: _language.tTypeText(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                value: _typeController.text,
                onChanged: (newValue) {
                  if (newValue != null) {
                    setState(() {
                      _typeController.text = newValue;
                      _markFormDirty();
                    });
                  }
                },
                items: EnumTranslations.getTypeOptions(_language.getLanguage())
                    .map((option) => DropdownMenuItem<String>(
                          value: option['value'],
                          child: Text(option['display']!),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> handleSubmit() async {
    if (!_formKey.currentState!.validate() || !_validateForm()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create updated service post with current photos
      final updatedPost = ServicePost(
        id: widget.servicePostId,
        title: _titleController.text,
        description: _descriptionController.text,
        price: double.tryParse(_priceController.text) ?? 0,
        locationLatitudes: widget.servicePost.locationLatitudes,
        locationLongitudes: widget.servicePost.locationLongitudes,
        userId: widget.userId,
        type: _typeController.text,
        category: _selectedCategory ?? widget.servicePost.category,
        subCategory: _selectedSubCategory ?? widget.servicePost.subCategory,
        photos: _pickedImages,
        // Always include the original badge parameters
        haveBadge: widget.servicePost.haveBadge,
        badgeDuration: widget.servicePost.badgeDuration,
      );

      // Process images directly from _pickedImages like in create screen
      final imageFiles = <http.MultipartFile>[];

      // Process images if any are selected
      if (_pickedImages != null) {
        for (final photo in _pickedImages!) {
          // Only process new photos (ones without an ID)
          if (photo.id == null && photo.src != null) {
            try {
              final file = File(photo.src!);
              if (await file.exists()) {
                final bytes = await file.readAsBytes();

                // Handle video files explicitly
                final bool isVideo = photo.isVideo ?? false;
                final String mimeType;

                // Set the correct mime type based on file type
                if (isVideo) {
                  mimeType = 'video/mp4';
                  print('Processing video file: ${photo.src}, isVideo: ${photo.isVideo}');
                } else {
                  mimeType = lookupMimeType(photo.src!) ?? 'image/jpeg';
                  print('Processing image file: ${photo.src}, type: $mimeType');
                }

                final filename = p.basename(photo.src!);
                print('Creating MultipartFile for $filename with type $mimeType');

                final multipartFile = http.MultipartFile.fromBytes(
                  'images[]',
                  bytes,
                  filename: filename,
                  contentType: MediaType.parse(mimeType),
                );
                imageFiles.add(multipartFile);
              } else {
                print('File does not exist: ${photo.src}');
              }
            } catch (e) {
              print('Error processing media file: $e');
            }
          }
        }
      }

      print('Sending update with ${imageFiles.length} new media files');

      // Add the update events
      context.read<ServicePostBloc>().add(UpdateServicePostEvent(
        servicePost: updatedPost,
        imageFiles: imageFiles,
      ));
    } catch (e) {
      print('Submit error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_language.tErrorUpdatingPost()))
        );
      }
    }
  }


  Future<List<http.MultipartFile>> _processImages() async {
    final imageFiles = <http.MultipartFile>[];
    final localImages = _imagePickerButtonKey.currentState?.getLocalImages();

    print('Processing local images: ${localImages?.length ?? 0}');

    if (localImages == null || localImages.isEmpty) return imageFiles;

    int processedCount = 0;
    int skipCount = 0;

    for (final photo in localImages) {
      if (photo.src == null) {
        print('Skipping image with null src');
        skipCount++;
        continue;
      }

      if (photo.id != null) {
        print('Skipping image with ID: ${photo.id}');
        skipCount++;
        continue;
      }

      // Skip if it's a server URL
      if (photo.src!.startsWith('http')) {
        print('Skipping server URL: ${photo.src}');
        skipCount++;
        continue;
      }

      try {
        final file = File(photo.src!);
        if (await file.exists()) {
          final bool isVideo = photo.isVideo ?? false;
          print('Processing ${isVideo ? "video" : "image"}: ${file.path}');

          final bytes = await file.readAsBytes();
          final String mimeType = isVideo
              ? 'video/mp4'
              : (lookupMimeType(photo.src!) ?? 'image/jpeg');

          print('File size: ${bytes.length} bytes, MIME type: $mimeType');

          final imageFile = http.MultipartFile.fromBytes(
            'images[]',
            bytes,
            filename: p.basename(photo.src!),
            contentType: MediaType.parse(mimeType),
          );
          imageFiles.add(imageFile);
          processedCount++;
        } else {
          print('File does not exist: ${photo.src}');
          skipCount++;
        }
      } catch (e) {
        print('Error processing media file: $e');
        skipCount++;
      }
    }

    print(
        'Total files: ${localImages.length}, Processed: $processedCount, Skipped: $skipCount');
    return imageFiles;
  }

  bool _isValidImageType(String mimeType) {
    return ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'video/mp4']
        .contains(mimeType);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_language.tUpdateText()),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: PointBalance(
              userId: widget.userId,
              showBalance: true,
              canClick: true,
            ),
          ),
        ],
      ),
      body: BlocListener<ServicePostBloc, ServicePostState>(
        listener: (context, state) {
          print('Current state: $state'); // Debug state changes

          if (state is ServicePostLoading) {
            // Keep the loading state active
            print('ServicePost loading: ${state.event}');
          } else if (state is ServicePostOperationSuccess) {
            if (mounted) {
              setState(() => _isLoading = false);

              // Check if there were videos in the update
              final hasVideos = _pickedImages?.any((photo) =>
                      photo.id == null && (photo.isVideo ?? false)) ??
                  false;

              if (hasVideos) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_language.tVideoUploadedText()),
                    duration: const Duration(seconds: 5),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                showCustomSnackBar(
                  context,
                  _language.tPostUpdatedSuccessfully(),
                  type: SnackBarType.success,
                );
              }

              Navigator.of(context).pop();
            }
          } else if (state is ServicePostImageDeletingSuccess) {
            if (mounted) {
              showCustomSnackBar(context, 'info', type: SnackBarType.info);
            }
          } else if (state is ServicePostOperationFailure) {
            print(
                'Operation failure: ${state.errorMessage}'); // Debug error message
            if (mounted) {
              setState(() => _isLoading = false);
              ErrorCustomWidget.show(context, message: state.errorMessage);
            }
          }
        },
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildStepIndicator(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    if (mounted) {
                      setState(() => _currentStep = index);
                    }
                  },
                  children: [
                    _buildImageSection(),
                    _buildDetailsSection(),
                    _buildCategorySection(),
                    _buildPriceSection(),
                  ],
                ),
              ),
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final bool isImageProcessing =
        _imagePickerButtonKey.currentState?.isProcessing ?? false;
    final bool isButtonDisabled = _isLoading || isImageProcessing;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton.icon(
              onPressed: isButtonDisabled
                  ? null
                  : () {
                      if (mounted) {
                        setState(() {
                          _currentStep--;
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        });
                      }
                    },
              icon: const Icon(Icons.arrow_back),
              label: Text(_language.tPreviousText()),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ElevatedButton.icon(
            onPressed: isButtonDisabled
                ? null
                : () {
                    if (_currentStep < _steps.length - 1) {
                      if (_validateCurrentStep()) {
                        if (mounted) {
                          setState(() {
                            _currentStep++;
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          });
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(_language.tFillAllFieldsText())),
                        );
                      }
                    } else {
                      if (_validateForm()) {
                        handleSubmit();
                      }
                    }
                  },
            icon: isButtonDisabled
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  )
                : Icon(_currentStep < _steps.length - 1
                    ? Icons.arrow_forward
                    : Icons.check),
            label: Text(
              _currentStep < _steps.length - 1
                  ? _language.tNextText()
                  : _language.tUpdateText(),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _validateForm() {
    if (_selectedCategory == null || _selectedSubCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_language.tSelectCategoryText())));
      return false;
    }

    if (_selectedCategory?.id != 7) {
      final price = double.tryParse(_priceController.text) ?? 0;
      if (price <= 0) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_language.tEnterPriceText())));
        return false;
      }
    }

    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_language.tFillAllFieldsText())));
      return false;
    }

    return true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _typeController.dispose();
    _pageController.dispose();
    _photosNotifier.dispose();

    super.dispose();
  }
}
