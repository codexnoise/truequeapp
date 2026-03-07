import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Replicates the _statusLabel logic from _ExchangeDetailBody
String statusLabel(String status) {
  return switch (status) {
    'pending' => 'Pendiente',
    'accepted' => 'Aceptado',
    'rejected' => 'Rechazado',
    'completed' => 'Completado',
    'counter_offered' => 'Contraoferta enviada',
    'closed' => 'Cerrado por contraoferta aceptada',
    'cancelled' => 'Cancelado',
    _ => status,
  };
}

/// Replicates the _statusInfo logic from _ExchangeCard in my_items_page.dart
(Color, String) statusInfo(String status) {
  return switch (status) {
    'pending' => (Colors.orange, 'Pendiente'),
    'accepted' => (Colors.green, 'Aceptado'),
    'rejected' => (Colors.red, 'Rechazado'),
    'completed' => (Colors.blue, 'Completado'),
    'counter_offered' => (Colors.purple, 'Contraoferta'),
    'closed' => (Colors.grey[600]!, 'Cerrada'),
    'cancelled' => (Colors.red[700]!, 'Cancelada'),
    _ => (Colors.grey, status),
  };
}

/// Replicates the _StatusBadge logic from exchange_detail_page.dart
(Color, String) statusBadgeInfo(String status, bool isDonation) {
  return switch (status) {
    'pending' => (
      Colors.orange[700]!,
      isDonation ? 'SOLICITUD DE DONACIÓN PENDIENTE' : 'PROPUESTA PENDIENTE',
    ),
    'accepted' => (Colors.green[700]!, 'ACEPTADO'),
    'rejected' => (Colors.red[700]!, 'RECHAZADO'),
    'completed' => (Colors.blue[700]!, 'COMPLETADO'),
    'counter_offered' => (Colors.purple[700]!, 'CONTRAOFERTA ENVIADA'),
    'closed' => (Colors.grey[700]!, 'CERRADO POR CONTRAOFERTA ACEPTADA'),
    'cancelled' => (Colors.red[700]!, 'CANCELADO - ARTÍCULO NO DISPONIBLE'),
    _ => (Colors.grey[700]!, status.toUpperCase()),
  };
}

void main() {
  group('Exchange Status Labels (_statusLabel)', () {
    test('pending returns Pendiente', () {
      expect(statusLabel('pending'), 'Pendiente');
    });

    test('accepted returns Aceptado', () {
      expect(statusLabel('accepted'), 'Aceptado');
    });

    test('rejected returns Rechazado', () {
      expect(statusLabel('rejected'), 'Rechazado');
    });

    test('completed returns Completado', () {
      expect(statusLabel('completed'), 'Completado');
    });

    test('counter_offered returns Contraoferta enviada', () {
      expect(statusLabel('counter_offered'), 'Contraoferta enviada');
    });

    test('closed returns Cerrado por contraoferta aceptada', () {
      expect(statusLabel('closed'), 'Cerrado por contraoferta aceptada');
    });

    test('cancelled returns Cancelado', () {
      expect(statusLabel('cancelled'), 'Cancelado');
    });

    test('unknown status returns raw status', () {
      expect(statusLabel('some_unknown'), 'some_unknown');
    });

    test('all known statuses have translations', () {
      final knownStatuses = [
        'pending',
        'accepted',
        'rejected',
        'completed',
        'counter_offered',
        'closed',
        'cancelled',
      ];

      for (final status in knownStatuses) {
        final label = statusLabel(status);
        expect(label, isNot(equals(status)),
            reason: 'Status "$status" should have a translated label, got "$label"');
      }
    });
  });

  group('Exchange Status Info (_statusInfo for list)', () {
    test('pending has orange color', () {
      final (color, label) = statusInfo('pending');
      expect(color, Colors.orange);
      expect(label, 'Pendiente');
    });

    test('accepted has green color', () {
      final (color, label) = statusInfo('accepted');
      expect(color, Colors.green);
      expect(label, 'Aceptado');
    });

    test('rejected has red color', () {
      final (color, label) = statusInfo('rejected');
      expect(color, Colors.red);
      expect(label, 'Rechazado');
    });

    test('completed has blue color', () {
      final (color, label) = statusInfo('completed');
      expect(color, Colors.blue);
      expect(label, 'Completado');
    });

    test('counter_offered has purple color', () {
      final (color, label) = statusInfo('counter_offered');
      expect(color, Colors.purple);
      expect(label, 'Contraoferta');
    });

    test('closed has grey color', () {
      final (color, label) = statusInfo('closed');
      expect(color, Colors.grey[600]);
      expect(label, 'Cerrada');
    });

    test('cancelled has dark red color', () {
      final (color, label) = statusInfo('cancelled');
      expect(color, Colors.red[700]);
      expect(label, 'Cancelada');
    });

    test('unknown status has grey color and raw label', () {
      final (color, label) = statusInfo('xyz');
      expect(color, Colors.grey);
      expect(label, 'xyz');
    });
  });

  group('Status Badge Info (_StatusBadge)', () {
    test('pending exchange shows PROPUESTA PENDIENTE', () {
      final (_, label) = statusBadgeInfo('pending', false);
      expect(label, 'PROPUESTA PENDIENTE');
    });

    test('pending donation shows SOLICITUD DE DONACIÓN PENDIENTE', () {
      final (_, label) = statusBadgeInfo('pending', true);
      expect(label, 'SOLICITUD DE DONACIÓN PENDIENTE');
    });

    test('accepted shows ACEPTADO', () {
      final (_, label) = statusBadgeInfo('accepted', false);
      expect(label, 'ACEPTADO');
    });

    test('rejected shows RECHAZADO', () {
      final (_, label) = statusBadgeInfo('rejected', false);
      expect(label, 'RECHAZADO');
    });

    test('counter_offered shows CONTRAOFERTA ENVIADA', () {
      final (_, label) = statusBadgeInfo('counter_offered', false);
      expect(label, 'CONTRAOFERTA ENVIADA');
    });

    test('closed shows CERRADO POR CONTRAOFERTA ACEPTADA', () {
      final (_, label) = statusBadgeInfo('closed', false);
      expect(label, 'CERRADO POR CONTRAOFERTA ACEPTADA');
    });

    test('cancelled shows CANCELADO - ARTÍCULO NO DISPONIBLE', () {
      final (color, label) = statusBadgeInfo('cancelled', false);
      expect(label, 'CANCELADO - ARTÍCULO NO DISPONIBLE');
      expect(color, Colors.red[700]);
    });

    test('unknown status returns uppercased', () {
      final (_, label) = statusBadgeInfo('custom_status', false);
      expect(label, 'CUSTOM_STATUS');
    });
  });
}
