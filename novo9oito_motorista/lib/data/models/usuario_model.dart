class UsuarioModel {
  final String nome;
  final String cidade;
  final String estado;
  final String tipo; // passageiro, motorista, empresa...
  final double latitude;
  final double longitude;
  final double raioKm;
  final String codigoRegiao;

  UsuarioModel({
    required this.nome,
    required this.cidade,
    required this.estado,
    required this.tipo,
    required this.latitude,
    required this.longitude,
    required this.raioKm,
    required this.codigoRegiao,
  });

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'cidade': cidade,
      'estado': estado,
      'tipo': tipo,
      'latitude': latitude,
      'longitude': longitude,
      'raio_km': raioKm,
      'codigo_regiao': codigoRegiao,
      'carteira': {},
    };
  }

}
