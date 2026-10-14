import 'package:go_router/go_router.dart';

import '../features/agent/agent_home.dart';
import '../features/auth/loading_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/signup_page.dart';
import '../features/manager/manager_shell.dart';
import '../features/pos/pos_home.dart';
import '../services/auth_service.dart';

GoRouter createRouter(AuthService auth) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: auth,
    redirect: (context, state) {
      final loggedIn = auth.user != null;
      final profile = auth.profile;
      final loc = state.matchedLocation;
      final onLogin = loc == '/login';
      final onSignup = loc == '/signup';

      if (!loggedIn) return (onLogin || onSignup) ? null : '/login';
      if (profile == null) return loc == '/loading' ? null : '/loading';
      if (onLogin || onSignup || loc == '/loading') {
        switch (profile.role) {
          case 'manager':
            return '/manager';
          case 'agent':
            return '/agent';
          case 'pos':
            return '/pos';
          default:
            return '/login';
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupPage()),
      GoRoute(path: '/loading', builder: (_, __) => const LoadingPage()),
      GoRoute(path: '/manager', builder: (_, __) => const ManagerShell()),
      GoRoute(path: '/agent', builder: (_, __) => const AgentHome()),
      GoRoute(path: '/pos', builder: (_, __) => const PosHome()),
    ],
  );
}
