import 'package:flutter/material.dart';

class CarteiraMotoristaPage extends StatefulWidget {
  const CarteiraMotoristaPage({super.key});

  @override
  State<CarteiraMotoristaPage> createState() => _CarteiraMotoristaPageState();
}

class _CarteiraMotoristaPageState extends State<CarteiraMotoristaPage> with TickerProviderStateMixin {
  late TabController _tabController;
  
  double _saldoDisponivel = 347.80;
  double _saldoPendente = 89.50;
  double _totalSemana = 922.40;
  
  final List<Map<String, dynamic>> _transacoes = [
    {
      'tipo': 'ganho',
      'descricao': 'Corrida #1247',
      'valor': 18.50,
      'data': '2024-08-03 18:30',
      'status': 'concluido',
    },
    {
      'tipo': 'ganho',
      'descricao': 'Corrida #1246',
      'valor': 25.00,
      'data': '2024-08-03 17:45',
      'status': 'concluido',
    },
    {
      'tipo': 'saque',
      'descricao': 'Saque PIX',
      'valor': -200.00,
      'data': '2024-08-03 14:20',
      'status': 'concluido',
    },
    {
      'tipo': 'ganho',
      'descricao': 'Corrida #1245',
      'valor': 32.80,
      'data': '2024-08-03 13:15',
      'status': 'concluido',
    },
    {
      'tipo': 'taxa',
      'descricao': 'Taxa de serviço',
      'valor': -3.70,
      'data': '2024-08-03 12:00',
      'status': 'concluido',
    },
  ];

  final List<Map<String, dynamic>> _relatorioSemanal = [
    {'dia': 'Segunda', 'ganhos': 156.80, 'corridas': 12},
    {'dia': 'Terça', 'ganhos': 198.50, 'corridas': 15},
    {'dia': 'Quarta', 'ganhos': 134.20, 'corridas': 10},
    {'dia': 'Quinta', 'ganhos': 187.30, 'corridas': 14},
    {'dia': 'Sexta', 'ganhos': 245.60, 'corridas': 18},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
              'Minha Carteira',
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
            Tab(text: 'Saldo'),
            Tab(text: 'Histórico'),
            Tab(text: 'Relatórios'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSaldoTab(),
          _buildHistoricoTab(),
          _buildRelatoriosTab(),
        ],
      ),
    );
  }

  Widget _buildSaldoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Card de saldo principal
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6A4C93), Color(0xFF8B5FBF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6A4C93).withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Saldo Disponível',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'R\$ ${_saldoDisponivel.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pendente: R\$ ${_saldoPendente.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Ações rápidas
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Sacar',
                  Icons.money,
                  const Color(0xFFFF6600), // Laranja
                  () => _mostrarDialogSaque(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Extrato',
                  Icons.receipt_long,
                  Colors.blue,
                  () => _gerarExtrato(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Ajuda',
                  Icons.help_outline,
                  Colors.grey,
                  () => _mostrarAjuda(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Resumo da semana
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
                  'Resumo da Semana',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildResumoItem('Total Ganho', 'R\$ ${_totalSemana.toStringAsFixed(2)}', Icons.trending_up, Colors.green),
                    _buildResumoItem('Média/Dia', 'R\$ ${(_totalSemana / 5).toStringAsFixed(2)}', Icons.calendar_today, Colors.blue),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildResumoItem('Corridas', '69', Icons.directions_car, const Color(0xFF6A4C93)),
                    _buildResumoItem('Taxa Média', '15%', Icons.percent, Colors.orange),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Metas financeiras
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
                  'Meta Mensal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildMetaProgress('R\$ 3.680,00', 'R\$ 4.000,00', 0.92),
                const SizedBox(height: 12),
                const Text(
                  'Faltam R\$ 320,00 para atingir sua meta!',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Dicas financeiras
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(
                      'Dica Financeira',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Seus ganhos estão 23% acima da média desta semana! Continue assim para bater sua meta mensal.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricoTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _transacoes.length,
      itemBuilder: (context, index) {
        final transacao = _transacoes[index];
        return _buildTransacaoCard(transacao);
      },
    );
  }

  Widget _buildRelatoriosTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Gráfico semanal simulado
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
                  'Ganhos da Semana',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 200,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: _relatorioSemanal.map((dia) {
                      double altura = (dia['ganhos'] / 250) * 150; // Normalizar altura
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'R\$ ${dia['ganhos'].toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 10),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 30,
                            height: altura,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6A4C93),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            dia['dia'].substring(0, 3),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Comparativo mensal
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
                  'Comparativo Mensal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildComparativoItem('Este Mês', 'R\$ 3.680,00', '+23%', Colors.green),
                const SizedBox(height: 12),
                _buildComparativoItem('Mês Anterior', 'R\$ 2.990,00', '-5%', Colors.red),
                const SizedBox(height: 12),
                _buildComparativoItem('Média 3 Meses', 'R\$ 3.220,00', '+14%', Colors.blue),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Botões de relatório
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _gerarRelatorioMensal(),
                  icon: const Icon(Icons.file_download),
                  label: const Text('Relatório Mensal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A4C93),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _gerarRelatorioAnual(),
                  icon: const Icon(Icons.analytics),
                  label: const Text('Relatório Anual'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6600),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
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
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumoItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildMetaProgress(String atual, String meta, double progresso) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(atual, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(meta, style: const TextStyle(color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progresso,
          backgroundColor: Colors.grey[300],
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6A4C93)),
        ),
      ],
    );
  }

  Widget _buildTransacaoCard(Map<String, dynamic> transacao) {
    IconData icon;
    Color iconColor;
    
    switch (transacao['tipo']) {
      case 'ganho':
        icon = Icons.add_circle;
        iconColor = Colors.green;
        break;
      case 'saque':
        icon = Icons.remove_circle;
        iconColor = Colors.red;
        break;
      case 'taxa':
        icon = Icons.remove_circle_outline;
        iconColor = Colors.orange;
        break;
      default:
        icon = Icons.help;
        iconColor = Colors.grey;
    }

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
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transacao['descricao'],
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  transacao['data'],
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${transacao['valor'] > 0 ? '+' : ''}R\$ ${transacao['valor'].toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: transacao['valor'] > 0 ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparativoItem(String periodo, String valor, String variacao, Color cor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(periodo, style: const TextStyle(fontWeight: FontWeight.w500)),
        Row(
          children: [
            Text(valor, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                variacao,
                style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _mostrarDialogSaque() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sacar Dinheiro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Saldo disponível: R\$ ${_saldoDisponivel.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Valor do saque',
                prefixText: 'R\$ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            const Text(
              'O valor será transferido via PIX em até 1 hora.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saque solicitado com sucesso!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6600),
            ),
            child: const Text('Sacar'),
          ),
        ],
      ),
    );
  }

  void _gerarExtrato() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gerando extrato... Será enviado por email.')),
    );
  }

  void _mostrarAjuda() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidade de ajuda em desenvolvimento')),
    );
  }

  void _gerarRelatorioMensal() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gerando relatório mensal...')),
    );
  }

  void _gerarRelatorioAnual() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gerando relatório anual...')),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

