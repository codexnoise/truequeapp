import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  String? _currentUserId;

  Future<void> initialize() async {
    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permission for iOS
    await _requestPermission();

    // Show notifications when app is in foreground (iOS)
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get FCM token
    _fcmToken = await _firebaseMessaging.getToken();
    debugPrint('FCM Token: $_fcmToken');
    
    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen((token) async {
      _fcmToken = token;
      debugPrint('FCM Token refreshed: $token');
      if (_currentUserId != null) {
        await saveUserToken(_currentUserId!);
      }
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle message when app is opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  Future<void> _requestPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('User granted provisional permission');
    } else {
      debugPrint('User declined or has not accepted permission');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Received a foreground message: ${message.messageId}');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');
    
    // Show local notification when app is in foreground
    _showLocalNotification(message);
    
    // Save notification to Firestore
    _saveNotificationToFirestore(message);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'exchange_requests',
      'Exchange Requests',
      channelDescription: 'Notifications for exchange requests and updates',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      id: message.hashCode,
      title: message.notification?.title ?? 'TruequeApp',
      body: message.notification?.body ?? 'Tienes una nueva notificación',
      payload: message.data.toString(),
      notificationDetails: platformChannelSpecifics,
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('Message opened app: ${message.messageId}');
    final exchangeId = message.data['exchangeId'] as String?;
    
    // Save notification to Firestore
    _saveNotificationToFirestore(message);

    if (exchangeId != null) _navigateToExchangeDetail(exchangeId);
  }

  void _onNotificationTapped(NotificationResponse notificationResponse) {
    debugPrint('Notification tapped: ${notificationResponse.payload}');
    final payload = notificationResponse.payload;

    if (payload != null) {
      final exchangeId = _extractExchangeId(payload);

      if (exchangeId != null) _navigateToExchangeDetail(exchangeId);
    }
  }

  void _navigateToExchangeDetail(String exchangeId) {
    final context = navigatorKey.currentContext;

    if (context != null) context.pushNamed('exchange-detail', extra: exchangeId);
  }

  String? _extractExchangeId(String payload) {
    final regex = RegExp(r'exchangeId:\s*([\w-]+)');
    final match = regex.firstMatch(payload);
    return match?.group(1);
  }

  Future<void> saveUserToken(String userId) async {
    if (_fcmToken == null) return;
    
    _currentUserId = userId;

    try {
      await _firestore.collection('users').doc(userId).set({
        'fcmToken': _fcmToken,
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('FCM token saved for user: $userId');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  Future<void> removeUserToken(String userId) async {
    _currentUserId = null;

    try {
      await _firestore.collection('users').doc(userId).set({
        'fcmToken': FieldValue.delete(),
      }, SetOptions(merge: true));
      debugPrint('FCM token removed for user: $userId');
    } catch (e) {
      debugPrint('Error removing FCM token: $e');
    }
  }

  Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
    try {
      final userId = message.data['userId'] as String?;
      final exchangeId = message.data['exchangeId'] as String?;
      final type = message.data['type'] as String?;
      
      if (userId == null || exchangeId == null) {
        debugPrint('Missing userId or exchangeId in notification data');
        return;
      }

      await _firestore.collection('notifications').add({
        'userId': userId,
        'exchangeId': exchangeId,
        'type': type ?? 'exchange_new',
        'title': message.notification?.title ?? 'Nueva notificación',
        'body': message.notification?.body ?? '',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('Notification saved to Firestore for user: $userId');
    } catch (e) {
      debugPrint('Error saving notification to Firestore: $e');
    }
  }
}

