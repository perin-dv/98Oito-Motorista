import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:timezone/timezone.dart' as tz;

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();

  factory BackgroundService() => _instance;

  BackgroundService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Inicializa o serviço de notificações em segundo plano
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _initializeLocalNotifications();
      await _initializeFirebaseMessaging();
      await _initializeWorkManager();

      _isInitialized = true;
      debugPrint('✅ Serviço de background inicializado');
    } catch (e) {
      debugPrint('❌ Erro ao inicializar serviço de background: $e');
    }
  }

  /// Inicializa notificações locais
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Solicita permissões no Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Inicializa Firebase Cloud Messaging
  Future<void> _initializeFirebaseMessaging() async {
    // Solicita permissões
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ Permissões de notificação concedidas');

      // Obtém token FCM
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveTokenToDatabase(token);
      }

      // Escuta mudanças no token
      _messaging.onTokenRefresh.listen(_saveTokenToDatabase);

      // Configura handlers para mensagens
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Verifica se o app foi aberto por uma notificação
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }
    } else {
      debugPrint('⚠️ Permissões de notificação negadas');
    }
  }

  /// Inicializa WorkManager para tarefas em segundo plano
  Future<void> _initializeWorkManager() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    // Registra tarefa periódica para verificar corridas
    await Workmanager().registerPeriodicTask(
      'check_rides',
      'checkForNewRides',
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  /// Salva token FCM no Firebase
  Future<void> _saveTokenToDatabase(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseDatabase.instance
          .ref('usuarios/$uid/fcmToken')
          .set(token);

      debugPrint('📱 Token FCM salvo: ${token.substring(0, 20)}...');
    } catch (e) {
      debugPrint('❌ Erro ao salvar token FCM: $e');
    }
  }

  /// Manipula mensagens recebidas em primeiro plano
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📨 Mensagem recebida em primeiro plano: ${message.messageId}');

    if (message.notification != null) {
      _showLocalNotification(
        title: message.notification!.title ?? 'Nova Corrida',
        body: message.notification!.body ?? 'Uma nova corrida está disponível',
        data: message.data,
      );
    }
  }

  /// Manipula quando o app é aberto por uma notificação
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('📱 App aberto por notificação: ${message.messageId}');

    // Aqui você pode navegar para uma tela específica
    // baseado nos dados da mensagem
    if (message.data.containsKey('rideId')) {
      // Navegar para tela de corrida
    }
  }

  /// Callback quando notificação local é tocada
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notificação tocada: ${response.payload}');

    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        // Processar dados e navegar se necessário
      } catch (e) {
        debugPrint('❌ Erro ao processar payload da notificação: $e');
      }
    }
  }

  /// Mostra notificação local
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'ride_channel',
      'Corridas',
      channelDescription: 'Notificações de novas corridas',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF6A4C93),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime
          .now()
          .millisecondsSinceEpoch
          .remainder(100000),
      title,
      body,
      details,
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  /// Envia notificação para um motorista específico
  Future<void> sendNotificationToDriver({
    required String driverUid,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Busca o token FCM do motorista
      final tokenSnapshot = await FirebaseDatabase.instance
          .ref('usuarios/$driverUid/fcmToken')
          .get();

      if (!tokenSnapshot.exists) {
        debugPrint('⚠️ Token FCM não encontrado para motorista $driverUid');
        return;
      }

      final token = tokenSnapshot.value as String;

      // Aqui você implementaria o envio via servidor
      // Por enquanto, apenas log
      debugPrint('📤 Enviando notificação para $driverUid: $title');
    } catch (e) {
      debugPrint('❌ Erro ao enviar notificação: $e');
    }
  }

  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    Map<String, dynamic>? data,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'scheduled_channel',
      'Lembretes',
      channelDescription: 'Notificações agendadas',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Converte DateTime normal para TZDateTime
    final tz.TZDateTime tzScheduled = tz.TZDateTime.from(
        scheduledTime, tz.local);

    await _localNotifications.zonedSchedule(
      DateTime
          .now()
          .millisecondsSinceEpoch
          .remainder(100000), // ID único
      title,
      body,
      tzScheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // opcional
      payload: data != null ? jsonEncode(data) : null,
    );


    /// Cancela todas as notificações
    Future<void> cancelAllNotifications() async {
      await _localNotifications.cancelAll();
    }

    /// Para o serviço de background
    Future<void> dispose() async {
      await Workmanager().cancelAll();
    }
  }

  /// Callback para tarefas em segundo plano
  @pragma('vm:entry-point')
  void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      debugPrint('🔄 Executando tarefa em background: $task');

      switch (task) {
        case 'checkForNewRides':
          await _checkForNewRides();
          break;
        default:
          debugPrint('⚠️ Tarefa desconhecida: $task');
      }

      return Future.value(true);
    });
  }

  /// Verifica novas corridas em segundo plano
  Future<void> _checkForNewRides() async {
    try {
      // Verifica se o motorista está online
      final prefs = await SharedPreferences.getInstance();
      final isOnline = prefs.getBool('driver_online') ?? false;

      if (!isOnline) {
        debugPrint('🔄 Motorista offline, pulando verificação');
        return;
      }

      // Aqui você implementaria a lógica para verificar novas corridas
      // e mostrar notificação se necessário
      debugPrint('🔍 Verificando novas corridas...');
    } catch (e) {
      debugPrint('❌ Erro ao verificar corridas em background: $e');
    }
  }

  /// Handler para mensagens em segundo plano
  @pragma('vm:entry-point')
  Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    debugPrint('📨 Mensagem recebida em segundo plano: ${message.messageId}');

    // Inicializa Firebase se necessário
    // await Firebase.initializeApp();

    // Processa a mensagem e mostra notificação se necessário
  }
}
