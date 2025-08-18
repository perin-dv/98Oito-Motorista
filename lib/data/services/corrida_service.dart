import 'dart:async';
import 'dart:math' show sin, cos, sqrt, asin, pi;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/corrida_model.dart';

class CorridaService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // Distância entre 2 pontos em KM (Haversine)
  double _distanciaKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * asin(sqrt(a));
    return r * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180.0);

  /// Cria corrida para o passageiro logado.
  Future<void> criarCorrida({
    required String origemDescricao,
    required double origemLat,
    required double origemLng,
    required String destinoDescricao,
    required double destinoLat,
    required double destinoLng,
    required String codigoRegiao,
  }) async {
    if (_uid == null) throw Exception('Usuário não logado');

    final id = _db.child('corridas_por_usuario').child(_uid!).push().key!;
    final now = DateTime.now().millisecondsSinceEpoch;

    double valor = 35.0;
    final user = _auth.currentUser;

    final corrida = CorridaModel(
      id: id,
      passageiroUid: _uid!,
      passageiroNome: user?.displayName ?? 'Passageiro', // 🔹 agora salva nome
      motoristaUid: null,
      origemDescricao: origemDescricao,
      origemLat: origemLat,
      origemLng: origemLng,
      destinoDescricao: destinoDescricao,
      destinoLat: destinoLat,
      destinoLng: destinoLng,
      status: 'pendente',
      codigoRegiao: codigoRegiao,
      criadoEm: now,
      valor: valor,
    );

    final updates = <String, Object?>{};
    updates['corridas_por_usuario/${_uid!}/$id'] = corrida.toMap();
    updates['corridas_por_regiao/$codigoRegiao/pendente/$id'] = corrida.toMap();
    updates['corridas/$id'] = corrida.toMap(); // 🔹 nó global

    await _db.update(updates);
  }

  /// Registra/atualiza estatística diária
  Future<void> _registrarEstatisticaDiaria({
    required String motoristaUid,
    required double valorCorrida,
  }) async {
    final hoje = DateTime.now();
    final data =
        '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}';

    final ref =
    _db.child('estatisticas_motorista').child(motoristaUid).child(data);

    final snap = await ref.get();
    if (snap.exists) {
      final atual = Map<String, dynamic>.from(snap.value as Map);
      await ref.update({
        'corridas': (atual['corridas'] ?? 0) + 1,
        'ganhos': ((atual['ganhos'] ?? 0) as num).toDouble() + valorCorrida,
      });
    } else {
      await ref.set({
        'corridas': 1,
        'ganhos': valorCorrida,
      });
    }
  }

  /// Atualiza status (e move entre nós de região + nós globais)
  Future<void> atualizarStatus({
    required CorridaModel corrida,
    required String novoStatus, // aceito | em_andamento | concluido | cancelado
    String? motoristaUid,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final atualizado = CorridaModel(
      id: corrida.id,
      passageiroUid: corrida.passageiroUid,
      passageiroNome: corrida.passageiroNome,
      motoristaUid: motoristaUid ?? corrida.motoristaUid,
      origemDescricao: corrida.origemDescricao,
      origemLat: corrida.origemLat,
      origemLng: corrida.origemLng,
      destinoDescricao: corrida.destinoDescricao,
      destinoLat: corrida.destinoLat,
      destinoLng: corrida.destinoLng,
      status: novoStatus,
      codigoRegiao: corrida.codigoRegiao,
      criadoEm: corrida.criadoEm,
      atualizadoEm: now,
      valor: corrida.valor,
    );

    final updates = <String, Object?>{};
    // remove da categoria antiga
    updates[
    'corridas_por_regiao/${corrida.codigoRegiao}/${corrida.status}/${corrida.id}'] = null;
    // adiciona na nova categoria
    updates[
    'corridas_por_regiao/${corrida.codigoRegiao}/$novoStatus/${corrida.id}'] = atualizado.toMap();
    // visão do passageiro
    updates['corridas_por_usuario/${corrida.passageiroUid}/${corrida.id}'] =
        atualizado.toMap();
    // nó global
    updates['corridas/${corrida.id}'] = atualizado.toMap();

    await _db.update(updates);

    // se concluído, registra estatística
    if (novoStatus == 'concluido' && atualizado.motoristaUid != null) {
      await _registrarEstatisticaDiaria(
        motoristaUid: atualizado.motoristaUid!,
        valorCorrida: atualizado.valor,
      );
    }
  }

  Stream<List<CorridaModel>> streamMinhasCorridas() {
    if (_uid == null) {
      return const Stream.empty();
    }
    final ref = _db.child('corridas_por_usuario').child(_uid!);
    return ref.onValue.map((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        return data.values
            .whereType<Map>()
            .map((m) => CorridaModel.fromMap(Map<String, dynamic>.from(m)))
            .toList()
          ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
      }
      return <CorridaModel>[];
    });
  }

  Stream<List<CorridaModel>> streamCorridasDaRegiao({
    required String codigoRegiao,
    required String status,
    required double centerLat,
    required double centerLng,
    required double raioKm,
  }) {
    final ref =
    _db.child('corridas_por_regiao').child(codigoRegiao).child(status);
    return ref.onValue.map((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        final todas = data.values
            .whereType<Map>()
            .map((m) => CorridaModel.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        final filtradas = todas.where((c) {
          final d =
          _distanciaKm(centerLat, centerLng, c.origemLat, c.origemLng);
          return d <= raioKm;
        }).toList()
          ..sort((a, b) => a.criadoEm.compareTo(b.criadoEm));
        return filtradas;
      }
      return <CorridaModel>[];
    });
  }

  Future<void> seedCorridasParaUsuarioLogado({
    required String codigoRegiao,
    int quantidade = 3,
    required double baseLat,
    required double baseLng,
  }) async {
    if (_uid == null) throw Exception('Usuário não logado para seed');

    for (int i = 0; i < quantidade; i++) {
      final lat = baseLat + (i * 0.0028);
      final lng = baseLng + (i * 0.0031);

      await criarCorrida(
        origemDescricao: 'Ponto $i - Origem',
        origemLat: lat,
        origemLng: lng,
        destinoDescricao: 'Destino $i',
        destinoLat: lat + 0.01,
        destinoLng: lng + 0.01,
        codigoRegiao: codigoRegiao,
      );
    }
  }
}
