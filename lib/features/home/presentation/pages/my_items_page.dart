import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/exchange_model.dart';
import '../providers/home_provider.dart';
import '../providers/my_exchanges_provider.dart';
import '../widgets/item_card_widget.dart';

class MyItemsPage extends ConsumerStatefulWidget {
  const MyItemsPage({super.key});

  @override
  ConsumerState<MyItemsPage> createState() => _MyItemsPageState();
}

class _MyItemsPageState extends ConsumerState<MyItemsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    if (authState is! AuthAuthenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final userId = authState.user.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Mi Actividad',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black38,
          indicatorColor: Colors.black,
          indicatorWeight: 2,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'MIS ARTÍCULOS'),
            Tab(text: 'ENVIADAS'),
            Tab(text: 'RECIBIDAS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MyItemsTab(userId: userId),
          _ExchangesTab(userId: userId, type: _ExchangeTabType.sent),
          _ExchangesTab(userId: userId, type: _ExchangeTabType.received),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        onPressed: () => context.pushNamed('add-item'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _MyItemsTab extends ConsumerWidget {
  final String userId;
  const _MyItemsTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(itemsStreamProvider).when(
      data: (items) {
        final myItems =
            items.where((item) => item.ownerId == userId).toList();

        if (myItems.isEmpty) {
          return const _EmptyState(
            icon: Icons.inventory_2_outlined,
            message: 'No has publicado ningún artículo.',
            subtitle: 'Toca + para agregar tu primer artículo.',
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: myItems.length,
          itemBuilder: (context, index) {
            final item = myItems[index];
            return ItemCard(
              item: item,
              onTap: () => context.pushNamed('edit-item', extra: item),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.black)),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }
}

enum _ExchangeTabType { sent, received }

class _ExchangesTab extends ConsumerWidget {
  final String userId;
  final _ExchangeTabType type;

  const _ExchangesTab({required this.userId, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = type == _ExchangeTabType.sent
        ? sentExchangesProvider(userId)
        : receivedExchangesProvider(userId);

    return ref.watch(provider).when(
      data: (exchanges) {
        if (exchanges.isEmpty) {
          return type == _ExchangeTabType.sent
              ? const _EmptyState(
                  icon: Icons.send_outlined,
                  message: 'No has enviado ninguna propuesta.',
                  subtitle: 'Explora artículos y haz una oferta.',
                )
              : const _EmptyState(
                  icon: Icons.inbox_outlined,
                  message: 'No has recibido ninguna propuesta.',
                  subtitle: 'Cuando alguien te haga una oferta aparecerá aquí.',
                );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: exchanges.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _ExchangeCard(
              exchange: exchanges[index],
              isSent: type == _ExchangeTabType.sent,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.black)),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }
}

class _ExchangeCard extends StatelessWidget {
  final ExchangeModel exchange;
  final bool isSent;

  const _ExchangeCard({required this.exchange, required this.isSent});

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusLabel) = _statusInfo(exchange.status);
    final isDonation = exchange.type == 'donation_request';

    return GestureDetector(
      onTap: () => context.pushNamed('exchange-detail', extra: exchange.id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isDonation ? Icons.volunteer_activism : Icons.swap_horiz,
                color: Colors.black54,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDonation ? 'Solicitud de donación' : 'Propuesta de intercambio',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isSent ? 'Enviada por ti' : 'Recibida',
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                  if (exchange.message != null && exchange.message!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        exchange.message!,
                        style: const TextStyle(color: Colors.black54, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Icon(Icons.chevron_right, color: Colors.black26, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (Color, String) _statusInfo(String status) {
    return switch (status) {
      'pending' => (Colors.orange, 'Pendiente'),
      'accepted' => (Colors.green, 'Aceptado'),
      'rejected' => (Colors.red, 'Rechazado'),
      'completed' => (Colors.blue, 'Completado'),
      'counter_offered' => (Colors.purple, 'Contraoferta'),
      _ => (Colors.grey, status),
    };
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: Colors.black12),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.black45, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}