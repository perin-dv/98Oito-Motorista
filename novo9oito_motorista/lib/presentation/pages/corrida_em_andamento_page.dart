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
  final LatLng origem;
  final LatLng destino;
  final String nomePassageiro;
  final double valorCorrida;

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
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _posicaoStream;
  Marker? _markerMotorista;
  BitmapDescriptor? _iconeCarro;

  Set<Polyline> _rotas = {};
  String _distanciaTexto = "--";
  String _tempoTexto = "--";
  double _bearingAtual = 0.0;

  bool corridaIniciada = false;

  final _db = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _carregarIconeCarro();
    _iniciarStreamLocalizacao();
  }

  Future<void> _carregarIconeCarro() async {
    final data =
    await DefaultAssetBundle.of(context).load("assets/images/carro_seta.png");
    final codec =
    await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: 100);
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    setState(() {
      _iconeCarro = BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
    });
  }

  void _iniciarStreamLocalizacao() {
    _posicaoStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((posicao) {
      if (_markerMotorista != null) {
        _bearingAtual = _calcularBearing(
          _markerMotorista!.position.latitude,
          _markerMotorista!.position.longitude,
          posicao.latitude,
          posicao.longitude,
        );
      }

      setState(() {
        _markerMotorista = Marker(
          markerId: const MarkerId("motorista"),
          position: LatLng(posicao.latitude, posicao.longitude),
          rotation: _bearingAtual,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          icon: _iconeCarro ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        );
      });

      if (corridaIniciada) {
        _mapController?.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(posicao.latitude, posicao.longitude),
            zoom: 17,
            bearing: _bearingAtual,
          ),
        ));
      }
    });
  }

  double _calcularBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * pi / 180;
    final y = sin(dLon) * cos(lat2 * pi / 180);
    final x = cos(lat1 * pi / 180) * sin(lat2 * pi / 180) -
        sin(lat1 * pi / 180) * cos(lat2 * pi / 180) * cos(dLon);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  Future<void> _desenharRota(LatLng origem, LatLng destino) async {
    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${origem.latitude},${origem.longitude}&destination=${destino.latitude},${destino.longitude}&key=$googleDirectionsApiKey&mode=driving";

    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);

    if (data["routes"].isNotEmpty) {
      final pontos =
      _decodificarPolyline(data["routes"][0]["overview_polyline"]["points"]);

      setState(() {
        _rotas = {
          Polyline(
            polylineId: const PolylineId("rota"),
            color: Colors.blueAccent,
            width: 6,
            points: pontos,
          ),
        };

        _distanciaTexto = data["routes"][0]["legs"][0]["distance"]["text"];
        _tempoTexto = data["routes"][0]["legs"][0]["duration"]["text"];
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              data["routes"][0]["bounds"]["southwest"]["lat"],
              data["routes"][0]["bounds"]["southwest"]["lng"],
            ),
            northeast: LatLng(
              data["routes"][0]["bounds"]["northeast"]["lat"],
              data["routes"][0]["bounds"]["northeast"]["lng"],
            ),
          ),
          80,
        ),
      );
    } else {
      print("Erro ao buscar rota: ${data['status']}");
    }
  }

  List<LatLng> _decodificarPolyline(String encoded) {
    List<LatLng> polylineCoords = [];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polylineCoords.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polylineCoords;
  }

  Future<void> _iniciarCorrida() async {
    setState(() => corridaIniciada = true);

    await _db.child("corridas/${widget.corridaId}").update({
      "status": "em_andamento",
      "iniciadaEm": ServerValue.timestamp,
    });

    final posicaoAtual = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
    );

    await _desenharRota(
      LatLng(posicaoAtual.latitude, posicaoAtual.longitude),
      widget.destino,
    );
  }

  Future<void> _finalizarCorrida() async {
    await _db.child("corridas/${widget.corridaId}").update({
      "status": "concluida",
      "finalizadaEm": ServerValue.timestamp,
      "valorFinal": widget.valorCorrida,
    });

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _posicaoStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition:
            CameraPosition(target: widget.origem, zoom: 15),
            markers: {
              if (_markerMotorista != null) _markerMotorista!,
              Marker(
                markerId: const MarkerId("destino"),
                position: widget.destino,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueViolet),
              ),
            },
            polylines: _rotas,
            onMapCreated: (controller) {
              _mapController = controller;
              _desenharRota(widget.origem, widget.destino);
            },
            myLocationEnabled: true,
            compassEnabled: true,
            zoomControlsEnabled: false,
          ),

          // Painel estilo Uber
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.directions_car, color: Colors.blueAccent),
                    Text("$_tempoTexto ($_distanciaTexto)",
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const Icon(Icons.navigation, color: Colors.green),
                  ],
                ),
              ),
            ),
          ),

          // Painel inferior estilo Uber
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.orange,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(widget.nomePassageiro,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      Text(
                        "R\$ ${widget.valorCorrida.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 24),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: corridaIniciada ? null : _iniciarCorrida,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text("Iniciar"),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 24),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: corridaIniciada ? _finalizarCorrida : null,
                        icon: const Icon(Icons.stop),
                        label: const Text("Finalizar"),
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
