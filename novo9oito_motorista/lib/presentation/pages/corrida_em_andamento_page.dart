import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;

import 'package:novo9oito_motorista/utils/constants.dart';

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
  String _proximaInstrucao = "Calculando rota...";

  bool _iniciada = false;
  double _bearing = 0;
  LatLng? _currentPosition;

  // Dados da rota atual
  List<LatLng> _routePoints = [];
  int _currentStepIndex = 0;
  List<Map<String, dynamic>> _steps = [];

  // Timer para atualização em tempo real
  Timer? _updateTimer;

  // Distância e tempo restantes
  double _distanciaRestanteKm = 0.0;
  int _tempoRestanteMinutos = 0;

  // ================== LIFECYCLE ==================
  @override
  void initState() {
    super.initState();
    _loadIcons();
    _startLocationStream();
    _startUpdateTimer();
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
      // Ícone do carro
      final carData = await DefaultAssetBundle.of(context).load('assets/images/arrow_icon.png');
      final carCodec = await ui.instantiateImageCodec(carData.buffer.asUint8List(), targetWidth: 96);
      final carFrame = await carCodec.getNextFrame();
      final carBytes = await carFrame.image.toByteData(format: ui.ImageByteFormat.png);

      if (mounted && carBytes != null) {
        setState(() {
          _carIcon = BitmapDescriptor.fromBytes(carBytes.buffer.asUint8List());
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar ícones: $e');
      // Fallback para ícones padrão
      setState(() {
        _carIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
        _destinationIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      });
    }
  }

  void _startLocationStream() {
    _locStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3, // Atualizar a cada 3 metros
      ),
    ).listen((pos) {
      final latLng = LatLng(pos.latitude, pos.longitude);
      _currentPosition = latLng;

      // Calcular bearing baseado na direção do movimento
      if (_mkMotorista != null) {
        _bearing = _calcBearing(
          _mkMotorista!.position.latitude,
          _mkMotorista!.position.longitude,
          latLng.latitude,
          latLng.longitude,
        );
      }

      setState(() {
        _mkMotorista = Marker(
          markerId: const MarkerId('motorista'),
          position: latLng,
          icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          rotation: _bearing,
          anchor: const Offset(0.5, 0.5),
          flat: true,
        );

        _mkDestino = Marker(
          markerId: const MarkerId('destino'),
          position: widget.destino,
          icon: _destinationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Destino',
            snippet: 'Ponto de chegada',
          ),
        );
      });

      // Durante a corrida, a câmera acompanha o carro
      if (_iniciada && _map != null) {
        _map!.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
            target: latLng,
            zoom: 18,
            bearing: _bearing,
            tilt: 45, // Visão 3D para melhor navegação
          ),
        ));

        // Atualizar navegação em tempo real
        _updateNavigation(latLng);
      }
    });
  }

  void _startUpdateTimer() {
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_iniciada && _currentPosition != null) {
        _updateRouteInfo();
      }
    });
  }

  double _calcBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * pi / 180.0;
    final y = sin(dLon) * cos(lat2 * pi / 180.0);
    final x = cos(lat1 * pi / 180.0) * sin(lat2 * pi / 180.0) -
        sin(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) * cos(dLon);
    return (atan2(y, x) * 180.0 / pi + 360.0) % 360.0;
  }

  // ================== NAVEGAÇÃO EM TEMPO REAL ==================
  void _updateNavigation(LatLng currentPos) {
    if (_routePoints.isEmpty || _steps.isEmpty) return;

    // Encontrar o ponto mais próximo na rota
    double minDistance = double.infinity;
    int closestPointIndex = 0;

    for (int i = 0; i < _routePoints.length; i++) {
      final distance = Geolocator.distanceBetween(
        currentPos.latitude,
        currentPos.longitude,
        _routePoints[i].latitude,
        _routePoints[i].longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestPointIndex = i;
      }
    }

    // Atualizar step atual baseado na posição
    _updateCurrentStep(closestPointIndex);

    // Calcular distância e tempo restantes
    _calculateRemainingDistanceAndTime(currentPos);
  }

  void _updateCurrentStep(int pointIndex) {
    // Lógica para determinar qual step estamos baseado no ponto da rota
    // Esta é uma implementação simplificada
    final progress = pointIndex / _routePoints.length;
    final stepIndex = (progress * _steps.length).floor();

    if (stepIndex != _currentStepIndex && stepIndex < _steps.length) {
      setState(() {
        _currentStepIndex = stepIndex;
        _proximaInstrucao = _steps[stepIndex]['html_instructions'] ?? 'Continue em frente';
        // Remover tags HTML da instrução
        _proximaInstrucao = _proximaInstrucao.replaceAll(RegExp(r'<[^>]*>'), '');
      });
    }
  }

  void _calculateRemainingDistanceAndTime(LatLng currentPos) {
    // Calcular distância restante até o destino
    final distanceToDestination = Geolocator.distanceBetween(
      currentPos.latitude,
      currentPos.longitude,
      widget.destino.latitude,
      widget.destino.longitude,
    );

    setState(() {
      _distanciaRestanteKm = distanceToDestination / 1000;
      // Estimar tempo baseado em velocidade média de 30 km/h no trânsito urbano
      _tempoRestanteMinutos = ((distanceToDestination / 1000) / 30 * 60).round();

      _distTexto = _distanciaRestanteKm < 1
          ? '${(distanceToDestination).round()} m'
          : '${_distanciaRestanteKm.toStringAsFixed(1)} km';

      _tempoTexto = _tempoRestanteMinutos < 60
          ? '$_tempoRestanteMinutos min'
          : '${(_tempoRestanteMinutos / 60).floor()}h ${_tempoRestanteMinutos % 60}min';
    });
  }

  // ================== ROUTE (Directions API) ==================
  Future<void> _desenharRota(LatLng origem, LatLng destino) async {
    final url =
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origem.latitude},${origem.longitude}'
        '&destination=${destino.latitude},${destino.longitude}'
        '&mode=driving'
        '&alternatives=false'
        '&key=${AppConstants.googleDirectionsApiKey}';

    try {
      final res = await http.get(Uri.parse(url));
      final json = jsonDecode(res.body);

      if (json['status'] != 'OK') {
        debugPrint('Directions status: ${json['status']} | url=$url');
        return;
      }

      final route = json['routes'][0];
      final leg = route['legs'][0];

      final pts = _decodePolyline(route['overview_polyline']['points'] as String);

      // Salvar pontos da rota e steps para navegação
      _routePoints = pts;
      _steps = List<Map<String, dynamic>>.from(leg['steps']);

      setState(() {
        _tempoTexto = leg['duration']['text'];
        _distTexto = leg['distance']['text'];
        _polylines = {
          Polyline(
            polylineId: const PolylineId('rota'),
            width: 8,
            color: Colors.orange, // Mudando para laranja conforme solicitado
            points: pts,
            patterns: [], // Linha sólida para melhor visibilidade
          ),
        };
      });

      // Ajustar zoom para mostrar a rota completa inicialmente
      if (!_iniciada) {
        final sw = LatLng(route['bounds']['southwest']['lat'], route['bounds']['southwest']['lng']);
        final ne = LatLng(route['bounds']['northeast']['lat'], route['bounds']['northeast']['lng']);
        _map?.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 100));
      }
    } catch (e) {
      debugPrint('Erro ao buscar rota: $e | url=$url');
    }
  }

  Future<void> _updateRouteInfo() async {
    if (_currentPosition == null) return;

    // Atualizar rota com posição atual
    await _desenharRota(_currentPosition!, widget.destino);
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do { b = encoded.codeUnitAt(index++) - 63; result |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
      final dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0; result = 0;
      do { b = encoded.codeUnitAt(index++) - 63; result |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
      final dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  // ================== AÇÕES ==================
  Future<void> _iniciarCorrida() async {
    setState(() => _iniciada = true);

    await _db.child('corridas/${widget.corridaId}').update({
      'status': 'em_andamento',
      'iniciadaEm': ServerValue.timestamp,
    });

    // Desenhar rota do ponto atual até o destino
    if (_currentPosition != null) {
      await _desenharRota(_currentPosition!, widget.destino);
    } else {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.bestForNavigation);
      await _desenharRota(LatLng(pos.latitude, pos.longitude), widget.destino);
    }
  }

  Future<void> _finalizarCorrida() async {
    await _db.child('corridas/${widget.corridaId}').update({
      'status': 'concluida',
      'finalizadaEm': ServerValue.timestamp,
      'valorFinal': widget.valorCorrida,
    });
    if (mounted) Navigator.pop(context);
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapa principal
          GoogleMap(
            initialCameraPosition: CameraPosition(target: widget.origem, zoom: 15),
            onMapCreated: (c) {
              _map = c;
              // Ao abrir a tela já traça a rota de origem->destino (pré-visualização)
              _desenharRota(widget.origem, widget.destino);
            },
            myLocationEnabled: false, // Usar nosso marker personalizado
            zoomControlsEnabled: false,
            compassEnabled: false,
            trafficEnabled: true, // Mostrar trânsito
            buildingsEnabled: true,
            markers: {
              if (_mkMotorista != null) _mkMotorista!,
              if (_mkDestino != null) _mkDestino!,
            },
            polylines: _polylines,
            mapType: MapType.normal,
          ),

          // Header com navegação estilo Waze/Uber
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Card(
              elevation: 12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: const Color(0xFF6A4C93), // Roxo do padrão
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Tempo e distância grandes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.access_time, color: Colors.white, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          _tempoTexto,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.straighten, color: Colors.white, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          _distTexto,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    if (_iniciada) ...[
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white30),
                      const SizedBox(height: 8),
                      // Próxima instrução
                      Row(
                        children: [
                          Icon(Icons.navigation, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _proximaInstrucao,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Botão de centralizar no motorista
          if (_iniciada)
            Positioned(
              top: MediaQuery.of(context).padding.top + 200,
              right: 16,
              child: FloatingActionButton(
                mini: true,
                onPressed: () {
                  if (_currentPosition != null && _map != null) {
                    _map!.animateCamera(CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: _currentPosition!,
                        zoom: 18,
                        bearing: _bearing,
                        tilt: 45,
                      ),
                    ));
                  }
                },
                backgroundColor: Colors.white,
                child: const Icon(Icons.my_location, color: Colors.orange), // Laranja do padrão
              ),
            ),

          // Bottom sheet estilo Uber
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 15,
                    offset: Offset(0, -5),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Indicador de arrastar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Informações do passageiro
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.orange.withOpacity(0.2), // Laranja claro
                        radius: 24,
                        child: const Icon(Icons.person, color: Color(0xFF6A4C93), size: 28), // Roxo
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.nomePassageiro,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Corrida ${_iniciada ? "em andamento" : "aceita"}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'R\$ ${widget.valorCorrida.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Botões de ação
                  Row(
                    children: [
                      // Botão de contato
                      Expanded(
                        flex: 1,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // Implementar chamada/mensagem
                          },
                          icon: const Icon(Icons.phone),
                          label: const Text('Ligar'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Botão principal
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _iniciada ? Colors.red : Colors.orange, // Laranja quando não iniciada
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          onPressed: _iniciada ? _finalizarCorrida : _iniciarCorrida,
                          icon: Icon(_iniciada ? Icons.stop : Icons.play_arrow),
                          label: Text(
                            _iniciada ? 'Finalizar Corrida' : 'Iniciar Corrida',
                            style: const TextStyle(
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
            ),
          ),
        ],
      ),
    );
  }
}

