const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } = require('firebase-functions/v2/firestore');
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
        ? `${sender.name || 'Alguien'} ha solicitado tu artículo "${item.title}"`
        : `${sender.name || 'Alguien'} quiere intercambiar tu artículo "${item.title}"`;

      const message = {
        token: fcmToken,
        notification: {
          title: title,
          body: body,
        },
        data: {
          userId: exchange.receiverId,
          exchangeId: event.params.exchangeId,
          type: 'exchange_new',
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

    // If a counter-offer is accepted, close the parent exchange
    if (before.status !== 'accepted' && after.status === 'accepted' && after.parentExchangeId) {
      try {
        await admin.firestore()
          .collection('exchanges')
          .doc(after.parentExchangeId)
          .update({
            status: 'closed',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        console.log('Parent exchange closed:', after.parentExchangeId);
      } catch (error) {
        console.error('Error closing parent exchange:', error);
      }
    }

    // If a counter-offer is rejected, restore parent exchange to pending
    if (before.status !== 'rejected' && after.status === 'rejected' && after.parentExchangeId) {
      try {
        await admin.firestore()
          .collection('exchanges')
          .doc(after.parentExchangeId)
          .update({
            status: 'pending',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        console.log('Parent exchange restored to pending:', after.parentExchangeId);
      } catch (error) {
        console.error('Error restoring parent exchange:', error);
      }
    }

    // If an exchange is accepted, cancel all other pending exchanges for the same items
    if (before.status !== 'accepted' && after.status === 'accepted') {
      try {
        const receiverItemId = after.receiverItemId;
        const senderItemId = after.senderItemId;
        const acceptedExchangeId = event.params.exchangeId;

        // Find all pending AND counter_offered exchanges involving these items
        const pendingExchanges = await admin.firestore()
          .collection('exchanges')
          .where('status', '==', 'pending')
          .get();
        
        const counterOfferedExchanges = await admin.firestore()
          .collection('exchanges')
          .where('status', '==', 'counter_offered')
          .get();
        
        // Combine both query results
        const allExchanges = [...pendingExchanges.docs, ...counterOfferedExchanges.docs];

        const batch = admin.firestore().batch();
        const usersToNotify = new Set();
        const cancelledExchangeIds = new Set();

        allExchanges.forEach((doc) => {
          const exchange = doc.data();
          const exchangeId = doc.id;

          // Skip the accepted exchange itself
          if (exchangeId === acceptedExchangeId) return;

          // Check if this exchange involves either of the items
          if (exchange.receiverItemId === receiverItemId || 
              exchange.receiverItemId === senderItemId ||
              (exchange.senderItemId && exchange.senderItemId === receiverItemId) ||
              (exchange.senderItemId && exchange.senderItemId === senderItemId)) {
            
            // Cancel this exchange
            batch.update(doc.ref, {
              status: 'cancelled',
              cancelledReason: 'item_no_longer_available',
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // Track users to notify (both sender and receiver)
            usersToNotify.add(exchange.senderId);
            usersToNotify.add(exchange.receiverId);
            cancelledExchangeIds.add(exchangeId);

            console.log(`Cancelling exchange ${exchangeId} due to accepted exchange ${acceptedExchangeId}`);
          }
        });

        await batch.commit();
        
        // Also cancel any counter-offers that have these cancelled exchanges as parents
        const counterOfferBatch = admin.firestore().batch();
        const counterOffersSnapshot = await admin.firestore()
          .collection('exchanges')
          .where('status', '==', 'pending')
          .get();
        
        counterOffersSnapshot.forEach((doc) => {
          const counterOffer = doc.data();
          if (counterOffer.parentExchangeId && cancelledExchangeIds.has(counterOffer.parentExchangeId)) {
            counterOfferBatch.update(doc.ref, {
              status: 'cancelled',
              cancelledReason: 'parent_exchange_cancelled',
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            usersToNotify.add(counterOffer.senderId);
            usersToNotify.add(counterOffer.receiverId);
            console.log(`Cancelling counter-offer ${doc.id} due to parent cancellation`);
          }
        });
        
        await counterOfferBatch.commit();
        console.log(`Cancelled ${usersToNotify.size} exchanges due to acceptance`);

        // Send notifications to affected users
        for (const userId of usersToNotify) {
          try {
            const userDoc = await admin.firestore().collection('users').doc(userId).get();
            if (userDoc.exists) {
              const userData = userDoc.data();
              const fcmToken = userData.fcmToken;

              if (fcmToken) {
                const message = {
                  token: fcmToken,
                  notification: {
                    title: 'Intercambio cancelado',
                    body: 'Un intercambio ha sido cancelado porque el artículo ya no está disponible.',
                  },
                  data: {
                    userId: userId,
                    type: 'exchange_cancelled',
                    reason: 'item_no_longer_available',
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
                console.log(`Cancellation notification sent to user ${userId}`);
              }
            }
          } catch (error) {
            console.error(`Error sending cancellation notification to user ${userId}:`, error);
          }
        }
      } catch (error) {
        console.error('Error cancelling other exchanges:', error);
      }
    }

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

        let title, body, notificationType;

        switch (after.status) {
          case 'accepted':
            title = '¡Propuesta aceptada!';
            body = 'Tu propuesta ha sido aceptada. Contacta con el otro usuario para coordinar el intercambio.';
            notificationType = 'exchange_accepted';
            break;
          case 'rejected':
            title = 'Propuesta rechazada';
            body = 'Tu propuesta ha sido rechazada. Puedes intentar con otros artículos.';
            notificationType = 'exchange_rejected';
            break;
          case 'counter_offered':
            // Get the receiver's name for counter-offer notification
            const receiverDoc = await admin.firestore()
              .collection('users')
              .doc(after.receiverId)
              .get();
            const name = receiverDoc.exists ? receiverDoc.data().name : 'Alguien';
            
            title = 'Nueva contraoferta';
            body = `${name} ha enviado una contraoferta. Revisa los detalles de la nueva propuesta.`;
            notificationType = 'exchange_counter_offered';
            break;
          case 'received': {
            // For 'received', notify the RECEIVER (product owner), not the sender
            const receiverDoc = await admin.firestore()
              .collection('users')
              .doc(after.receiverId)
              .get();

            if (!receiverDoc.exists) return null;

            const receiverData = receiverDoc.data();
            const receiverToken = receiverData.fcmToken;

            if (!receiverToken) {
              console.log('No FCM token for receiver:', after.receiverId);
              return null;
            }

            const receivedMessage = {
              token: receiverToken,
              notification: {
                title: '¡Producto recibido!',
                body: 'El solicitante ha confirmado la recepción del producto. ¡Gracias por usar TruequeApp!',
              },
              data: {
                userId: after.receiverId,
                exchangeId: event.params.exchangeId,
                type: 'exchange_received',
                status: 'received',
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

            await admin.messaging().send(receivedMessage);
            console.log('Received notification sent to receiver:', after.receiverId);
            return null;
          }
          case 'completed':
            title = '¡Intercambio completado!';
            body = 'El intercambio ha sido marcado como completado. ¡Gracias por usar TruequeApp!';
            notificationType = 'exchange_completed';
            break;
          case 'cancelled':
            title = 'Intercambio cancelado';
            body = 'El intercambio ha sido cancelado porque el artículo ya no está disponible.';
            notificationType = 'exchange_cancelled';
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
            userId: after.senderId,
            exchangeId: event.params.exchangeId,
            type: notificationType,
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

// Send push notification when a new message notification is created
exports.sendMessageNotification = onDocumentCreated(
  'notifications/{notificationId}',
  async (event) => {
    const snap = event.data;
    const notification = snap.data();

    // Only handle new_message type to avoid double-sending for exchange notifications
    if (notification.type !== 'new_message') {
      return null;
    }

    try {
      const userId = notification.userId;
      const exchangeId = notification.exchangeId;

      if (!userId || !exchangeId) {
        console.log('Missing userId or exchangeId in notification');
        return null;
      }

      // Get receiver's FCM token
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(userId)
        .get();

      if (!userDoc.exists) {
        console.log('User not found:', userId);
        return null;
      }

      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;

      if (!fcmToken) {
        console.log('No FCM token for user:', userId);
        return null;
      }

      console.log('Sending message notification to token:', fcmToken);

      const message = {
        token: fcmToken,
        notification: {
          title: notification.title || 'Nuevo mensaje',
          body: notification.body || 'Tienes un nuevo mensaje',
        },
        data: {
          userId: userId,
          exchangeId: exchangeId,
          type: 'new_message',
          senderId: notification.senderId || '',
          senderName: notification.senderName || '',
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

      const response = await admin.messaging().send(message);
      console.log('Message notification sent successfully:', response);

      return response;
    } catch (error) {
      if (error.code === 'messaging/registration-token-not-registered' ||
          error.code === 'messaging/invalid-registration-token') {
        await admin.firestore().collection('users').doc(userId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
        console.log('Cleaned up stale FCM token for user:', userId);
      } else {
        console.error('Error sending message notification:', error);
      }
      return null;
    }
  }
);

// Cancel pending exchanges when an item is deleted
exports.cancelExchangesOnItemDelete = onDocumentDeleted(
  'items/{itemId}',
  async (event) => {
    const itemId = event.params.itemId;
    console.log(`Item ${itemId} deleted, cancelling related exchanges...`);

    try {
      // Find all pending exchanges involving this item
      const exchangesSnapshot = await admin.firestore()
        .collection('exchanges')
        .where('status', '==', 'pending')
        .get();

      const batch = admin.firestore().batch();
      const usersToNotify = new Set();
      const cancelledExchangeIds = new Set();

      exchangesSnapshot.forEach((doc) => {
        const exchange = doc.data();
        const exchangeId = doc.id;
        
        // Check if this exchange involves the deleted item
        if (exchange.receiverItemId === itemId || 
            (exchange.senderItemId && exchange.senderItemId === itemId)) {
          
          // Cancel this exchange
          batch.update(doc.ref, {
            status: 'cancelled',
            cancelledReason: 'item_deleted',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Track users to notify (both sender and receiver)
          usersToNotify.add(exchange.senderId);
          usersToNotify.add(exchange.receiverId);
          cancelledExchangeIds.add(exchangeId);

          console.log(`Cancelling exchange ${exchangeId} due to item deletion`);
        }
      });

      await batch.commit();
      
      // Also cancel any counter-offers that have these cancelled exchanges as parents
      const counterOfferBatch = admin.firestore().batch();
      const counterOffersSnapshot = await admin.firestore()
        .collection('exchanges')
        .where('status', '==', 'pending')
        .get();
      
      counterOffersSnapshot.forEach((doc) => {
        const counterOffer = doc.data();
        if (counterOffer.parentExchangeId && cancelledExchangeIds.has(counterOffer.parentExchangeId)) {
          counterOfferBatch.update(doc.ref, {
            status: 'cancelled',
            cancelledReason: 'parent_exchange_cancelled',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          usersToNotify.add(counterOffer.senderId);
          usersToNotify.add(counterOffer.receiverId);
          console.log(`Cancelling counter-offer ${doc.id} due to parent cancellation`);
        }
      });
      
      await counterOfferBatch.commit();
      console.log(`Cancelled exchanges for deleted item ${itemId}`);

      // Send notifications to affected users
      for (const userId of usersToNotify) {
        try {
          const userDoc = await admin.firestore().collection('users').doc(userId).get();
          if (userDoc.exists) {
            const userData = userDoc.data();
            const fcmToken = userData.fcmToken;

            if (fcmToken) {
              const message = {
                token: fcmToken,
                notification: {
                  title: 'Intercambio cancelado',
                  body: 'Un intercambio ha sido cancelado porque el artículo fue eliminado.',
                },
                data: {
                  userId: userId,
                  type: 'exchange_cancelled',
                  reason: 'item_deleted',
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
              console.log(`Cancellation notification sent to user ${userId}`);
            }
          }
        } catch (error) {
          console.error(`Error sending cancellation notification to user ${userId}:`, error);
        }
      }

      return null;
    } catch (error) {
      console.error('Error cancelling exchanges on item delete:', error);
      return null;
    }
  }
);
