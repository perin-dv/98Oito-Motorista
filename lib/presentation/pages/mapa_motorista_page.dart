import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_database/firebase_database.dart';

import '../../data/models/corrida_model.dart';
import '../../data/services/corrida_service.dart';
import 'corrida_em_andamento_page.dart';


class MapaMotoristaPage extends StatefulWidget
{
  const MapaMotoristaPage({super.key});

  @override
  State<MapaMotoristaPage> createState() => _MapaMotoristaPageState();
}

class _MapaMotoristaPageState extends State<MapaMotoristaPage>
{
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

  // corrida “ofertada”
  String? _corridaId;
  Map<String, dynamic>? _corridaData;
  StreamSubscription<DatabaseEvent>? _corridasSub;

  @override
  void initState()
{
    super.initState();
    _loadArrowIcon();
    _tickClock();
    _initLocation();
    _listenCorridas();
    _restoreOnlineFlag();
    _loadTodayStats();
  }

  @override
  void dispose()
{
    _posSub?.cancel();
    _corridasSub?.cancel();
    _map?.dispose();
    super.dispose();
  }

  // ---------------- CLOCK ----------------
  void _tickClock()
{
    setState(()
{
      final now = DateTime.now();
      _currentTime =
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    }
);
    Future.delayed(const Duration(minutes: 1), _tickClock);
  }

  Future<void> _loadArrowIcon() async {
    final data = await rootBundle.load('assets/images/arrow_icon.png'); // coloque sua seta em PNG no assets
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: 80, // tamanho da seta
    );
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes != null) {
      setState(() {
        _arrowIcon = BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
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
    final dataHoje = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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
        debugPrint('⚠️ Nenhum dado para hoje nessa chave.');
        return;
      }

      // snapshot pode vir como Map<dynamic,dynamic>
      final map = Map<String, dynamic>.from(event.snapshot.value as Map);

      num _toNum(dynamic v) {
        if (v is num) return v;
        if (v is String) return num.tryParse(v.replaceAll(',', '.')) ?? 0;
        return 0;
      }

      final ganhosNum = _toNum(map['ganhos']);
      final corridasNum = _toNum(map['corridas']);

      setState(() {
        _todayEarnings = ganhosNum.toDouble();
        _todayRides = corridasNum.toInt();
      });

      debugPrint('✅ Atualizado: $_todayRides corridas | R\$ ${_todayEarnings.toStringAsFixed(2)}');
    });
  }




  // --------------- LOCATION ----------------
  Future<void> _initLocation() async
{
    // permissões
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied)
{
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied)
{
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permita o acesso à localização.')),
      );
      return;
    }

    // ultima posição conhecida
    final pos = await Geolocator.getCurrentPosition();
    _updateCamera(LatLng(pos.latitude, pos.longitude), pos.heading);

    // stream contínua
    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((p)
{
      _updateCamera(LatLng(p.latitude, p.longitude), p.heading);
      // se online, atualiza presença no DB
      if (_isOnline) _updatePresence(p);
    }
);
  }

  void _updateCamera(LatLng latLng, double bearing) {
    setState(() {
      _camera = latLng;
      _bearing = bearing.isNaN ? 0 : bearing;

      // atualizar marker de direção
      if (_arrowIcon != null) {
        _driverMarker = Marker(
          markerId: const MarkerId('driver'),
          position: latLng,
          rotation: _bearing,
          icon: _arrowIcon!,
          anchor: const Offset(0.5, 0.5),
          flat: true,
        );
      }
    });

    _map?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: latLng, zoom: 15, bearing: _bearing),
      ),
    );
  }

  // --------------- FIREBASE: ONLINE / PRESENÇA ----------------
  Future<void> _restoreOnlineFlag() async
{
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final snap = await _db.child('usuarios/$uid/online').get();
    if (snap.exists && snap.value is bool)
{
      setState(() => _isOnline = snap.value as bool);
    }
  }

  Future<void> _toggleOnline() async
{
    final uid = _auth.currentUser?.uid;
    if (uid == null)
{
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para ficar online.')),
      );
      return;
    }
    setState(() => _isOnline = !_isOnline);
    await _db.update(
{
      'usuarios/$uid/online': _isOnline,
      'usuarios/$uid/lastOnlineAt': ServerValue.timestamp,
    
}
);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isOnline ? 'Você está online!' : 'Você está offline'),
        backgroundColor: _isOnline ? Colors.green : Colors.grey,
      ),
    );
  }

  Future<void> _updatePresence(Position p) async
{
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.child('usuarios/$uid/localizacao').set(
{
      'lat': p.latitude,
      'lng': p.longitude,
      'bearing': p.heading,
      'at': ServerValue.timestamp,
    
}
);
  }

  // Cálculo simples de ETA (pode ser chamado ao atualizar a posição)
  void _updateEta(Position p, LatLng destino) {
    final distancia = Geolocator.distanceBetween(
      p.latitude, p.longitude, destino.latitude, destino.longitude,
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
    final regRaw = perfil.child('codigo_regiao').value ?? perfil.child('codigoRegiao').value;
    if (regRaw is String && regRaw.isNotEmpty) regiao = regRaw;

    final rawRaio = perfil.child('raio_km').value ?? perfil.child('raioKm').value ?? 30;
    final raioKm = _toDouble(rawRaio, def: 30);

    final pos = await Geolocator.getCurrentPosition();

    debugPrint('🧭 Região usada: $regiao | Raio: ${raioKm.toStringAsFixed(1)} km');
    debugPrint('📍 Driver: ${pos.latitude}, ${pos.longitude}');


    // 1) tenta seu serviço (se ele filtra por distância)
    _subRegiao?.cancel();
    _subRegiao = CorridaService().streamCorridasDaRegiao(
      codigoRegiao: regiao,
      status: 'pendente',
      centerLat: pos.latitude,
      centerLng: pos.longitude,
      raioKm: raioKm,
    ).listen((list) async {
      if (!mounted) return;

      if (list.isNotEmpty) {
        final c = list.first.toMap();
        setState(() { _corridaId = c['id']; _corridaData = c; });
        return;
      }

      // 2) Fallback por índice: pega 1 id em pendente e busca o detalhe em corridas/{id}
      final idxSnap = await _db.child('corridas_por_regiao/$regiao/pendente')
          .limitToFirst(1).get();

      if (!idxSnap.exists) {
        setState(() { _corridaId = null; _corridaData = null; });
        // 3) Último fallback: vasculhar `corridas` pelo status antigo
        final all = await _db.child('corridas').get();
        if (all.exists) {
          for (final n in all.children) {
            final m = Map<String, dynamic>.from(n.value as Map);
            if ((m['status'] == 'buscando_motorista' || m['status'] == 'pendente') &&
                (m['codigoRegiao'] == regiao)) {
              final norm = _normalizeCorrida(m, n.key!);
              setState(() { _corridaId = n.key; _corridaData = norm; });
              return;
            }
          }
        }
        return;
      }

      final id = idxSnap.children.first.key!;
      final detalhe = await _db.child('corridas/$id').get();
      if (!detalhe.exists) return;

      final norm = _normalizeCorrida(
        Map<String, dynamic>.from(detalhe.value as Map), id,
      );
      setState(() { _corridaId = id; _corridaData = norm; });
    });
  }

  Map<String, dynamic> _normalizeCorrida(Map<String, dynamic> raw, String id) {
    // Se já estiver no formato A, devolve direto
    if (raw.containsKey('origemDescricao') && raw.containsKey('destinoDescricao')) {
      return raw..putIfAbsent('id', () => id);
    }
    // Formato B -> converte
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

    final uidMotorista = FirebaseAuth.instance.currentUser?.uid;
    if (uidMotorista == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: motorista não logado')),
      );
      return;
    }

    try {
      // 1. Atualizar no Firebase
      await FirebaseDatabase.instance.ref("corridas/$_corridaId").update({
        "status": "aceita",
        "motoristaId": uidMotorista,
        "aceitaEm": ServerValue.timestamp,
      });

      // 2. Navegar para a tela de corrida em andamento
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CorridaEmAndamentoPage(
            origem: LatLng(
              (_corridaData!['origemLat'] as num).toDouble(),
              (_corridaData!['origemLng'] as num).toDouble(),
            ),
            destino: LatLng(
              (_corridaData!['destinoLat'] as num).toDouble(),
              (_corridaData!['destinoLng'] as num).toDouble(),
            ),
            nomePassageiro: _corridaData!['passageiro'] ?? "Passageiro",
            valorCorrida: (_corridaData!['valor'] as num).toDouble(), corridaId: '',
          ),
        ),
      );
    } catch (e) {
      debugPrint("❌ Erro ao aceitar corrida: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao aceitar corrida')),
      );
    }
  }

  Future<void> _recusarCorrida() async
{
    // Marca recusa só para exemplo (poderia criar histórico de recusas)
    setState(()
{
      _corridaId = null;
      _corridaData = null;
    }
);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Corrida recusada')));
  }

  Future<void> _finalizarCorrida() async
{
    if (_corridaId == null) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final agora = DateTime.now();
    final dataHoje =
        '${agora.year}-${agora.month.toString().padLeft(2, '0')}-${agora.day.toString().padLeft(2, '0')}';
    const valorCorrida = 18.50; // Pegue o valor real do banco se houver

    // Atualiza status da corrida
    await _db.child('corridas/${_corridaId!}').update(
{
      'status': 'concluida',
      'concluidaEm': ServerValue.timestamp,
      'data': dataHoje,
    
}
);

    // Atualiza estatísticas diárias
    final refEstatisticas =
    _db.child('estatisticas_motorista/$uid/$dataHoje');
    final snap = await refEstatisticas.get();
    if (snap.exists)
{
      final dados = Map<String, dynamic>.from(snap.value as Map);
      await refEstatisticas.update(
{
        'ganhos': (dados['ganhos'] ?? 0) + valorCorrida,
        'corridas': (dados['corridas'] ?? 0) + 1,
      
}
);
    }
else
{
      await refEstatisticas.set(
{
        'ganhos': valorCorrida,
        'corridas': 1,
      
}
);
    }

    setState(()
{
      _hasActiveRide = false;
      _todayEarnings += valorCorrida;
      _todayRides += 1;
      _corridaId = null;
      _corridaData = null;
    }
);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Corrida finalizada com sucesso!'),
        backgroundColor: Colors.green,
      ),
    );
  }


  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _camera, zoom: 15),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            compassEnabled: false,
            mapToolbarEnabled: false,
            trafficEnabled: false,
            buildingsEnabled: true,
            onMapCreated: (c) => _map = c,
            markers: {
              if (_driverMarker != null) _driverMarker!,
            },
          ),

          // Exibir ETA no canto se tiver
          if (_etaText.isNotEmpty && _etaText != '--')
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 160,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Text(
                  'ETA: $_etaText',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
            ),
          // Online / Offline
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 16,
            child: GestureDetector(
              onTap: _toggleOnline,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: _isOnline ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isOnline
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: Colors.white,
                      size: 20,
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

          // ganhos dia
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Hoje', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text('R\$ ${_todayEarnings.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6A4C93))),
                  Text('$_todayRides corridas',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),

          // Bottom sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: _hasActiveRide ? _buildActiveRidePanel() : _buildWaitingPanel(),
            ),
          ),

          // Card “nova corrida”
          if (_isOnline && !_hasActiveRide && _corridaId != null && _corridaData != null)
            Positioned(
              bottom: 200,
              left: 20,
              right: 20,
              child: _buildRideRequestCard(),
            ),
        ],
      ),
    );
  }

  Widget _buildWaitingPanel()
{
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isOnline ? Colors.green[50] : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(_isOnline ? Icons.search : Icons.info_outline,
                  color: _isOnline ? Colors.green : Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isOnline
                      ? 'Procurando corridas na sua região...'
                      : 'Você está offline. Ative o modo online para receber corridas.',
                  style: TextStyle(
                      color: _isOnline ? Colors.green : Colors.grey,
                      fontWeight: _isOnline ? FontWeight.w500 : FontWeight.normal),
                ),
              ),
              if (_isOnline)
                const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _quickAction('Destino', Icons.location_on, ()
{
}
)),
            const SizedBox(width: 12),
            Expanded(child: _quickAction('Filtros', Icons.tune, ()
{
}
)),
            const SizedBox(width: 12),
            Expanded(child: _quickAction('Histórico', Icons.history, ()
{
}
)),
          ],
        ),
      ],
    );
  }

  Widget _quickAction(String title, IconData icon, VoidCallback onTap)
{
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF6A4C93)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildRideRequestCard()
{
  final origem  = _corridaData?['origemDescricao']  ?? 'Origem';
  final destino = _corridaData?['destinoDescricao'] ?? 'Destino';
  final preco   = _corridaData?['valor'] != null
      ? 'R\$ ${(_corridaData!['valor'] as num).toStringAsFixed(2)}'
      : '—';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car, color: Color(0xFFFF6600), size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nova Corrida Disponível',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Próxima de você', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              Text(
                preco,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6A4C93)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.radio_button_checked, color: Colors.green, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text('$origem')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.location_on, color: Colors.red, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text('$destino')),
          ]),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _recusarCorrida,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: const BorderSide(color: Colors.grey),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Recusar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _aceitarCorrida,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6600),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Aceitar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRidePanel()
{
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF6A4C93),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Color(0xFF6A4C93)),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('João Silva',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        Text('⭐ 4.8 • Viagem em andamento',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  Icon(Icons.phone, color: Colors.white),
                  SizedBox(width: 12),
                  Icon(Icons.chat, color: Colors.white),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Shopping Center → Aeroporto',
                        style: TextStyle(color: Colors.white)),
                  ),
                  Text('R\$ 25,50',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _finalizarCorrida,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6600),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle),
              SizedBox(width: 8),
              Text('Finalizar Corrida',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}
