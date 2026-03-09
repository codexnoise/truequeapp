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
    final conversationsAsync = ref.watch(conversationsStreamProvider);
    final authState = ref.watch(authProvider);
    final currentUserId =
        authState is AuthAuthenticated ? authState.user.uid : '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mensajes',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: conversationsAsync.when(
        data: (exchanges) {
          if (exchanges.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.forum_outlined, size: 56, color: Colors.black26),
                  SizedBox(height: 16),
                  Text(
                    'No tienes conversaciones',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      'Cuando un intercambio o donación sea aceptado, podrás chatear aquí',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black38, fontSize: 13),
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
                Divider(height: 1, color: Colors.grey[100]),
            itemBuilder: (context, index) {
              final exchange = exchanges[index];
              return _ConversationTile(
                exchange: exchange,
                currentUserId: currentUserId,
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.black),
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
              userData['displayName'] as String? ?? 'Usuario';
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDonation = widget.exchange.type == 'donation_request';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: Colors.black,
        radius: 24,
        child: Text(
          _otherUserName.isNotEmpty ? _otherUserName[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
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
        style: const TextStyle(color: Colors.black54, fontSize: 13),
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
              style: const TextStyle(color: Colors.black38, fontSize: 11),
            ),
          const SizedBox(height: 4),
          Icon(
            isDonation ? Icons.volunteer_activism : Icons.swap_horiz,
            size: 16,
            color: Colors.black38,
          ),
        ],
      ),
      onTap: () {
        if (!_loaded) return;
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
