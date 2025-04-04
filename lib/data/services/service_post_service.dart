import 'package:talabna/data/models/service_post.dart';
import 'package:talabna/data/repositories/service_post_repository.dart';

import '../../core/service_locator.dart';

class ServicePostService {
  final ServicePostRepository _repository =
      serviceLocator<ServicePostRepository>();

  Future<List<ServicePost>> getAllServicePosts() async {
    return await _repository.getAllServicePosts();
  }

  Future<ServicePost> getServicePostById(int id) async {
    return await _repository.getServicePostById(id);
  }

  Future<List<ServicePost>> getUserServicePosts(int userId, int page) async {
    return await _repository.getServicePostsByUserId(
        userId: userId, page: page);
  }

  Future<List<ServicePost>> getServicePostsByCategory(
      int category, int page) async {
    return await _repository.getServicePostsByCategory(
        categories: category, page: page);
  }

  Future<List<ServicePost>> getServicePostsByCategorySubCategory(
      int category, int subCategory, int page) async {
    return await _repository.getServicePostsByCategorySubCategory(
        page: page, categories: category, subCategories: subCategory);
  }
}
