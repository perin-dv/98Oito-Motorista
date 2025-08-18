import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ContaMotoristaPage extends StatefulWidget {
  const ContaMotoristaPage({super.key});

  @override
  State<ContaMotoristaPage> createState() => _ContaMotoristaPageState();
}

class _ContaMotoristaPageState extends State<ContaMotoristaPage> {
  bool _notificacoesCorridas = true;
  bool _notificacoesPromocoes = false;
  bool _modoEconomico = false;
  String _nomeMotorista = 'Carregando...';

  @override
  void initState() {
    super.initState();
    _loadMotoristaName();
  }

  Future<void> _loadMotoristaName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseDatabase.instance.ref("usuarios/$uid/nome").get();
    if (snapshot.exists && snapshot.value != null) {
      setState(() {
        _nomeMotorista = snapshot.value.toString();
      });
    }
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
              'Minha Conta',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Perfil do motorista
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Row(
                children: [
                  Stack(
                    children: [
                      const CircleAvatar(
                        radius: 40,
                        backgroundColor: Color(0xFF6A4C93),
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nomeMotorista,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Row(
                              children: List.generate(5, (index) {
                                return Icon(
                                  Icons.star,
                                  color: index < 5 ? const Color(0xFFFF6600) : Colors.grey[300],
                                  size: 16,
                                );
                              }),
                            ),
                            const SizedBox(width: 8),
                            const Text('4.9 • 1.247 corridas'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Motorista Verificado',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _editarPerfil(),
                    icon: const Icon(Icons.edit),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Veículo
            _buildSection(
              'Meu Veículo',
              [
                _buildListTile(
                  'Honda Civic 2020',
                  'Placa: ABC-1234 • Branco',
                  Icons.directions_car,
                  () => _editarVeiculo(),
                ),
                _buildListTile(
                  'Documentos do Veículo',
                  'CRLV, Seguro - Todos aprovados',
                  Icons.description,
                  () => _verDocumentosVeiculo(),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Documentos pessoais
            _buildSection(
              'Documentos',
              [
                _buildListTile(
                  'CNH',
                  'Aprovado • Vence em 12/2026',
                  Icons.credit_card,
                  () => _verDocumento('CNH'),
                ),
                _buildListTile(
                  'Documentos Pessoais',
                  'RG, CPF - Todos aprovados',
                  Icons.badge,
                  () => _verDocumentosPessoais(),
                ),
                _buildListTile(
                  'Validação Facial',
                  'Última verificação: hoje',
                  Icons.face,
                  () => _refazerValidacaoFacial(),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Configurações
            _buildSection(
              'Configurações',
              [
                _buildSwitchTile(
                  'Notificações de Corridas',
                  'Receber alertas de novas corridas',
                  Icons.notifications,
                  _notificacoesCorridas,
                  (value) {
                    setState(() {
                      _notificacoesCorridas = value;
                    });
                  },
                ),
                _buildSwitchTile(
                  'Promoções e Ofertas',
                  'Receber notificações de promoções',
                  Icons.local_offer,
                  _notificacoesPromocoes,
                  (value) {
                    setState(() {
                      _notificacoesPromocoes = value;
                    });
                  },
                ),
                _buildSwitchTile(
                  'Modo Econômico',
                  'Reduzir uso de dados móveis',
                  Icons.data_usage,
                  _modoEconomico,
                  (value) {
                    setState(() {
                      _modoEconomico = value;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Financeiro
            _buildSection(
              'Financeiro',
              [
                _buildListTile(
                  'Métodos de Saque',
                  'PIX, Transferência bancária',
                  Icons.payment,
                  () => _configurarSaque(),
                ),
                _buildListTile(
                  'Histórico de Pagamentos',
                  'Ver todos os pagamentos recebidos',
                  Icons.history,
                  () => _verHistoricoPagamentos(),
                ),
                _buildListTile(
                  'Declaração de Renda',
                  'Gerar comprovantes para IR',
                  Icons.receipt_long,
                  () => _gerarDeclaracao(),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Suporte
            _buildSection(
              'Suporte',
              [
                _buildListTile(
                  'Central de Ajuda',
                  'Perguntas frequentes e tutoriais',
                  Icons.help,
                  () => _abrirCentralAjuda(),
                ),
                _buildListTile(
                  'Falar com Suporte',
                  'Chat ou telefone 24h',
                  Icons.support_agent,
                  () => _falarComSuporte(),
                ),
                _buildListTile(
                  'Reportar Problema',
                  'Relatar bugs ou problemas técnicos',
                  Icons.bug_report,
                  () => _reportarProblema(),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Sobre
            _buildSection(
              'Sobre',
              [
                _buildListTile(
                  'Termos de Uso',
                  'Condições de uso do aplicativo',
                  Icons.description,
                  () => _verTermos(),
                ),
                _buildListTile(
                  'Política de Privacidade',
                  'Como tratamos seus dados',
                  Icons.privacy_tip,
                  () => _verPrivacidade(),
                ),
                _buildListTile(
                  'Sobre o 9Oito',
                  'Versão 1.0.0',
                  Icons.info,
                  () => _mostrarSobre(),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Botão de logout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _logout(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 8),
                      Text(
                        'Sair da Conta',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6A4C93),
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildListTile(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF6A4C93)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, IconData icon, bool value, Function(bool) onChanged) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF6A4C93)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFFFF6600),
      ),
    );
  }

  void _editarPerfil() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidade de editar perfil em desenvolvimento')),
    );
  }

  void _editarVeiculo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidade de editar veículo em desenvolvimento')),
    );
  }

  void _verDocumentosVeiculo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidade de documentos do veículo em desenvolvimento')),
    );
  }

  void _verDocumento(String tipo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Visualizando $tipo')),
    );
  }

  void _verDocumentosPessoais() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidade de documentos pessoais em desenvolvimento')),
    );
  }

  void _refazerValidacaoFacial() {
    Navigator.pushNamed(context, '/validacao_facial');
  }

  void _configurarSaque() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidade de configurar saque em desenvolvimento')),
    );
  }

  void _verHistoricoPagamentos() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidade de histórico de pagamentos em desenvolvimento')),
    );
  }

  void _gerarDeclaracao() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidade de declaração de renda em desenvolvimento')),
    );
  }

  void _abrirCentralAjuda() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidade de central de ajuda em desenvolvimento')),
    );
  }

  void _falarComSuporte() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidade de suporte em desenvolvimento')),
    );
  }

  void _reportarProblema() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidade de reportar problema em desenvolvimento')),
    );
  }

  void _verTermos() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidade de termos de uso em desenvolvimento')),
    );
  }

  void _verPrivacidade() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidade de política de privacidade em desenvolvimento')),
    );
  }

  void _mostrarSobre() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              const Text('9Oito Motorista'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Versão: 1.0.0'),
              SizedBox(height: 8),
              Text('Aplicativo para motoristas parceiros da 9Oito'),
              SizedBox(height: 8),
              Text('Desenvolvido com Flutter'),
              SizedBox(height: 8),
              Text('© 2024 9Oito - Todos os direitos reservados'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sair da Conta'),
          content: const Text('Tem certeza que deseja sair da sua conta?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/login');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Sair'),
            ),
          ],
        );
      },
    );
  }
}

