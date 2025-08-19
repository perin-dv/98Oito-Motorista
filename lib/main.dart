import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:novo9oito_motorista/presentation/pages/aguardando_aprovacao_page.dart';

import 'routes/app_routes.dart';
import 'presentation/pages/splash_page.dart';
import 'presentation/pages/welcome_page.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/pages/cadastro_motorista_page.dart';
import 'presentation/pages/main_screen_motorista.dart';
import 'presentation/pages/validacao_facial_page.dart';
import 'data/services/background_service.dart';

// Handler para mensagens em segundo plano
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📨 Mensagem em segundo plano: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa Firebase
  await Firebase.initializeApp();
  
  // Configura handler para mensagens em segundo plano
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Inicializa serviço de background
  await BackgroundService().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '9Oito Motorista',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        primaryColor: const Color(0xFF6A4C93), // Roxo da logo
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6A4C93),
          secondary: const Color(0xFFFF6600), // Laranja da logo
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF6A4C93),
          foregroundColor: Colors.white,
        ),
        // Tema para notificações e overlays
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF6A4C93),
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (context) => const SplashPage(),
        AppRoutes.welcome: (context) => const WelcomePage(),
        AppRoutes.login: (context) => const LoginPage(),
        AppRoutes.cadastro: (context) => const CadastroMotoristaPage(),
        AppRoutes.home: (context) => const MainScreenMotorista(),
        '/validacao_facial': (context) => const ValidacaoFacialPage(),
        '/aguardando_aprovacao': (context) => const AguardandoAprovacaoPage(),
      },
    );
  }
}
