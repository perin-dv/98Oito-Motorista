import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../data/models/usuario_model.dart';
import '../../data/services/firebase_service.dart';

import '../../routes/app_routes.dart';

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final nomeController = TextEditingController();
  final cidadeController = TextEditingController();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  String tipo = 'passageiro';
  final service = FirebaseService();


  void cadastrar() async {
    try {
      // Obter posição atual
      Position posicao = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      double latitude = posicao.latitude;
      double longitude = posicao.longitude;

      // Obter dados de cidade e estado
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      String cidade = placemarks.first.locality ?? '';
      String estado = placemarks.first.administrativeArea ?? '';

      // Gerar código da região
      String codigoRegiao = '$cidade-$estado'.toLowerCase().replaceAll(' ', '_');

      // Criar objeto UsuarioModel
      final usuario = UsuarioModel(
        nome: nomeController.text,
        cidade: cidade,
        estado: estado,
        tipo: tipo,
        latitude: latitude,
        longitude: longitude,
        raioKm: 20.0, // valor fixo ou vindo de um campo do form
        codigoRegiao: codigoRegiao,
      );

      // Chamar service.cadastrar para salvar
      await service.cadastrar(
        emailController.text,
        senhaController.text,
        usuario, // aqui passamos o model completo
      );

      // Navegar para próxima tela
      Navigator.pushReplacementNamed(context, '/home');

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao cadastrar usuário: $e')),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar Conta')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListView(
          children: [
            TextField(controller: nomeController, decoration: const InputDecoration(labelText: 'Nome')),
            TextField(controller: cidadeController, decoration: const InputDecoration(labelText: 'Cidade')),
            DropdownButtonFormField(
              value: tipo,
              items: const [
                DropdownMenuItem(value: 'passageiro', child: Text('Sou Passageiro')),
                DropdownMenuItem(value: 'motorista', child: Text('Sou Motorista')),
              ],
              onChanged: (value) => setState(() => tipo = value.toString()),
              decoration: const InputDecoration(labelText: 'Tipo de conta'),
            ),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'E-mail')),
            TextField(controller: senhaController, decoration: const InputDecoration(labelText: 'Senha'), obscureText: true),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: cadastrar, child: const Text('Cadastrar')),
          ],
        ),
      ),
    );
  }
}
