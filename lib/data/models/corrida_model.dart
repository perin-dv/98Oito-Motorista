class CorridaModel {
  final String id;
  final String passageiroUid;
  final String? passageiroNome; // 🔹 nome do passageiro (opcional)
  final String? motoristaUid;
  final String origemDescricao;
  final double origemLat;
  final double origemLng;
  final String destinoDescricao;
  final double destinoLat;
  final double destinoLng;

  /// pendente | aceito | em_andamento | concluido | cancelado
  final String status;

  /// Ex: SP_Capital, RJ_Baixada, etc.
  final String codigoRegiao;

  /// timestamp em ms
  final int criadoEm;
  final int? atualizadoEm;

  /// Valor final da corrida (em reais)
  final double valor;

  CorridaModel({
    required this.id,
    required this.passageiroUid,
    this.passageiroNome,
    this.motoristaUid,
    required this.origemDescricao,
    required this.origemLat,
    required this.origemLng,
    required this.destinoDescricao,
    required this.destinoLat,
    required this.destinoLng,
    required this.status,
    required this.codigoRegiao,
    required this.criadoEm,
    this.atualizadoEm,
    required this.valor,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'passageiroUid': passageiroUid,
      'passageiroNome': passageiroNome,
      'motoristaUid': motoristaUid,
      'origemDescricao': origemDescricao,
      'origemLat': origemLat,
      'origemLng': origemLng,
      'destinoDescricao': destinoDescricao,
      'destinoLat': destinoLat,
      'destinoLng': destinoLng,
      'status': status,
      'codigoRegiao': codigoRegiao,
      'criadoEm': criadoEm,
      'atualizadoEm': atualizadoEm,
      'valor': valor,
    };
  }

  factory CorridaModel.fromMap(Map<dynamic, dynamic> map) {
    return CorridaModel(
      id: map['id']?.toString() ?? '',
      passageiroUid: map['passageiroUid']?.toString() ?? '',
      passageiroNome: map['passageiroNome']?.toString(),
      motoristaUid: map['motoristaUid']?.toString(),
      origemDescricao: map['origemDescricao']?.toString() ?? '',
      origemLat: (map['origemLat'] as num?)?.toDouble() ?? 0.0,
      origemLng: (map['origemLng'] as num?)?.toDouble() ?? 0.0,
      destinoDescricao: map['destinoDescricao']?.toString() ?? '',
      destinoLat: (map['destinoLat'] as num?)?.toDouble() ?? 0.0,
      destinoLng: (map['destinoLng'] as num?)?.toDouble() ?? 0.0,
      status: map['status']?.toString() ?? '',
      codigoRegiao: map['codigoRegiao']?.toString() ?? '',
      criadoEm: (map['criadoEm'] as num?)?.toInt() ?? 0,
      atualizadoEm: (map['atualizadoEm'] as num?)?.toInt(),
      valor: (map['valor'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
