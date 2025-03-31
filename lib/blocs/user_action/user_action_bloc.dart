import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talabna/blocs/user_action/user_action_event.dart';
import 'package:talabna/blocs/user_action/user_action_state.dart';
import 'package:talabna/data/models/service_post.dart';
import 'package:talabna/data/models/user.dart';
import 'package:talabna/data/repositories/user_follow_repository.dart';

class UserActionBloc extends Bloc<UserActionEvent, UserActionState> {
  final UserFollowRepository _repository;

  UserActionBloc({required UserFollowRepository repository})
      : _repository = repository,
        super(UserActionInitial()) {
    print('UserActionBloc created: $hashCode');

    on<ToggleUserMakeFollowEvent>((event, emit) async {
      emit(UserActionInProgress());
      try {
        bool newFollowerStatus =
            await _repository.toggleUserActionFollow(userId: event.user);
        emit(UserFollowUnFollowToggled(
            isFollower: newFollowerStatus, userId: event.user));
      } catch (e) {
        emit(UserActionFailure(error: e.toString()));
      }
    });
    on<ToggleUserMakeFollowFromListEvent>((event, emit) async {
      emit(UserActionInProgress());
      try {
        bool newFollowerStatus =
            await _repository.toggleUserActionFollow(userId: event.user);
        emit(UserFollowUnFollowFromListToggled(
            isFollower: newFollowerStatus, userId: event.user));
      } catch (e) {
        emit(UserActionFailure(error: e.toString()));
      }
    });
    on<UserMakeFollowSubcategories>((event, emit) async {
      emit(UserActionInProgress());
      try {
        final bool subcategories =
            await _repository.toggleFollowSubcategories(event.subCategoryId);
        emit(UserMakeFollowSubcategoriesSuccess(subcategories));
      } catch (e) {
        emit(UserActionFailure(error: e.toString()));
      }
    });
    on<GetUserFollow>((event, emit) async {
      emit(UserActionInProgress());
      try {
        final bool subCategoryMenu =
            await _repository.getUserFollow(event.user);
        emit(GetFollowUserSuccess(subCategoryMenu));
      } catch (e) {
        emit(UserActionFailure(error: e.toString()));
      }
    });
    on<GetUserFollowSubcategories>((event, emit) async {
      emit(UserActionInProgress());
      try {
        final bool subCategoryMenu =
            await _repository.getUserFollowSubcategories(event.subCategoryId);
        emit(GetFollowSubcategoriesSuccess(subCategoryMenu));
      } catch (e) {
        emit(UserActionFailure(error: e.toString()));
      }
    });

    on<UserSearchAction>((event, emit) async {
      emit(UserActionInProgress());
      try {
        // Log the search query and page
        print("Searching for: ${event.search}, page: ${event.page}");

        final results = await _repository.searchUserOrPost(
            searchAction: event.search, page: event.page);
        print("Search results received: ${results.toString()}");

        // Check pagination limits
        bool postsHasReachedMax = results["posts"].length < 10;
        bool usersHasReachedMax = results["users"].length < 10;
        print("Has reached max - users: $usersHasReachedMax, posts: $postsHasReachedMax");

        // Initialize empty lists
        List<User> users = [];
        List<ServicePost> servicePosts = [];

        // Populate users list safely
        for (var user in results["users"]) {
          try {
            users.add(user as User);
          } catch (e) {
            print("Error adding user: $e for item: $user");
          }
        }
        print("Processed ${users.length} users");

        // Populate posts list safely
        for (var post in results["posts"]) {
          try {
            servicePosts.add(post as ServicePost);
          } catch (e) {
            print("Error adding post: $e for item: $post");
          }
        }
        print("Processed ${servicePosts.length} posts");

        // Emit successful result
        emit(UserSearchActionResult(
            users: users,
            servicePosts: servicePosts,
            usersHasReachedMax: usersHasReachedMax,
            servicePostsHasReachedMax: postsHasReachedMax));

      } catch (e, stackTrace) {
        print("Search error: $e");
        print("Stack trace: $stackTrace");
        emit(UserActionFailure(error: "حدث خطأ في البحث: ${e.toString()}"));
      }
    });
  }
}
