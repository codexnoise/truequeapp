import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/item_entity.dart';
import '../providers/exchange_provider.dart';
import '../providers/home_provider.dart';

class ItemDetailPage extends ConsumerStatefulWidget {
  final ItemEntity item;

  const ItemDetailPage({super.key, required this.item});

  @override
  ConsumerState<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends ConsumerState<ItemDetailPage> {
  final _messageController = TextEditingController();
  ItemEntity? _selectedOfferItem;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _showOfferDialog(String senderId) {
    final myItemsAsync = ref.watch(myItemsProvider);
    final isDonation = widget.item.desiredItem == 'Donation';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDonation ? "REQUERIR DONACIÓN" : "HACER UNA OFERTA",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                if (!isDonation) ...[
                  const Text(
                    "¿Qué quieres ofrecer a cambio?",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  myItemsAsync.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return const Text("No tienes artículos para ofrecer. Puedes enviar un mensaje.");
                      }
                      return SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final isSelected = _selectedOfferItem?.id == item.id;
                            return GestureDetector(
                              onTap: () => setModalState(() => _selectedOfferItem = item),
                              child: Container(
                                width: 100,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected ? Colors.black : Colors.transparent,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: NetworkImage(item.imageUrls.first),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Text('Error: $e'),
                  ),
                  const SizedBox(height: 24),
                ],
                const Text(
                  "MENSAJE (OPCIONAL)",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _messageController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: isDonation 
                        ? "¿Por qué necesitas este artículo?" 
                        : "Explica tu oferta...",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    ref.read(exchangeProvider.notifier).sendRequest(
                          senderId: senderId,
                          receiverId: widget.item.ownerId,
                          receiverItemId: widget.item.id,
                          senderItemId: _selectedOfferItem?.id,
                          message: _messageController.text.trim(),
                        );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(isDonation ? "SOLICITAR" : "ENVIAR OFERTA"),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isDonation = widget.item.desiredItem == 'Donation';
    final authState = ref.watch(authProvider);

    ref.listen<ExchangeState>(exchangeProvider, (prev, next) {
      if (next is ExchangeLoading) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
        );
      }
      if (next is ExchangeSuccess) {
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Solicitud enviada con éxito!')),
        );
        Navigator.pop(context); // Back to list
      }
      if (next is ExchangeError) {
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message)),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: screenSize.height * 0.45,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(widget.item.imageUrls.first, fit: BoxFit.cover),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.item.title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text(isDonation ? "DONACIÓN" : "BUSCA: ${widget.item.desiredItem}"),
                  const SizedBox(height: 24),
                  Text(widget.item.description),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(24),
        child: ElevatedButton(
          onPressed: authState is AuthAuthenticated 
              ? () => _showOfferDialog(authState.user.uid) 
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 64),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(isDonation ? "SOLICITAR ARTÍCULO" : "HACER OFERTA", style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
