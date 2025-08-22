import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/gallery_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/edit_screen.dart'; // 'EditScreen'이 정의되지 않은 오류를 해결하기 위해 추가했습니다.
import 'services/image_service.dart';
import 'services/file_manager_service.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 앱 초기 설정
  await _initializeApp();

  runApp(const MyApp());
}

Future<void> _initializeApp() async {
  // 시스템 UI 설정
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // 화면 방향 고정 (세로 모드만)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 디렉토리 초기화
  await FileManagerService.initializeDirectories();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ImageService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Image Editor Pro',
            debugShowCheckedModeBanner: false,
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
            routes: {
              '/gallery': (context) => const GalleryScreen(),
              '/edit': (context) => const EditScreen(),
            },
          );
        },
      ),
    );
  }

  ThemeData _buildLightTheme() {
    final baseTheme = ThemeData.from(
      colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue, brightness: Brightness.light),
      useMaterial3: true,
    );
    return baseTheme.copyWith(
      scaffoldBackgroundColor: Colors.grey[50],
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final baseTheme = ThemeData.from(
      colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue, brightness: Brightness.dark),
      useMaterial3: true,
    );
    return baseTheme.copyWith(
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
