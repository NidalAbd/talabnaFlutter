// File: lib/blocs/category/subcategory_count_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talabna/data/repositories/categories_repository.dart';
import 'package:talabna/utils/debug_logger.dart';

// Events
abstract class SubcategoryCountEvent {}

class RefreshSubcategoryCount extends SubcategoryCountEvent {
  final int categoryId;
  final int subcategoryId;

  RefreshSubcategoryCount({
    required this.categoryId,
    required this.subcategoryId,
  });
}

class UpdateSubcategoryCount extends SubcategoryCountEvent {
  final int subcategoryId;
  final int count;

  UpdateSubcategoryCount({
    required this.subcategoryId,
    required this.count,
  });
}

// States
abstract class SubcategoryCountState {}

class SubcategoryCountInitial extends SubcategoryCountState {}

class SubcategoryCountUpdated extends SubcategoryCountState {
  final int subcategoryId;
  final int count;

  SubcategoryCountUpdated({
    required this.subcategoryId,
    required this.count,
  });
}

// Bloc
class SubcategoryCountBloc extends Bloc<SubcategoryCountEvent, SubcategoryCountState> {
  final CategoriesRepository categoriesRepository;
  final Map<int, int> _counts = {}; // Cache of subcategory counts

  SubcategoryCountBloc({
    required this.categoriesRepository,
  }) : super(SubcategoryCountInitial()) {
    on<RefreshSubcategoryCount>(_handleRefreshSubcategoryCount);
    on<UpdateSubcategoryCount>(_handleUpdateSubcategoryCount);
  }

  void _handleRefreshSubcategoryCount(
      RefreshSubcategoryCount event,
      Emitter<SubcategoryCountState> emit,
      ) async {
    try {
      // Fetch just this specific subcategory
      final subcategories = await categoriesRepository.getSubCategoriesMenu(
        event.categoryId,
        forceRefresh: true,
      );

      // Find the specific subcategory
      final subcategory = subcategories.firstWhere(
            (s) => s.id == event.subcategoryId,
        orElse: () => throw Exception('Subcategory not found'),
      );

      // Update the count cache
      _counts[event.subcategoryId] = subcategory.servicePostsCount;

      emit(SubcategoryCountUpdated(
        subcategoryId: event.subcategoryId,
        count: subcategory.servicePostsCount,
      ));

      DebugLogger.log(
        'Updated count for subcategory ${event.subcategoryId}: ${subcategory.servicePostsCount}',
        category: 'SUBCATEGORY_COUNT',
      );
    } catch (e) {
      DebugLogger.log(
        'Error refreshing subcategory count: $e',
        category: 'SUBCATEGORY_COUNT',
      );
    }
  }

  void _handleUpdateSubcategoryCount(
      UpdateSubcategoryCount event,
      Emitter<SubcategoryCountState> emit,
      ) {
    // Update the count cache
    _counts[event.subcategoryId] = event.count;

    emit(SubcategoryCountUpdated(
      subcategoryId: event.subcategoryId,
      count: event.count,
    ));
  }

  // Helper method to get the current count
  int getCount(int subcategoryId) {
    return _counts[subcategoryId] ?? 0;
  }

  // Update the counts from a bulk list of subcategories
  void updateCounts(List<dynamic> subcategories) {
    for (final subcategory in subcategories) {
      if (subcategory.id != null && subcategory.servicePostsCount != null) {
        add(UpdateSubcategoryCount(
          subcategoryId: subcategory.id,
          count: subcategory.servicePostsCount,
        ));
      }
    }
  }
}