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
  
  // Поиск
  static const searchPeople = '/search-people';
  
  // Вспомогательный метод для замены параметров
  static String buildPath(String template, Map<String, String> params) {
    String path = template;
    params.forEach((key, value) {
      path = path.replaceAll(':$key', value);
    });
    return path;
  }

  // Другие (пока закомментированы)
  // static const notifications = '/notifications';
  // static const session = '/session';
}