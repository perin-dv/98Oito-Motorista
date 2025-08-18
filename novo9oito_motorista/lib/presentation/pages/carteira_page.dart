import 'package:flutter/material.dart';

class CarteiraPage extends StatefulWidget {
  const CarteiraPage({super.key});

  @override
  State<CarteiraPage> createState() => _CarteiraPageState();
}

class _CarteiraPageState extends State<CarteiraPage> {
  double _saldo = 125.50;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2B3C), // Azul escuro
        title: const Text(
          'Carteira',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card do saldo
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6600), Color(0xFFFF8533)], // Gradiente laranja
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6600).withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        size: 32,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Saldo Disponível',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'R\$ ${_saldo.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Última atualização: agora',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Botões de ação
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'Adicionar',
                    Icons.add,
                    const Color(0xFF1A2B3C), // Azul escuro
                    () {
                      _showAddFundsDialog();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'Transferir',
                    Icons.send,
                    Colors.grey[600]!,
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Funcionalidade em desenvolvimento')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'Histórico',
                    Icons.history,
                    Colors.grey[600]!,
                    () {
                      // Scroll para a seção de histórico
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Seção de histórico
            const Text(
              'Histórico de Transações',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A2B3C), // Azul escuro
              ),
            ),
            const SizedBox(height: 16),

            // Lista de transações
            _buildTransactionItem(
              'Corrida para Shopping Center',
              'Hoje, 14:30',
              -25.50,
              Icons.directions_car,
            ),
            _buildTransactionItem(
              'Recarga de saldo',
              'Ontem, 09:15',
              50.00,
              Icons.add_circle,
            ),
            _buildTransactionItem(
              'Corrida para Aeroporto',
              'Ontem, 18:45',
              -35.80,
              Icons.directions_car,
            ),
            _buildTransactionItem(
              'Corrida para Centro',
              '2 dias atrás, 12:20',
              -18.90,
              Icons.directions_car,
            ),
            _buildTransactionItem(
              'Recarga de saldo',
              '3 dias atrás, 16:00',
              100.00,
              Icons.add_circle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color),
        ),
        elevation: 2,
      ),
      child: Column(
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(String title, String date, double amount, IconData icon) {
    bool isPositive = amount > 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isPositive ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isPositive ? Colors.green : Colors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isPositive ? '+' : ''}R\$ ${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddFundsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String selectedAmount = '20.00';
        
        return AlertDialog(
          title: const Text('Adicionar Saldo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Selecione o valor para adicionar:'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: ['20.00', '50.00', '100.00', '200.00'].map((amount) {
                  return ChoiceChip(
                    label: Text('R\$ $amount'),
                    selected: selectedAmount == amount,
                    onSelected: (selected) {
                      if (selected) {
                        selectedAmount = amount;
                      }
                    },
                    selectedColor: const Color(0xFFFF6600).withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: selectedAmount == amount ? const Color(0xFFFF6600) : Colors.black,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _saldo += double.parse(selectedAmount);
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('R\$ $selectedAmount adicionado com sucesso!')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6600),
                foregroundColor: Colors.white,
              ),
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
  }
}

