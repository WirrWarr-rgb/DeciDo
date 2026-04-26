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
import '../../modules/session/presentation/screens/create_session_screen.dart';
import '../../modules/session/presentation/screens/ranking_screen.dart';
import '../../modules/session/presentation/screens/results_screen.dart';
import '../../modules/session/presentation/screens/select_friends_screen.dart';
import '../../modules/session/presentation/screens/session_screen.dart';
import '../../modules/social/presentation/screens/search_people_screen.dart';
import '../../modules/list/presentation/screens/my_lists_screen.dart';
import '../../modules/list/presentation/screens/edit_list_screen.dart';
import '../../modules/social/presentation/screens/friends_screen.dart';
import '../../modules/social/presentation/screens/friend_requests_screen.dart';
import '../../modules/social/presentation/screens/search_friends_screen.dart';
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
      
      print('Redirect check - isAuth: $isAuth, location: ${state.matchedLocation}');
      
      final isAuthRoute = state.matchedLocation == RouteNames.login ||
          state.matchedLocation == RouteNames.register ||
          state.matchedLocation == RouteNames.onboarding;
      
      if (isAuth && isAuthRoute) {
        print('Redirecting to home');
        return RouteNames.home;
      }
      
      if (!isAuth && !isAuthRoute && state.matchedLocation != RouteNames.onboarding) {
        print('Redirecting to login');
        return RouteNames.login;
      }
      
      print('No redirect needed');
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


      // Друзья
      GoRoute(
        path: RouteNames.friends,
        name: 'friends',
        builder: (context, state) => const FriendsScreen(),
      ),
      GoRoute(
        path: RouteNames.friendRequests,
        name: 'friendRequests',
        builder: (context, state) => const FriendRequestsScreen(),
      ),
      GoRoute(
        path: RouteNames.searchFriends,
        name: 'searchFriends',
        builder: (context, state) => const SearchFriendsScreen(),
      ),
      
      // Поиск
      GoRoute(
        path: RouteNames.searchPeople,
        name: 'searchPeople',
        builder: (context, state) => const SearchPeopleScreen(),
      ),


      // Лобби
      GoRoute(
        path: RouteNames.createSession,
        name: 'createSession',
        builder: (context, state) => const CreateSessionScreen(),
      ),
      GoRoute(
        path: RouteNames.selectFriends,
        name: 'selectFriends',
        builder: (context, state) => const SelectFriendsScreen(),
      ),
      GoRoute(
        path: RouteNames.session,
        name: 'session',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return SessionScreen(sessionId: int.parse(id));
        },
      ),
      GoRoute(
        path: RouteNames.ranking,
        name: 'ranking',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return RankingScreen(sessionId: int.parse(id));
        },
      ),
      GoRoute(
        path: RouteNames.results,
        name: 'results',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ResultsScreen(sessionId: int.parse(id));
        },
      ),
    ],
  );
});