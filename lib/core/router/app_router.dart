import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/presentation/pages/login_page.dart';
import '../../../features/auth/presentation/pages/register_page.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/home/domain/entities/item_entity.dart';
import '../../features/home/presentation/pages/add_item_page.dart';
import '../../features/home/presentation/pages/edit_item_page.dart';
import '../../features/home/presentation/pages/exchange_detail_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/pages/item_detail_page.dart';
import '../../features/home/presentation/pages/my_items_page.dart';
import '../../features/messages/presentation/pages/chat_page.dart';
import '../../features/messages/presentation/pages/conversations_page.dart';
import '../../features/auth/presentation/pages/profile_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/auth/presentation/pages/recovery_page.dart';
import '../../features/auth/presentation/pages/email_verification_page.dart';
import '../../features/legal/presentation/pages/terms_and_conditions_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Notifier that bridges Riverpod auth state to GoRouter's refreshListenable.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
}

/// Provider that manages the global routing configuration.
/// Uses refreshListenable instead of ref.watch to avoid recreating GoRouter on every auth state change.
final routerProvider = Provider<GoRouter>((ref) {
  final authChangeNotifier = _AuthChangeNotifier(ref);
  ref.onDispose(() => authChangeNotifier.dispose());

  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/splash',
    refreshListenable: authChangeNotifier,

    /// Handles automatic redirects based on the current authentication state.
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final bool isSplash = state.matchedLocation == '/splash';
      final bool isTerms = state.matchedLocation == '/terms';
      if (isSplash || isTerms) return null;

      final bool isAuthPath =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/recovery';

      final bool isVerifyPath = state.matchedLocation == '/verify-email';

      if (authState is AuthEmailNotVerified) {
        return isVerifyPath ? null : '/verify-email';
      }

      if (authState is AuthAuthenticated) {
        return (isAuthPath || isVerifyPath) ? '/home' : null;
      }

      if (authState is! AuthLoading) {
        return (isAuthPath ? null : '/login');
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/recovery',
        builder: (context, state) => const RecoveryPage(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const EmailVerificationPage(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/my-items',
        name: 'my-items',
        builder: (context, state) => const MyItemsPage(),
      ),
      GoRoute(
        path: '/item-detail',
        name: 'item-detail',
        builder: (context, state) {
          final item = state.extra as ItemEntity;
          return ItemDetailPage(item: item);
        },
      ),
      GoRoute(
        path: '/add-item',
        name: 'add-item',
        builder: (context, state) => const AddItemPage(),
      ),
      GoRoute(
        path: '/edit-item',
        name: 'edit-item',
        builder: (context, state) {
          final item = state.extra as ItemEntity;
          return EditItemPage(item: item);
        },
      ),
      GoRoute(
        path: '/exchange-detail',
        name: 'exchange-detail',
        builder: (context, state) {
          final exchangeId = state.extra as String;
          return ExchangeDetailPage(exchangeId: exchangeId);
        },
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/conversations',
        name: 'conversations',
        builder: (context, state) => const ConversationsPage(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/chat',
        name: 'chat',
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>;
          return ChatPage(
            exchangeId: data['exchangeId'] as String,
            otherUserName: data['otherUserName'] as String,
            otherUserId: data['otherUserId'] as String,
          );
        },
      ),
      GoRoute(
        path: '/terms',
        name: 'terms',
        builder: (context, state) => const TermsAndConditionsPage(),
      ),
    ],
  );
});
