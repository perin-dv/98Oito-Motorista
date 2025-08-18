import 'package:flutter/material.dart';

class AguardandoAprovacaoPage extends StatelessWidget {
  const AguardandoAprovacaoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF6A4C93),
        title: const Text(
          'Cadastro em Análise',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user,
                  color: Colors.amber, size: 80),
              const SizedBox(height: 20),
              const Text(
                'Seu cadastro foi enviado com sucesso!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Aguarde a aprovação para começar a dirigir. '
                    'Você receberá uma notificação assim que for aprovado.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A4C93),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 30, vertical: 14),
                ),
                child: const Text('Voltar ao Início'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
