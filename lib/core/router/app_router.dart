import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/presentation/pages/login_page.dart';
import '../../../features/auth/presentation/pages/register_page.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/home/domain/entities/item_entity.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/pages/item_detail_page.dart';

/// Provider that manages the global routing configuration.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',

    /// Handles automatic redirects based on the current authentication state.
    redirect: (context, state) {
      final bool isAuthPath =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (authState is AuthAuthenticated) {
        // Redirect to home if user is already authenticated
        return isAuthPath ? '/home' : null;
      }

      if (authState is! AuthLoading) {
        // Redirect to login if user is not authenticated and not on an auth path
        return isAuthPath ? null : '/login';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/item-detail',
        name: 'item-detail',
        builder: (context, state) {
          final item = state.extra as ItemEntity;
          return ItemDetailPage(item: item);
        },
      ),
    ],
  );
});
