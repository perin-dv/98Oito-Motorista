import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class HistoricoCorridasPage extends StatefulWidget {
  const HistoricoCorridasPage({super.key});

  @override
  State<HistoricoCorridasPage> createState() => _HistoricoCorridasPageState();
}

class _HistoricoCorridasPageState extends State<HistoricoCorridasPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance.ref();
  
  List<Map<String, dynamic>> _corridas = [];
  bool _isLoading = true;
  String _filtroSelecionado = 'todas'; // todas, concluidas, canceladas
  
  @override
  void initState() {
    super.initState();
    _carregarHistorico();
  }

  Future<void> _carregarHistorico() async {
    setState(() => _isLoading = true);
    
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Buscar corridas do motorista
      final snapshot = await _db
          .child('corridas')
          .orderByChild('motoristaUid')
          .equalTo(uid)
          .get();

      if (!snapshot.exists) {
        setState(() {
          _corridas = [];
          _isLoading = false;
        });
        return;
      }

      final List<Map<String, dynamic>> corridasTemp = [];
      
      for (final child in snapshot.children) {
        final data = Map<String, dynamic>.from(child.value as Map);
        data['id'] = child.key;
        
        // Normalizar dados
        final corrida = _normalizarCorrida(data);
        corridasTemp.add(corrida);
      }

      // Ordenar por data (mais recente primeiro)
      corridasTemp.sort((a, b) {
        final dateA = DateTime.tryParse(a['criadoEm'] ?? '') ?? DateTime.now();
        final dateB = DateTime.tryParse(b['criadoEm'] ?? '') ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      setState(() {
        _corridas = corridasTemp;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar histórico: $e');
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _normalizarCorrida(Map<String, dynamic> data) {
    // Normalizar origem
    final origem = data['origem'] ?? {};
    final origemLat = origem['lat'] ?? data['origemLat'];
    final origemLng = origem['lng'] ?? data['origemLng'];
    final origemEndereco = origem['endereco'] ?? data['origemDescricao'] ?? 'Origem não informada';

    // Normalizar destino
    final destino = data['destino'] ?? {};
    final destinoLat = destino['lat'] ?? data['destinoLat'];
    final destinoLng = destino['lng'] ?? data['destinoLng'];
    final destinoEndereco = destino['endereco'] ?? data['destinoDescricao'] ?? 'Destino não informado';

    // Normalizar valor
    double valor = 0.0;
    if (data['valor'] is num) {
      valor = data['valor'].toDouble();
    } else if (data['valor'] is String) {
      valor = double.tryParse(data['valor'].replaceAll(',', '.')) ?? 0.0;
    }

    return {
      'id': data['id'],
      'status': data['status'] ?? 'desconhecido',
      'criadoEm': data['criadoEm'] ?? data['timestamp'] ?? DateTime.now().toIso8601String(),
      'finalizadoEm': data['finalizadoEm'],
      'valor': valor,
      'distancia': data['distancia'] ?? 0.0,
      'duracao': data['duracao'] ?? 0,
      'origemEndereco': origemEndereco,
      'destinoEndereco': destinoEndereco,
      'passageiroNome': data['passageiroNome'] ?? data['nomePassageiro'] ?? 'Passageiro',
      'avaliacao': data['avaliacao'] ?? 0,
      'comentario': data['comentario'] ?? '',
      'metodoPagamento': data['metodoPagamento'] ?? 'Dinheiro',
    };
  }

  List<Map<String, dynamic>> get _corridasFiltradas {
    switch (_filtroSelecionado) {
      case 'concluidas':
        return _corridas.where((c) => c['status'] == 'concluida').toList();
      case 'canceladas':
        return _corridas.where((c) => c['status'] == 'cancelada').toList();
      default:
        return _corridas;
    }
  }

  String _formatarData(String? dataStr) {
    if (dataStr == null || dataStr.isEmpty) return 'Data não informada';
    
    try {
      final data = DateTime.parse(dataStr);
      return DateFormat('dd/MM/yyyy HH:mm').format(data);
    } catch (e) {
      return 'Data inválida';
    }
  }

  String _formatarDuracao(dynamic duracao) {
    if (duracao == null) return '--';
    
    int minutos = 0;
    if (duracao is int) {
      minutos = duracao;
    } else if (duracao is String) {
      minutos = int.tryParse(duracao) ?? 0;
    }
    
    if (minutos == 0) return '--';
    
    final horas = minutos ~/ 60;
    final mins = minutos % 60;
    
    if (horas > 0) {
      return '${horas}h ${mins}min';
    } else {
      return '${mins}min';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'concluida':
        return Colors.green;
      case 'cancelada':
        return Colors.red;
      case 'em_andamento':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'concluida':
        return 'Concluída';
      case 'cancelada':
        return 'Cancelada';
      case 'em_andamento':
        return 'Em Andamento';
      case 'pendente':
        return 'Pendente';
      default:
        return 'Desconhecido';
    }
  }

  Widget _buildCorridaCard(Map<String, dynamic> corrida) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header com status e data
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(corrida['status']),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(corrida['status']),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  _formatarData(corrida['criadoEm']),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Origem e Destino
            Row(
              children: [
                const Icon(Icons.radio_button_checked, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    corrida['origemEndereco'],
                    style: const TextStyle(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 4),
            
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    corrida['destinoEndereco'],
                    style: const TextStyle(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Informações da corrida
            Row(
              children: [
                // Valor
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Valor',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'R\$ ${corrida['valor'].toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Duração
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Duração',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _formatarDuracao(corrida['duracao']),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Passageiro
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Passageiro',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        corrida['passageiroNome'],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Avaliação (se houver)
            if (corrida['avaliacao'] > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Avaliação: ',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < corrida['avaliacao'] ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 16,
                      );
                    }),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${corrida['avaliacao']}/5',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6A4C93),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6A4C93),
        foregroundColor: Colors.white,
        title: const Text(
          'Histórico de Corridas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarHistorico,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildFiltroButton('Todas', 'todas'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFiltroButton('Concluídas', 'concluidas'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFiltroButton('Canceladas', 'canceladas'),
                ),
              ],
            ),
          ),
          
          // Lista de corridas
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6A4C93),
                      ),
                    )
                  : _corridasFiltradas.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Nenhuma corrida encontrada',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Suas corridas aparecerão aqui',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _carregarHistorico,
                          color: const Color(0xFF6A4C93),
                          child: ListView.builder(
                            padding: const EdgeInsets.only(top: 16, bottom: 16),
                            itemCount: _corridasFiltradas.length,
                            itemBuilder: (context, index) {
                              return _buildCorridaCard(_corridasFiltradas[index]);
                            },
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroButton(String texto, String valor) {
    final isSelected = _filtroSelecionado == valor;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filtroSelecionado = valor;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
          ),
        ),
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? const Color(0xFF6A4C93) : Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

