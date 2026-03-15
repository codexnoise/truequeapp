import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/item_entity.dart';

class ItemCard extends StatelessWidget {
  final ItemEntity item;
  final VoidCallback? onTap;

  const ItemCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap ?? () => context.pushNamed('item-detail', extra: item),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  image: item.imageUrls.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(item.imageUrls.first),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: item.imageUrls.isEmpty
                    ? Icon(Icons.image, color: colorScheme.onSurfaceVariant)
                    : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Busca: ${item.desiredItem}',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
