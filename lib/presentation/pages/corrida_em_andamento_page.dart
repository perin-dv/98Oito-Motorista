import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';

class CorridaEmAndamentoPage extends StatefulWidget {
  final String corridaId;
  final LatLng origem;            // origem (ponto inicial do motorista)
  final LatLng destino;           // destino da corrida
  final String nomePassageiro;    // exibir no card
  final double valorCorrida;      // exibir no card

  const CorridaEmAndamentoPage({
    Key? key,
    required this.corridaId,
    required this.origem,
    required this.destino,
    required this.nomePassageiro,
    required this.valorCorrida,
  }) : super(key: key);

  @override
  State<CorridaEmAndamentoPage> createState() => _CorridaEmAndamentoPageState();
}

class _CorridaEmAndamentoPageState extends State<CorridaEmAndamentoPage> {
  final _db = FirebaseDatabase.instance.ref();

  GoogleMapController? _map;
  StreamSubscription<Position>? _locStream;

  Marker? _mkMotorista;
  Marker? _mkDestino;
  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _destinationIcon;

  Set<Polyline> _polylines = {};
  String _tempoTexto = "--";
  String _distTexto = "--";
  String _proximaInstrucao = "Iniciando navegação...";
  String _nomeRua = "";
  String _proximaRua = "";

  bool _corridaIniciada = false;
  double _bearing = 0;
  LatLng? _currentPosition;
  double _currentSpeed = 0; // km/h

  // Distância e tempo restantes
  double _distanciaRestanteKm = 0.0;
  int _tempoRestanteMinutos = 0;

  // Timer para atualização em tempo real
  Timer? _updateTimer;

  // ================== LIFECYCLE ==================
  @override
  void initState() {
    super.initState();
    _loadIcons();
    _startLocationStream();
    _startUpdateTimer();
    _setupInitialRoute();
  }

  @override
  void dispose() {
    _locStream?.cancel();
    _updateTimer?.cancel();
    super.dispose();
  }

  // ================== ICONS & LOCATION ==================
  Future<void> _loadIcons() async {
    try {
      // Tentar carregar ícone personalizado do carro
      try {
        final data = await rootBundle.load('assets/images/car_icon.png');
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
          targetWidth: 60,
        );
        final frame = await codec.getNextFrame();
        final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes != null) {
          setState(() {
            _carIcon = BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
          });
        }
      } catch (e) {
        debugPrint('Ícone personalizado não encontrado, usando padrão: $e');
        setState(() {
          _carIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
        });
      }

      // Ícone do destino
      setState(() {
        _destinationIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      });
    } catch (e) {
      debugPrint('Erro ao carregar ícones: $e');
      setState(() {
        _carIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
        _destinationIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      });
    }
  }

  void _startLocationStream() {
    _locStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3, // Atualizar a cada 3 metros
      ),
    ).listen((pos) {
      final newPos = LatLng(pos.latitude, pos.longitude);
      final newBearing = pos.heading.isNaN ? _bearing : pos.heading;
      final newSpeed = pos.speed * 3.6; // m/s para km/h

      setState(() {
        _currentPosition = newPos;
        _bearing = newBearing;
        _currentSpeed = newSpeed;

        // Atualizar marker do motorista com rotação
        _mkMotorista = Marker(
          markerId: const MarkerId('motorista'),
          position: newPos,
          icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          rotation: _bearing,
          anchor: const Offset(0.5, 0.5),
          flat: true,
        );
      });

      // Atualizar câmera para seguir o motorista APENAS SE A CORRIDA FOI INICIADA
      if (_corridaIniciada && _map != null) {
        _map!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: newPos,
              zoom: 18,
              bearing: _bearing,
              tilt: 60, // Visão 3D estilo Waze
            ),
          ),
        );
      }

      // Atualizar distância e tempo
      _updateDistanceAndTime();
      _updateNavigationInstruction();
    });
  }

  void _startUpdateTimer() {
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_currentPosition != null) {
        _updateDistanceAndTime();
      }
    });
  }

  // ================== ROTA E NAVEGAÇÃO ==================
  Future<void> _setupInitialRoute() async {
    // Obter localização atual
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      _currentPosition = LatLng(pos.latitude, pos.longitude);
      _bearing = pos.heading.isNaN ? 0 : pos.heading;
      _currentSpeed = pos.speed * 3.6; // m/s para km/h
    } catch (e) {
      debugPrint('Erro ao obter localização: $e');
      _currentPosition = widget.origem; // usar origem como fallback
    }

    // Criar linha reta da origem ao destino
    _createStraightRoute();

    // Calcular distância e tempo inicial
    _updateDistanceAndTime();

    // Ajustar câmera para mostrar a rota
    if (!_corridaIniciada) {
      _fitRouteInView();
    }
  }

  void _createStraightRoute() {
    final origem = _currentPosition ?? widget.origem;

    setState(() {
      // Criar polyline (linha reta da origem ao destino)
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: [origem, widget.destino],
          color: const Color(0xFF00BFFF), // Azul ciano estilo Waze
          width: 8,
          patterns: [],
        ),
      };

      // Criar marker de destino
      _mkDestino = Marker(
        markerId: const MarkerId('destino'),
        position: widget.destino,
        icon: _destinationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Destino',
          snippet: widget.nomePassageiro,
        ),
      );

      // Criar marker do motorista
      _mkMotorista = Marker(
        markerId: const MarkerId('motorista'),
        position: origem,
        icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        rotation: _bearing,
        anchor: const Offset(0.5, 0.5),
        flat: true,
      );
    });
  }

  void _fitRouteInView() {
    if (_map == null) return;

    final origem = _currentPosition ?? widget.origem;
    final destino = widget.destino;

    final bounds = LatLngBounds(
      southwest: LatLng(
        min(origem.latitude, destino.latitude),
        min(origem.longitude, destino.longitude),
      ),
      northeast: LatLng(
        max(origem.latitude, destino.latitude),
        max(origem.longitude, destino.longitude),
      ),
    );

    _map!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100.0),
    );
  }

  void _updateDistanceAndTime() {
    if (_currentPosition == null) return;

    // Calcular distância restante até o destino
    final distanceToDestination = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      widget.destino.latitude,
      widget.destino.longitude,
    );

    final distanceKm = distanceToDestination / 1000;
    // Estimar tempo baseado na velocidade atual ou velocidade média urbana
    final avgSpeed = _currentSpeed > 5 ? _currentSpeed : 25; // usar velocidade atual se > 5 km/h
    final estimatedTimeMinutes = (distanceKm / avgSpeed * 60).round();

    setState(() {
      _distanciaRestanteKm = distanceKm;
      _tempoRestanteMinutos = estimatedTimeMinutes;

      _distTexto = distanceKm < 1
          ? '${distanceToDestination.round()}m'
          : '${distanceKm.toStringAsFixed(1)}km';

      _tempoTexto = estimatedTimeMinutes < 60
          ? '${estimatedTimeMinutes}min'
          : '${(estimatedTimeMinutes / 60).toStringAsFixed(1)}h';
    });

    // Verificar se chegou ao destino (menos de 30 metros)
    if (distanceToDestination < 30 && _corridaIniciada) {
      _finalizarCorrida();
    }
  }

  void _updateNavigationInstruction() {
    if (_currentPosition == null || !_corridaIniciada) {
      setState(() {
        _proximaInstrucao = "Clique em 'Iniciar' para começar a navegação";
        _nomeRua = "";
        _proximaRua = "";
      });
      return;
    }

    // Calcular direção para o destino
    final bearing = Geolocator.bearingBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      widget.destino.latitude,
      widget.destino.longitude,
    );

    // Converter bearing para direção cardinal
    String direction = _bearingToDirection(bearing);
    String turnInstruction = _bearingToTurnInstruction(bearing);

    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      widget.destino.latitude,
      widget.destino.longitude,
    );

    setState(() {
      _nomeRua = "Rua Atual"; // Placeholder - em produção seria obtido via geocoding
      _proximaRua = "Destino";

      if (distance < 100) {
        _proximaInstrucao = "Você chegou ao destino!";
      } else if (distance < 500) {
        _proximaInstrucao = "Continue em frente por ${distance.round()}m";
      } else {
        _proximaInstrucao = "$turnInstruction em ${(distance/1000).toStringAsFixed(1)}km";
      }
    });
  }

  String _bearingToDirection(double bearing) {
    // Normalizar bearing para 0-360
    bearing = bearing < 0 ? bearing + 360 : bearing;

    if (bearing >= 337.5 || bearing < 22.5) return "norte";
    if (bearing >= 22.5 && bearing < 67.5) return "nordeste";
    if (bearing >= 67.5 && bearing < 112.5) return "leste";
    if (bearing >= 112.5 && bearing < 157.5) return "sudeste";
    if (bearing >= 157.5 && bearing < 202.5) return "sul";
    if (bearing >= 202.5 && bearing < 247.5) return "sudoeste";
    if (bearing >= 247.5 && bearing < 292.5) return "oeste";
    if (bearing >= 292.5 && bearing < 337.5) return "noroeste";
    return "em frente";
  }

  String _bearingToTurnInstruction(double bearing) {
    // Normalizar bearing para 0-360
    bearing = bearing < 0 ? bearing + 360 : bearing;

    if (bearing >= 315 || bearing < 45) return "Continue em frente";
    if (bearing >= 45 && bearing < 135) return "Vire à direita";
    if (bearing >= 135 && bearing < 225) return "Faça o retorno";
    if (bearing >= 225 && bearing < 315) return "Vire à esquerda";
    return "Continue em frente";
  }

  void _iniciarCorrida() {
    setState(() {
      _corridaIniciada = true;
    });

    // Mudar para modo navegação (seguir motorista)
    if (_currentPosition != null && _map != null) {
      _map!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentPosition!,
            zoom: 18,
            bearing: _bearing,
            tilt: 60, // Visão 3D estilo Waze
          ),
        ),
      );
    }

    // Atualizar instrução
    _updateNavigationInstruction();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Corrida iniciada! Siga as instruções de navegação.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _cancelarCorrida() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Corrida'),
        content: const Text('Tem certeza que deseja cancelar esta corrida?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Não'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Fechar dialog
              Navigator.of(context).pop(); // Voltar para o mapa
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sim, Cancelar'),
          ),
        ],
      ),
    );
  }

  void _finalizarCorrida() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Corrida Finalizada!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Passageiro: ${widget.nomePassageiro}'),
            Text('Valor: R\$ ${widget.valorCorrida.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            const Text('Corrida finalizada com sucesso!'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Fechar dialog
              Navigator.of(context).pop(); // Voltar para o mapa
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6600),
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _centerOnDriver() {
    if (_currentPosition != null && _map != null) {
      _map!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentPosition!,
            zoom: 18,
            bearing: _bearing,
            tilt: _corridaIniciada ? 60 : 0, // 3D apenas quando iniciada
          ),
        ),
      );
    }
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // MAPA
          GoogleMap(
            onMapCreated: (controller) {
              _map = controller;
              // Aplicar estilo escuro estilo Waze
              _map?.setMapStyle('''
              [
                {
                  "elementType": "geometry",
                  "stylers": [{"color": "#242f3e"}]
                },
                {
                  "elementType": "labels.text.stroke",
                  "stylers": [{"color": "#242f3e"}]
                },
                {
                  "elementType": "labels.text.fill",
                  "stylers": [{"color": "#746855"}]
                },
                {
                  "featureType": "administrative.locality",
                  "elementType": "labels.text.fill",
                  "stylers": [{"color": "#d59563"}]
                },
                {
                  "featureType": "poi",
                  "elementType": "labels.text.fill",
                  "stylers": [{"color": "#d59563"}]
                },
                {
                  "featureType": "poi.park",
                  "elementType": "geometry",
                  "stylers": [{"color": "#263c3f"}]
                },
                {
                  "featureType": "poi.park",
                  "elementType": "labels.text.fill",
                  "stylers": [{"color": "#6b9a76"}]
                },
                {
                  "featureType": "road",
                  "elementType": "geometry",
                  "stylers": [{"color": "#38414e"}]
                },
                {
                  "featureType": "road",
                  "elementType": "geometry.stroke",
                  "stylers": [{"color": "#212a37"}]
                },
                {
                  "featureType": "road",
                  "elementType": "labels.text.fill",
                  "stylers": [{"color": "#9ca5b3"}]
                },
                {
                  "featureType": "road.highway",
                  "elementType": "geometry",
                  "stylers": [{"color": "#746855"}]
                },
                {
                  "featureType": "road.highway",
                  "elementType": "geometry.stroke",
                  "stylers": [{"color": "#1f2835"}]
                },
                {
                  "featureType": "road.highway",
                  "elementType": "labels.text.fill",
                  "stylers": [{"color": "#f3d19c"}]
                },
                {
                  "featureType": "transit",
                  "elementType": "geometry",
                  "stylers": [{"color": "#2f3948"}]
                },
                {
                  "featureType": "transit.station",
                  "elementType": "labels.text.fill",
                  "stylers": [{"color": "#d59563"}]
                },
                {
                  "featureType": "water",
                  "elementType": "geometry",
                  "stylers": [{"color": "#17263c"}]
                },
                {
                  "featureType": "water",
                  "elementType": "labels.text.fill",
                  "stylers": [{"color": "#515c6d"}]
                },
                {
                  "featureType": "water",
                  "elementType": "labels.text.stroke",
                  "stylers": [{"color": "#17263c"}]
                }
              ]
              ''');
            },
            initialCameraPosition: CameraPosition(
              target: widget.origem,
              zoom: 15,
            ),
            markers: {
              if (_mkMotorista != null) _mkMotorista!,
              if (_mkDestino != null) _mkDestino!,
            },
            polylines: _polylines, // LINHA DA ROTA
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // HEADER ESTILO WAZE PROFISSIONAL
          if (_corridaIniciada)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.9),
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // HEADER PRINCIPAL ESTILO WAZE
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Column(
                            children: [
                              // LINHA SUPERIOR: SETA + DISTÂNCIA + TEMPO
                              Row(
                                children: [
                                  // SETA DE DIREÇÃO
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00BFFF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.straight,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),

                                  const SizedBox(width: 16),

                                  // DISTÂNCIA
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _distTexto,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          _proximaRua.isNotEmpty ? _proximaRua : "Destino",
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.8),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // TEMPO E VELOCIDADE
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _tempoTexto,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${_currentSpeed.round()} km/h',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // INSTRUÇÃO DE NAVEGAÇÃO
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _proximaInstrucao,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // CARD DE INFORMAÇÕES DA CORRIDA (INFERIOR)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Informações do Passageiro
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFF6A4C93),
                            radius: 25,
                            child: Text(
                              widget.nomePassageiro.isNotEmpty
                                  ? widget.nomePassageiro[0].toUpperCase()
                                  : 'P',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.nomePassageiro,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      _corridaIniciada ? Icons.navigation : Icons.schedule,
                                      size: 16,
                                      color: _corridaIniciada ? Colors.green : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _corridaIniciada ? 'Corrida em andamento' : 'Aguardando início',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _corridaIniciada ? Colors.green : Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Valor da corrida
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6600), Color(0xFFFF8533)],
                              ),
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF6600).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              'R\$ ${widget.valorCorrida.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Botões de Ação (ESTILO MODERNO)
                      Row(
                        children: [
                          // Botão de Cancelar
                          Expanded(
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.red, Color(0xFFFF4444)],
                                ),
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _cancelarCorrida,
                                icon: const Icon(Icons.cancel, color: Colors.white),
                                label: const Text(
                                  'Cancelar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Botão de Iniciar
                          Expanded(
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _corridaIniciada
                                      ? [Colors.grey, Colors.grey.shade600]
                                      : [Colors.green, const Color(0xFF4CAF50)],
                                ),
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_corridaIniciada ? Colors.grey : Colors.green).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _corridaIniciada ? null : _iniciarCorrida,
                                icon: Icon(
                                  _corridaIniciada ? Icons.navigation : Icons.play_arrow,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  _corridaIniciada ? 'Em Andamento' : 'Iniciar',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
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
              ),
            ),
          ),

          // BOTÃO DE CENTRALIZAR NO MOTORISTA (ESTILO WAZE)
          Positioned(
            bottom: 200,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6600), Color(0xFFFF8533)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6600).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: FloatingActionButton(
                mini: true,
                onPressed: _centerOnDriver,
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: const Icon(
                  Icons.my_location,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

