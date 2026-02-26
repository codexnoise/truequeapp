import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/item_entity.dart';
import '../providers/exchange_detail_provider.dart';
import '../providers/home_provider.dart';

class ExchangeDetailPage extends ConsumerStatefulWidget {
  final String exchangeId;

  const ExchangeDetailPage({super.key, required this.exchangeId});

  @override
  ConsumerState<ExchangeDetailPage> createState() => _ExchangeDetailPageState();
}

class _ExchangeDetailPageState extends ConsumerState<ExchangeDetailPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(exchangeDetailProvider.notifier).loadExchange(widget.exchangeId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exchangeDetailProvider);

    ref.listen<ExchangeDetailState>(exchangeDetailProvider, (prev, next) {
      if (next is ExchangeDetailSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message), backgroundColor: Colors.black),
        );
        Navigator.pop(context);
      }
      if (next is ExchangeDetailError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message), backgroundColor: Colors.red[800]),
        );
      }
    });

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
          'Detalle del Intercambio',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: switch (state) {
        ExchangeDetailInitial() || ExchangeDetailLoading() => const Center(
          child: CircularProgressIndicator(color: Colors.black),
        ),
        ExchangeDetailLoaded(data: final data) => _ExchangeDetailBody(
          data: data,
          isActionLoading: false,
        ),
        ExchangeDetailActionLoading(data: final data) => _ExchangeDetailBody(
          data: data,
          isActionLoading: true,
        ),
        ExchangeDetailError(message: final msg) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.black38),
              const SizedBox(height: 16),
              Text(msg, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref
                    .read(exchangeDetailProvider.notifier)
                    .loadExchange(widget.exchangeId),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        ExchangeDetailSuccess() => const SizedBox.shrink(),
      },
    );
  }
}

class _ExchangeDetailBody extends ConsumerWidget {
  final ExchangeDetailData data;
  final bool isActionLoading;

  const _ExchangeDetailBody({required this.data, required this.isActionLoading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final currentUserId = authState is AuthAuthenticated ? authState.user.uid : null;
    final isReceiver = currentUserId == data.exchange.receiverId;
    final isPending = data.exchange.status == 'pending';
    final isDonation = data.exchange.type == 'donation_request';

    final senderName = data.senderUser['displayName'] as String? ?? 'Usuario';
    final senderEmail = data.senderUser['email'] as String? ?? '';

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusBadge(status: data.exchange.status, isDonation: isDonation),
              const SizedBox(height: 24),

              _SectionLabel(isDonation ? 'SOLICITANTE' : 'PROPUESTA DE'),
              const SizedBox(height: 12),
              _UserCard(name: senderName, email: senderEmail),
              const SizedBox(height: 24),

              _SectionLabel('ARTÍCULO SOLICITADO'),
              const SizedBox(height: 12),
              _ItemCard(item: data.receiverItem),
              const SizedBox(height: 24),

              if (!isDonation && data.senderItem != null) ...[
                _SectionLabel('OFRECE A CAMBIO'),
                const SizedBox(height: 12),
                _ItemCard(item: data.senderItem!),
                const SizedBox(height: 24),
              ],

              if (data.exchange.message != null && data.exchange.message!.isNotEmpty) ...[
                _SectionLabel('MENSAJE'),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border.all(color: Colors.grey[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    data.exchange.message!,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              _SectionLabel('INFORMACIÓN DEL INTERCAMBIO'),
              const SizedBox(height: 12),
              _InfoRow(
                label: 'Tipo',
                value: isDonation ? 'Solicitud de donación' : 'Propuesta de intercambio',
              ),
              _InfoRow(label: 'Estado', value: _statusLabel(data.exchange.status)),
              if (data.exchange.createdAt != null)
                _InfoRow(label: 'Fecha', value: _formatDate(data.exchange.createdAt!)),
            ],
          ),
        ),

        if (isReceiver && isPending)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _ActionButtons(
              data: data,
              isLoading: isActionLoading,
              currentUserId: currentUserId!,
            ),
          ),

        if (!isReceiver && isPending)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_top, size: 18, color: Colors.black54),
                    SizedBox(width: 8),
                    Text(
                      'Esperando respuesta del receptor',
                      style: TextStyle(color: Colors.black54, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (isActionLoading)
          Container(
            color: Colors.black26,
            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
      ],
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'pending' => 'Pendiente',
      'accepted' => 'Aceptado',
      'rejected' => 'Rechazado',
      'completed' => 'Completado',
      'counter_offered' => 'Contraoferta enviada',
      _ => status,
    };
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}  '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

class _ActionButtons extends ConsumerStatefulWidget {
  final ExchangeDetailData data;
  final bool isLoading;
  final String currentUserId;

  const _ActionButtons({
    required this.data,
    required this.isLoading,
    required this.currentUserId,
  });

  @override
  ConsumerState<_ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends ConsumerState<_ActionButtons> {
  void _showCounterOfferSheet() {
    final isDonation = widget.data.exchange.type == 'donation_request';
    final senderItemId = widget.data.exchange.senderItemId;
    
    // Validación 1: No permitir contraoferta en donaciones
    if (isDonation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No puedes hacer contraoferta en una solicitud de donación'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final messageController = TextEditingController();
    ItemEntity? selectedItem;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final myItemsAsync = ref.watch(myItemsProvider);
          return StatefulBuilder(
            builder: (context, setModalState) => Padding(
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
                    const Text(
                      'ENVIAR CONTRAOFERTA',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Propón un artículo diferente o ajusta las condiciones.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'ARTÍCULO A OFRECER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    myItemsAsync.when(
                      data: (items) {
                        // Validación 2: Verificar si el solicitante tiene más items disponibles
                        final availableItems = items.where((item) => item.id != senderItemId).toList();
                        
                        if (availableItems.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'No tienes otros artículos disponibles para ofrecer. El solicitante ya ofreció su único artículo.',
                                    style: TextStyle(fontSize: 13, color: Colors.orange[900]),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        return SizedBox(
                          height: 110,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: availableItems.length,
                            itemBuilder: (context, index) {
                              final item = availableItems[index];
                              final isSelected = selectedItem?.id == item.id;
                              return GestureDetector(
                                onTap: () => setModalState(() => selectedItem = item),
                                child: Container(
                                  width: 90,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.black
                                          : Colors.grey[300]!,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    image: item.imageUrls.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(item.imageUrls.first),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                    color: Colors.grey[100],
                                  ),
                                  child: item.imageUrls.isEmpty
                                      ? const Icon(
                                          Icons.image_not_supported,
                                          color: Colors.grey,
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                        );
                      },
                      loading: () => const CircularProgressIndicator(color: Colors.black),
                      error: (e, _) => Text('Error: $e'),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'MENSAJE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: messageController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Explica los términos de tu contraoferta...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        final msg = messageController.text.trim();
                        
                        // Validación 3: Requiere un artículo diferente al del solicitante
                        if (selectedItem == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Debes seleccionar un artículo para la contraoferta',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        
                        // Validar que no sea el mismo artículo que ofreció el solicitante
                        if (selectedItem?.id == senderItemId) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Debes seleccionar un artículo diferente al que te ofrecieron',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        Navigator.pop(context);
                        ref
                            .read(exchangeDetailProvider.notifier)
                            .sendCounterOffer(
                              originalExchangeId: widget.data.exchange.id,
                              senderId: widget.currentUserId,
                              receiverId: widget.data.exchange.senderId,
                              receiverItemId: widget.data.exchange.receiverItemId,
                              senderItemId: selectedItem?.id,
                              message: msg.isEmpty ? null : msg,
                            );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('ENVIAR CONTRAOFERTA'),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmReject() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Rechazar propuesta'),
        content: const Text('¿Estás seguro de que quieres rechazar esta propuesta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.black54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(exchangeDetailProvider.notifier)
                  .rejectExchange(widget.data.exchange.id);
            },
            child: const Text('Rechazar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: widget.isLoading
                ? null
                : () {
                    print(
                      'DEBUG UI: Accept button pressed for exchange: ${widget.data.exchange.id}',
                    );
                    ref
                        .read(exchangeDetailProvider.notifier)
                        .acceptExchange(widget.data.exchange.id);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'ACEPTAR PROPUESTA',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.isLoading || widget.data.exchange.type == 'donation_request' 
                      ? null 
                      : _showCounterOfferSheet,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black),
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'CONTRAOFERTA',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.isLoading ? null : _confirmReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'RECHAZAR',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool isDonation;

  const _StatusBadge({required this.status, required this.isDonation});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'pending' => (
        Colors.orange[700]!,
        isDonation ? 'SOLICITUD DE DONACIÓN PENDIENTE' : 'PROPUESTA PENDIENTE',
      ),
      'accepted' => (Colors.green[700]!, 'ACEPTADO'),
      'rejected' => (Colors.red[700]!, 'RECHAZADO'),
      'completed' => (Colors.blue[700]!, 'COMPLETADO'),
      'counter_offered' => (Colors.purple[700]!, 'CONTRAOFERTA ENVIADA'),
      _ => (Colors.grey[700]!, status.toUpperCase()),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: Colors.black54,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final String name;
  final String email;

  const _UserCard({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.black,
            radius: 22,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final ItemEntity item;

  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
            child: item.imageUrls.isNotEmpty
                ? Image.network(
                    item.imageUrls.first,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey[100],
                    child: const Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  if (item.desiredItem.isNotEmpty && item.desiredItem != 'Donation')
                    Text(
                      'Busca: ${item.desiredItem}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
