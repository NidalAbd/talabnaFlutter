// lib/data/repositories/categories_repository.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talabna/data/datasources/category_data_source.dart';
import 'package:talabna/data/datasources/local/local_category_data_source.dart';
import 'package:talabna/data/models/categories.dart';
import 'package:talabna/data/models/categories_selected_menu.dart';
import 'package:talabna/data/models/category_menu.dart';
import 'package:talabna/utils/debug_logger.dart';

import '../datasources/remote/remote_category_data_source.dart';

class CategoriesRepository {
  final CategoryDataSource remoteDataSource;
  final LocalCategoryDataSource localDataSource;

  CategoriesRepository({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  static Future<CategoriesRepository> legacy() async {
    // Create direct instances of dependencies without service locator
    return CategoriesRepository(
      remoteDataSource: RemoteCategoryDataSource(),
      localDataSource: LocalCategoryDataSource(
        sharedPreferences: await SharedPreferences.getInstance(),
      ),
    );
  }

  Future<List<CategoryMenu>> getCategoryMenu(
      {bool forceRefresh = false}) async {
    try {
      // Check if we have valid cache and forceRefresh is false
      if (!forceRefresh &&
          localDataSource.isCacheValid('cached_category_menu')) {
        final cachedMenu = await localDataSource.getCategoryMenu();
        if (cachedMenu.isNotEmpty) {
          DebugLogger.log('Returning cached category menu',
              category: 'REPOSITORY');
          return cachedMenu;
        }
      }

      // Fetch fresh data from remote
      DebugLogger.log('Fetching category menu from API',
          category: 'REPOSITORY');
      final remoteMenu = await remoteDataSource.getCategoryMenu();

      // Cache the new data
      await localDataSource.cacheCategoryMenu(remoteMenu);

      return remoteMenu;
    } catch (e) {
      DebugLogger.log('Error fetching category menu from API: $e',
          category: 'REPOSITORY');

      // If remote fetch fails, try to return cached data
      final cachedMenu = await localDataSource.getCategoryMenu();
      if (cachedMenu.isNotEmpty) {
        DebugLogger.log('Returning cached category menu after API error',
            category: 'REPOSITORY');
        return cachedMenu;
      }

      // If no cache, rethrow the error
      rethrow;
    }
  }

  Future<List<Category>> getCategories() async {
    try {
      // Fetch fresh data from remote
      DebugLogger.log('Fetching categories from API', category: 'DATA_SOURCE');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        DebugLogger.log('Error: Auth token is null', category: 'DATA_SOURCE');
        throw Exception('User is not authenticated');
      }

      final response = await http.get(
        Uri.parse('${RemoteCategoryDataSource.baseUrl}/api/categories_list'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);

        if (decodedResponse is! Map<String, dynamic>) {
          throw Exception('Invalid API response format');
        }

        if (!decodedResponse.containsKey('categories')) {
          throw Exception('Missing "categories" key in API response');
        }

        final categoriesJson = decodedResponse['categories'];
        if (categoriesJson is! List) {
          throw Exception('"categories" field must be a list');
        }

        final categories = categoriesJson.map((json) {
          try {
            return Category.fromJson(json);
          } catch (e) {
            throw Exception('Failed to parse category');
          }
        }).toList();

        DebugLogger.log('Fetched ${categories.length} categories from API',
            category: 'DATA_SOURCE');
        return categories;
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      DebugLogger.log('Error fetching categories from API: $e',
          category: 'DATA_SOURCE');
      rethrow;
    }
  }

  Future<List<SubCategory>> getSubCategories(int categoryId) async {
    try {
      // Fetch fresh data from remote
      DebugLogger.log(
          'Fetching subcategories for category $categoryId from API',
          category: 'DATA_SOURCE');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        DebugLogger.log('Error: Auth token is null', category: 'DATA_SOURCE');
        throw Exception('User is not authenticated');
      }

      final response = await http.get(
        Uri.parse(
            '${RemoteCategoryDataSource.baseUrl}/api/categories_list/$categoryId/sub_categories/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseJson = jsonDecode(response.body);
        final List<dynamic> subcategoriesJson = responseJson['subcategories'];

        final subcategories = subcategoriesJson
            .map((json) => SubCategory.fromJson(json))
            .toList();

        DebugLogger.log(
            'Fetched ${subcategories.length} subcategories from API',
            category: 'DATA_SOURCE');
        return subcategories;
      } else {
        throw Exception(
            'Failed to load subcategories for category $categoryId: ${response.statusCode}');
      }
    } catch (e) {
      DebugLogger.log('Error fetching subcategories from API: $e',
          category: 'DATA_SOURCE');
      rethrow;
    }
  }

  Future<List<SubCategoryMenu>> getSubCategoriesMenu(
      int categoryId,
      {bool forceRefresh = false}
      ) async {
    try {
      // Use cache if not forcing refresh and the cache is valid
      if (!forceRefresh && localDataSource.isCacheValid('cached_subcategory_menu_$categoryId')) {
        final cachedMenu = await localDataSource.getSubCategoriesMenu(categoryId);
        if (cachedMenu.isNotEmpty) {
          DebugLogger.log('Returning cached subcategory menu for category $categoryId',
              category: 'REPOSITORY');
          return cachedMenu;
        }
      }

      // Otherwise fetch from API
      DebugLogger.log(
          'Fetching subcategory menu for category $categoryId from API (forceRefresh: $forceRefresh)',
          category: 'REPOSITORY'
      );

      final remoteMenu = await remoteDataSource.getSubCategoriesMenu(categoryId);

      // Cache the new data
      await localDataSource.cacheSubCategoriesMenu(categoryId, remoteMenu);

      return remoteMenu;
    } catch (e) {
      DebugLogger.log('Error fetching subcategory menu from API: $e',
          category: 'REPOSITORY');

      // If remote fetch fails, try to return cached data
      final cachedMenu = await localDataSource.getSubCategoriesMenu(categoryId);
      if (cachedMenu.isNotEmpty) {
        DebugLogger.log('Returning cached subcategory menu after API error',
            category: 'REPOSITORY');
        return cachedMenu;
      }

      // If no cache, rethrow the error
      rethrow;
    }
  }
}
