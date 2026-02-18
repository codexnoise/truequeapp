const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.sendExchangeNotification = functions.firestore
  .document('exchanges/{exchangeId}')
  .onCreate(async (snap, context) => {
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
        console.log('No FCM token for receiver');
        return null;
      }

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

      const notification = {
        token: fcmToken,
        notification: {
          title: title,
          body: body,
          sound: 'default',
          badge: '1',
        },
        data: {
          type: 'exchange_request',
          exchangeId: context.params.exchangeId,
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
      const response = await admin.messaging().send(notification);
      console.log('Notification sent successfully:', response);

      // Mark notification as sent
      await snap.ref.update({ notificationSent: true });

      return response;
    } catch (error) {
      console.error('Error sending notification:', error);
      return null;
    }
  });

// Handle notification updates (optional)
exports.updateNotificationStatus = functions.firestore
  .document('exchanges/{exchangeId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Send notification when status changes
    if (before.status !== after.status) {
      try {
        const receiverDoc = await admin.firestore()
          .collection('users')
          .doc(after.senderId) // Notify sender about status change
          .get();

        if (!receiverDoc.exists) return null;

        const receiverData = receiverDoc.data();
        const fcmToken = receiverData.fcmToken;

        if (!fcmToken) return null;

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

        const notification = {
          token: fcmToken,
          notification: {
            title: title,
            body: body,
            sound: 'default',
          },
          data: {
            type: 'exchange_status_update',
            exchangeId: context.params.exchangeId,
            status: after.status,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
        };

        await admin.messaging().send(notification);
        console.log('Status update notification sent');
      } catch (error) {
        console.error('Error sending status update:', error);
      }
    }

    return null;
  });
