import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/home_provider.dart';
import '../widgets/item_card_widget.dart';

class MyItemsPage extends ConsumerWidget {
  const MyItemsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Artículos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ref.watch(itemsStreamProvider).when(
        data: (items) {
          if (authState is AuthAuthenticated) {
            final currentUserId = authState.user.uid;
            final myItems = items.where((item) => item.ownerId == currentUserId).toList();

            if (myItems.isEmpty) {
              return const Center(child: Text("No has publicado ningún artículo."));
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16.0),
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
          }
          return const Center(child: CircularProgressIndicator());
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }
}