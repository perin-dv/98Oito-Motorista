class CorridaModel {
  final String id;
  final String passageiroUid;
  final String? passageiroNome; // ✅ novo campo
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
    this.passageiroNome, // ✅ agora pode salvar o nome
    required this.motoristaUid,
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
      'passageiroNome': passageiroNome, // ✅ salva no Firebase
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
      id: map['id'] as String,
      passageiroUid: map['passageiroUid'] as String,
      passageiroNome: map['passageiroNome'] as String?, // ✅ lê do Firebase
      motoristaUid: map['motoristaUid'] as String?,
      origemDescricao: map['origemDescricao'] as String,
      origemLat: (map['origemLat'] as num).toDouble(),
      origemLng: (map['origemLng'] as num).toDouble(),
      destinoDescricao: map['destinoDescricao'] as String,
      destinoLat: (map['destinoLat'] as num).toDouble(),
      destinoLng: (map['destinoLng'] as num).toDouble(),
      status: map['status'] as String,
      codigoRegiao: map['codigoRegiao'] as String,
      criadoEm: map['criadoEm'] as int,
      atualizadoEm: map['atualizadoEm'] as int?,
      valor: (map['valor'] as num).toDouble(),
    );
  }
}
