import 'package:flutter/material.dart';
import 'services/warteg_data_service.dart';
import 'theme/warteg_theme.dart';
import 'screens/auth/role_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WartegDataService().init();
  runApp(const WartegApp());
}

class WartegApp extends StatelessWidget {
  const WartegApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Warteg Mobile Management',
      debugShowCheckedModeBanner: false,
      theme: WartegTheme.themeData,
      home: const RoleSelectionScreen(),
    );
  }
}
