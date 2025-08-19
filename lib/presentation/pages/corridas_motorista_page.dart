import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../data/models/corrida_model.dart';
import 'corrida_em_andamento_page.dart';

class CorridasMotoristaPage extends StatefulWidget {
  const CorridasMotoristaPage({super.key});

  @override
  State<CorridasMotoristaPage> createState() => _CorridasMotoristaPageState();
}

class _CorridasMotoristaPageState extends State<CorridasMotoristaPage> with TickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _corridasHoje = [];


  final List<Map<String, dynamic>> _corridasSemana = [
    {
      'data': 'Segunda-feira',
      'corridas': 12,
      'ganhos': 156.80,
      'tempo': '8h 30min',
    },
    {
      'data': 'Terça-feira',
      'corridas': 15,
      'ganhos': 198.50,
      'tempo': '9h 15min',
    },
    {
      'data': 'Quarta-feira',
      'corridas': 10,
      'ganhos': 134.20,
      'tempo': '7h 45min',
    },
    {
      'data': 'Quinta-feira',
      'corridas': 14,
      'ganhos': 187.30,
      'tempo': '8h 50min',
    },
    {
      'data': 'Sexta-feira',
      'corridas': 18,
      'ganhos': 245.60,
      'tempo': '10h 20min',
    },
  ];

  @override
  void initState() {
    super.initState();
    _carregarCorridasHoje();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override

  void _carregarCorridasHoje() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final hoje = DateFormat('yyyy-MM-dd').format(DateTime.now());

    FirebaseDatabase.instance
        .ref('corridas')
        .orderByChild('motoristaId')
        .equalTo(uid)
        .onValue
        .listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        final corridasFiltradas = data.entries
            .map((e) => Map<String, dynamic>.from(e.value))
            .where((corrida) => corrida['data'] == hoje)
            .toList();

        setState(() {
          _corridasHoje = corridasFiltradas;
        });
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF6A4C93), // Roxo
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            const Text(
              'Minhas Corridas',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF6600), // Laranja
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Hoje'),
            Tab(text: 'Semana'),
            Tab(text: 'Estatísticas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHojeTab(),
          _buildSemanaTab(),
          _buildEstatisticasTab(),
        ],
      ),
    );
  }

  Widget _buildHojeTab() {
    double totalHoje = _corridasHoje.fold(0.0, (sum, corrida) => sum + corrida['valor']);

    return Column(
      children: [
        // Resumo do dia
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6A4C93), Color(0xFF8B5FBF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Text(
                'Resumo de Hoje',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildResumoItem('Corridas', '${_corridasHoje.length}', Icons.directions_car),
                  _buildResumoItem('Ganhos', 'R\$ ${totalHoje.toStringAsFixed(2)}', Icons.attach_money),
                  _buildResumoItem('Tempo', '6h 30min', Icons.access_time),
                ],
              ),
            ],
          ),
        ),

        // Lista de corridas
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _corridasHoje.length,
            itemBuilder: (context, index) {
              final corrida = _corridasHoje[index];
              return _buildCorridaCard(corrida);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSemanaTab() {
    double totalSemana = _corridasSemana.fold(0.0, (sum, dia) => sum + dia['ganhos']);
    int totalCorridas = _corridasSemana.fold(0, (sum, dia) => sum + (dia['corridas'] as int));

    return Column(
      children: [
        // Resumo da semana
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6600), Color(0xFFFF8533)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Text(
                'Resumo da Semana',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildResumoItem('Corridas', '$totalCorridas', Icons.directions_car),
                  _buildResumoItem('Ganhos', 'R\$ ${totalSemana.toStringAsFixed(2)}', Icons.attach_money),
                  _buildResumoItem('Média/dia', 'R\$ ${(totalSemana / 5).toStringAsFixed(2)}', Icons.trending_up),
                ],
              ),
            ],
          ),
        ),

        // Lista por dia
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _corridasSemana.length,
            itemBuilder: (context, index) {
              final dia = _corridasSemana[index];
              return _buildDiaCard(dia);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEstatisticasTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Avaliação geral
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'Sua Avaliação',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '4.9',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6A4C93),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      children: [
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              Icons.star,
                              color: index < 5 ? const Color(0xFFFF6600) : Colors.grey[300],
                              size: 24,
                            );
                          }),
                        ),
                        const SizedBox(height: 4),
                        const Text('Baseado em 127 avaliações'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Estatísticas gerais
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Total de Corridas', '1,247', Icons.directions_car, Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('Km Rodados', '15,832', Icons.route, Colors.green),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildStatCard('Taxa de Aceitação', '94%', Icons.check_circle, Colors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('Taxa de Cancelamento', '2%', Icons.cancel, Colors.red),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Metas
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Metas da Semana',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildMetaProgress('Corridas', 69, 80, const Color(0xFF6A4C93)),
                const SizedBox(height: 12),
                _buildMetaProgress('Ganhos', 922.40, 1000.00, const Color(0xFFFF6600)),
                const SizedBox(height: 12),
                _buildMetaProgress('Tempo Online', 44.5, 50.0, Colors.green),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCorridaCard(Map<String, dynamic> corrida) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF6A4C93),
                child: Text(
                  corrida['passageiro'].split(' ')[0][0],
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      corrida['passageiro'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              Icons.star,
                              color: index < corrida['avaliacao'] ? const Color(0xFFFF6600) : Colors.grey[300],
                              size: 16,
                            );
                          }),
                        ),
                        const SizedBox(width: 8),
                        Text('${corrida['avaliacao']}'),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'R\$ ${corrida['valor'].toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF6A4C93),
                    ),
                  ),
                  Text(
                    corrida['tempo'],
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.radio_button_checked, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(corrida['origem'], style: const TextStyle(fontSize: 12))),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(corrida['destino'], style: const TextStyle(fontSize: 12))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  corrida['distancia'],
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _mostrarDetalhesCorrida(corrida),
                child: const Text('Ver detalhes'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiaCard(Map<String, dynamic> dia) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dia['data'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text('${dia['corridas']} corridas • ${dia['tempo']}'),
              ],
            ),
          ),
          Text(
            'R\$ ${dia['ganhos'].toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF6A4C93),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMetaProgress(String title, double atual, double meta, Color color) {
    double progresso = atual / meta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('${atual.toStringAsFixed(title == 'Tempo Online' ? 1 : 0)}/${meta.toStringAsFixed(title == 'Tempo Online' ? 1 : 0)}${title == 'Ganhos' ? '' : title == 'Tempo Online' ? 'h' : ''}'),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progresso > 1.0 ? 1.0 : progresso,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }

  double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
    return 0.0;
  }

  LatLng _latLngFrom(dynamic lat, dynamic lng) =>
      LatLng(_asDouble(lat), _asDouble(lng));


  void _mostrarDetalhesCorrida(Map<String, dynamic> corrida) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Corrida #${corrida['id']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Passageiro: ${corrida['passageiro']}'),
            const SizedBox(height: 8),
            Text('Origem: ${corrida['origem']}'),
            const SizedBox(height: 8),
            Text('Destino: ${corrida['destino']}'),
            const SizedBox(height: 8),
            Text('Valor: R\$ ${corrida['valor'].toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text('Distância: ${corrida['distancia']}'),
            const SizedBox(height: 8),
            Text('Horário: ${corrida['tempo']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              final origem = _latLngFrom(
                corrida['origemLat'] ?? corrida['origem']?['lat'],
                corrida['origemLng'] ?? corrida['origem']?['lng'],
              );

              final destino = _latLngFrom(
                corrida['destinoLat'] ?? corrida['destino']?['lat'],
                corrida['destinoLng'] ?? corrida['destino']?['lng'],
              );

              final nome = (corrida['passageiroNome'] ?? corrida['nomePassageiro'] ?? 'Passageiro').toString();
              final valor = _asDouble(corrida['valor']);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CorridaEmAndamentoPage(
                    corridaId: corrida['id'],
                    origem: origem,
                    destino: destino,
                    nomePassageiro: nome,
                    valorCorrida: valor,
                  ),
                ),
              );
            },
            child: const Text('Ver detalhes'),
          )



        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

