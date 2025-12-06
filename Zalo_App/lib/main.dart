import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
// 1. QUAN TRỌNG: Import file AuthGate của bạn ở đây
// (Kiểm tra xem file AuthGate bạn lưu tên là gì, ví dụ auth_gate.dart)
import 'package:zalo_app/auth_gate.dart';
import 'package:zalo_app/providers/theme_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFFC6E7FF),
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFFC6E7FF),
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'TapTap',
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent, brightness: Brightness.light),
              scaffoldBackgroundColor: const Color(0xFFC6E7FF),
              appBarTheme: const AppBarTheme(
                systemOverlayStyle: SystemUiOverlayStyle(
                  statusBarColor: Color(0xFFC6E7FF),
                  statusBarIconBrightness: Brightness.dark,
                  systemNavigationBarColor: Color(0xFFC6E7FF),
                  systemNavigationBarIconBrightness: Brightness.dark,
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blueAccent,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            debugShowCheckedModeBanner: false,

            // 2. THAY ĐỔI LỚN NHẤT Ở ĐÂY:
            // Bỏ toàn bộ StreamBuilder cũ, chỉ gọi đúng 1 dòng này:
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}