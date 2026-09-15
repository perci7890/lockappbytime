import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/home/providers/lock_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppLockerApp());
}

class AppLockerApp extends StatelessWidget {
  const AppLockerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LockProvider(),
      child: MaterialApp(
        title: 'App Locker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
