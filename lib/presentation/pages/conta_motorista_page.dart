import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';

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

    try {
      final snapshot = await FirebaseDatabase.instance.ref("usuarios/$uid/nome").get();
      if (snapshot.exists && snapshot.value != null) {
        setState(() {
          _nomeMotorista = snapshot.value.toString();
        });
      } else {
        // Fallback para displayName ou email se nome não estiver no banco
        final user = FirebaseAuth.instance.currentUser;
        setState(() {
          _nomeMotorista = user?.displayName ?? 
                          user?.email?.split('@').first ?? 
                          'Motorista';
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar nome do motorista: $e');
      // Fallback em caso de erro
      final user = FirebaseAuth.instance.currentUser;
      setState(() {
        _nomeMotorista = user?.displayName ?? 
                        user?.email?.split('@').first ?? 
                        'Motorista';
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
            const Icon(
              Icons.person,
              color: Colors.white,
              size: 24,
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
        automaticallyImplyLeading: false,
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
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: const Color(0xFF6A4C93),
                        child: Text(
                          _nomeMotorista.isNotEmpty ? _nomeMotorista[0].toUpperCase() : 'M',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
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
                          style: const TextStyle(
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
                    icon: const Icon(Icons.edit, color: Color(0xFF6A4C93)),
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
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFFF6600)),
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
    _showDialog('Editar Perfil', 'Funcionalidade para editar informações pessoais do motorista.');
  }

  void _editarVeiculo() {
    _showDialog('Editar Veículo', 'Funcionalidade para alterar dados do veículo cadastrado.');
  }

  void _verDocumentosVeiculo() {
    _showDialog('Documentos do Veículo', 'Visualizar e gerenciar documentos do veículo (CRLV, seguro, etc.).');
  }

  void _verDocumento(String tipo) {
    _showDialog('Documento: $tipo', 'Visualizar e gerenciar documento: $tipo');
  }

  void _verDocumentosPessoais() {
    _showDialog('Documentos Pessoais', 'Visualizar e gerenciar RG, CPF e outros documentos pessoais.');
  }

  void _refazerValidacaoFacial() {
    Navigator.pushNamed(context, '/validacao_facial');
  }

  void _configurarSaque() {
    _showMetodosSaqueDialog();
  }

  void _verHistoricoPagamentos() {
    _showHistoricoPagamentosDialog();
  }

  void _gerarDeclaracao() {
    _showDialog('Declaração de Renda', 'Gerar comprovantes de renda para declaração do Imposto de Renda.');
  }

  void _abrirCentralAjuda() {
    _showCentralAjudaDialog();
  }

  void _falarComSuporte() {
    _showSuporteDialog();
  }

  void _reportarProblema() {
    _showDialog('Reportar Problema', 'Relatar bugs ou problemas técnicos encontrados no aplicativo.');
  }

  void _verTermos() {
    _showDialog('Termos de Uso', 'Condições de uso do aplicativo 9Oito Motorista.');
  }

  void _verPrivacidade() {
    _showDialog('Política de Privacidade', 'Como tratamos e protegemos seus dados pessoais.');
  }

  void _mostrarSobre() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info, color: Color(0xFF6A4C93)),
              SizedBox(width: 8),
              Text('Sobre o 9Oito'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('9Oito Motorista'),
              Text('Versão: 1.0.0'),
              SizedBox(height: 16),
              Text('Aplicativo para motoristas parceiros da plataforma 9Oito.'),
              SizedBox(height: 8),
              Text('Desenvolvido com Flutter e Firebase.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar', style: TextStyle(color: Color(0xFF6A4C93))),
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(context).pop();
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              child: const Text('Sair', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar', style: TextStyle(color: Color(0xFF6A4C93))),
            ),
          ],
        );
      },
    );
  }

  void _showMetodosSaqueDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.payment, color: Color(0xFF6A4C93)),
              SizedBox(width: 8),
              Text('Métodos de Saque'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: Icon(Icons.pix, color: Color(0xFFFF6600)),
                title: Text('PIX'),
                subtitle: Text('Saque instantâneo'),
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                leading: Icon(Icons.account_balance, color: Color(0xFFFF6600)),
                title: Text('Transferência Bancária'),
                subtitle: Text('1-2 dias úteis'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar', style: TextStyle(color: Color(0xFF6A4C93))),
            ),
          ],
        );
      },
    );
  }

  void _showHistoricoPagamentosDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.history, color: Color(0xFF6A4C93)),
              SizedBox(width: 8),
              Text('Histórico de Pagamentos'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('R\$ 150,00'),
                subtitle: Text('18/08/2024 - PIX'),
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('R\$ 280,50'),
                subtitle: Text('17/08/2024 - Transferência'),
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('R\$ 95,75'),
                subtitle: Text('16/08/2024 - PIX'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar', style: TextStyle(color: Color(0xFF6A4C93))),
            ),
          ],
        );
      },
    );
  }

  void _showCentralAjudaDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.help, color: Color(0xFF6A4C93)),
              SizedBox(width: 8),
              Text('Central de Ajuda'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.question_answer, color: Color(0xFFFF6600)),
                title: Text('Como aceitar corridas?'),
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                leading: Icon(Icons.question_answer, color: Color(0xFFFF6600)),
                title: Text('Como sacar meus ganhos?'),
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                leading: Icon(Icons.question_answer, color: Color(0xFFFF6600)),
                title: Text('Problemas com o GPS'),
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                leading: Icon(Icons.question_answer, color: Color(0xFFFF6600)),
                title: Text('Atualizar documentos'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar', style: TextStyle(color: Color(0xFF6A4C93))),
            ),
          ],
        );
      },
    );
  }

  void _showSuporteDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.support_agent, color: Color(0xFF6A4C93)),
              SizedBox(width: 8),
              Text('Falar com Suporte'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.chat, color: Color(0xFFFF6600)),
                title: Text('Chat Online'),
                subtitle: Text('Disponível 24h'),
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                leading: Icon(Icons.phone, color: Color(0xFFFF6600)),
                title: Text('Telefone'),
                subtitle: Text('0800-123-4567'),
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                leading: Icon(Icons.email, color: Color(0xFFFF6600)),
                title: Text('E-mail'),
                subtitle: Text('suporte@9oito.com.br'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar', style: TextStyle(color: Color(0xFF6A4C93))),
            ),
          ],
        );
      },
    );
  }
}

