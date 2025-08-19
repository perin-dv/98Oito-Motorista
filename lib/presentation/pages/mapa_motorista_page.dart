import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/corrida_model.dart';
import '../../data/services/corrida_service.dart';
import '../../data/services/firebase_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/audio_service.dart';
import '../../widgets/ride_notification_overlay.dart' hide DottedLinePainter;
import '../../widgets/professional_stats_card.dart';
import '../../widgets/animated_car_marker.dart';
import '../../widgets/dotted_line_painter.dart';
import 'corrida_em_andamento_page.dart';
import 'historico_corridas_page.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';




class MapaMotoristaPage extends StatefulWidget {
  const MapaMotoristaPage({super.key});

  @override
  State<MapaMotoristaPage> createState() => _MapaMotoristaPageState();
}

class _MapaMotoristaPageState extends State<MapaMotoristaPage> {
  // --- MAPA / LOCALIZAÇÃO ---
  GoogleMapController? _map;
  LatLng _camera = const LatLng(-23.5505, -46.6333); // fallback SP
  double _bearing = 0;
  StreamSubscription<Position>? _posSub;

  BitmapDescriptor? _arrowIcon;
  Marker? _driverMarker;
  String _etaText = '';

  // --- UI / ESTADO ---
  bool _isOnline = false;
  bool _hasActiveRide = false;
  String _currentTime = '';
  double _todayEarnings = 0.0;
  int _todayRides = 0;

  // --- FIREBASE ---
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance.ref();
  final _firebaseService = FirebaseService();
  final _notificationService = NotificationService();
  final _audioService = AudioService();

  // corrida "ofertada" - SÓ APARECE QUANDO ONLINE
  String? _corridaId;
  Map<String, dynamic>? _corridaData;
  StreamSubscription<DatabaseEvent>? _corridasSub;

  // DADOS DA CORRIDA ATIVA (persistente)
  String? _activeCorridaId;
  Map<String, dynamic>? _activeCorridaData;
  String? _activeCorridaStatus; // 'aceita', 'iniciada', 'finalizada'

  // Overlay de notificação
  OverlayEntry? _notificationOverlay;
  bool _showingNotification = false;

  @override
  void initState() {
    super.initState();
    _loadArrowIcon();
    _tickClock();
    _initLocation();
    _initializeServices();
    _restoreOnlineFlag();
    _loadTodayStats();
    _restoreActiveRideState(); // RESTAURAR ESTADO DA CORRIDA ATIVA
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _corridasSub?.cancel();
    _map?.dispose();
    _notificationService.dispose();
    _firebaseService.dispose();
    _hideNotificationOverlay();
    super.dispose();
  }

  // SALVAR E RESTAURAR ESTADO DA CORRIDA ATIVA
  Future<void> _saveActiveRideState() async {
    final prefs = await SharedPreferences.getInstance();

    if (_hasActiveRide && _activeCorridaId != null && _activeCorridaData != null) {
      await prefs.setString('active_corrida_id', _activeCorridaId!);
      await prefs.setString('active_corrida_data', _activeCorridaData.toString());
      await prefs.setString('active_corrida_status', _activeCorridaStatus ?? 'aceita');
      await prefs.setBool('has_active_ride', true);
      debugPrint('💾 Estado da corrida ativa salvo: $_activeCorridaId');
    } else {
      await prefs.remove('active_corrida_id');
      await prefs.remove('active_corrida_data');
      await prefs.remove('active_corrida_status');
      await prefs.setBool('has_active_ride', false);
      debugPrint('💾 Estado da corrida ativa limpo');
    }
  }

  Future<void> _restoreActiveRideState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasActiveRide = prefs.getBool('has_active_ride') ?? false;

      if (hasActiveRide) {
        final corridaId = prefs.getString('active_corrida_id');
        final corridaStatus = prefs.getString('active_corrida_status') ?? 'aceita';

        if (corridaId != null) {
          // Buscar dados atualizados da corrida no Firebase
          final corridaSnapshot = await _db.child('corridas/$corridaId').get();

          if (corridaSnapshot.exists) {
            final corridaData = Map<String, dynamic>.from(corridaSnapshot.value as Map);
            final status = corridaData['status'] ?? 'aceita';

            // Verificar se a corrida ainda está ativa
            if (status == 'aceita' || status == 'iniciada' || status == 'em_andamento') {
              setState(() {
                _hasActiveRide = true;
                _activeCorridaId = corridaId;
                _activeCorridaData = _normalizeCorrida(corridaData, corridaId);
                _activeCorridaStatus = status;
              });

              debugPrint('🔄 Estado da corrida ativa restaurado: $corridaId (status: $status)');

              // Não escutar novas corridas se tem uma ativa
              return;
            } else {
              // Corrida foi finalizada/cancelada, limpar estado
              await _clearActiveRideState();
            }
          } else {
            // Corrida não existe mais, limpar estado
            await _clearActiveRideState();
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao restaurar estado da corrida ativa: $e');
      await _clearActiveRideState();
    }
  }

  Future<void> _clearActiveRideState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_corrida_id');
    await prefs.remove('active_corrida_data');
    await prefs.remove('active_corrida_status');
    await prefs.setBool('has_active_ride', false);

    setState(() {
      _hasActiveRide = false;
      _activeCorridaId = null;
      _activeCorridaData = null;
      _activeCorridaStatus = null;
      // ZERAR TAMBÉM A CORRIDA PENDENTE
      _corridaId = null;
      _corridaData = null;
    });

    debugPrint('🗑️ Estado da corrida ativa limpo');
  }

  /// Inicializa os serviços
  void _initializeServices() {
    _notificationService.onNewRide = (rideData) {
      // SÓ MOSTRA NOTIFICAÇÃO SE ESTIVER ONLINE E NÃO TIVER CORRIDA ATIVA
      if (_isOnline && !_showingNotification && !_hasActiveRide) {
        _showRideNotification(rideData);
      }
    };

    _notificationService.onRideStatusChanged = (rideId, status) {
      if (rideId == _corridaId) {
        setState(() {
          if (_corridaData != null) {
            _corridaData!['status'] = status;
          }
        });

        if (status == 'cancelada') {
          _audioService.playErrorSound();
          _hideNotificationOverlay();
        }
      }

      // Verificar se é a corrida ativa que foi cancelada
      if (rideId == _activeCorridaId && (status == 'cancelada' || status == 'finalizada')) {
        _clearActiveRideState();

        // Voltar a escutar corridas se ainda estiver online
        if (_isOnline) {
          _listenCorridas();
        }
      }
    };

    _notificationService.initialize();
  }

  void _showRideNotification(Map<String, dynamic> rideData) {
    if (_showingNotification || !_isOnline || _hasActiveRide) return;

    setState(() {
      _showingNotification = true;
      _corridaId = rideData['id'];
      _corridaData = rideData;
    });

    _notificationOverlay = OverlayEntry(
      builder: (context) => RideNotificationOverlay(
        rideData: rideData,
        onAccept: () {
          _hideNotificationOverlay();
          _aceitarCorrida(); // navega
        },
        onDecline: () {
          _hideNotificationOverlay();
          _recusarCorrida();
        },
        timeoutSeconds: 15,
      ),
    );

    // 👇 importante: rootOverlay:false prende o overlay nesta página
    Overlay.of(context, rootOverlay: false)?.insert(_notificationOverlay!);
  }

  /// Esconde overlay de notificação
  void _hideNotificationOverlay() {
    if (_notificationOverlay != null) {
      _notificationOverlay!.remove();
      _notificationOverlay = null;
    }
    setState(() {
      _showingNotification = false;
    });
  }

  // ---------------- CLOCK ----------------
  void _tickClock() {
    setState(() {
      final now = DateTime.now();
      _currentTime =
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
    Future.delayed(const Duration(minutes: 1), _tickClock);
  }

  Future<void> _loadArrowIcon() async {
    try {
      final data = await rootBundle.load('assets/images/arrow_icon.png');
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 80,
      );
      final frame = await codec.getNextFrame();
      final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return;
      if (bytes != null) {
        setState(() {
          _arrowIcon = BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
        });
      }
    } catch (e) {
      debugPrint('⚠️ Falha ao carregar arrow_icon.png: $e');
      // Fallback para ícone padrão se não conseguir carregar o personalizado
      setState(() {
        _arrowIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      });
    }
  }

  void _loadTodayStats() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      debugPrint('⚠️ UID não encontrado no Auth');
      return;
    }

    final now = DateTime.now();
    final dataHoje =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final path = 'estatisticas_motorista/$uid/$dataHoje';
    debugPrint('📡 Lendo $path');

    _db.child(path).onValue.listen((event) {
      debugPrint('📥 Recebido: ${event.snapshot.value}');
      if (!mounted) return;

      if (!event.snapshot.exists) {
        setState(() {
          _todayEarnings = 0.0;
          _todayRides = 0;
        });
        return;
      }

      final map = Map<String, dynamic>.from(event.snapshot.value as Map);
      num _toNum(dynamic v) {
        if (v is num) return v;
        if (v is String) return num.tryParse(v.replaceAll(',', '.')) ?? 0;
        return 0;
      }

      setState(() {
        _todayEarnings = _toNum(map['ganhos']).toDouble();
        _todayRides = _toNum(map['corridas']).toInt();
      });
    });
  }

  // --------------- LOCATION ----------------
  Future<void> _initLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permita o acesso à localização para usar o mapa.')),
        );
        return;
      }

      // Verificar se o serviço de localização está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Habilite o GPS para usar o mapa.')),
        );
        return;
      }

      // última posição conhecida
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      _updateCamera(LatLng(pos.latitude, pos.longitude), pos.heading);

      // stream contínua
      _posSub?.cancel();
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3, // Reduzido para melhor precisão
        ),
      ).listen((p) {
        _updateCamera(LatLng(p.latitude, p.longitude), p.heading);
        if (_isOnline) _updatePresence(p);
      });
    } catch (e) {
      debugPrint('Erro ao inicializar localização: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao obter localização. Verifique as permissões.')),
      );
    }
  }

  void _updateCamera(LatLng latLng, double bearing) {
    setState(() {
      _camera = latLng;
      _bearing = (bearing.isNaN || bearing.isInfinite) ? 0 : bearing;

      _driverMarker = Marker(
        markerId: const MarkerId("driver"),
        position: latLng,
        rotation: _bearing,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        icon: _arrowIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      );
    });

    // Animar câmera suavemente
    _map?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: latLng, zoom: 16, bearing: _bearing),
      ),
    );
  }

  // Função para centralizar o mapa na localização atual
  Future<void> _centerOnCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      _map?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(pos.latitude, pos.longitude),
            zoom: 17,
            bearing: _bearing,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Erro ao obter localização atual: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao obter localização atual')),
      );
    }
  }

  // --------------- FIREBASE: ONLINE / PRESENÇA ----------------
  Future<void> _restoreOnlineFlag() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final snap = await _db.child('usuarios/$uid/online').get();
      if (snap.exists && snap.value is bool) {
        setState(() => _isOnline = snap.value as bool);
        // Quando restaurar o status online, iniciar escuta de corridas APENAS SE NÃO TEM CORRIDA ATIVA
        if (_isOnline && !_hasActiveRide) {
          _listenCorridas();
        }
      }
    } catch (e) {
      debugPrint('Erro ao restaurar status online: $e');
    }
  }

  Future<void> _toggleOnline() async {
    // BLOQUEAR SE TEM CORRIDA ATIVA
    if (_hasActiveRide) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você não pode ficar offline durante uma corrida!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para ficar online.')),
      );
      return;
    }

    setState(() => _isOnline = !_isOnline);

    try {
      await _firebaseService.setOnlineStatus(_isOnline);

      if (_isOnline) {
        _audioService.playRideAcceptedSound();
        if (!_hasActiveRide) {
          _listenCorridas(); // Iniciar escuta quando ficar online APENAS SE NÃO TEM CORRIDA ATIVA
        }
      } else {
        _audioService.playLightFeedback();
        _corridasSub?.cancel();
        _subRegiao?.cancel();
        _hideNotificationOverlay(); // 👈 sumir overlay na hora
        setState(() {
          _corridaId = null;
          _corridaData = null;
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isOnline ? 'Você está online!' : 'Você está offline'),
          backgroundColor: _isOnline ? Colors.orange : Colors.grey,
        ),
      );
    } catch (e) {
      debugPrint('Erro ao alterar status online: $e');
      // Reverter o estado em caso de erro
      setState(() => _isOnline = !_isOnline);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao alterar status. Tente novamente.')),
      );
    }
  }

  Future<void> _updatePresence(Position p) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db.child('usuarios/$uid/localizacao').set({
        'lat': p.latitude,
        'lng': p.longitude,
        'bearing': p.heading,
        'at': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('Erro ao atualizar presença: $e');
    }
  }

  // --------------- FIREBASE: ESCUTA CORRIDAS (SÓ QUANDO ONLINE E SEM CORRIDA ATIVA) ----------------
  StreamSubscription<List<CorridaModel>>? _subRegiao;

  double _toDouble(dynamic v, {double def = 30}) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? def;
    return def;
  }

  Future<void> _listenCorridas() async {
    if (!_isOnline || _hasActiveRide) return; // SÓ ESCUTA SE ONLINE E SEM CORRIDA ATIVA
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final perfil = await _db.child('usuarios/$uid').get();
      if (!perfil.exists) return;

      String regiao = 'SP-CAPITAL';
      final regRaw =
          perfil.child('codigo_regiao').value ?? perfil.child('codigoRegiao').value;
      if (regRaw is String && regRaw.isNotEmpty) regiao = regRaw;

      final rawRaio =
          perfil.child('raio_km').value ?? perfil.child('raioKm').value ?? 30;
      final raioKm = _toDouble(rawRaio, def: 30);

      final pos = await Geolocator.getCurrentPosition();

      debugPrint('🧭 Região usada: $regiao | Raio: ${raioKm.toStringAsFixed(1)} km');
      debugPrint('📍 Driver: ${pos.latitude}, ${pos.longitude}');

      _subRegiao?.cancel();
      _subRegiao = CorridaService()
          .streamCorridasDaRegiao(
        codigoRegiao: regiao,
        status: 'pendente',
        centerLat: pos.latitude,
        centerLng: pos.longitude,
        raioKm: raioKm,
      )
          .listen((list) async {
        if (!mounted || !_isOnline || _hasActiveRide) return; // SÓ PROCESSA SE ONLINE E SEM CORRIDA ATIVA

        // Fallback
        final idxSnap = await _db
            .child('corridas_por_regiao/$regiao/pendente')
            .limitToFirst(1)
            .get();

        if (!idxSnap.exists) {
          setState(() {
            _corridaId = null;
            _corridaData = null;
          });

          final all = await _db.child('corridas').get();
          if (all.exists) {
            for (final n in all.children) {
              final m = Map<String, dynamic>.from(n.value as Map);
              if ((m['status'] == 'buscando_motorista' ||
                  m['status'] == 'pendente') &&
                  (m['codigoRegiao'] == regiao)) {
                final norm = _normalizeCorrida(m, n.key!);
                setState(() {
                  _corridaId = n.key;
                  _corridaData = norm;
                });
                return;
              }
            }
          }
          return;
        }

        final id = idxSnap.children.first.key!;
        final detalhe = await _db.child('corridas/$id').get();
        if (!detalhe.exists) return;

        final norm =
        _normalizeCorrida(Map<String, dynamic>.from(detalhe.value as Map), id);
        setState(() {
          _corridaId = id;
          _corridaData = norm;
        });
      });
    } catch (e) {
      debugPrint('Erro ao escutar corridas: $e');
    }
  }

  Map<String, dynamic> _normalizeCorrida(Map<String, dynamic> raw, String id) {
    if (raw.containsKey('origemDescricao') &&
        raw.containsKey('destinoDescricao')) {
      return raw..putIfAbsent('id', () => id);
    }
    final origem = raw['origem'] ?? {};
    final destino = raw['destino'] ?? {};
    return {
      'id': id,
      'status': raw['status'] ?? 'pendente',
      'codigoRegiao': raw['codigoRegiao'] ?? raw['codigo_regiao'] ?? 'SP-CAPITAL',
      'passageiroUid': raw['passageiroUid'],
      'motoristaUid': raw['motoristaUid'],
      'valor': (raw['valor'] is num) ? raw['valor'] : 0,
      'criadoEm': raw['criadoEm'],
      'atualizadoEm': raw['atualizadoEm'],
      'origemDescricao': origem['endereco'] ?? 'Origem',
      'origemLat': origem['lat'] ?? raw['origemLat'],
      'origemLng': origem['lng'] ?? raw['origemLng'],
      'destinoDescricao': destino['endereco'] ?? 'Destino',
      'destinoLat': destino['lat'] ?? raw['destinoLat'],
      'destinoLng': destino['lng'] ?? raw['destinoLng'],
    };
  }

  // --------------- ACEITAR / RECUSAR / FINALIZAR ----------------
  Future<void> _aceitarCorrida() async {
    if (_corridaId == null || _corridaData == null) {
      debugPrint('❌ Erro: _corridaId ou _corridaData é null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: dados da corrida não encontrados'), backgroundColor: Colors.red),
      );
      return;
    }

    debugPrint('🚗 Iniciando processo de aceitar corrida: $_corridaId');

    try {
      // PRIMEIRO: Parar de escutar novas corridas e salvar dados da corrida ativa
      _corridasSub?.cancel();
      _subRegiao?.cancel();

      setState(() {
        _hasActiveRide = true; // Marcar como tendo corrida ativa
        _showingNotification = false;

        // SALVAR DADOS DA CORRIDA ATIVA
        _activeCorridaId = _corridaId;
        _activeCorridaData = Map<String, dynamic>.from(_corridaData!);
        _activeCorridaStatus = 'aceita';
      });

      // SALVAR NO SHARED PREFERENCES
      await _saveActiveRideState();

      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );

      final success = await _firebaseService.acceptRide(_corridaId!, _corridaData!);

      // Fechar loading
      if (mounted) Navigator.of(context).pop();

      debugPrint('🚗 Resultado acceptRide: $success');

      // NAVEGAR PARA A TELA DE CORRIDA
      await _navegarParaCorridaAtiva();

    } catch (e) {
      debugPrint('❌ Erro ao aceitar corrida: $e');

      // Fechar loading se ainda estiver aberto
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Reverter estado em caso de erro
      await _clearActiveRideState();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao aceitar corrida: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _recusarCorrida() async {
    if (_corridaId == null) return;

    setState(() {
      _corridaId = null;
      _corridaData = null;
    });

    _audioService.playLightFeedback();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Corrida recusada')),
    );
  }

  // FUNÇÃO PARA CANCELAR CORRIDA ATIVA (ZERAR TELA)
  Future<void> _cancelarCorridaAtiva() async {
    try {
      // Mostrar confirmação
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancelar Corrida'),
          content: const Text('Tem certeza que deseja cancelar esta corrida?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Não'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Sim, Cancelar'),
            ),
          ],
        ),
      );

      if (confirmar == true) {
        // Cancelar no Firebase se necessário
        if (_activeCorridaId != null) {
          await _firebaseService.cancelRide(
            _activeCorridaId!,
            _activeCorridaData!['codigoRegiao'],
            _activeCorridaData!['passageiroUid'],
          );

        }

        // ZERAR TUDO
        await _clearActiveRideState();

        // Voltar a escutar corridas se ainda estiver online
        if (_isOnline) {
          _listenCorridas();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Corrida cancelada'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao cancelar corrida: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao cancelar corrida: $e')),
      );
    }
  }

  // FUNÇÃO PARA NAVEGAR PARA CORRIDA ATIVA (sem pedir confirmação)
  Future<void> _navegarParaCorridaAtiva() async {
    if (_activeCorridaId == null || _activeCorridaData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma corrida ativa encontrada')),
      );
      return;
    }

    try {
      final data = _activeCorridaData!;

      double _asDouble(dynamic v) {
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
        return 0.0;
      }

      LatLng _latLngFrom(dynamic lat, dynamic lng) {
        final latValue = _asDouble(lat);
        final lngValue = _asDouble(lng);
        return LatLng(latValue, lngValue);
      }

      // Obter localização atual do motorista como origem
      LatLng origem;
      try {
        final pos = await Geolocator.getCurrentPosition();
        origem = LatLng(pos.latitude, pos.longitude);
      } catch (e) {
        origem = _camera; // usar posição da câmera como fallback
      }

      final destino = _latLngFrom(
        data['destinoLat'] ?? data['destino']?['lat'] ?? -23.5505,
        data['destinoLng'] ?? data['destino']?['lng'] ?? -46.6333,
      );

      final nomePassageiro =
      (data['passageiroNome'] ?? data['nomePassageiro'] ?? 'Passageiro').toString();

      final valor = _asDouble(data['valor']);

      // LIMPAR DADOS DA CORRIDA PENDENTE (mas manter os dados ativos)
      setState(() {
        _corridaId = null;
        _corridaData = null;
      });

      // Navegar para a tela de corrida em andamento
      debugPrint('🚗 Navegando para CorridaEmAndamentoPage...');
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CorridaEmAndamentoPage(
            corridaId: _activeCorridaId!,
            origem: origem,
            destino: destino,
            nomePassageiro: nomePassageiro,
            valorCorrida: valor,
          ),
        ),
      );

      debugPrint('🚗 Retornou da CorridaEmAndamentoPage com resultado: $result');

      // Quando voltar da tela de corrida, verificar se foi finalizada
      if (mounted && result == 'finalizada') {
        await _clearActiveRideState();

        // Voltar a escutar corridas se ainda estiver online
        if (_isOnline) {
          _listenCorridas();
        }
      } else {
        // Se não foi finalizada, atualizar status para 'iniciada'
        setState(() {
          _activeCorridaStatus = 'iniciada';
        });
        await _saveActiveRideState();
      }
    } catch (e) {
      debugPrint('Erro ao navegar para corrida ativa: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao navegar para corrida: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obter nome do usuário sem duplicação
    final userName = _auth.currentUser?.displayName ??
        _auth.currentUser?.email?.split('@').first ??
        'Motorista';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER ESTILO 99 - MAIS CLEAN
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Avatar do motorista
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.orange,
                    child: Text(
                      userName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Nome e status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Olá, $userName',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _hasActiveRide
                                    ? Colors.green
                                    : (_isOnline ? Colors.orange : Colors.grey),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _hasActiveRide
                                  ? 'Em corrida'
                                  : (_isOnline ? 'Online' : 'Offline'),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Horário
                  Text(
                    _currentTime,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // STATS CARD ESTILO 99
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Ganhos
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ganhos',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'R\$ ${_todayEarnings.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Divisor
                  Container(
                    height: 40,
                    width: 1,
                    color: Colors.grey[300],
                  ),

                  // Corridas
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Corridas',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_todayRides',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // MAPA ESTILO 99
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: GoogleMap(
                        onMapCreated: (controller) {
                          _map = controller;
                          // Estilo mais clean do mapa
                          _map?.setMapStyle('''
                          [
                            {
                              "featureType": "poi",
                              "elementType": "labels",
                              "stylers": [{"visibility": "off"}]
                            },
                            {
                              "featureType": "transit",
                              "elementType": "labels",
                              "stylers": [{"visibility": "off"}]
                            },
                            {
                              "featureType": "road",
                              "elementType": "labels.icon",
                              "stylers": [{"visibility": "off"}]
                            }
                          ]
                          ''');
                        },
                        initialCameraPosition: CameraPosition(
                          target: _camera,
                          zoom: 15,
                          bearing: _bearing,
                        ),
                        markers: _driverMarker != null ? {_driverMarker!} : {},
                        myLocationEnabled: false,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        compassEnabled: false,
                        rotateGesturesEnabled: true,
                        scrollGesturesEnabled: true,
                        zoomGesturesEnabled: true,
                        tiltGesturesEnabled: false,
                      ),
                    ),

                    // BOTÃO DE CENTRALIZAR LOCALIZAÇÃO
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: _centerOnCurrentLocation,
                          icon: const Icon(Icons.my_location, color: Colors.orange),
                          iconSize: 24,
                        ),
                      ),
                    ),

                    // INDICADOR DE CORRIDA ATIVA ESTILO 99
                    if (_hasActiveRide && _activeCorridaData != null)
                      Positioned(
                        top: 20,
                        left: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.navigation, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                'Corrida Ativa',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _cancelarCorridaAtiva,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.white24,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // CARD DE CORRIDA ESTILO 99 (MUITO MAIS BONITO)
            if (_isOnline && _corridaData != null && !_showingNotification && !_hasActiveRide)
              Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header do card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.directions_car, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Nova Corrida',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'R\$ ${(_corridaData!['valor'] ?? 0).toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Conteúdo do card
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Origem
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _corridaData!['origemDescricao'] ?? 'Origem não informada',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          // Linha conectora
                          Container(
                            margin: const EdgeInsets.only(left: 6, top: 8, bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 2,
                                  height: 20,
                                  color: Colors.grey[300],
                                ),
                              ],
                            ),
                          ),

                          // Destino
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _corridaData!['destinoDescricao'] ?? 'Destino não informado',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Botões
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: TextButton(
                                    onPressed: _recusarCorrida,
                                    style: TextButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                    ),
                                    child: Text(
                                      'Recusar',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Colors.orange, Color(0xFFFF8C00)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(25),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.orange.withOpacity(0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: TextButton(
                                    onPressed: _aceitarCorrida,
                                    style: TextButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                    ),
                                    child: const Text(
                                      'Aceitar',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // NAVEGAÇÃO INFERIOR ESTILO 99
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Mapa
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map, color: Colors.white, size: 24),
                          SizedBox(height: 4),
                          Text(
                            'Mapa',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Destino/Corrida
                  Expanded(
                    child: GestureDetector(
                      onTap: _hasActiveRide ? _navegarParaCorridaAtiva : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _hasActiveRide ? Colors.green : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _hasActiveRide ? Icons.navigation : Icons.location_on,
                              color: _hasActiveRide ? Colors.white : Colors.grey[600],
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _hasActiveRide ? 'Corrida' : 'Destino',
                              style: TextStyle(
                                fontSize: 12,
                                color: _hasActiveRide ? Colors.white : Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Histórico
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HistoricoCorridasPage(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history, color: Colors.grey[600], size: 24),
                            const SizedBox(height: 4),
                            Text(
                              'Histórico',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // BOTÃO ONLINE/OFFLINE ESTILO 99
            Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _toggleOnline,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasActiveRide
                        ? Colors.grey[400] // Desabilitado quando tem corrida ativa
                        : (_isOnline ? Colors.red : Colors.orange),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: _hasActiveRide ? 0 : 8,
                    shadowColor: _isOnline ? Colors.red.withOpacity(0.4) : Colors.orange.withOpacity(0.4),
                  ),
                  child: Text(
                    _hasActiveRide
                        ? 'EM CORRIDA - NÃO É POSSÍVEL FICAR OFFLINE'
                        : (_isOnline ? 'FICAR OFFLINE' : 'FICAR ONLINE'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

