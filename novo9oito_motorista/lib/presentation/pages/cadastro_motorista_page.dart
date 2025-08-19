import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'validacao_facial_page.dart';

class CadastroMotoristaPage extends StatefulWidget {
  const CadastroMotoristaPage({super.key});

  @override
  State<CadastroMotoristaPage> createState() => _CadastroMotoristaPageState();
}

class _CadastroMotoristaPageState extends State<CadastroMotoristaPage> {
  final _formKey = GlobalKey<FormState>();

  // Dados pessoais
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _cpfController = TextEditingController();
  final _cnhController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  // Veículo
  final _marcaVeiculoController = TextEditingController();
  final _modeloVeiculoController = TextEditingController();
  final _anoVeiculoController = TextEditingController();
  final _placaVeiculoController = TextEditingController();
  final _corVeiculoController = TextEditingController();

  // Categoria de serviço
  String _categoriaServico = '99Pop';
  final List<String> _categoriasDisponiveis = ['99Pop', 'Executivo'];

  bool _isLoading = false;
  int _currentStep = 0;

  // Controle do status dos documentos
  final Map<String, String> _statusDocumentos = {
    "cnh": "pendente",
    "rg": "pendente",
    "comprovante": "pendente",
    "foto_perfil": "pendente",
    "crlv": "pendente"
  };

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    _cpfController.dispose();
    _cnhController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    _marcaVeiculoController.dispose();
    _modeloVeiculoController.dispose();
    _anoVeiculoController.dispose();
    _placaVeiculoController.dispose();
    _corVeiculoController.dispose();
    super.dispose();
  }

  Future<void> _uploadDocument(String tipo) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? foto =
      await picker.pickImage(source: ImageSource.camera, imageQuality: 80);

      if (foto == null) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Faça login antes de enviar documentos")),
        );
        return;
      }

      final storageRef = FirebaseStorage.instance
          .ref()
          .child("documentos_motorista/${user.uid}/$tipo.jpg");

      await storageRef.putFile(File(foto.path));
      final url = await storageRef.getDownloadURL();

      await FirebaseDatabase.instance
          .ref()
          .child("usuarios/${user.uid}/documentos/$tipo")
          .set(url);

      setState(() {
        _statusDocumentos[tipo] = "enviado";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Documento enviado com sucesso")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao enviar documento: $e")),
      );
    }
  }

  void _avancarStep(StepperType type, int index) {
    if (_currentStep == 0 && !_formKey.currentState!.validate()) return;
    setState(() {
      _currentStep = _currentStep + 1;
    });
  }

  Future<void> _finalizarCadastro() async {
    if (!_formKey.currentState!.validate()) return;
    if (_senhaController.text != _confirmarSenhaController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('As senhas não conferem')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1) Auth
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _senhaController.text.trim(),
      );
      final uid = cred.user!.uid;

      // 2) Payload base
      final dadosMotorista = {
        "nome": _nomeController.text.trim(),
        "email": _emailController.text.trim(),
        "telefone": _telefoneController.text.trim(),
        "cpf": _cpfController.text.trim(),
        "cnh": _cnhController.text.trim(),
        "tipo": "motorista",
        "status": "pendente_aprovacao",
        "categoriaServico": _categoriaServico, // Adicionando categoria
        "veiculo": {
          "marca": _marcaVeiculoController.text.trim(),
          "modelo": _modeloVeiculoController.text.trim(),
          "ano": _anoVeiculoController.text.trim(),
          "placa": _placaVeiculoController.text.trim(),
          "cor": _corVeiculoController.text.trim(),
          "categoria": _categoriaServico, // Categoria também no veículo
        },
        "documentos": {
          "cnh": "pendente",
          "rg": "pendente",
          "comprovante": "pendente",
          "foto_perfil": "pendente",
          "crlv": "pendente",
        },
        "carteira": {},
      };

      final db = FirebaseDatabase.instance.ref();

      // 3) Escreve perfil + índice de pendência (mesma base)
      await db.update({
        "usuarios/$uid": dadosMotorista,
        "motoristasPendentes/$uid": {
          ...dadosMotorista,
          "enviadosEm": ServerValue.timestamp,
        },
        // não cria "motoristas/$uid" ainda — só quando for aprovado
      });

      // 4) Validação facial
      final ok = await Navigator.pushNamed<bool>(context, '/validacao_facial');
      if (ok == true) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/aguardando_aprovacao');
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Validação facial não concluída')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF6A4C93),
        title: const Text("Cadastro Motorista",
            style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: (_currentStep + 1) / 4,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFFF6600)),
                  ),
                ),
                const SizedBox(width: 12),
                Text("Passo ${_currentStep + 1} de 4",
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, color: Color(0xFF6A4C93))),
              ],
            ),
          ),
          Expanded(
            child: Stepper(
              currentStep: _currentStep,
              onStepTapped: (step) {
                if (step > _currentStep) {
                  if (!_formKey.currentState!.validate()) return;
                }
                setState(() => _currentStep = step);
              },
              onStepContinue: () {
                if (_currentStep == 3) {
                  _finalizarCadastro();
                } else {
                  if (_currentStep == 0 && !_formKey.currentState!.validate()) {
                    return;
                  }
                  setState(() => _currentStep++);
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() => _currentStep--);
                }
              },
              controlsBuilder: (context, details) {
                return Row(
                  children: [
                    ElevatedButton(
                      onPressed: details.onStepContinue,
                      child: Text(_currentStep == 3 ? "Finalizar" : "Continuar"),
                    ),
                    if (_currentStep > 0)
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: const Text("Voltar"),
                      ),
                  ],
                );
              },
              steps: [
                Step(
                  title: const Text("Dados Pessoais"),
                  content: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _campoTexto(_nomeController, "Nome Completo",
                            Icons.person),
                        _campoTexto(_emailController, "Email", Icons.email,
                            tipo: TextInputType.emailAddress, email: true),
                        _campoTexto(_telefoneController, "Telefone", Icons.phone,
                            tipo: TextInputType.phone),
                        _campoTexto(_cpfController, "CPF", Icons.badge,
                            tipo: TextInputType.number),
                        _campoTexto(_cnhController, "CNH", Icons.credit_card,
                            tipo: TextInputType.number),
                        _campoTexto(_senhaController, "Senha", Icons.lock,
                            senha: true, min: 6),
                        _campoTexto(_confirmarSenhaController,
                            "Confirmar Senha", Icons.lock,
                            senha: true, min: 6),
                      ],
                    ),
                  ),
                  isActive: _currentStep >= 0,
                ),
                Step(
                  title: const Text("Documentos"),
                  content: Column(
                    children: [
                      _buildDocumentCard(
                          "CNH", "Foto da frente da CNH", Icons.credit_card, "cnh"),
                      _buildDocumentCard("RG", "Foto da frente do RG",
                          Icons.badge, "rg"),
                      _buildDocumentCard(
                          "Comprovante", "Conta recente", Icons.home, "comprovante"),
                      _buildDocumentCard("Foto de Perfil", "Selfie",
                          Icons.camera_alt, "foto_perfil"),
                    ],
                  ),
                  isActive: _currentStep >= 1,
                ),
                Step(
                  title: const Text("Veículo"),
                  content: Column(
                    children: [
                      // Categoria de serviço
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.orange),
                                const SizedBox(width: 8),
                                const Text(
                                  'Categoria de Serviço',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _categoriaServico,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: _categoriasDisponiveis.map((categoria) {
                                return DropdownMenuItem(
                                  value: categoria,
                                  child: Row(
                                    children: [
                                      Icon(
                                        categoria == '99Pop' 
                                            ? Icons.directions_car 
                                            : Icons.business_center,
                                        color: categoria == '99Pop' 
                                            ? Colors.orange 
                                            : const Color(0xFF6A4C93),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            categoria,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            categoria == '99Pop' 
                                                ? 'Corridas econômicas' 
                                                : 'Corridas premium',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _categoriaServico = value!;
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _categoriaServico == '99Pop'
                                  ? '• Corridas com preço acessível\n• Veículos populares aceitos\n• Maior volume de corridas'
                                  : '• Corridas premium com preço diferenciado\n• Veículos de luxo ou seminovos\n• Passageiros executivos',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      _campoTexto(_marcaVeiculoController, "Marca do Veículo",
                          Icons.directions_car),
                      _campoTexto(_modeloVeiculoController, "Modelo do Veículo",
                          Icons.directions_car),
                      _campoTexto(_anoVeiculoController, "Ano do Veículo",
                          Icons.calendar_today,
                          tipo: TextInputType.number),
                      _campoTexto(_placaVeiculoController, "Placa do Veículo",
                          Icons.confirmation_number),
                      _campoTexto(_corVeiculoController, "Cor do Veículo",
                          Icons.palette),
                      _buildDocumentCard("CRLV", "Documento do veículo",
                          Icons.description, "crlv"),
                    ],
                  ),
                  isActive: _currentStep >= 2,
                ),
                Step(
                  title: const Text("Validação"),
                  content: const Text(
                      "Seus documentos serão analisados em até 24 horas."),
                  isActive: _currentStep >= 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoTexto(TextEditingController controller, String label,
      IconData icon,
      {TextInputType tipo = TextInputType.text,
        bool email = false,
        bool senha = false,
        int min = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: senha,
        keyboardType: tipo,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Preencha este campo';
          if (value.length < min) return 'Mínimo de $min caracteres';
          if (email && !value.contains('@')) return 'E-mail inválido';
          return null;
        },
      ),
    );
  }

  Widget _buildDocumentCard(
      String title, String subtitle, IconData icon, String tipo) {
    final status = _statusDocumentos[tipo] ?? "pendente";
    return Card(
      child: ListTile(
        leading: Icon(icon,
            color: status == "enviado" ? Colors.green : const Color(0xFFFF6600)),
        title: Text(title),
        subtitle: Text(status == "enviado" ? "Enviado com sucesso" : subtitle),
        trailing: const Icon(Icons.camera_alt),
        onTap: () => _uploadDocument(tipo),
      ),
    );
  }
}
