import 'package:flutter/material.dart';
import 'package:talabna/data/models/service_post.dart';
import 'package:talabna/provider/language.dart';

class FilterOptions {
  final String? typeFilter;
  final RangeValues? priceRangeFilter;

  FilterOptions({this.typeFilter, this.priceRangeFilter});

  bool get hasActiveFilters => typeFilter != null || priceRangeFilter != null;

  // Create a copy with updated fields
  FilterOptions copyWith({
    String? typeFilter,
    RangeValues? priceRangeFilter,
    bool clearTypeFilter = false,
    bool clearPriceFilter = false,
  }) {
    return FilterOptions(
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      priceRangeFilter: clearPriceFilter ? null : (priceRangeFilter ?? this.priceRangeFilter),
    );
  }
}

class ServicePostFilterBar extends StatefulWidget {
  final List<ServicePost> posts;
  final FilterOptions filterOptions;
  final Function(FilterOptions) onFilterChanged;
  final bool initiallyExpanded;

  const ServicePostFilterBar({
    Key? key,
    required this.posts,
    required this.filterOptions,
    required this.onFilterChanged,
    this.initiallyExpanded = false,
  }) : super(key: key);

  @override
  _ServicePostFilterBarState createState() => _ServicePostFilterBarState();
}

class _ServicePostFilterBarState extends State<ServicePostFilterBar> with SingleTickerProviderStateMixin {
  late bool _showFilters;
  late AnimationController _animationController;
  late Animation<double> _arrowAnimation;

  final language = Language();

  @override
  void initState() {
    super.initState();
    _showFilters = widget.initiallyExpanded;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _arrowAnimation = Tween<double>(
      begin: 0.0,
      end: 0.5,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    if (_showFilters) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleFiltersVisibility() {
    setState(() {
      _showFilters = !_showFilters;
      if (_showFilters) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _resetFilters() {
    widget.onFilterChanged(FilterOptions());
  }

  void _updateTypeFilter(String type) {
    final currentTypeFilter = widget.filterOptions.typeFilter;
    final newTypeFilter = currentTypeFilter == type ? null : type;
    widget.onFilterChanged(widget.filterOptions.copyWith(typeFilter: newTypeFilter));
  }

  void _updatePriceFilter(RangeValues values) {
    widget.onFilterChanged(widget.filterOptions.copyWith(priceRangeFilter: values));
  }

  // Get min and max prices from posts
  RangeValues _getPriceRange() {
    if (widget.posts.isEmpty) {
      return RangeValues(0, 1000);
    }

    double minPrice = double.infinity;
    double maxPrice = 0;

    for (var post in widget.posts) {
      final price = post.price?.toDouble() ?? 0;
      if (price < minPrice) minPrice = price;
      if (price > maxPrice) maxPrice = price;
    }

    // Make sure we have a reasonable range
    if (minPrice == maxPrice) {
      maxPrice = minPrice + 100;
    }

    // If min is infinity (no posts with price), set it to 0
    if (minPrice == double.infinity) {
      minPrice = 0;
    }

    // If max is still 0, set it to a reasonable value
    if (maxPrice == 0) {
      maxPrice = 1000;
    }

    return RangeValues(minPrice, maxPrice);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isArabic = language.getLanguage() == 'ar';

    // Get price range
    final priceRange = _getPriceRange();

    // Current price filter or default range
    final currentPriceFilter = widget.filterOptions.priceRangeFilter ?? priceRange;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Filter toggle button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _toggleFiltersVisibility,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.filter_list,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isArabic ? 'فلترة' : 'Filter',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const Spacer(),
                          RotationTransition(
                            turns: _arrowAnimation,
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.filterOptions.hasActiveFilters)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: IconButton(
                      icon: Icon(Icons.clear, color: theme.colorScheme.primary),
                      onPressed: _resetFilters,
                      tooltip: isArabic ? 'إعادة ضبط' : 'Reset Filters',
                    ),
                  ),
              ],
            ),
          ),

          // Expandable filter options
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _showFilters ? Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type filter
                  Text(
                    isArabic ? 'النوع' : 'Type',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Request option
                      Expanded(
                        child: InkWell(
                          onTap: () => _updateTypeFilter('طلب'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: widget.filterOptions.typeFilter == 'طلب'
                                  ? theme.colorScheme.primary.withOpacity(0.2)
                                  : isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: widget.filterOptions.typeFilter == 'طلب'
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              isArabic ? 'طلب' : 'Request',
                              style: TextStyle(
                                fontWeight: widget.filterOptions.typeFilter == 'طلب' ? FontWeight.bold : FontWeight.normal,
                                color: widget.filterOptions.typeFilter == 'طلب'
                                    ? theme.colorScheme.primary
                                    : theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Offer option
                      Expanded(
                        child: InkWell(
                          onTap: () => _updateTypeFilter('عرض'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: widget.filterOptions.typeFilter == 'عرض'
                                  ? theme.colorScheme.primary.withOpacity(0.2)
                                  : isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: widget.filterOptions.typeFilter == 'عرض'
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              isArabic ? 'عرض' : 'Offer',
                              style: TextStyle(
                                fontWeight: widget.filterOptions.typeFilter == 'عرض' ? FontWeight.bold : FontWeight.normal,
                                color: widget.filterOptions.typeFilter == 'عرض'
                                    ? theme.colorScheme.primary
                                    : theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Price range filter
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        isArabic ? 'السعر' : 'Price',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${currentPriceFilter.start.toInt()} - ${currentPriceFilter.end.toInt()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  RangeSlider(
                    values: currentPriceFilter,
                    min: priceRange.start,
                    max: priceRange.end,
                    divisions: 20,
                    activeColor: theme.colorScheme.primary,
                    inactiveColor: theme.colorScheme.primary.withOpacity(0.2),
                    onChanged: _updatePriceFilter,
                  ),
                ],
              ),
            ) : const SizedBox.shrink(),
          ),

          // Filter counts indicator
          if (widget.filterOptions.hasActiveFilters)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_alt,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isArabic ? 'الفلاتر النشطة:' : 'Active filters:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.filterOptions.typeFilter != null)
                    _FilterChip(
                      label: widget.filterOptions.typeFilter == 'طلب'
                          ? (isArabic ? 'طلب' : 'Request')
                          : (isArabic ? 'عرض' : 'Offer'),
                      onRemove: () => widget.onFilterChanged(
                        widget.filterOptions.copyWith(clearTypeFilter: true),
                      ),
                    ),
                  if (widget.filterOptions.priceRangeFilter != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: _FilterChip(
                        label: isArabic
                            ? 'السعر: ${widget.filterOptions.priceRangeFilter!.start.toInt()}-${widget.filterOptions.priceRangeFilter!.end.toInt()}'
                            : 'Price: ${widget.filterOptions.priceRangeFilter!.start.toInt()}-${widget.filterOptions.priceRangeFilter!.end.toInt()}',
                        onRemove: () => widget.onFilterChanged(
                          widget.filterOptions.copyWith(clearPriceFilter: true),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _FilterChip({
    Key? key,
    required this.label,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.close,
                size: 12,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}