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

  /// Inicializa os serviços
  void _initializeServices() {
    _notificationService.onNewRide = (rideData) {
      // SÓ MOSTRA NOTIFICAÇÃO SE ESTIVER ONLINE
      if (_isOnline && !_showingNotification) {
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
    };

    _notificationService.initialize();
  }

  /// Mostra overlay de notificação de corrida
  void _showRideNotification(Map<String, dynamic> rideData) {
    if (_showingNotification || !_isOnline) return; // SÓ SE ONLINE

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
          _aceitarCorrida();
        },
        onDecline: () {
          _hideNotificationOverlay();
          _recusarCorrida();
        },
        timeoutSeconds: 15,
      ),
    );

    Overlay.of(context).insert(_notificationOverlay!);
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
        // Quando restaurar o status online, iniciar escuta de corridas
        if (_isOnline) {
          _listenCorridas();
        }
      }
    } catch (e) {
      debugPrint('Erro ao restaurar status online: $e');
    }
  }

  Future<void> _toggleOnline() async {
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
        _listenCorridas(); // Iniciar escuta quando ficar online
      } else {
        _audioService.playLightFeedback();
        _corridasSub?.cancel(); // Parar escuta quando ficar offline
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

  // --------------- FIREBASE: ESCUTA CORRIDAS (SÓ QUANDO ONLINE) ----------------
  StreamSubscription<List<CorridaModel>>? _subRegiao;

  double _toDouble(dynamic v, {double def = 30}) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? def;
    return def;
  }

  Future<void> _listenCorridas() async {
    if (!_isOnline) return; // SÓ ESCUTA SE ONLINE
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
        if (!mounted || !_isOnline) return; // SÓ PROCESSA SE ONLINE

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
    if (_corridaId == null || _corridaData == null) return;

    try {
      final success = await _firebaseService.acceptRide(_corridaId!, _corridaData!);

      if (success) {
        if (!mounted) return;
        setState(() => _hasActiveRide = true);
        _audioService.playRideAcceptedSound();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Corrida aceita!'), backgroundColor: Colors.orange),
        );

        _notificationService.listenToRideStatus(_corridaId!);

        final data = Map<String, dynamic>.from(_corridaData!);

        double _asDouble(dynamic v) {
          if (v is num) return v.toDouble();
          if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
          return 0.0;
        }

        LatLng _latLngFrom(dynamic lat, dynamic lng) =>
            LatLng(_asDouble(lat), _asDouble(lng));

        final origem = _latLngFrom(
          data['origemLat'] ?? data['origem']?['lat'],
          data['origemLng'] ?? data['origem']?['lng'],
        );

        final destino = _latLngFrom(
          data['destinoLat'] ?? data['destino']?['lat'],
          data['destinoLng'] ?? data['destino']?['lng'],
        );

        final nomePassageiro =
        (data['passageiroNome'] ?? data['nomePassageiro'] ?? 'Passageiro').toString();

        final valor = _asDouble(data['valor']);

        // Navegar para a tela de corrida em andamento
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CorridaEmAndamentoPage(
              corridaId: _corridaId!,
              origem: origem,
              destino: destino,
              nomePassageiro: nomePassageiro,
              valorCorrida: valor,
            ),
          ),
        );

        // Quando voltar da tela de corrida, resetar o estado
        if (mounted) {
          setState(() {
            _hasActiveRide = false;
            _corridaId = null;
            _corridaData = null;
          });
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao aceitar corrida'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint('Erro ao aceitar corrida: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao aceitar corrida'), backgroundColor: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    // Obter nome do usuário sem duplicação
    final userName = _auth.currentUser?.displayName ??
        _auth.currentUser?.email?.split('@').first ??
        'Motorista';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // MAPA EM TELA CHEIA
          GoogleMap(
            onMapCreated: (controller) {
              _map = controller;
              // Aplicar estilo do mapa após criação
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

          // HEADER COMPACTO NO TOPO
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Status Online/Offline
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isOnline ? Colors.orange : Colors.grey,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isOnline ? Icons.circle : Icons.circle_outlined,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isOnline ? 'Online' : 'Offline',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Nome do usuário (SEM DUPLICAÇÃO)
                    Text(
                      'Olá, $userName',
                      style: const TextStyle(
                        color: Color(0xFF6A4C93),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Horário
                    Text(
                      _currentTime,
                      style: const TextStyle(
                        color: Color(0xFF6A4C93),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // CARD GANHOS E CORRIDAS - POSICIONADO NO TOPO DIREITO
          Positioned(
            top: 100,
            right: 16,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ganhos
                    Row(
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        const Text(
                          'Ganhos',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                    Text(
                      'R\$ ${_todayEarnings.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF6A4C93),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Corridas
                    Row(
                      children: [
                        const Icon(Icons.directions_car, color: Color(0xFF6A4C93), size: 16),
                        const SizedBox(width: 4),
                        const Text(
                          'Corridas',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                    Text(
                      '$_todayRides',
                      style: const TextStyle(
                        color: Color(0xFF6A4C93),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // BOTÃO DE CENTRALIZAR LOCALIZAÇÃO
          Positioned(
            bottom: 180,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              onPressed: _centerOnCurrentLocation,
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              child: const Icon(Icons.my_location),
            ),
          ),

          // NOTIFICAÇÃO DE CORRIDA (SÓ APARECE QUANDO ONLINE E HÁ CORRIDA)
          if (_isOnline && _corridaData != null && !_showingNotification)
            Positioned(
              bottom: 120,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nova Corrida Disponível',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6A4C93), // Roxo
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'De: ${_corridaData!['origemDescricao']}',
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Para: ${_corridaData!['destinoDescricao']}',
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Valor: R\$ ${(_corridaData!['valor'] ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange, // Laranja
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _recusarCorrida,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Recusar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _aceitarCorrida,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange, // Laranja
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Aceitar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // BOTÃO ONLINE/OFFLINE NA PARTE INFERIOR
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: SafeArea(
              child: ElevatedButton(
                onPressed: _toggleOnline,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isOnline ? Colors.red : Colors.orange, // Laranja quando offline
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  _isOnline ? 'FICAR OFFLINE' : 'FICAR ONLINE',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

