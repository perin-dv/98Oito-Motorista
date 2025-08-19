import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'mapa_motorista_page.dart';
import 'corridas_motorista_page.dart';
import 'carteira_motorista_page.dart';
import 'conta_motorista_page.dart';

class MainScreenMotorista extends StatefulWidget {
  const MainScreenMotorista({super.key});

  @override
  State<MainScreenMotorista> createState() => _MainScreenMotoristaState();
}

class _MainScreenMotoristaState extends State<MainScreenMotorista> {
  int _currentIndex = 0;
  String _userName = 'Carregando...';

  final List<Widget> _pages = [
    const MapaMotoristaPage(),
    const CorridasMotoristaPage(),
    const CarteiraMotoristaPage(),
    const ContaMotoristaPage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snapshot = await FirebaseDatabase.instance.ref('usuarios/$uid/nome').get();
      if (snapshot.exists && snapshot.value != null) {
        setState(() {
          _userName = snapshot.value.toString();
        });
      } else {
        // Fallback para displayName ou email se nome não estiver no banco
        final user = FirebaseAuth.instance.currentUser;
        setState(() {
          _userName = user?.displayName ?? 
                     user?.email?.split('@').first ?? 
                     'Motorista';
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar nome do usuário: $e');
      // Fallback em caso de erro
      final user = FirebaseAuth.instance.currentUser;
      setState(() {
        _userName = user?.displayName ?? 
                   user?.email?.split('@').first ?? 
                   'Motorista';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Removendo AppBar para evitar duplicação de nome
      body: SafeArea(
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            selectedItemColor: const Color(0xFFFF6600), // Laranja
            unselectedItemColor: Colors.grey,
            elevation: 0,
            selectedFontSize: 12,
            unselectedFontSize: 10,
            items: [
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.map,
                    color: _currentIndex == 0 ? const Color(0xFFFF6600) : Colors.grey,
                    size: 24,
                  ),
                ),
                label: 'Mapa',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.directions_car,
                    color: _currentIndex == 1 ? const Color(0xFFFF6600) : Colors.grey,
                    size: 24,
                  ),
                ),
                label: 'Corridas',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: _currentIndex == 2 ? const Color(0xFFFF6600) : Colors.grey,
                    size: 24,
                  ),
                ),
                label: 'Carteira',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.person,
                    color: _currentIndex == 3 ? const Color(0xFFFF6600) : Colors.grey,
                    size: 24,
                  ),
                ),
                label: 'Conta',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

