import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get user => _auth.currentUser;
  AppUser? profile;

  Future<String?> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      final p = await _fetchOrCreateProfile(cred.user!);
      if (p == null) {
        await _auth.signOut();
        return 'هذا الحساب غير مسجل في النظام. اسأل المدير عن إضافته.';
      }
      profile = p;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'لا يوجد حساب بهذا البريد';
        case 'wrong-password':
        case 'invalid-credential':
          return 'كلمة المرور غير صحيحة';
        case 'invalid-email':
          return 'البريد الإلكتروني غير صالح';
        case 'network-request-failed':
          return 'لا يوجد اتصال بالإنترنت';
        default:
          return 'خطأ في الدخول: ${e.code}';
      }
    } catch (e) {
      return 'خطأ غير متوقع: $e';
    }
  }

  Future<AppUser?> _fetchOrCreateProfile(User u) async {
    final doc = await _db.collection('users').doc(u.uid).get();
    if (doc.exists) {
      return AppUser.fromMap(u.uid, doc.data()!);
    }
    // أول حساب يدخل النظام يصبح المدير (bootstrap) — بعده لا يُقبل إلا من أنشأه المدير
    final mgr = await _db
        .collection('users')
        .where('role', isEqualTo: 'manager')
        .limit(1)
        .get();
    if (mgr.docs.isEmpty) {
      final name = u.email?.split('@').first ?? 'المدير';
      final p = AppUser(uid: u.uid, name: name, role: 'manager');
      await _db.collection('users').doc(u.uid).set(p.toMap());
      return p;
    }
    return null;
  }

  Future<void> signOut() async {
    profile = null;
    await _auth.signOut();
    notifyListeners();
  }

  Future<void> restore() async {
    final u = _auth.currentUser;
    if (u != null) {
      final doc = await _db.collection('users').doc(u.uid).get();
      if (doc.exists) {
        profile = AppUser.fromMap(u.uid, doc.data()!);
        notifyListeners();
      }
    }
  }
}
