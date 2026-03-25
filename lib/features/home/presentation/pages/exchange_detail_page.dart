import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/item_entity.dart';
import '../providers/exchange_detail_provider.dart';
import '../providers/home_provider.dart';
import '../widgets/fullscreen_image_viewer.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(exchangeDetailProvider);

    ref.listen<ExchangeDetailState>(exchangeDetailProvider, (prev, next) {
      if (next is ExchangeDetailSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message), backgroundColor: colorScheme.primary),
        );

        Navigator.pop(context);

        if (Navigator.canPop(context)) Navigator.pop(context);
      }
      if (next is ExchangeDetailError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message), backgroundColor: colorScheme.error),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Detalle del Intercambio',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: switch (state) {
        ExchangeDetailInitial() || ExchangeDetailLoading() => Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
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
              Icon(Icons.error_outline, size: 48, color: colorScheme.onSurface.withValues(alpha: 0.38)),
              const SizedBox(height: 16),
              Text(msg, style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.54))),
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
    final colorScheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final currentUserId = authState is AuthAuthenticated ? authState.user.uid : null;
    final isReceiver = currentUserId == data.exchange.receiverId;
    final isPending = data.exchange.status == 'pending';
    final isAccepted = data.exchange.status == 'accepted';
    final isReceived = data.exchange.status == 'received';
    final isClosed = data.exchange.status == 'closed';
    final isCancelled = data.exchange.status == 'cancelled';
    final isDonation = data.exchange.type == 'donation_request';
    final isSender = currentUserId == data.exchange.senderId;

    final senderName = data.senderUser['name'] as String? ?? 'Usuario';
    final senderEmail = data.senderUser['email'] as String? ?? '';
    final receiverName = data.receiverUser['name'] as String? ?? 'Usuario';
    final receiverEmail = data.receiverUser['email'] as String? ?? '';

    // Mostrar datos del otro usuario según el rol
    final displayName = isSender ? receiverName : senderName;
    final displayEmail = isSender ? receiverEmail : senderEmail;
    final userLabel = isDonation
        ? 'SOLICITANTE'
        : isSender
            ? 'PROPUESTA PARA'
            : 'PROPUESTA DE';

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusBadge(status: data.exchange.status, isDonation: isDonation, isReceiver: isReceiver),
              const SizedBox(height: 24),

              _SectionLabel(userLabel),
              const SizedBox(height: 12),
              _UserCard(name: displayName, email: displayEmail),
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
                    color: colorScheme.surfaceContainerLow,
                    border: Border.all(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
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
              color: colorScheme.surface,
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_top, size: 18, color: colorScheme.onSurface.withValues(alpha: 0.54)),
                    const SizedBox(width: 8),
                    Text(
                      'Esperando respuesta del receptor',
                      style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (isClosed)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: colorScheme.surface,
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange[200]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Esta propuesta fue cerrada porque se aceptó una contraoferta',
                        style: TextStyle(color: Colors.orange[900], fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (isCancelled)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: colorScheme.surface,
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[200]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cancel_outlined, size: 20, color: Colors.red[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Este intercambio fue cancelado porque el artículo ya no está disponible',
                        style: TextStyle(color: Colors.red[900], fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (isAccepted && isReceiver)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  final otherUserName = data.senderUser['name'] as String? ?? 'Usuario';
                  context.pushNamed(
                    'chat',
                    extra: {
                      'exchangeId': data.exchange.id,
                      'otherUserName': otherUserName,
                      'otherUserId': data.exchange.senderId,
                    },
                  );
                },
                icon: const Icon(Icons.chat, size: 20),
                label: const Text(
                  'ENVIAR MENSAJE',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

        if (isAccepted && isSender)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _SenderAcceptedActions(data: data, isLoading: isActionLoading),
          ),

        if (isReceived)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: colorScheme.surface,
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal[50],
                  border: Border.all(color: Colors.teal[200]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      isReceiver ? Icons.local_shipping_outlined : Icons.check_circle_outline,
                      size: 20,
                      color: Colors.teal[700],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isReceiver
                            ? 'El solicitante confirmó la recepción del producto. ¡Entrega completada!'
                            : 'Has confirmado la recepción del producto.',
                        style: TextStyle(color: Colors.teal[900], fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (isActionLoading)
          Container(
            color: colorScheme.onSurface.withValues(alpha: 0.26),
            child: Center(child: CircularProgressIndicator(color: colorScheme.onPrimary)),
          ),
      ],
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'pending' => 'Pendiente',
      'accepted' => 'Aceptado',
      'received' => 'Recibido',
      'rejected' => 'Rechazado',
      'completed' => 'Completado',
      'counter_offered' => 'Contraoferta enviada',
      'closed' => 'Cerrado por contraoferta aceptada',
      'cancelled' => 'Cancelado',
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
    final isCounterOffer = widget.data.exchange.parentExchangeId != null;
    final senderItemId = widget.data.exchange.senderItemId;
    final receiverItemId = widget.data.exchange.receiverItemId;

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

    // Validación 2: No permitir contraoferta sobre una contraoferta (evitar bucle infinito)
    if (isCounterOffer) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No puedes hacer contraoferta sobre una contraoferta. Solo puedes aceptar o rechazar.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 150,
            left: 10,
            right: 10,
          ),
        ),
      );
      return;
    }

    final messageController = TextEditingController();
    ItemEntity? selectedItem;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final colorScheme = Theme.of(context).colorScheme;
          final myItemsAsync = ref.watch(myItemsProvider);
          return StatefulBuilder(
            builder: (context, setModalState) => GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Padding(
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
                    Text(
                      'Propón un artículo diferente o ajusta las condiciones.',
                      style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.54)),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'ARTÍCULO A OFRECER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    myItemsAsync.when(
                      data: (items) {
                        // Filtrar: solo items disponibles, excluyendo el item solicitado originalmente y el ofrecido por el solicitante
                        final availableItems = items.where((item) =>
                          item.status == 'available' &&
                          item.id != receiverItemId &&
                          item.id != senderItemId
                        ).toList();

                        if (availableItems.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(12),
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
                                          ? colorScheme.primary
                                          : colorScheme.outlineVariant,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    image: item.imageUrls.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(item.imageUrls.first),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                    color: colorScheme.surfaceContainerLow,
                                  ),
                                  child: item.imageUrls.isEmpty
                                      ? Icon(
                                          Icons.image_not_supported,
                                          color: colorScheme.onSurfaceVariant,
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                        );
                      },
                      loading: () => CircularProgressIndicator(color: colorScheme.primary),
                      error: (e, _) => Text('Error: $e'),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'MENSAJE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: messageController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Explica los términos de tu contraoferta...',
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        final msg = messageController.text.trim();

                        // Validación 3: Requiere un artículo diferente al del solicitante
                        if (selectedItem == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Debes seleccionar un artículo para la contraoferta',
                              ),
                              backgroundColor: Colors.orange,
                              behavior: SnackBarBehavior.floating,
                              margin: EdgeInsets.only(
                                bottom: MediaQuery.of(context).size.height - 150,
                                left: 10,
                                right: 10,
                              ),
                            ),
                          );
                          return;
                        }

                        // Validar que no sea el mismo artículo que ofreció el solicitante
                        if (selectedItem?.id == senderItemId) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Debes seleccionar un artículo diferente al que te ofrecieron',
                              ),
                              backgroundColor: Colors.orange,
                              behavior: SnackBarBehavior.floating,
                              margin: EdgeInsets.only(
                                bottom: MediaQuery.of(context).size.height - 150,
                                left: 10,
                                right: 10,
                              ),
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
                              receiverItemId: widget.data.exchange.senderItemId!,
                              senderItemId: selectedItem?.id,
                              message: msg.isEmpty ? null : msg,
                            );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('ENVIAR CONTRAOFERTA'),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
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
      builder: (context) {
        final dlgColorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('Rechazar propuesta'),
          content: const Text('¿Estás seguro de que quieres rechazar esta propuesta?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: dlgColorScheme.onSurface.withValues(alpha: 0.54))),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
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
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  onPressed: widget.isLoading ||
                      widget.data.exchange.type == 'donation_request' ||
                      widget.data.exchange.parentExchangeId != null
                      ? null
                      : _showCounterOfferSheet,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.onSurface,
                    side: BorderSide(color: colorScheme.onSurface),
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

class _SenderAcceptedActions extends ConsumerWidget {
  final ExchangeDetailData data;
  final bool isLoading;

  const _SenderAcceptedActions({required this.data, required this.isLoading});

  void _confirmMarkReceived(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        final dlgColorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('Confirmar recepción'),
          content: const Text('¿Confirmas que recibiste el producto? Esta acción no se puede deshacer y el chat se cerrará.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: dlgColorScheme.onSurface.withValues(alpha: 0.54))),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ref
                    .read(exchangeDetailProvider.notifier)
                    .markAsReceived(data.exchange.id);
              },
              child: Text('Confirmar', style: TextStyle(color: Colors.teal[700])),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final otherUserName = data.receiverUser['name'] as String? ?? 'Usuario';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            onPressed: isLoading
                ? null
                : () => _confirmMarkReceived(context, ref),
            icon: const Icon(Icons.check_circle_outline, size: 20),
            label: const Text(
              'MARCAR COMO RECIBIDO',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[700],
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: isLoading
                ? null
                : () {
                    context.pushNamed(
                      'chat',
                      extra: {
                        'exchangeId': data.exchange.id,
                        'otherUserName': otherUserName,
                        'otherUserId': data.exchange.receiverId,
                      },
                    );
                  },
            icon: const Icon(Icons.chat, size: 20),
            label: const Text(
              'ENVIAR MENSAJE',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.onSurface,
              side: BorderSide(color: colorScheme.onSurface),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool isDonation;
  final bool isReceiver;

  const _StatusBadge({required this.status, required this.isDonation, required this.isReceiver});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'pending' => (
        Colors.orange[700]!,
        isDonation ? 'SOLICITUD DE DONACIÓN PENDIENTE' : 'PROPUESTA PENDIENTE',
      ),
      'accepted' => (Colors.green[700]!, 'ACEPTADO'),
      'received' => (Colors.teal[700]!, isReceiver ? 'ENTREGADO' : 'RECIBIDO'),
      'rejected' => (Colors.red[700]!, 'RECHAZADO'),
      'completed' => (Colors.blue[700]!, 'COMPLETADO'),
      'counter_offered' => (Colors.purple[700]!, 'CONTRAOFERTA ENVIADA'),
      'closed' => (Colors.grey[700]!, 'CERRADO POR CONTRAOFERTA ACEPTADA'),
      'cancelled' => (Colors.red[700]!, 'CANCELADO - ARTÍCULO NO DISPONIBLE'),
      _ => (Colors.grey[700]!, status.toUpperCase()),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: colorScheme.onSurface.withValues(alpha: 0.54),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.primary,
            radius: 22,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
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
                    style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 13),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: item.imageUrls.isNotEmpty
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FullscreenImageViewer(imageUrls: item.imageUrls),
                      ),
                    )
                : null,
            child: ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
              child: item.imageUrls.isNotEmpty
                  ? Stack(
                      children: [
                        Image.network(
                          item.imageUrls.first,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.zoom_in, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      width: 100,
                      height: 100,
                      color: colorScheme.surfaceContainerLow,
                      child: Icon(Icons.image_not_supported, color: colorScheme.onSurfaceVariant),
                    ),
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
                    style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 13),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 13),
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
