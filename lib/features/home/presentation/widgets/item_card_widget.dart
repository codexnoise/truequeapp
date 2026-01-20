import 'package:flutter/material.dart';

import '../../domain/entities/item_entity.dart';

class ItemCard extends StatelessWidget {
  final ItemEntity item;
  const ItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
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
                  ? const Icon(Icons.image, color: Colors.grey)
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Trade for: ${item.desiredItem}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
