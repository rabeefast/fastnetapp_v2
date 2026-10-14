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
        return 'هذا الحساب غير مسجل في النظام.';
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
          return 'خطأ في الدخول: ' + e.code;
      }
    } catch (e) {
      if (e.toString().contains('PENDING')) {
        await _auth.signOut();
        return 'طلبك قيد مراجعة المدير. انتظر الموافقة قبل تسجيل الدخول.';
      }
      return 'تعذر الاتصال بالخادم. تحقق من الإنترنت وإعدادات Firestore.';
    }
  }

  Future<AppUser?> _fetchOrCreateProfile(User u) async {
    final doc = await _db.collection('users').doc(u.uid).get();
    if (doc.exists) {
      return AppUser.fromMap(u.uid, doc.data()!);
    }
    final req = await _db.collection('requests').doc(u.uid).get();
    if (req.exists && req.data()?['status'] == 'pending') {
      throw Exception('PENDING');
    }
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

  /// طلب حساب جديد (وكيل / نقطة بيع) من داخل التطبيق
  Future<String?> signUpRequest({
    required String name,
    required String phone,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      await _db.collection('requests').doc(cred.user!.uid).set({
        'name': name,
        'phone': phone,
        'role': role,
        'status': 'pending',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      await _auth.signOut();
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'هذا البريد مسجل مسبقًا';
        case 'weak-password':
          return 'كلمة المرور ضعيفة (6 أحرف فأكثر)';
        case 'invalid-email':
          return 'البريد الإلكتروني غير صالح';
        default:
          return 'خطأ: ' + e.code;
      }
    } catch (e) {
      return 'تعذر إنشاء الطلب. حاول لاحقًا.';
    }
  }

  Future<void> signOut() async {
    profile = null;
    await _auth.signOut();
    notifyListeners();
  }

  Future<void> restore() async {
    try {
      final u = _auth.currentUser;
      if (u != null) {
        profile = await _fetchOrCreateProfile(u);
        if (profile == null) {
          await _auth.signOut();
        }
        notifyListeners();
      }
    } catch (e) {
      if (e.toString().contains('PENDING')) {
        await _auth.signOut();
        profile = null;
        notifyListeners();
      }
      // عند انقطاع الشبكة نترك الجلسة كما هي؛ شاشة التحميل تعرض خيارًا واضحًا
      // لتسجيل الخروج بدل البقاء على مؤشر تحميل بلا نهاية.
    }
  }
}
