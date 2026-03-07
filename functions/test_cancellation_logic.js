/**
 * Unit tests for Cloud Functions cancellation logic.
 * Uses Node.js built-in assert module (no extra dependencies).
 * 
 * Run: node test_cancellation_logic.js
 */

const assert = require('assert');

// ============================================================================
// Pure logic functions extracted from Cloud Functions for testing
// ============================================================================

/**
 * Determines which exchanges should be cancelled when an exchange is accepted.
 * Replicates the logic in updateNotificationStatus Cloud Function.
 */
function findExchangesToCancelOnAcceptance({
  acceptedExchangeId,
  receiverItemId,
  senderItemId,
  allExchanges, // Array of { id, receiverItemId, senderItemId, status, parentExchangeId, senderId, receiverId }
}) {
  const cancelIds = [];

  for (const exchange of allExchanges) {
    if (exchange.id === acceptedExchangeId) continue;
    if (exchange.status !== 'pending' && exchange.status !== 'counter_offered') continue;

    const involvesItem =
      exchange.receiverItemId === receiverItemId ||
      exchange.receiverItemId === senderItemId ||
      (exchange.senderItemId && exchange.senderItemId === receiverItemId) ||
      (exchange.senderItemId && exchange.senderItemId === senderItemId);

    if (involvesItem) {
      cancelIds.push(exchange.id);
    }
  }

  return cancelIds;
}

/**
 * Determines which exchanges should be cancelled when an item is deleted.
 * Replicates the logic in cancelExchangesOnItemDelete Cloud Function.
 */
function findExchangesToCancelOnItemDelete({ deletedItemId, allExchanges }) {
  const cancelIds = [];

  for (const exchange of allExchanges) {
    if (exchange.status !== 'pending') continue;

    if (
      exchange.receiverItemId === deletedItemId ||
      (exchange.senderItemId && exchange.senderItemId === deletedItemId)
    ) {
      cancelIds.push(exchange.id);
    }
  }

  return cancelIds;
}

/**
 * Finds orphaned counter-offers whose parent exchange was cancelled.
 */
function findOrphanedCounterOffers({ cancelledParentIds, allExchanges }) {
  const cancelIds = [];

  for (const exchange of allExchanges) {
    if (exchange.status !== 'pending') continue;
    if (exchange.parentExchangeId && cancelledParentIds.has(exchange.parentExchangeId)) {
      cancelIds.push(exchange.id);
    }
  }

  return cancelIds;
}

/**
 * Determines which users should be notified for a set of cancelled exchanges.
 */
function getUsersToNotify(cancelledExchanges) {
  const users = new Set();
  for (const exchange of cancelledExchanges) {
    users.add(exchange.senderId);
    users.add(exchange.receiverId);
  }
  return users;
}

/**
 * Determines the notification message for a status change.
 */
function getNotificationForStatus(status) {
  switch (status) {
    case 'accepted':
      return { title: '¡Propuesta aceptada!', type: 'exchange_accepted' };
    case 'rejected':
      return { title: 'Propuesta rechazada', type: 'exchange_rejected' };
    case 'counter_offered':
      return { title: 'Nueva contraoferta', type: 'exchange_counter_offered' };
    case 'completed':
      return { title: '¡Intercambio completado!', type: 'exchange_completed' };
    case 'cancelled':
      return { title: 'Intercambio cancelado', type: 'exchange_cancelled' };
    default:
      return null;
  }
}

/**
 * Determines the parent exchange status based on counter-offer action.
 */
function getParentStatusOnCounterOfferAction(action) {
  if (action === 'accepted') return 'closed';
  if (action === 'rejected') return 'pending';
  return null;
}

// ============================================================================
// Test runner
// ============================================================================

let passed = 0;
let failed = 0;
const failures = [];

function test(name, fn) {
  try {
    fn();
    passed++;
    console.log(`  ✅ ${name}`);
  } catch (e) {
    failed++;
    failures.push({ name, error: e.message });
    console.log(`  ❌ ${name}`);
    console.log(`     ${e.message}`);
  }
}

function group(name, fn) {
  console.log(`\n📦 ${name}`);
  fn();
}

// ============================================================================
// Tests
// ============================================================================

group('Exchange Cancellation on Acceptance', () => {
  test('cancels other pending exchanges for same receiverItem', () => {
    const exchanges = [
      { id: 'ex1', receiverItemId: 'itemX', senderItemId: 'itemA', status: 'pending', senderId: 'userA', receiverId: 'ownerX' },
      { id: 'ex2', receiverItemId: 'itemX', senderItemId: 'itemB', status: 'pending', senderId: 'userB', receiverId: 'ownerX' },
      { id: 'ex3', receiverItemId: 'itemX', senderItemId: 'itemC', status: 'pending', senderId: 'userC', receiverId: 'ownerX' },
    ];

    const result = findExchangesToCancelOnAcceptance({
      acceptedExchangeId: 'ex1',
      receiverItemId: 'itemX',
      senderItemId: 'itemA',
      allExchanges: exchanges,
    });

    assert.ok(result.includes('ex2'), 'Should cancel ex2');
    assert.ok(result.includes('ex3'), 'Should cancel ex3');
    assert.ok(!result.includes('ex1'), 'Should NOT cancel accepted exchange');
  });

  test('cancels exchanges involving senderItem as receiverItem in another exchange', () => {
    const exchanges = [
      { id: 'ex1', receiverItemId: 'itemX', senderItemId: 'itemA', status: 'pending', senderId: 'userA', receiverId: 'ownerX' },
      { id: 'ex2', receiverItemId: 'itemA', senderItemId: 'itemD', status: 'pending', senderId: 'userD', receiverId: 'userA' },
    ];

    const result = findExchangesToCancelOnAcceptance({
      acceptedExchangeId: 'ex1',
      receiverItemId: 'itemX',
      senderItemId: 'itemA',
      allExchanges: exchanges,
    });

    assert.ok(result.includes('ex2'), 'Should cancel ex2 (involves itemA as receiverItem)');
  });

  test('cancels exchanges involving senderItem as senderItem in another exchange', () => {
    const exchanges = [
      { id: 'ex1', receiverItemId: 'itemX', senderItemId: 'itemA', status: 'pending', senderId: 'userA', receiverId: 'ownerX' },
      { id: 'ex2', receiverItemId: 'itemY', senderItemId: 'itemA', status: 'pending', senderId: 'userA', receiverId: 'ownerY' },
    ];

    const result = findExchangesToCancelOnAcceptance({
      acceptedExchangeId: 'ex1',
      receiverItemId: 'itemX',
      senderItemId: 'itemA',
      allExchanges: exchanges,
    });

    assert.ok(result.includes('ex2'), 'Should cancel ex2 (involves itemA as senderItem)');
  });

  test('does NOT cancel unrelated exchanges', () => {
    const exchanges = [
      { id: 'ex1', receiverItemId: 'itemX', senderItemId: 'itemA', status: 'pending', senderId: 'userA', receiverId: 'ownerX' },
      { id: 'ex2', receiverItemId: 'itemY', senderItemId: 'itemD', status: 'pending', senderId: 'userD', receiverId: 'ownerY' },
    ];

    const result = findExchangesToCancelOnAcceptance({
      acceptedExchangeId: 'ex1',
      receiverItemId: 'itemX',
      senderItemId: 'itemA',
      allExchanges: exchanges,
    });

    assert.strictEqual(result.length, 0, 'Should not cancel unrelated exchanges');
  });

  test('does NOT cancel already rejected exchanges', () => {
    const exchanges = [
      { id: 'ex1', receiverItemId: 'itemX', senderItemId: 'itemA', status: 'pending', senderId: 'userA', receiverId: 'ownerX' },
      { id: 'ex2', receiverItemId: 'itemX', senderItemId: 'itemB', status: 'rejected', senderId: 'userB', receiverId: 'ownerX' },
    ];

    const result = findExchangesToCancelOnAcceptance({
      acceptedExchangeId: 'ex1',
      receiverItemId: 'itemX',
      senderItemId: 'itemA',
      allExchanges: exchanges,
    });

    assert.ok(!result.includes('ex2'), 'Should NOT cancel rejected exchange');
  });

  test('cancels counter_offered status exchanges', () => {
    const exchanges = [
      { id: 'ex1', receiverItemId: 'itemX', senderItemId: 'itemA', status: 'pending', senderId: 'userA', receiverId: 'ownerX' },
      { id: 'ex2', receiverItemId: 'itemX', senderItemId: 'itemB', status: 'counter_offered', senderId: 'userB', receiverId: 'ownerX' },
    ];

    const result = findExchangesToCancelOnAcceptance({
      acceptedExchangeId: 'ex1',
      receiverItemId: 'itemX',
      senderItemId: 'itemA',
      allExchanges: exchanges,
    });

    assert.ok(result.includes('ex2'), 'Should cancel counter_offered exchange');
  });

  test('does NOT cancel the accepted exchange itself', () => {
    const exchanges = [
      { id: 'ex1', receiverItemId: 'itemX', senderItemId: 'itemA', status: 'pending', senderId: 'userA', receiverId: 'ownerX' },
    ];

    const result = findExchangesToCancelOnAcceptance({
      acceptedExchangeId: 'ex1',
      receiverItemId: 'itemX',
      senderItemId: 'itemA',
      allExchanges: exchanges,
    });

    assert.strictEqual(result.length, 0, 'Should NOT cancel itself');
  });

  test('handles donation exchanges (null senderItemId)', () => {
    const exchanges = [
      { id: 'ex1', receiverItemId: 'itemX', senderItemId: null, status: 'pending', senderId: 'userA', receiverId: 'ownerX' },
      { id: 'ex2', receiverItemId: 'itemX', senderItemId: null, status: 'pending', senderId: 'userB', receiverId: 'ownerX' },
    ];

    const result = findExchangesToCancelOnAcceptance({
      acceptedExchangeId: 'ex1',
      receiverItemId: 'itemX',
      senderItemId: null,
      allExchanges: exchanges,
    });

    assert.ok(result.includes('ex2'), 'Should cancel other donation request');
  });

  test('does NOT cancel already completed exchanges', () => {
    const exchanges = [
      { id: 'ex1', receiverItemId: 'itemX', senderItemId: 'itemA', status: 'pending', senderId: 'userA', receiverId: 'ownerX' },
      { id: 'ex2', receiverItemId: 'itemX', senderItemId: 'itemB', status: 'completed', senderId: 'userB', receiverId: 'ownerX' },
    ];

    const result = findExchangesToCancelOnAcceptance({
      acceptedExchangeId: 'ex1',
      receiverItemId: 'itemX',
      senderItemId: 'itemA',
      allExchanges: exchanges,
    });

    assert.ok(!result.includes('ex2'), 'Should NOT cancel completed exchange');
  });

  test('does NOT cancel closed exchanges', () => {
    const exchanges = [
      { id: 'ex1', receiverItemId: 'itemX', senderItemId: 'itemA', status: 'pending', senderId: 'userA', receiverId: 'ownerX' },
      { id: 'ex2', receiverItemId: 'itemX', senderItemId: 'itemB', status: 'closed', senderId: 'userB', receiverId: 'ownerX' },
    ];

    const result = findExchangesToCancelOnAcceptance({
      acceptedExchangeId: 'ex1',
      receiverItemId: 'itemX',
      senderItemId: 'itemA',
      allExchanges: exchanges,
    });

    assert.ok(!result.includes('ex2'), 'Should NOT cancel closed exchange');
  });
});

group('Exchange Cancellation on Item Delete', () => {
  test('cancels pending exchanges where deleted item is receiverItem', () => {
    const exchanges = [
      { id: 'ex1', receiverItemId: 'itemX', senderItemId: 'itemA', status: 'pending', senderId: 'userA', receiverId: 'ownerX' },
      { id: 'ex2', receiverItemId: 'itemX', senderItemId: 'itemB', status: 'pending', senderId: 'userB', receiverId: 'ownerX' },
      { id: 'ex3', receiverItemId: 'itemY', senderItemId: 'itemC', status: 'pending', senderId: 'userC', receiverId: 'ownerY' },
    ];

    const result = findExchangesToCancelOnItemDelete({
      deletedItemId: 'itemX',
      allExchanges: exchanges,
    });

    assert.ok(result.includes('ex1'));
    assert.ok(result.includes('ex2'));
    assert.ok(!result.includes('ex3'));
  });

  test('cancels pending exchanges where deleted item is senderItem', () => {
    const exchanges = [
      { id: 'ex1', receiverItemId: 'itemY', senderItemId: 'itemX', status: 'pending', senderId: 'userA', receiverId: 'ownerY' },
    ];

    const result = findExchangesToCancelOnItemDelete({
      deletedItemId: 'itemX',
      allExchanges: exchanges,
    });

    assert.ok(result.includes('ex1'));
  });

  test('does NOT cancel non-pending exchanges', () => {
    const exchanges = [
      { id: 'ex1', receiverItemId: 'itemX', senderItemId: 'itemA', status: 'accepted', senderId: 'userA', receiverId: 'ownerX' },
      { id: 'ex2', receiverItemId: 'itemX', senderItemId: 'itemB', status: 'rejected', senderId: 'userB', receiverId: 'ownerX' },
      { id: 'ex3', receiverItemId: 'itemX', senderItemId: 'itemC', status: 'completed', senderId: 'userC', receiverId: 'ownerX' },
      { id: 'ex4', receiverItemId: 'itemX', senderItemId: 'itemD', status: 'closed', senderId: 'userD', receiverId: 'ownerX' },
    ];

    const result = findExchangesToCancelOnItemDelete({
      deletedItemId: 'itemX',
      allExchanges: exchanges,
    });

    assert.strictEqual(result.length, 0, 'Should not cancel non-pending exchanges');
  });

  test('does NOT cancel exchanges for unrelated items', () => {
    const exchanges = [
      { id: 'ex1', receiverItemId: 'itemY', senderItemId: 'itemZ', status: 'pending', senderId: 'userA', receiverId: 'ownerY' },
    ];

    const result = findExchangesToCancelOnItemDelete({
      deletedItemId: 'itemX',
      allExchanges: exchanges,
    });

    assert.strictEqual(result.length, 0);
  });
});

group('Orphaned Counter-Offers Cancellation', () => {
  test('cancels counter-offer when parent exchange is cancelled', () => {
    const exchanges = [
      { id: 'counter1', receiverItemId: 'itemA', senderItemId: 'itemB', status: 'pending', parentExchangeId: 'ex1', senderId: 'userA', receiverId: 'userB' },
    ];

    const result = findOrphanedCounterOffers({
      cancelledParentIds: new Set(['ex1']),
      allExchanges: exchanges,
    });

    assert.ok(result.includes('counter1'));
  });

  test('does NOT cancel counter-offers with non-cancelled parents', () => {
    const exchanges = [
      { id: 'counter1', receiverItemId: 'itemA', senderItemId: 'itemB', status: 'pending', parentExchangeId: 'ex2', senderId: 'userA', receiverId: 'userB' },
    ];

    const result = findOrphanedCounterOffers({
      cancelledParentIds: new Set(['ex1']),
      allExchanges: exchanges,
    });

    assert.strictEqual(result.length, 0);
  });

  test('does NOT cancel regular exchanges without parentExchangeId', () => {
    const exchanges = [
      { id: 'ex3', receiverItemId: 'itemA', senderItemId: 'itemB', status: 'pending', senderId: 'userA', receiverId: 'userB' },
    ];

    const result = findOrphanedCounterOffers({
      cancelledParentIds: new Set(['ex1']),
      allExchanges: exchanges,
    });

    assert.strictEqual(result.length, 0);
  });

  test('cancels multiple counter-offers for same parent', () => {
    const exchanges = [
      { id: 'counter1', receiverItemId: 'itemA', senderItemId: 'itemB', status: 'pending', parentExchangeId: 'ex1', senderId: 'userA', receiverId: 'userB' },
      { id: 'counter2', receiverItemId: 'itemC', senderItemId: 'itemD', status: 'pending', parentExchangeId: 'ex1', senderId: 'userC', receiverId: 'userB' },
    ];

    const result = findOrphanedCounterOffers({
      cancelledParentIds: new Set(['ex1']),
      allExchanges: exchanges,
    });

    assert.ok(result.includes('counter1'));
    assert.ok(result.includes('counter2'));
  });

  test('only cancels pending counter-offers', () => {
    const exchanges = [
      { id: 'counter1', receiverItemId: 'itemA', senderItemId: 'itemB', status: 'pending', parentExchangeId: 'ex1', senderId: 'userA', receiverId: 'userB' },
      { id: 'counter2', receiverItemId: 'itemC', senderItemId: 'itemD', status: 'rejected', parentExchangeId: 'ex1', senderId: 'userC', receiverId: 'userB' },
    ];

    const result = findOrphanedCounterOffers({
      cancelledParentIds: new Set(['ex1']),
      allExchanges: exchanges,
    });

    assert.ok(result.includes('counter1'));
    assert.ok(!result.includes('counter2'));
  });

  test('handles cascading cancellations with multiple parents', () => {
    const exchanges = [
      { id: 'counter1', receiverItemId: 'itemA', senderItemId: 'itemB', status: 'pending', parentExchangeId: 'ex1', senderId: 'userA', receiverId: 'userB' },
      { id: 'counter2', receiverItemId: 'itemC', senderItemId: 'itemD', status: 'pending', parentExchangeId: 'ex2', senderId: 'userC', receiverId: 'userD' },
      { id: 'counter3', receiverItemId: 'itemE', senderItemId: 'itemF', status: 'pending', parentExchangeId: 'ex3', senderId: 'userE', receiverId: 'userF' },
    ];

    const result = findOrphanedCounterOffers({
      cancelledParentIds: new Set(['ex1', 'ex2']),
      allExchanges: exchanges,
    });

    assert.ok(result.includes('counter1'));
    assert.ok(result.includes('counter2'));
    assert.ok(!result.includes('counter3'));
  });
});

group('Full Cancellation Cascade Scenarios', () => {
  test('Scenario: accept exchange cancels related + their counter-offers', () => {
    const exchanges = [
      { id: 'ex1', receiverItemId: 'itemX', senderItemId: 'itemA', status: 'pending', senderId: 'userA', receiverId: 'ownerX' },
      { id: 'ex2', receiverItemId: 'itemX', senderItemId: 'itemB', status: 'counter_offered', senderId: 'userB', receiverId: 'ownerX' },
      { id: 'counter2', receiverItemId: 'itemB', senderItemId: 'itemZ', status: 'pending', parentExchangeId: 'ex2', senderId: 'ownerX', receiverId: 'userB' },
    ];

    // Step 1: Accept ex1 → cancel ex2
    const directCancels = findExchangesToCancelOnAcceptance({
      acceptedExchangeId: 'ex1',
      receiverItemId: 'itemX',
      senderItemId: 'itemA',
      allExchanges: exchanges,
    });

    assert.ok(directCancels.includes('ex2'), 'ex2 should be cancelled (counter_offered, involves itemX)');

    // Step 2: ex2 cancelled → cancel counter2
    const orphanedCancels = findOrphanedCounterOffers({
      cancelledParentIds: new Set(directCancels),
      allExchanges: exchanges,
    });

    assert.ok(orphanedCancels.includes('counter2'), 'counter2 should be cancelled (orphaned counter-offer)');
  });

  test('Scenario: multiple users request same item, one accepted', () => {
    const exchanges = [
      { id: 'ex1', receiverItemId: 'itemX', senderItemId: 'itemA', status: 'pending', senderId: 'userA', receiverId: 'ownerX' },
      { id: 'ex2', receiverItemId: 'itemX', senderItemId: 'itemB', status: 'pending', senderId: 'userB', receiverId: 'ownerX' },
      { id: 'ex3', receiverItemId: 'itemX', senderItemId: 'itemC', status: 'pending', senderId: 'userC', receiverId: 'ownerX' },
    ];

    const result = findExchangesToCancelOnAcceptance({
      acceptedExchangeId: 'ex1',
      receiverItemId: 'itemX',
      senderItemId: 'itemA',
      allExchanges: exchanges,
    });

    assert.strictEqual(result.length, 2, 'Should cancel 2 exchanges');
    assert.ok(result.includes('ex2'));
    assert.ok(result.includes('ex3'));
  });

  test('Scenario: bilateral item unavailability', () => {
    const exchanges = [
      { id: 'ex1', receiverItemId: 'itemX', senderItemId: 'itemA', status: 'pending', senderId: 'userA', receiverId: 'ownerX' },
      { id: 'ex2', receiverItemId: 'itemA', senderItemId: 'itemD', status: 'pending', senderId: 'userD', receiverId: 'userA' },
    ];

    const result = findExchangesToCancelOnAcceptance({
      acceptedExchangeId: 'ex1',
      receiverItemId: 'itemX',
      senderItemId: 'itemA',
      allExchanges: exchanges,
    });

    assert.ok(result.includes('ex2'), 'ex2 should be cancelled (itemA no longer available)');
  });

  test('Scenario: item deleted with active exchanges and counter-offers', () => {
    const exchanges = [
      { id: 'ex1', receiverItemId: 'itemX', senderItemId: 'itemA', status: 'pending', senderId: 'userA', receiverId: 'ownerX' },
      { id: 'ex2', receiverItemId: 'itemX', senderItemId: 'itemB', status: 'pending', senderId: 'userB', receiverId: 'ownerX' },
      { id: 'counter1', receiverItemId: 'itemA', senderItemId: 'itemZ', status: 'pending', parentExchangeId: 'ex1', senderId: 'ownerX', receiverId: 'userA' },
    ];

    // Step 1: Delete itemX → cancel ex1, ex2
    const directCancels = findExchangesToCancelOnItemDelete({
      deletedItemId: 'itemX',
      allExchanges: exchanges,
    });

    assert.ok(directCancels.includes('ex1'));
    assert.ok(directCancels.includes('ex2'));

    // Step 2: ex1 cancelled → cancel counter1
    const orphanedCancels = findOrphanedCounterOffers({
      cancelledParentIds: new Set(directCancels),
      allExchanges: exchanges,
    });

    assert.ok(orphanedCancels.includes('counter1'), 'counter1 should be cancelled (parent ex1 cancelled)');
  });
});

group('Users to Notify', () => {
  test('notifies both sender and receiver of cancelled exchanges', () => {
    const exchanges = [
      { id: 'ex1', senderId: 'userA', receiverId: 'ownerX' },
      { id: 'ex2', senderId: 'userB', receiverId: 'ownerX' },
    ];

    const users = getUsersToNotify(exchanges);

    assert.ok(users.has('userA'));
    assert.ok(users.has('userB'));
    assert.ok(users.has('ownerX'));
    assert.strictEqual(users.size, 3, 'Should have 3 unique users');
  });

  test('deduplicates users across exchanges', () => {
    const exchanges = [
      { id: 'ex1', senderId: 'userA', receiverId: 'ownerX' },
      { id: 'ex2', senderId: 'userA', receiverId: 'ownerX' },
    ];

    const users = getUsersToNotify(exchanges);
    assert.strictEqual(users.size, 2, 'Should deduplicate');
  });
});

group('Notification Messages', () => {
  test('accepted status has correct notification', () => {
    const notif = getNotificationForStatus('accepted');
    assert.ok(notif !== null);
    assert.strictEqual(notif.type, 'exchange_accepted');
  });

  test('rejected status has correct notification', () => {
    const notif = getNotificationForStatus('rejected');
    assert.ok(notif !== null);
    assert.strictEqual(notif.type, 'exchange_rejected');
  });

  test('counter_offered status has correct notification', () => {
    const notif = getNotificationForStatus('counter_offered');
    assert.ok(notif !== null);
    assert.strictEqual(notif.type, 'exchange_counter_offered');
  });

  test('completed status has correct notification', () => {
    const notif = getNotificationForStatus('completed');
    assert.ok(notif !== null);
    assert.strictEqual(notif.type, 'exchange_completed');
  });

  test('cancelled status has correct notification', () => {
    const notif = getNotificationForStatus('cancelled');
    assert.ok(notif !== null);
    assert.strictEqual(notif.type, 'exchange_cancelled');
    assert.ok(notif.title.includes('cancelado'), 'Title should mention cancellation');
  });

  test('unknown status returns null', () => {
    const notif = getNotificationForStatus('some_random_status');
    assert.strictEqual(notif, null);
  });

  test('pending status returns null (no notification needed)', () => {
    const notif = getNotificationForStatus('pending');
    assert.strictEqual(notif, null);
  });
});

group('Parent Exchange Status on Counter-Offer Action', () => {
  test('parent becomes closed when counter-offer accepted', () => {
    assert.strictEqual(getParentStatusOnCounterOfferAction('accepted'), 'closed');
  });

  test('parent restored to pending when counter-offer rejected', () => {
    assert.strictEqual(getParentStatusOnCounterOfferAction('rejected'), 'pending');
  });

  test('other actions return null', () => {
    assert.strictEqual(getParentStatusOnCounterOfferAction('completed'), null);
    assert.strictEqual(getParentStatusOnCounterOfferAction('cancelled'), null);
  });
});

// ============================================================================
// Summary
// ============================================================================

console.log('\n' + '='.repeat(60));
console.log(`\n📊 Results: ${passed} passed, ${failed} failed, ${passed + failed} total\n`);

if (failures.length > 0) {
  console.log('❌ Failures:');
  failures.forEach(f => console.log(`   - ${f.name}: ${f.error}`));
  process.exit(1);
} else {
  console.log('✅ All tests passed!\n');
  process.exit(0);
}
