//# Названия маршрутов

class RouteNames {
  // Онбординг и авторизация
  static const onboarding = '/';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  
  // Профиль
  static const profile = '/profile';
  
  // Группы
  static const groups = '/groups';
  static const createGroup = '/create-group';
  static const groupDetail = '/group/:id';
  
  // Списки
  static const myLists = '/my-lists';
  static const editList = '/edit-list/:id';  // Исправлено: добавляем :id параметр

    // Друзья
  static const friends = '/friends';
  static const friendRequests = '/friend-requests';
  static const searchFriends = '/search-friends';
  
  // Поиск
  static const searchPeople = '/search-people';
  
  // Другие (пока закомментированы)
  // static const notifications = '/notifications';
  // static const session = '/session';
}