//# Названия маршрутов

class RouteNames {
  // Онбординг и авторизация
  static const onboarding = '/';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  
  // Профиль
  static const profile = '/profile';
  
  // Списки
  static const myLists = '/my-lists';
  static const editList = '/edit-list/:id';  // Исправлено: добавляем :id параметр

    // Друзья
  static const friends = '/friends';
  static const friendRequests = '/friend-requests';
  static const searchFriends = '/search-friends';
  
  // Поиск
  static const searchPeople = '/search-people';
  
  // Лобби (сессии)
  static const createSession = '/create-session';
  static const session = '/session/:id';
  static const selectFriends = '/select-friends';
  static const ranking = '/session/:id/ranking';
  static const results = '/session/:id/results';
}