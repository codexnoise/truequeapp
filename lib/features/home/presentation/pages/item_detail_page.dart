import 'package:flutter/material.dart';
import '../../domain/entities/item_entity.dart';

class ItemDetailPage extends StatelessWidget {
  final ItemEntity item;

  const ItemDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    // Optimized screen size access
    final screenSize = MediaQuery.sizeOf(context);
    final isDonation = item.desiredItem == 'Donation';

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: screenSize.height * 0.45,
            elevation: 0,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.white.withOpacity(0.1),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.8),
                child: const BackButton(color: Colors.black),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: item.imageUrls.isNotEmpty
                  ? PageView.builder(
                      itemCount: item.imageUrls.length,
                      itemBuilder: (context, index) => Image.network(
                        item.imageUrls[index],
                        fit: BoxFit.cover,
                      ),
                    )
                  : Container(
                      color: const Color(0xFFF0F0F0),
                      child: const Icon(
                        Icons.image,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.categoryId.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Exchange section
                  Text(
                    isDonation ? "DONATION" : "LOOKING FOR",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isDonation ? Colors.green.shade700 : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isDonation ? "This is a free item offered as a donation." : item.desiredItem,
                      style: TextStyle(
                        fontSize: isDonation ? 16 : 18,
                        fontWeight: FontWeight.w500,
                        fontStyle: isDonation ? FontStyle.normal : FontStyle.italic,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Text(
                    "DESCRIPTION",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.description,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: Color(0xFF333333),
                    ),
                  ),
                  // Bottom padding for floating action area
                  const SizedBox(height: 140),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        child: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 64),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: Text(
            isDonation ? "REQUEST ITEM" : "SEND OFFER",
            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ),
      ),
    );
  }
}
