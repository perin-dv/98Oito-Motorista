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

    final snapshot = await FirebaseDatabase.instance.ref('usuarios/$uid/nome').get();
    if (snapshot.exists && snapshot.value != null) {
      setState(() {
        _userName = snapshot.value.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFFF6600), // Laranja
        unselectedItemColor: Colors.grey,
        elevation: 8,
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.map,
              color: _currentIndex == 0 ? const Color(0xFFFF6600) : Colors.grey,
            ),
            label: 'Mapa',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.directions_car,
              color: _currentIndex == 1 ? const Color(0xFFFF6600) : Colors.grey,
            ),
            label: 'Corridas',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.account_balance_wallet,
              color: _currentIndex == 2 ? const Color(0xFFFF6600) : Colors.grey,
            ),
            label: 'Carteira',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.person,
              color: _currentIndex == 3 ? const Color(0xFFFF6600) : Colors.grey,
            ),
            label: 'Conta',
          ),
        ],
      ),
    );
  }
}

