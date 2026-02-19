const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

admin.initializeApp();

exports.sendExchangeNotification = onDocumentCreated(
  'exchanges/{exchangeId}',
  async (event) => {
    const snap = event.data;
    const exchange = snap.data();

    // Don't send notification if already sent
    if (exchange.notificationSent) {
      return null;
    }

    try {
      // Get receiver's FCM token
      const receiverDoc = await admin.firestore()
        .collection('users')
        .doc(exchange.receiverId)
        .get();

      if (!receiverDoc.exists) {
        console.log('Receiver not found');
        return null;
      }

      const receiverData = receiverDoc.data();
      const fcmToken = receiverData.fcmToken;

      if (!fcmToken) {
        console.log('No FCM token for receiver:', exchange.receiverId);
        return null;
      }

      console.log('Attempting to send notification to token:', fcmToken);

      // Get item details
      const itemDoc = await admin.firestore()
        .collection('items')
        .doc(exchange.receiverItemId)
        .get();

      if (!itemDoc.exists) {
        console.log('Item not found');
        return null;
      }

      const item = itemDoc.data();

      // Get sender details
      const senderDoc = await admin.firestore()
        .collection('users')
        .doc(exchange.senderId)
        .get();

      if (!senderDoc.exists) {
        console.log('Sender not found');
        return null;
      }

      const sender = senderDoc.data();

      // Prepare notification
      const isDonation = exchange.type === 'donation_request';
      const title = isDonation ? '¡Nueva solicitud de donación!' : '¡Nueva propuesta de intercambio!';
      const body = isDonation
        ? `${sender.displayName || 'Alguien'} ha solicitado tu artículo "${item.title}"`
        : `${sender.displayName || 'Alguien'} quiere intercambiar por "${item.title}"`;

      const message = {
        token: fcmToken,
        notification: {
          title: title,
          body: body,
        },
        data: {
          type: 'exchange_request',
          exchangeId: event.params.exchangeId,
          senderId: exchange.senderId,
          receiverItemId: exchange.receiverItemId,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            priority: 'high',
            sound: 'default',
            channelId: 'exchange_requests',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
              category: 'EXCHANGE_REQUEST',
            },
          },
        },
      };

      // Send notification
      const response = await admin.messaging().send(message);
      console.log('Notification sent successfully:', response);

      // Mark notification as sent
      await snap.ref.update({ notificationSent: true });

      return response;
    } catch (error) {
      console.error('Error sending notification:', error);
      return null;
    }
  }
);

// Handle notification updates (optional)
exports.updateNotificationStatus = onDocumentUpdated(
  'exchanges/{exchangeId}',
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    // Send notification when status changes
    if (before.status !== after.status) {
      try {
        const senderDoc = await admin.firestore()
          .collection('users')
          .doc(after.senderId) // Notify sender about status change
          .get();

        if (!senderDoc.exists) return null;

        const senderData = senderDoc.data();
        const fcmToken = senderData.fcmToken;

        if (!fcmToken) {
        console.log('No FCM token for sender:', after.senderId);
        return null;
      }

      console.log('Attempting to send status update to token:', fcmToken);

        let title, body;

        switch (after.status) {
          case 'accepted':
            title = '¡Propuesta aceptada!';
            body = 'Tu propuesta ha sido aceptada. Contacta con el otro usuario para coordinar el intercambio.';
            break;
          case 'rejected':
            title = 'Propuesta rechazada';
            body = 'Tu propuesta ha sido rechazada. Puedes intentar con otros artículos.';
            break;
          case 'completed':
            title = '¡Intercambio completado!';
            body = 'El intercambio ha sido marcado como completado. ¡Gracias por usar TruequeApp!';
            break;
          default:
            return null;
        }

        const message = {
          token: fcmToken,
          notification: {
            title: title,
            body: body,
          },
          data: {
            type: 'exchange_status_update',
            exchangeId: event.params.exchangeId,
            status: after.status,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          android: {
            priority: 'high',
            notification: {
              sound: 'default',
              channelId: 'exchange_requests',
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
        };

        await admin.messaging().send(message);
        console.log('Status update notification sent');
      } catch (error) {
        console.error('Error sending status update:', error);
      }
    }

    return null;
  }
);
