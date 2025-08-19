import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import '../models/usuario_model.dart';
import 'dart:async';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  StreamSubscription<Position>? _locationSubscription;
  Timer? _presenceTimer;

  Future<User?> login(String email, String senha) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: senha);
    if (cred.user != null) {
      await _initializeUserPresence();
    }
    return cred.user;
  }

  Future<User?> cadastrar(String email, String senha, UsuarioModel usuario) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: senha);
      final uid = cred.user?.uid;

      if (uid != null) {
        await _db.child('usuarios').child(uid).set(usuario.toMap());
        await _initializeUserPresence();
      }

      return cred.user;
    } catch (e) {
      print("❌ Erro ao cadastrar: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getPerfilAtual() async {
    final uid = usuarioAtual?.uid;
    if (uid == null) return null;

    final snap = await _db.child('usuarios').child(uid).get();
    if (!snap.exists) return null;

    return Map<String, dynamic>.from(snap.value as Map);
  }

  Future<void> _initializeUserPresence() async {
    final uid = usuarioAtual?.uid;
    if (uid == null) return;

    try {
      await _db.child('usuarios/$uid/lastSeen').set(ServerValue.timestamp);
      await _db.child('usuarios/$uid/isOnline').set(true);
      await _db.child('usuarios/$uid/isOnline').onDisconnect().set(false);
      await _db.child('usuarios/$uid/lastSeen').onDisconnect().set(ServerValue.timestamp);

      _presenceTimer?.cancel();
      _presenceTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        _updatePresence();
      });

    } catch (e) {
      print("❌ Erro ao configurar presença: $e");
    }
  }

  Future<void> _updatePresence() async {
    final uid = usuarioAtual?.uid;
    if (uid == null) return;

    try {
      await _db.child('usuarios/$uid/lastSeen').set(ServerValue.timestamp);
    } catch (e) {
      print("❌ Erro ao atualizar presença: $e");
    }
  }

  Future<void> updateLocation(Position position) async {
    final uid = usuarioAtual?.uid;
    if (uid == null) return;

    try {
      await _db.child('usuarios/$uid/localizacao').set({
        'lat': position.latitude,
        'lng': position.longitude,
        'bearing': position.heading,
        'speed': position.speed,
        'accuracy': position.accuracy,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      print("❌ Erro ao atualizar localização: $e");
    }
  }

  Future<void> setOnlineStatus(bool isOnline) async {
    final uid = usuarioAtual?.uid;
    if (uid == null) return;

    try {
      await _db.child('usuarios/$uid/online').set(isOnline);
      await _db.child('usuarios/$uid/lastOnlineAt').set(ServerValue.timestamp);

      if (isOnline) {
        await _startLocationTracking();
      } else {
        await _stopLocationTracking();
      }
    } catch (e) {
      print("❌ Erro ao definir status online: $e");
    }
  }

  Future<void> _startLocationTracking() async {
    _locationSubscription?.cancel();

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {
      updateLocation(position);
    });
  }

  Future<void> _stopLocationTracking() async {
    _locationSubscription?.cancel();
  }

  Stream<List<Map<String, dynamic>>> listenToRidesInRegion(String regiao) {
    return _db
        .child('corridas_por_regiao/$regiao/pendente')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return <Map<String, dynamic>>[];

      final data = event.snapshot.value as Map<dynamic, dynamic>;
      return data.entries.map((entry) {
        final rideData = Map<String, dynamic>.from(entry.value as Map);
        rideData['id'] = entry.key;
        return rideData;
      }).toList();
    });
  }

  Future<bool> acceptRide(String rideId, Map<String, dynamic> rideData) async {
    final uid = usuarioAtual?.uid;
    if (uid == null) return false;

    try {
      final regiao = rideData['codigoRegiao'];
      final passageiroUid = rideData['passageiroUid'];

      final updatedRide = Map<String, dynamic>.from(rideData);
      updatedRide['motoristaUid'] = uid;
      updatedRide['status'] = 'aceito';
      updatedRide['atualizadoEm'] = ServerValue.timestamp;

      await _db.update({
        'corridas_por_regiao/$regiao/pendente/$rideId': null,
        'corridas_por_regiao/$regiao/aceito/$rideId': updatedRide,
        'corridas/$rideId/motoristaUid': uid,
        'corridas/$rideId/status': 'aceito',
        'corridas/$rideId/atualizadoEm': ServerValue.timestamp,
        'corridas_por_usuario/$passageiroUid/$rideId/motoristaUid': uid,
        'corridas_por_usuario/$passageiroUid/$rideId/status': 'aceito',
      });

      return true;
    } catch (e) {
      print("❌ Erro ao aceitar corrida: $e");
      return false;
    }
  }

  Future<bool> completeRide(String rideId, double valor) async {
    final uid = usuarioAtual?.uid;
    if (uid == null) return false;

    try {
      final now = DateTime.now();
      final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await _db.child('corridas/$rideId').update({
        'status': 'concluida',
        'concluidaEm': ServerValue.timestamp,
        'valorFinal': valor,
      });

      final statsRef = _db.child('estatisticas_motorista/$uid/$dateKey');
      final statsSnap = await statsRef.get();

      if (statsSnap.exists) {
        final stats = Map<String, dynamic>.from(statsSnap.value as Map);
        await statsRef.update({
          'ganhos': (stats['ganhos'] ?? 0) + valor,
          'corridas': (stats['corridas'] ?? 0) + 1,
        });
      } else {
        await statsRef.set({
          'ganhos': valor,
          'corridas': 1,
        });
      }

      return true;
    } catch (e) {
      print("❌ Erro ao finalizar corrida: $e");
      return false;
    }
  }

  /// 🚨 Novo método para cancelar corrida
  Future<bool> cancelRide(String rideId, String regiao, String passageiroUid) async {
    final uid = usuarioAtual?.uid;
    if (uid == null) return false;

    try {
      await _db.update({
        'corridas/$rideId/status': 'cancelada',
        'corridas/$rideId/canceladaEm': ServerValue.timestamp,
        'corridas/$rideId/motoristaUid': null,
        'corridas_por_regiao/$regiao/pendente/$rideId': null,
        'corridas_por_regiao/$regiao/aceito/$rideId': null,
        'corridas_por_usuario/$passageiroUid/$rideId/status': 'cancelada',
      });

      return true;
    } catch (e) {
      print("❌ Erro ao cancelar corrida: $e");
      return false;
    }
  }

  User? get usuarioAtual => _auth.currentUser;

  Future<void> logout() async {
    final uid = usuarioAtual?.uid;
    if (uid != null) {
      await _db.child('usuarios/$uid/online').set(false);
      await _db.child('usuarios/$uid/isOnline').set(false);
      await _db.child('usuarios/$uid/lastSeen').set(ServerValue.timestamp);
    }

    _locationSubscription?.cancel();
    _presenceTimer?.cancel();
    await _auth.signOut();
  }

  void dispose() {
    _locationSubscription?.cancel();
    _presenceTimer?.cancel();
  }
}
