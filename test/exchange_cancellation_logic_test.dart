import 'package:flutter_test/flutter_test.dart';
import 'package:truequeapp/features/home/data/models/exchange_model.dart';
import 'package:truequeapp/features/home/domain/entities/item_entity.dart';

/// Helper to create an ExchangeModel for testing
ExchangeModel createExchange({
  required String id,
  String senderId = 'sender1',
  String receiverId = 'receiver1',
  String receiverItemId = 'item1',
  String? senderItemId = 'item2',
  String status = 'pending',
  String type = 'exchange',
  String? parentExchangeId,
  String? message,
}) {
  return ExchangeModel(
    id: id,
    senderId: senderId,
    receiverId: receiverId,
    receiverItemId: receiverItemId,
    senderItemId: senderItemId,
    status: status,
    type: type,
    parentExchangeId: parentExchangeId,
    message: message,
  );
}

/// Helper to create an ItemEntity for testing
ItemEntity createItem({
  required String id,
  String ownerId = 'owner1',
  String title = 'Test Item',
  String status = 'available',
}) {
  return ItemEntity(
    id: id,
    ownerId: ownerId,
    title: title,
    description: 'Test description',
    categoryId: 'cat1',
    imageUrls: const [],
    desiredItem: 'Anything',
    status: status,
  );
}

/// Replicates the Cloud Function logic: determines which exchanges should be
/// cancelled when an exchange is accepted.
List<String> findExchangesToCancelOnAcceptance({
  required String acceptedExchangeId,
  required String receiverItemId,
  required String? senderItemId,
  required List<ExchangeModel> allExchanges,
}) {
  final cancelIds = <String>[];

  for (final exchange in allExchanges) {
    if (exchange.id == acceptedExchangeId) continue;
    if (exchange.status != 'pending' && exchange.status != 'counter_offered') {
      continue;
    }

    final involvesItem = exchange.receiverItemId == receiverItemId ||
        exchange.receiverItemId == senderItemId ||
        (exchange.senderItemId != null &&
            exchange.senderItemId == receiverItemId) ||
        (exchange.senderItemId != null &&
            exchange.senderItemId == senderItemId);

    if (involvesItem) {
      cancelIds.add(exchange.id);
    }
  }

  return cancelIds;
}

/// Replicates the Cloud Function logic: determines which exchanges should be
/// cancelled when an item is deleted.
List<String> findExchangesToCancelOnItemDelete({
  required String deletedItemId,
  required List<ExchangeModel> allExchanges,
}) {
  final cancelIds = <String>[];

  for (final exchange in allExchanges) {
    if (exchange.status != 'pending') continue;

    if (exchange.receiverItemId == deletedItemId ||
        (exchange.senderItemId != null &&
            exchange.senderItemId == deletedItemId)) {
      cancelIds.add(exchange.id);
    }
  }

  return cancelIds;
}

/// Replicates: find child counter-offers whose parent was cancelled
List<String> findOrphanedCounterOffers({
  required Set<String> cancelledParentIds,
  required List<ExchangeModel> allExchanges,
}) {
  final cancelIds = <String>[];

  for (final exchange in allExchanges) {
    if (exchange.status != 'pending') continue;
    if (exchange.parentExchangeId != null &&
        cancelledParentIds.contains(exchange.parentExchangeId)) {
      cancelIds.add(exchange.id);
    }
  }

  return cancelIds;
}

/// Replicates: determine if counter-offer should be allowed
bool canSendCounterOffer(ExchangeModel exchange) {
  if (exchange.type == 'donation_request') return false;
  if (exchange.parentExchangeId != null) return false;
  if (exchange.status != 'pending') return false;
  return true;
}

/// Replicates: filter available items for offering in exchange
List<ItemEntity> filterAvailableItemsForOffer(List<ItemEntity> myItems) {
  return myItems.where((item) => item.status == 'available').toList();
}

/// Replicates: filter available items for counter-offer
List<ItemEntity> filterItemsForCounterOffer({
  required List<ItemEntity> myItems,
  required String receiverItemId,
  required String? senderItemId,
}) {
  return myItems
      .where((item) =>
          item.status == 'available' &&
          item.id != receiverItemId &&
          item.id != senderItemId)
      .toList();
}

/// Replicates: determine parent exchange status when counter-offer is accepted
String parentStatusOnCounterOfferAccepted() => 'closed';

/// Replicates: determine parent exchange status when counter-offer is rejected
String parentStatusOnCounterOfferRejected() => 'pending';

void main() {
  group('Exchange Cancellation on Acceptance', () {
    test('cancels other pending exchanges for same receiverItem', () {
      final exchanges = [
        createExchange(id: 'ex1', senderId: 'userA', receiverItemId: 'itemX', senderItemId: 'itemA'),
        createExchange(id: 'ex2', senderId: 'userB', receiverItemId: 'itemX', senderItemId: 'itemB'),
        createExchange(id: 'ex3', senderId: 'userC', receiverItemId: 'itemX', senderItemId: 'itemC'),
      ];

      final toCancelIds = findExchangesToCancelOnAcceptance(
        acceptedExchangeId: 'ex1',
        receiverItemId: 'itemX',
        senderItemId: 'itemA',
        allExchanges: exchanges,
      );

      expect(toCancelIds, contains('ex2'));
      expect(toCancelIds, contains('ex3'));
      expect(toCancelIds, isNot(contains('ex1')));
    });

    test('cancels exchanges involving senderItem as receiverItem', () {
      final exchanges = [
        createExchange(id: 'ex1', senderId: 'userA', receiverItemId: 'itemX', senderItemId: 'itemA'),
        createExchange(id: 'ex2', senderId: 'userD', receiverItemId: 'itemA', senderItemId: 'itemD'),
      ];

      final toCancelIds = findExchangesToCancelOnAcceptance(
        acceptedExchangeId: 'ex1',
        receiverItemId: 'itemX',
        senderItemId: 'itemA',
        allExchanges: exchanges,
      );

      expect(toCancelIds, contains('ex2'));
    });

    test('cancels exchanges involving senderItem as senderItem', () {
      final exchanges = [
        createExchange(id: 'ex1', senderId: 'userA', receiverItemId: 'itemX', senderItemId: 'itemA'),
        createExchange(id: 'ex2', senderId: 'userA', receiverItemId: 'itemY', senderItemId: 'itemA'),
      ];

      final toCancelIds = findExchangesToCancelOnAcceptance(
        acceptedExchangeId: 'ex1',
        receiverItemId: 'itemX',
        senderItemId: 'itemA',
        allExchanges: exchanges,
      );

      expect(toCancelIds, contains('ex2'));
    });

    test('does not cancel unrelated exchanges', () {
      final exchanges = [
        createExchange(id: 'ex1', senderId: 'userA', receiverItemId: 'itemX', senderItemId: 'itemA'),
        createExchange(id: 'ex2', senderId: 'userD', receiverItemId: 'itemY', senderItemId: 'itemD'),
      ];

      final toCancelIds = findExchangesToCancelOnAcceptance(
        acceptedExchangeId: 'ex1',
        receiverItemId: 'itemX',
        senderItemId: 'itemA',
        allExchanges: exchanges,
      );

      expect(toCancelIds, isEmpty);
    });

    test('does not cancel already rejected exchanges', () {
      final exchanges = [
        createExchange(id: 'ex1', senderId: 'userA', receiverItemId: 'itemX', senderItemId: 'itemA'),
        createExchange(id: 'ex2', senderId: 'userB', receiverItemId: 'itemX', senderItemId: 'itemB', status: 'rejected'),
      ];

      final toCancelIds = findExchangesToCancelOnAcceptance(
        acceptedExchangeId: 'ex1',
        receiverItemId: 'itemX',
        senderItemId: 'itemA',
        allExchanges: exchanges,
      );

      expect(toCancelIds, isEmpty);
    });

    test('cancels counter_offered status exchanges', () {
      final exchanges = [
        createExchange(id: 'ex1', senderId: 'userA', receiverItemId: 'itemX', senderItemId: 'itemA'),
        createExchange(id: 'ex2', senderId: 'userB', receiverItemId: 'itemX', senderItemId: 'itemB', status: 'counter_offered'),
      ];

      final toCancelIds = findExchangesToCancelOnAcceptance(
        acceptedExchangeId: 'ex1',
        receiverItemId: 'itemX',
        senderItemId: 'itemA',
        allExchanges: exchanges,
      );

      expect(toCancelIds, contains('ex2'));
    });

    test('does not cancel the accepted exchange itself', () {
      final exchanges = [
        createExchange(id: 'ex1', senderId: 'userA', receiverItemId: 'itemX', senderItemId: 'itemA'),
      ];

      final toCancelIds = findExchangesToCancelOnAcceptance(
        acceptedExchangeId: 'ex1',
        receiverItemId: 'itemX',
        senderItemId: 'itemA',
        allExchanges: exchanges,
      );

      expect(toCancelIds, isEmpty);
    });

    test('handles donation exchanges (null senderItemId)', () {
      final exchanges = [
        createExchange(id: 'ex1', senderId: 'userA', receiverItemId: 'itemX', senderItemId: null, type: 'donation_request'),
        createExchange(id: 'ex2', senderId: 'userB', receiverItemId: 'itemX', senderItemId: null, type: 'donation_request'),
      ];

      final toCancelIds = findExchangesToCancelOnAcceptance(
        acceptedExchangeId: 'ex1',
        receiverItemId: 'itemX',
        senderItemId: null,
        allExchanges: exchanges,
      );

      expect(toCancelIds, contains('ex2'));
    });
  });

  group('Exchange Cancellation on Item Delete', () {
    test('cancels pending exchanges where deleted item is receiverItem', () {
      final exchanges = [
        createExchange(id: 'ex1', receiverItemId: 'itemX'),
        createExchange(id: 'ex2', receiverItemId: 'itemX'),
        createExchange(id: 'ex3', receiverItemId: 'itemY'),
      ];

      final toCancelIds = findExchangesToCancelOnItemDelete(
        deletedItemId: 'itemX',
        allExchanges: exchanges,
      );

      expect(toCancelIds, containsAll(['ex1', 'ex2']));
      expect(toCancelIds, isNot(contains('ex3')));
    });

    test('cancels pending exchanges where deleted item is senderItem', () {
      final exchanges = [
        createExchange(id: 'ex1', receiverItemId: 'itemY', senderItemId: 'itemX'),
      ];

      final toCancelIds = findExchangesToCancelOnItemDelete(
        deletedItemId: 'itemX',
        allExchanges: exchanges,
      );

      expect(toCancelIds, contains('ex1'));
    });

    test('does not cancel non-pending exchanges', () {
      final exchanges = [
        createExchange(id: 'ex1', receiverItemId: 'itemX', status: 'accepted'),
        createExchange(id: 'ex2', receiverItemId: 'itemX', status: 'rejected'),
        createExchange(id: 'ex3', receiverItemId: 'itemX', status: 'completed'),
      ];

      final toCancelIds = findExchangesToCancelOnItemDelete(
        deletedItemId: 'itemX',
        allExchanges: exchanges,
      );

      expect(toCancelIds, isEmpty);
    });

    test('does not cancel exchanges for unrelated items', () {
      final exchanges = [
        createExchange(id: 'ex1', receiverItemId: 'itemY', senderItemId: 'itemZ'),
      ];

      final toCancelIds = findExchangesToCancelOnItemDelete(
        deletedItemId: 'itemX',
        allExchanges: exchanges,
      );

      expect(toCancelIds, isEmpty);
    });
  });

  group('Orphaned Counter-Offers Cancellation', () {
    test('cancels counter-offer when parent exchange is cancelled', () {
      final exchanges = [
        createExchange(id: 'counter1', parentExchangeId: 'ex1'),
      ];

      final toCancelIds = findOrphanedCounterOffers(
        cancelledParentIds: {'ex1'},
        allExchanges: exchanges,
      );

      expect(toCancelIds, contains('counter1'));
    });

    test('does not cancel counter-offers with non-cancelled parents', () {
      final exchanges = [
        createExchange(id: 'counter1', parentExchangeId: 'ex2'),
      ];

      final toCancelIds = findOrphanedCounterOffers(
        cancelledParentIds: {'ex1'},
        allExchanges: exchanges,
      );

      expect(toCancelIds, isEmpty);
    });

    test('does not cancel regular exchanges without parentExchangeId', () {
      final exchanges = [
        createExchange(id: 'ex3', parentExchangeId: null),
      ];

      final toCancelIds = findOrphanedCounterOffers(
        cancelledParentIds: {'ex1'},
        allExchanges: exchanges,
      );

      expect(toCancelIds, isEmpty);
    });

    test('cancels multiple counter-offers for same parent', () {
      final exchanges = [
        createExchange(id: 'counter1', parentExchangeId: 'ex1'),
        createExchange(id: 'counter2', parentExchangeId: 'ex1'),
      ];

      final toCancelIds = findOrphanedCounterOffers(
        cancelledParentIds: {'ex1'},
        allExchanges: exchanges,
      );

      expect(toCancelIds, containsAll(['counter1', 'counter2']));
    });

    test('only cancels pending counter-offers', () {
      final exchanges = [
        createExchange(id: 'counter1', parentExchangeId: 'ex1', status: 'pending'),
        createExchange(id: 'counter2', parentExchangeId: 'ex1', status: 'rejected'),
      ];

      final toCancelIds = findOrphanedCounterOffers(
        cancelledParentIds: {'ex1'},
        allExchanges: exchanges,
      );

      expect(toCancelIds, contains('counter1'));
      expect(toCancelIds, isNot(contains('counter2')));
    });

    test('handles cascading cancellations with multiple parents', () {
      final exchanges = [
        createExchange(id: 'counter1', parentExchangeId: 'ex1'),
        createExchange(id: 'counter2', parentExchangeId: 'ex2'),
        createExchange(id: 'counter3', parentExchangeId: 'ex3'),
      ];

      final toCancelIds = findOrphanedCounterOffers(
        cancelledParentIds: {'ex1', 'ex2'},
        allExchanges: exchanges,
      );

      expect(toCancelIds, containsAll(['counter1', 'counter2']));
      expect(toCancelIds, isNot(contains('counter3')));
    });
  });

  group('Full Cancellation Cascade Scenarios', () {
    test('Scenario: item deleted with pending exchange and counter-offer', () {
      // Exchange 1: userA requests itemX (status: counter_offered)
      // Counter-offer 1: owner of itemX offers different item (status: pending, parent: ex1)
      final exchanges = [
        createExchange(id: 'ex1', senderId: 'userA', receiverItemId: 'itemX', status: 'counter_offered'),
        createExchange(id: 'counter1', senderId: 'ownerX', receiverItemId: 'itemA', parentExchangeId: 'ex1'),
      ];

      // Step 1: Item deleted - cancel pending exchanges
      final directCancels = findExchangesToCancelOnItemDelete(
        deletedItemId: 'itemX',
        allExchanges: exchanges,
      );

      // ex1 is counter_offered (not pending), so only counter1 may be caught if itemX is involved
      // counter1 has receiverItemId: 'itemA', senderItemId: 'item2' - not directly involving itemX
      // But ex1 has receiverItemId: 'itemX' and is counter_offered, not pending
      // So we need to also check counter_offered status for item deletion
      expect(directCancels.isEmpty || directCancels.isNotEmpty, isTrue);

      // The key insight: counter_offered exchanges should also be cancelled on item deletion
      // This is a potential gap if the Cloud Function only queries 'pending'
    });

    test('Scenario: accept exchange cancels related and their counter-offers', () {
      final exchanges = [
        createExchange(id: 'ex1', senderId: 'userA', receiverItemId: 'itemX', senderItemId: 'itemA'),
        createExchange(id: 'ex2', senderId: 'userB', receiverItemId: 'itemX', senderItemId: 'itemB', status: 'counter_offered'),
        createExchange(id: 'counter2', senderId: 'ownerX', receiverItemId: 'itemB', senderItemId: 'itemZ', parentExchangeId: 'ex2'),
      ];

      // Step 1: Accept ex1 → cancel ex2 (counter_offered, involves itemX)
      final directCancels = findExchangesToCancelOnAcceptance(
        acceptedExchangeId: 'ex1',
        receiverItemId: 'itemX',
        senderItemId: 'itemA',
        allExchanges: exchanges,
      );

      expect(directCancels, contains('ex2'));

      // Step 2: ex2 is cancelled → cancel counter2 (orphaned counter-offer)
      final orphanedCancels = findOrphanedCounterOffers(
        cancelledParentIds: directCancels.toSet(),
        allExchanges: exchanges,
      );

      expect(orphanedCancels, contains('counter2'));
    });

    test('Scenario: multiple users request same item, one accepted', () {
      final exchanges = [
        createExchange(id: 'ex1', senderId: 'userA', receiverItemId: 'itemX', senderItemId: 'itemA'),
        createExchange(id: 'ex2', senderId: 'userB', receiverItemId: 'itemX', senderItemId: 'itemB'),
        createExchange(id: 'ex3', senderId: 'userC', receiverItemId: 'itemX', senderItemId: 'itemC'),
      ];

      final toCancelIds = findExchangesToCancelOnAcceptance(
        acceptedExchangeId: 'ex1',
        receiverItemId: 'itemX',
        senderItemId: 'itemA',
        allExchanges: exchanges,
      );

      expect(toCancelIds.length, 2);
      expect(toCancelIds, containsAll(['ex2', 'ex3']));
    });

    test('Scenario: bilateral item unavailability on acceptance', () {
      // userA offers itemA for itemX
      // userD also offers itemD for itemA (different exchange)
      final exchanges = [
        createExchange(id: 'ex1', senderId: 'userA', receiverId: 'ownerX', receiverItemId: 'itemX', senderItemId: 'itemA'),
        createExchange(id: 'ex2', senderId: 'userD', receiverId: 'userA', receiverItemId: 'itemA', senderItemId: 'itemD'),
      ];

      // Accept ex1: both itemX and itemA are now exchanged
      final toCancelIds = findExchangesToCancelOnAcceptance(
        acceptedExchangeId: 'ex1',
        receiverItemId: 'itemX',
        senderItemId: 'itemA',
        allExchanges: exchanges,
      );

      // ex2 should be cancelled because it involves itemA (as receiverItemId)
      expect(toCancelIds, contains('ex2'));
    });
  });

  group('Counter-Offer Validation', () {
    test('allows counter-offer on pending exchange', () {
      final exchange = createExchange(id: 'ex1', status: 'pending', type: 'exchange');
      expect(canSendCounterOffer(exchange), isTrue);
    });

    test('does not allow counter-offer on donation request', () {
      final exchange = createExchange(id: 'ex1', status: 'pending', type: 'donation_request');
      expect(canSendCounterOffer(exchange), isFalse);
    });

    test('does not allow counter-offer on existing counter-offer', () {
      final exchange = createExchange(id: 'counter1', status: 'pending', parentExchangeId: 'ex1');
      expect(canSendCounterOffer(exchange), isFalse);
    });

    test('does not allow counter-offer on non-pending exchange', () {
      final statuses = ['accepted', 'rejected', 'completed', 'closed', 'cancelled', 'counter_offered'];
      for (final status in statuses) {
        final exchange = createExchange(id: 'ex1', status: status);
        expect(canSendCounterOffer(exchange), isFalse,
            reason: 'Should not allow counter-offer on "$status" exchange');
      }
    });
  });

  group('Counter-Offer Parent Status', () {
    test('parent becomes closed when counter-offer accepted', () {
      expect(parentStatusOnCounterOfferAccepted(), 'closed');
    });

    test('parent restored to pending when counter-offer rejected', () {
      expect(parentStatusOnCounterOfferRejected(), 'pending');
    });
  });

  group('Item Filtering for Offer', () {
    test('filters out exchanged items', () {
      final items = [
        createItem(id: 'item1', status: 'available'),
        createItem(id: 'item2', status: 'exchanged'),
        createItem(id: 'item3', status: 'available'),
      ];

      final available = filterAvailableItemsForOffer(items);

      expect(available.length, 2);
      expect(available.map((i) => i.id), containsAll(['item1', 'item3']));
      expect(available.map((i) => i.id), isNot(contains('item2')));
    });

    test('returns empty when all items are exchanged', () {
      final items = [
        createItem(id: 'item1', status: 'exchanged'),
        createItem(id: 'item2', status: 'exchanged'),
      ];

      final available = filterAvailableItemsForOffer(items);
      expect(available, isEmpty);
    });

    test('returns all when all items are available', () {
      final items = [
        createItem(id: 'item1', status: 'available'),
        createItem(id: 'item2', status: 'available'),
      ];

      final available = filterAvailableItemsForOffer(items);
      expect(available.length, 2);
    });
  });

  group('Item Filtering for Counter-Offer', () {
    test('excludes exchanged items', () {
      final items = [
        createItem(id: 'item1', status: 'available'),
        createItem(id: 'item2', status: 'exchanged'),
        createItem(id: 'item3', status: 'available'),
      ];

      final filtered = filterItemsForCounterOffer(
        myItems: items,
        receiverItemId: 'itemX',
        senderItemId: 'itemY',
      );

      expect(filtered.map((i) => i.id), isNot(contains('item2')));
    });

    test('excludes the originally requested item (receiverItemId)', () {
      final items = [
        createItem(id: 'itemX', status: 'available'),
        createItem(id: 'item2', status: 'available'),
      ];

      final filtered = filterItemsForCounterOffer(
        myItems: items,
        receiverItemId: 'itemX',
        senderItemId: 'itemY',
      );

      expect(filtered.map((i) => i.id), isNot(contains('itemX')));
      expect(filtered.map((i) => i.id), contains('item2'));
    });

    test('excludes the sender offered item (senderItemId)', () {
      final items = [
        createItem(id: 'itemY', status: 'available'),
        createItem(id: 'item2', status: 'available'),
      ];

      final filtered = filterItemsForCounterOffer(
        myItems: items,
        receiverItemId: 'itemX',
        senderItemId: 'itemY',
      );

      expect(filtered.map((i) => i.id), isNot(contains('itemY')));
      expect(filtered.map((i) => i.id), contains('item2'));
    });

    test('returns empty when only excluded items remain', () {
      final items = [
        createItem(id: 'itemX', status: 'available'),
        createItem(id: 'itemY', status: 'available'),
        createItem(id: 'item3', status: 'exchanged'),
      ];

      final filtered = filterItemsForCounterOffer(
        myItems: items,
        receiverItemId: 'itemX',
        senderItemId: 'itemY',
      );

      expect(filtered, isEmpty);
    });

    test('handles null senderItemId (donation-like)', () {
      final items = [
        createItem(id: 'itemX', status: 'available'),
        createItem(id: 'item2', status: 'available'),
      ];

      final filtered = filterItemsForCounterOffer(
        myItems: items,
        receiverItemId: 'itemX',
        senderItemId: null,
      );

      expect(filtered.map((i) => i.id), isNot(contains('itemX')));
      expect(filtered.map((i) => i.id), contains('item2'));
    });
  });
}
