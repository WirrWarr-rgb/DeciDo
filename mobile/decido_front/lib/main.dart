import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'config/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/network/dio_client.dart';
import 'modules/auth/providers/auth_controller_provider.dart';
import 'modules/list/models/list_model.dart';
import 'modules/list/models/list_item_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Загружаем переменные окружения
  await dotenv.load();
  
  // Инициализация Hive
  await Hive.initFlutter();
  
  // Регистрируем адаптеры (обязательно!)
  Hive.registerAdapter(ListModelAdapter());
  Hive.registerAdapter(ListItemModelAdapter());
  
  // Открываем боксы с правильными типами
  await Hive.openBox<ListModel>('lists');
  await Hive.openBox<ListItemModel>('items');
  await Hive.openBox('settings');  // settings может быть dynamic
  
  // Инициализируем Dio клиент
  DioClient.init();
  
  testBackendConnection();

  runApp(const ProviderScope(child: MyApp()));
}

void testBackendConnection() async {
  try {
    final response = await Dio().get('http://localhost:8000/health');
    print('Backend is reachable: ${response.data}');
  } catch (e) {
    print('Backend connection failed: $e');
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider).checkAuth();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    
    return MaterialApp.router(
      title: 'DeciDo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}