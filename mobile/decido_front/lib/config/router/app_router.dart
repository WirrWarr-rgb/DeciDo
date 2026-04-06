//# GoRouter конфигурация
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../modules/auth/presentation/screens/onboarding_screen.dart';
import '../../modules/auth/presentation/screens/login_screen.dart';
import '../../modules/auth/presentation/screens/register_screen.dart';
import '../../modules/home/presentation/screens/home_screen.dart';
import '../../modules/auth/providers/auth_state_provider.dart';
import '../../modules/profile/presentation/screens/profile_screen.dart';
import '../../modules/social/presentation/screens/groups_screen.dart';
import '../../modules/social/presentation/screens/group_detail_screen.dart';
import '../../modules/social/presentation/screens/create_group_screen.dart';
import '../../modules/social/presentation/screens/search_people_screen.dart';
import '../../modules/list/presentation/screens/my_lists_screen.dart';
import '../../modules/list/presentation/screens/edit_list_screen.dart';
import 'route_names.dart';  // Добавляем импорт route_names

// Временно убираем несуществующие экраны
// import '../../modules/list/presentation/screens/create_list_screen.dart';
// import '../../modules/list/presentation/screens/list_detail_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RouteNames.onboarding,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isAuth = authState != null;
      
      final isAuthRoute = state.matchedLocation == RouteNames.login ||
          state.matchedLocation == RouteNames.register ||
          state.matchedLocation == RouteNames.onboarding;
      
      if (isAuth && isAuthRoute) {
        return RouteNames.home;
      }
      
      if (!isAuth && !isAuthRoute && state.matchedLocation != RouteNames.onboarding) {
        return RouteNames.login;
      }
      
      return null;
    },
    routes: [
      // Онбординг и авторизация
      GoRoute(
        path: RouteNames.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.register,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RouteNames.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      
      // Профиль
      GoRoute(
        path: RouteNames.profile,
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      
      // Группы
      GoRoute(
        path: RouteNames.groups,
        name: 'groups',
        builder: (context, state) => const GroupsScreen(),
      ),
      GoRoute(
        path: RouteNames.createGroup,
        name: 'createGroup',
        builder: (context, state) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: RouteNames.groupDetail,
        name: 'groupDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return GroupDetailScreen(groupId: id);
        },
      ),
      
      // Списки
      GoRoute(
        path: RouteNames.myLists,
        name: 'myLists',
        builder: (context, state) => const MyListsScreen(),
      ),
      GoRoute(
        path: RouteNames.editList,
        name: 'editList',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EditListScreen(listId: id);
        },
      ),
      
      // Поиск
      GoRoute(
        path: RouteNames.searchPeople,
        name: 'searchPeople',
        builder: (context, state) => const SearchPeopleScreen(),
      ),
    ],
  );
});