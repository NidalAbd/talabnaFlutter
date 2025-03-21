// categories_dropdown.dart
import 'package:flutter/material.dart';
import 'package:talabna/app_theme.dart';
import 'package:talabna/data/models/categories.dart';
import 'package:talabna/data/repositories/categories_repository.dart';

import '../../core/service_locator.dart';

class CategoriesDropdown extends StatefulWidget {
  final Function(Category) onCategorySelected;
  final Category? initialValue;
  final String language;

  // Add a new parameter to identify if the widget is being called from service post
  final bool hideServicePostCategories;

  const CategoriesDropdown({
    super.key,
    required this.onCategorySelected,
    required this.language,
    this.initialValue,
    // Default to false to maintain backward compatibility
    this.hideServicePostCategories = false,
  });

  @override
  State<CategoriesDropdown> createState() => _CategoriesDropdownState();
}

class _CategoriesDropdownState extends State<CategoriesDropdown> {
  final CategoriesRepository _repository =
      serviceLocator<CategoriesRepository>();
  List<Category> _categories = [];
  Category? _selectedCategory;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialValue;
    _isInitialized = false;
    if (widget.initialValue != null) {
      _categories = [widget.initialValue!];
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final fetchedCategories = await _repository.getCategories();

      if (!mounted) return;

      setState(() {
        // Filter out categories 6 and 7 if hideServicePostCategories is true
        var filteredCategories = widget.hideServicePostCategories
            ? fetchedCategories
                .where((cat) => cat.id != 6 && cat.id != 7)
                .toList()
            : fetchedCategories;

        if (widget.initialValue != null) {
          // Only include initialValue if it's not supposed to be hidden
          if (!widget.hideServicePostCategories ||
              (widget.initialValue!.id != 6 && widget.initialValue!.id != 7)) {
            _categories = filteredCategories
                .where((cat) => cat.id != widget.initialValue!.id)
                .toList();
            _categories.insert(0, widget.initialValue!);
          } else {
            _categories = filteredCategories;
          }
        } else {
          _categories = filteredCategories;
          if (_selectedCategory == null && _categories.isNotEmpty) {
            _selectedCategory = _categories.first;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onCategorySelected(_categories.first);
            });
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load categories';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? AppTheme.darkBackgroundColor
        : AppTheme.lightBackgroundColor;
    final primaryColor =
        isDarkMode ? AppTheme.darkSecondaryColor : AppTheme.lightPrimaryColor;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.lightTextColor;

    if (_isLoading && _categories.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    if (_error != null && _categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: AppTheme.lightErrorColor)),
            TextButton(
              onPressed: _fetchCategories,
              style: TextButton.styleFrom(foregroundColor: primaryColor),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        DropdownButtonFormField<Category>(
          value: _selectedCategory,
          decoration: InputDecoration(
            labelText: "Select Category",
            labelStyle: TextStyle(color: textColor.withOpacity(0.8)),
            filled: true,
            fillColor: backgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
          ),
          dropdownColor:
              isDarkMode ? AppTheme.darkBackgroundColor : Colors.white,
          icon: Icon(Icons.arrow_drop_down, color: primaryColor),
          isExpanded: true,
          items: _categories.map((category) {
            return DropdownMenuItem<Category>(
              value: category,
              child: Text(
                _getCategoryName(category),
                style: TextStyle(color: textColor, fontSize: 16),
              ),
            );
          }).toList(),
          onChanged: (Category? newCategory) {
            if (newCategory != null && newCategory != _selectedCategory) {
              setState(() {
                _selectedCategory = newCategory;
              });
              widget.onCategorySelected(newCategory);
            }
          },
        ),
        if (_isLoading)
          Positioned(
            right: 40,
            top: 15,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: primaryColor,
              ),
            ),
          ),
      ],
    );
  }

  String _getCategoryName(Category category) {
    return category.name[widget.language] ??
        category.name['en'] ??
        'Unknown Category';
  }
}
