import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<DatabaseEvent>? _corridaSubscription;
  
  // Callback para quando uma nova corrida é encontrada
  Function(Map<String, dynamic>)? onNewRide;
  
  // Callback para quando o status da corrida muda
  Function(String, String)? onRideStatusChanged;

  /// Inicializa o serviço de notificações
  void initialize() {
    _listenForNewRides();
  }

  /// Para o serviço de notificações
  void dispose() {
    _corridaSubscription?.cancel();
  }

  /// Escuta por novas corridas na região do motorista
  void _listenForNewRides() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      // Busca a região do motorista
      final perfil = await _db.child('usuarios/$uid').get();
      if (!perfil.exists) return;

      String regiao = 'SP-CAPITAL';
      final regRaw = perfil.child('codigo_regiao').value ?? 
                     perfil.child('codigoRegiao').value;
      if (regRaw is String && regRaw.isNotEmpty) regiao = regRaw;

      // Escuta corridas pendentes na região
      _corridaSubscription?.cancel();
      _corridaSubscription = _db
          .child('corridas_por_regiao/$regiao/pendente')
          .onChildAdded
          .listen((event) {
        if (event.snapshot.exists) {
          final corridaData = Map<String, dynamic>.from(
            event.snapshot.value as Map
          );
          corridaData['id'] = event.snapshot.key;
          
          // Toca som de notificação
          _playNotificationSound();
          
          // Chama callback se definido
          onNewRide?.call(corridaData);
          
          // Mostra notificação visual
          _showRideNotification(corridaData);
        }
      });
    } catch (e) {
      debugPrint('❌ Erro ao configurar escuta de corridas: $e');
    }
  }

  /// Toca som de notificação para nova corrida
  void _playNotificationSound() {
    try {
      // Vibração
      HapticFeedback.heavyImpact();
      
      // Som do sistema (pode ser customizado)
      SystemSound.play(SystemSoundType.alert);
      
      debugPrint('🔊 Som de notificação tocado');
    } catch (e) {
      debugPrint('❌ Erro ao tocar som: $e');
    }
  }

  /// Mostra notificação visual para nova corrida
  void _showRideNotification(Map<String, dynamic> corridaData) {
    // Esta função será chamada pelo widget principal para mostrar
    // um overlay ou dialog com os detalhes da corrida
    debugPrint('🚗 Nova corrida disponível: ${corridaData['origemDescricao']}');
  }

  /// Escuta mudanças de status de uma corrida específica
  void listenToRideStatus(String rideId) {
    _db.child('corridas/$rideId/status').onValue.listen((event) {
      if (event.snapshot.exists) {
        final status = event.snapshot.value as String;
        onRideStatusChanged?.call(rideId, status);
        
        // Toca som para mudanças importantes
        if (status == 'aceito' || status == 'concluida' || status == 'cancelada') {
          _playNotificationSound();
        }
      }
    });
  }

  /// Envia notificação push (placeholder para implementação futura)
  Future<void> sendPushNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // Implementar com Firebase Cloud Messaging
    debugPrint('📱 Push notification: $title - $body');
  }

  /// Agenda notificação local (placeholder)
  Future<void> scheduleLocalNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    // Implementar com flutter_local_notifications
    debugPrint('⏰ Notificação agendada: $title para ${scheduledTime.toString()}');
  }
}

