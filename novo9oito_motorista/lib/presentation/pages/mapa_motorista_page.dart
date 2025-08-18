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
import 'package:firebase_auth/firebase_auth.dart';

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

  BitmapDescriptor? _arrowIcon; // seta personalizada
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

  // corrida "ofertada"
  String? _corridaId;
  Map<String, dynamic>? _corridaData;
  StreamSubscription<DatabaseEvent>? _corridasSub;

  // Overlay de notificação
  OverlayEntry? _notificationOverlay;
  bool _showingNotification = false;

  // estilo do mapa (antes estava dentro de GoogleMap como `style:` — isso não existe)
  static const String _mapStyleJson = '''
  [
    {"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},
    {"featureType":"transit","elementType":"labels","stylers":[{"visibility":"off"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _loadArrowIcon();
    _tickClock();
    _initLocation();
    _initializeServices();
    _listenCorridas();
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
      if (!_showingNotification) {
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
    if (_showingNotification) return;

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
      final data =
      await rootBundle.load('assets/images/arrow_icon.png'); // PNG no assets
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 80,
      );
      final frame = await codec.getNextFrame();
      final bytes =
      await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return;
      if (bytes != null) {
        setState(() {
          _arrowIcon = BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
        });
      }
    } catch (e) {
      debugPrint('⚠️ Falha ao carregar arrow_icon.png: $e');
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
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permita o acesso à localização.')),
      );
      return;
    }

    // última posição conhecida
    final pos = await Geolocator.getCurrentPosition();
    _updateCamera(LatLng(pos.latitude, pos.longitude), pos.heading);

    // stream contínua
    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((p) {
      _updateCamera(LatLng(p.latitude, p.longitude), p.heading);
      if (_isOnline) _updatePresence(p);
    });
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
        icon: _arrowIcon ?? BitmapDescriptor.defaultMarker, // evita null
      );
    });

    _map?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: latLng, zoom: 15, bearing: _bearing),
      ),
    );
  }

  // --------------- FIREBASE: ONLINE / PRESENÇA ----------------
  Future<void> _restoreOnlineFlag() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final snap = await _db.child('usuarios/$uid/online').get();
    if (snap.exists && snap.value is bool) {
      setState(() => _isOnline = snap.value as bool);
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

    await _firebaseService.setOnlineStatus(_isOnline);

    if (_isOnline) {
      _audioService.playRideAcceptedSound();
    } else {
      _audioService.playLightFeedback();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isOnline ? 'Você está online!' : 'Você está offline'),
        backgroundColor: _isOnline ? Colors.green : Colors.grey,
      ),
    );
  }

  Future<void> _updatePresence(Position p) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.child('usuarios/$uid/localizacao').set({
      'lat': p.latitude,
      'lng': p.longitude,
      'bearing': p.heading,
      'at': ServerValue.timestamp,
    });
  }

  // Cálculo simples de ETA (pode ser chamado ao atualizar a posição)
  void _updateEta(Position p, LatLng destino) {
    final distancia = Geolocator.distanceBetween(
      p.latitude,
      p.longitude,
      destino.latitude,
      destino.longitude,
    ); // metros
    if (p.speed > 0) {
      final segundos = distancia / p.speed;
      final minutos = (segundos / 60).round();
      setState(() {
        _etaText = '$minutos min';
      });
    } else {
      setState(() {
        _etaText = '--';
      });
    }
  }

  // --------------- FIREBASE: ESCUTA CORRIDAS ----------------
  StreamSubscription<List<CorridaModel>>? _subRegiao;

  double _toDouble(dynamic v, {double def = 30}) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? def;
    return def;
  }

  Future<void> _listenCorridas() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

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
      if (!mounted) return;

      if (list.isNotEmpty) {
        final c = list.first.toMap();
        setState(() {
          _corridaId = c['id'];
          _corridaData = c;
        });
        return;
      }

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

    final success = await _firebaseService.acceptRide(_corridaId!, _corridaData!);

    if (success) {
      if (!mounted) return;
      setState(() => _hasActiveRide = true);
      _audioService.playRideAcceptedSound();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Corrida aceita!'),
          backgroundColor: Colors.green,
        ),
      );

      // Escuta mudanças de status da corrida
      _notificationService.listenToRideStatus(_corridaId!);


      final motoristaUid = FirebaseAuth.instance.currentUser!.uid;
      // Navega para a tela de corrida em andamento
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CorridaEmAndamentoPage(
            corridaId: _corridaId!,  motoristaId: motoristaUid,
          ),
        ),
      );

      if (!mounted) return;
      setState(() {
        _hasActiveRide = false;
        _corridaId = null;
        _corridaData = null;
      });
    } else {
      if (!mounted) return;
      _audioService.playErrorSound();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao aceitar corrida'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _recusarCorrida() async {
    _audioService.playLightFeedback();
    setState(() {
      _corridaId = null;
      _corridaData = null;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Corrida recusada')));
  }

  Future<void> _finalizarCorrida() async {
    if (_corridaId == null || _corridaData == null) return;

    const valorCorrida = 18.50; // TODO: pegar do banco
    final success =
    await _firebaseService.completeRide(_corridaId!, valorCorrida);

    if (success) {
      if (!mounted) return;
      setState(() {
        _hasActiveRide = false;
        _todayEarnings += valorCorrida;
        _todayRides += 1;
        _corridaId = null;
        _corridaData = null;
      });

      _audioService.playRideCompletedSound();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Corrida finalizada com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      if (!mounted) return;
      _audioService.playErrorSound();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao finalizar corrida'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          // Mapa
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _camera, zoom: 15),
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            trafficEnabled: true,
            buildingsEnabled: true,
            onMapCreated: (c) {
              _map = c;
              _map?.setMapStyle(_mapStyleJson); // aplica o estilo aqui
            },
            markers: {
              if (_driverMarker != null) _driverMarker!,
            },
          ),

          // Card de estatísticas profissional
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: ProfessionalStatsCard(
              todayEarnings: _todayEarnings,
              todayRides: _todayRides,
              isOnline: _isOnline,
              currentTime: _currentTime,
            ),
          ),

          // Botão Online/Offline melhorado
          Positioned(
            top: MediaQuery.of(context).padding.top + 200,
            left: 16,
            child: GestureDetector(
              onTap: _toggleOnline,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isOnline
                        ? [const Color(0xFF4CAF50), const Color(0xFF66BB6A)]
                        : [Colors.grey[400]!, Colors.grey[500]!],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color:
                      (_isOnline ? const Color(0xFF4CAF50) : Colors.grey)
                          .withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: _isOnline
                            ? [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.8),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isOnline ? 'ONLINE' : 'OFFLINE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Painel inferior melhorado
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 0,
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Indicador de arrastar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: _hasActiveRide
                        ? _buildActiveRidePanel()
                        : _buildWaitingPanel(),
                  ),
                ],
              ),
            ),
          ),

          // Card de nova corrida melhorado
          if (_isOnline &&
              !_hasActiveRide &&
              _corridaId != null &&
              _corridaData != null)
            Positioned(
              bottom: 200,
              left: 16,
              right: 16,
              child: _buildEnhancedRideRequestCard(),
            ),
        ],
      ),
    );
  }

  Widget _buildWaitingPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isOnline
                  ? [
                const Color(0xFF4CAF50).withOpacity(0.1),
                const Color(0xFF66BB6A).withOpacity(0.05)
              ]
                  : [Colors.grey[100]!, Colors.grey[50]!],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isOnline
                  ? const Color(0xFF4CAF50).withOpacity(0.3)
                  : Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isOnline ? const Color(0xFF4CAF50) : Colors.grey[400],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isOnline ? Icons.search : Icons.info_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isOnline ? 'Procurando corridas' : 'Modo offline',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isOnline
                            ? const Color(0xFF4CAF50)
                            : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isOnline
                          ? 'Aguardando corridas na sua região...'
                          : 'Ative o modo online para receber corridas',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (_isOnline)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        const Color(0xFF4CAF50)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildQuickAction(
                'Destino',
                Icons.location_on,
                const Color(0xFF6A4C93),
                    () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickAction(
                'Filtros',
                Icons.tune,
                const Color(0xFFFF6600),
                    () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickAction(
                'Histórico',
                Icons.history,
                const Color(0xFF4CAF50),
                    () {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAction(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedRideRequestCard() {
    final origem = _corridaData?['origemDescricao'] ?? 'Origem';
    final destino = _corridaData?['destinoDescricao'] ?? 'Destino';
    final preco = _corridaData?['valor'] != null
        ? 'R\$ ${(_corridaData!['valor'] as num).toStringAsFixed(2)}'
        : '—';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A4C93).withOpacity(0.2),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  gradient:
                  LinearGradient(colors: [Color(0xFFFF6600), Color(0xFFFFAB40)]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_car,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nova Corrida Disponível',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6A4C93),
                      ),
                    ),
                    Text(
                      'Próxima de você',
                      style:
                      TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF6A4C93), Color(0xFF8B5CF6)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  preco,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        origem,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  height: 20,
                  child: CustomPaint(
                    painter: DottedLinePainter(),
                    child: const SizedBox(),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF6600),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        destino,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _recusarCorrida,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    side: BorderSide(color: Colors.grey[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Recusar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _aceitarCorrida,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Aceitar Corrida',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRidePanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A4C93), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Color(0xFF6A4C93),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'João Silva',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          '⭐ 4.8 • Viagem em andamento',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Shopping Center → Aeroporto',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      'R\$ 25,50',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _finalizarCorrida,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 24),
              SizedBox(width: 12),
              Text(
                'Finalizar Corrida',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
