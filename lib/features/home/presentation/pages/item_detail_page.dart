import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/item_entity.dart';
import '../providers/exchange_provider.dart';
import '../providers/home_provider.dart';
import '../providers/my_exchanges_provider.dart';

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
    final isDonation = widget.item.desiredItem == 'Donation';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final myItemsAsync = ref.watch(myItemsProvider);
          
          return StatefulBuilder(
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
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange[200]!),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline, size: 18, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Debes publicar un artículo propio antes de poder hacer una oferta.",
                                      style: TextStyle(fontSize: 13, color: Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
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
                              ),
                              if (_selectedOfferItem == null)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    "* Selecciona un artículo para ofrecer a cambio.",
                                    style: TextStyle(fontSize: 11, color: Colors.red, fontStyle: FontStyle.italic),
                                  ),
                                ),
                            ],
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, s) => Text('Error: $e'),
                      ),
                      const SizedBox(height: 24),
                    ],
                    const Text(
                      "MENSAJE",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _messageController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: isDonation
                            ? "¿Por qué necesitas este artículo?"
                            : "Mensaje adicional (opcional)...",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        hintStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Consumer(
                      builder: (context, ref, _) {
                        final exchangeState = ref.watch(exchangeProvider);
                        final isLoading = exchangeState is ExchangeLoading;

                        return ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () {
                                  final message = _messageController.text.trim();

                                  if (!isDonation && _selectedOfferItem == null) {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: Colors.white,
                                        surfaceTintColor: Colors.white,
                                        title: const Text('Artículo requerido'),
                                        content: const Text('Debes seleccionar un artículo para ofrecer a cambio.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Entendido', style: TextStyle(color: Colors.black)),
                                          ),
                                        ],
                                      ),
                                    );
                                    return;
                                  }

                                  ref.read(exchangeProvider.notifier).sendRequest(
                                        senderId: senderId,
                                        receiverId: widget.item.ownerId,
                                        receiverItemId: widget.item.id,
                                        senderItemId: _selectedOfferItem?.id,
                                        message: message,
                                      );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 60),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(isDonation ? "SOLICITAR" : "ENVIAR OFERTA"),
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomSheet(BuildContext context, dynamic authState, bool isDonation) {
    if (authState is! AuthAuthenticated) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 64),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(isDonation ? 'SOLICITAR ARTÍCULO' : 'HACER OFERTA',
              style: const TextStyle(color: Colors.white)),
        ),
      );
    }

    final existingAsync = ref.watch(existingExchangeForItemProvider(
      (senderId: authState.user.uid, receiverItemId: widget.item.id),
    ));

    return existingAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.all(24),
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 64),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
          ),
        ),
      ),
      error: (_, __) => Container(
        padding: const EdgeInsets.all(24),
        child: ElevatedButton(
          onPressed: () => _showOfferDialog(authState.user.uid),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 64),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(isDonation ? 'SOLICITAR ARTÍCULO' : 'HACER OFERTA',
              style: const TextStyle(color: Colors.white)),
        ),
      ),
      data: (existing) {
        if (existing != null) {
          final statusLabel = existing.status == 'accepted' ? 'ACEPTADA' : 'PENDIENTE';
          final statusColor = existing.status == 'accepted' ? Colors.green : Colors.orange;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: statusColor, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          existing.status == 'accepted'
                              ? 'Tu solicitud fue aceptada.'
                              : 'Ya has solicitado este artículo. Tu solicitud está en espera.',
                          style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, color: statusColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'SOLICITUD $statusLabel',
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(24),
          child: ElevatedButton(
            onPressed: () => _showOfferDialog(authState.user.uid),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 64),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(isDonation ? 'SOLICITAR ARTÍCULO' : 'HACER OFERTA',
                style: const TextStyle(color: Colors.white)),
          ),
        );
      },
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
        Navigator.pop(context); // Pop requested article
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
              background: widget.item.imageUrls.isNotEmpty 
                  ? Image.network(widget.item.imageUrls.first, fit: BoxFit.cover)
                  : Container(color: Colors.grey[200]),
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
                  Text(
                    isDonation ? "DONACIÓN" : "BUSCA: ${widget.item.desiredItem}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDonation ? Colors.green : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text("DESCRIPCIÓN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(widget.item.description),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomSheet(context, authState, isDonation),
    );
  }
}
