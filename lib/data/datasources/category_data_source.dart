import 'package:talabna/data/models/categories_selected_menu.dart';

import '../models/category_menu.dart';

abstract class CategoryDataSource {
  Future<List<CategoryMenu>> getCategoryMenu();

  Future<List<SubCategoryMenu>> getSubCategoriesMenu(int categoryId);
}
