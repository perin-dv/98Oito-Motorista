import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/usuario_model.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Future<User?> login(String email, String senha) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: senha);
    return cred.user;
  }

  Future<User?> cadastrar(String email, String senha, UsuarioModel usuario) async {
    try {
      // Criar usuário no Firebase Auth
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: senha);
      final uid = cred.user?.uid;

      if (uid != null) {
        // Salvar dados do usuário no Realtime Database
        await _db.child('usuarios').child(uid).set(usuario.toMap());
      }

      return cred.user;
    } catch (e) {
      print("❌ Erro ao cadastrar: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getPerfilAtual() async {
    final uid = usuarioAtual?.uid;
    if (uid == null) return null;

    final snap = await _db.child('usuarios').child(uid).get();
    if (!snap.exists) return null;

    return Map<String, dynamic>.from(snap.value as Map);
  }

  User? get usuarioAtual => _auth.currentUser;

  Future<void> logout() async {
    await _auth.signOut();
  }
}
