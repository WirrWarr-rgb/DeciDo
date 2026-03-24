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
import '../../modules/list/presentation/screens/list_detail_screen.dart';
import '../../modules/list/presentation/screens/create_list_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isAuth = authState != null;
      
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/';
      
      if (isAuth && isAuthRoute) {
        return '/home';
      }
      
      if (!isAuth && !isAuthRoute && state.matchedLocation != '/') {
        return '/login';
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      // Профиль
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      // Группы
      GoRoute(
        path: '/groups',
        name: 'groups',
        builder: (context, state) => const GroupsScreen(),
      ),
      GoRoute(
        path: '/create-group',
        name: 'createGroup',
        builder: (context, state) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: '/group/:id',
        name: 'groupDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return GroupDetailScreen(groupId: id);
        },
      ),
      // Списки
      GoRoute(
        path: '/my-lists',
        name: 'myLists',
        builder: (context, state) => const MyListsScreen(),
      ),
      GoRoute(
        path: '/create-list',
        name: 'createList',
        builder: (context, state) => const CreateListScreen(),
      ),
      GoRoute(
        path: '/list/:id',
        name: 'listDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ListDetailScreen(listId: id);
        },
      ),
      // Поиск
      GoRoute(
        path: '/search-people',
        name: 'searchPeople',
        builder: (context, state) => const SearchPeopleScreen(),
      ),
    ],
  );
});