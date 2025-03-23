// File: lib/widgets/subcategory_count_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talabna/blocs/category/subcategory_bloc.dart';
import 'package:talabna/blocs/category/subcategory_event.dart';
import 'package:talabna/blocs/category/subcategory_state.dart';
import 'package:talabna/app_theme.dart';

class SubcategoryCountWidget extends StatefulWidget {
  final int subcategoryId;
  final int count;
  final Color primaryColor;

  const SubcategoryCountWidget({
    Key? key,
    required this.subcategoryId,
    required this.count,
    required this.primaryColor,
  }) : super(key: key);

  @override
  _SubcategoryCountWidgetState createState() => _SubcategoryCountWidgetState();
}

class _SubcategoryCountWidgetState extends State<SubcategoryCountWidget> {
  late int _displayCount;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _displayCount = widget.count;
  }

  @override
  void didUpdateWidget(SubcategoryCountWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only animate if the count actually changed
    if (oldWidget.count != widget.count) {
      setState(() {
        _isUpdating = true;
      });

      // Briefly delay to show animation
      Future.delayed(Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _displayCount = widget.count;
            _isUpdating = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.primaryColor.withOpacity(_isUpdating ? 0.3 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Total: ${formatNumber(_displayCount)}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: widget.primaryColor,
        ),
      ),
    );
  }

  String formatNumber(int number) {
    if (number >= 1000000000) {
      return '${(number / 1000000000).toStringAsFixed(1)}B';
    } else if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}