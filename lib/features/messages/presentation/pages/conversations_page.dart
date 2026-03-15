import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../home/data/models/exchange_model.dart';
import '../../../../core/di/injection_container.dart';
import '../../../home/domain/repositories/home_repository.dart';
import '../providers/message_provider.dart';

class ConversationsPage extends ConsumerWidget {
  const ConversationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final conversationsAsync = ref.watch(conversationsStreamProvider);
    final authState = ref.watch(authProvider);
    final currentUserId =
        authState is AuthAuthenticated ? authState.user.uid : '';

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mensajes',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: conversationsAsync.when(
        data: (exchanges) {
          if (exchanges.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.forum_outlined, size: 56, color: colorScheme.onSurface.withValues(alpha: 0.26)),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes conversaciones',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.54),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      'Cuando un intercambio o donación sea aceptado, podrás chatear aquí',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: exchanges.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: colorScheme.surfaceContainerLow),
            itemBuilder: (context, index) {
              final exchange = exchanges[index];
              return _ConversationTile(
                exchange: exchange,
                currentUserId: currentUserId,
              );
            },
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatefulWidget {
  final ExchangeModel exchange;
  final String currentUserId;

  const _ConversationTile({
    required this.exchange,
    required this.currentUserId,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  String _otherUserName = 'Usuario';
  String _otherUserId = '';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadOtherUser();
  }

  Future<void> _loadOtherUser() async {
    final isSender = widget.currentUserId == widget.exchange.senderId;
    _otherUserId =
        isSender ? widget.exchange.receiverId : widget.exchange.senderId;

    try {
      final userData = await sl<HomeRepository>().getUserById(_otherUserId);
      if (userData != null && mounted) {
        setState(() {
          _otherUserName =
              userData['name'] as String? ?? 'Usuario';
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDonation = widget.exchange.type == 'donation_request';

    if (!_loaded) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: colorScheme.outlineVariant,
          radius: 24,
        ),
        title: Container(
          height: 14,
          width: 100,
          decoration: BoxDecoration(
            color: colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        subtitle: Container(
          height: 12,
          width: 60,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: colorScheme.primary,
        radius: 24,
        child: Text(
          _otherUserName.isNotEmpty ? _otherUserName[0].toUpperCase() : '?',
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      title: Text(
        _otherUserName,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      subtitle: Text(
        isDonation ? 'Donación' : 'Intercambio',
        style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 13),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (widget.exchange.updatedAt != null)
            Text(
              _formatTime(widget.exchange.updatedAt!),
              style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 11),
            ),
          const SizedBox(height: 4),
          Icon(
            isDonation ? Icons.volunteer_activism : Icons.swap_horiz,
            size: 16,
            color: colorScheme.onSurface.withValues(alpha: 0.38),
          ),
        ],
      ),
      onTap: () {
        context.pushNamed(
          'chat',
          extra: {
            'exchangeId': widget.exchange.id,
            'otherUserName': _otherUserName,
            'otherUserId': _otherUserId,
          },
        );
      },
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }
}
