import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import '../di/injection_container.dart';
import '../router/app_router.dart';
import '../../features/home/domain/repositories/home_repository.dart';

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

  static const _exchangeChannelId = 'exchange_requests';
  static const _exchangeChannelName = 'Exchange Requests';
  static const _exchangeChannelDescription = 'Notifications for exchange requests and updates';

  static const _newItemsChannelId = 'new_items';
  static const _newItemsChannelName = 'Artículos nuevos';
  static const _newItemsChannelDescription = 'Avisos cuando alguien publica un artículo';

  static const _exchangeChannel = AndroidNotificationDetails(
    _exchangeChannelId,
    _exchangeChannelName,
    channelDescription: _exchangeChannelDescription,
    importance: Importance.max,
    priority: Priority.high,
  );

  static const _newItemsChannel = AndroidNotificationDetails(
    _newItemsChannelId,
    _newItemsChannelName,
    channelDescription: _newItemsChannelDescription,
    importance: Importance.high,
    priority: Priority.high,
  );

  /// Data of the push that launched the app from terminated state; handled
  /// consumed by HomePage once the user is authenticated and on /home.
  Map<String, dynamic>? _pendingLaunchData;

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

    // Create Android channels explicitly so background FCM pushes (shown by
    // the system, not by this plugin) find them even on a fresh install.
    // new_items is separate so users can mute it in system settings.
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      _exchangeChannelId,
      _exchangeChannelName,
      description: _exchangeChannelDescription,
      importance: Importance.max,
    ));
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      _newItemsChannelId,
      _newItemsChannelName,
      description: _newItemsChannelDescription,
      importance: Importance.high,
    ));

    // App launched from terminated state by tapping a local notification
    // (shown in foreground earlier). An FCM initial message overrides it below.
    try {
      final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
      final payload = launchDetails?.notificationResponse?.payload;
      if (launchDetails?.didNotificationLaunchApp == true && payload != null) {
        _pendingLaunchData = Map<String, dynamic>.from(jsonDecode(payload) as Map);
      }
    } catch (e) {
      debugPrint('Error reading notification launch details: $e');
    }

    // Request permission for iOS
    await _requestPermission();

    // Show notifications when app is in foreground (iOS)
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get FCM token.
    // On iOS/macOS, the FCM token is derived from the native APNs device
    // token, which arrives asynchronously after permission is granted (it
    // is NOT guaranteed to be ready immediately, and may never arrive on
    // the iOS Simulator). Calling getToken() before it's set throws
    // `apns-token-not-set`. We wait for it with a bounded retry, and never
    // let a failure here block app startup (DI awaits this service).
    try {
      var canFetchToken = true;
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        String? apnsToken = await _firebaseMessaging.getAPNSToken();
        var attempts = 0;
        while (apnsToken == null && attempts < 10) {
          await Future.delayed(const Duration(milliseconds: 500));
          apnsToken = await _firebaseMessaging.getAPNSToken();
          attempts++;
        }
        canFetchToken = apnsToken != null;
        if (!canFetchToken) {
          debugPrint('APNS token unavailable after waiting; skipping FCM token fetch.');
        }
      }
      if (canFetchToken) {
        _fcmToken = await _firebaseMessaging.getToken();
        debugPrint('FCM Token: $_fcmToken');
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
    
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

    // App launched from terminated state by tapping an FCM push.
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _pendingLaunchData = Map<String, dynamic>.from(initialMessage.data);
    }
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

    // Show local notification when app is in foreground.
    // The notifications collection is now populated server-side by Cloud
    // Functions, so we no longer save here to avoid duplicate documents.
    _showLocalNotification(message);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final isNewItem = message.data['type'] == 'new_item';

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: isNewItem ? _newItemsChannel : _exchangeChannel,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      id: message.hashCode,
      title: message.notification?.title ?? 'TruequeApp',
      body: message.notification?.body ?? 'Tienes una nueva notificación',
      payload: jsonEncode(message.data),
      notificationDetails: platformChannelSpecifics,
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('Message opened app: ${message.messageId}');
    _handleNotificationData(Map<String, dynamic>.from(message.data));
  }

  void _onNotificationTapped(NotificationResponse notificationResponse) {
    debugPrint('Notification tapped: ${notificationResponse.payload}');
    final payload = notificationResponse.payload;
    if (payload == null) return;
    try {
      _handleNotificationData(Map<String, dynamic>.from(jsonDecode(payload) as Map));
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
    }
  }

  /// Routes a notification tap by its data payload.
  void _handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    if (type == 'new_item') {
      final itemId = data['itemId'] as String?;
      if (itemId != null) _navigateToItemDetail(itemId);
      return;
    }

    // The notifications collection is populated server-side; just navigate.
    final exchangeId = data['exchangeId'] as String?;
    if (exchangeId == null) return;
    if (type == 'new_message') {
      _navigateToChat(exchangeId, data);
    } else {
      _navigateToExchangeDetail(exchangeId);
    }
  }

  Future<void> _navigateToItemDetail(String itemId) async {
    try {
      final item = await sl<HomeRepository>().getItemById(itemId);
      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) return;

      if (item == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El artículo ya no está disponible')),
        );
        return;
      }
      context.pushNamed('item-detail', extra: item);
    } catch (e) {
      debugPrint('Error navigating to item detail: $e');
    }
  }

  void _navigateToExchangeDetail(String exchangeId) {
    final context = navigatorKey.currentContext;

    if (context != null) context.pushNamed('exchange-detail', extra: exchangeId);
  }

  void _navigateToChat(String exchangeId, Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    context.pushNamed(
      'chat',
      extra: {
        'exchangeId': exchangeId,
        'otherUserName': data['senderName'] as String? ?? 'Usuario',
        'otherUserId': data['senderId'] as String? ?? '',
      },
    );
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

  /// Navigates for the notification that launched the app, if any. Called by
  /// HomePage after its first frame, so the user is authenticated and the
  /// splash has already been left behind. Runs at most once per launch tap.
  void consumePendingLaunchData() {
    final data = _pendingLaunchData;
    if (data == null) return;
    _pendingLaunchData = null;
    _handleNotificationData(data);
  }

  Future<void> removeUserToken(String userId) async {
    _currentUserId = null;
    // Drop any unhandled launch tap so it can't navigate after a later login.
    _pendingLaunchData = null;

    try {
      await _firestore.collection('users').doc(userId).set({
        'fcmToken': FieldValue.delete(),
      }, SetOptions(merge: true));
      debugPrint('FCM token removed for user: $userId');
    } catch (e) {
      debugPrint('Error removing FCM token: $e');
    }
  }

}

