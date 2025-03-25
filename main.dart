import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_application_1/login_page.dart';
import 'package:flutter_application_1/register_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ Initialize Local Notifications Plugin
FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ✅ Background Notification Handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("🔥 Background Notification: ${message.notification?.title}");
}

// ✅ Handle Notifications When App is Clicked (Background or Terminated)
void _onMessageOpenedApp(RemoteMessage message) {
  print("🚀 Notification Clicked: ${message.notification?.title}");
}

// ✅ Function to Initialize Firebase & Notifications
Future<void> initFirebase() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    print("✅ Firebase initialized successfully!");

    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await FirebaseMessaging.instance.setAutoInitEnabled(true);

    // ✅ Request Notification Permissions
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print("✅ Notifications permission granted!");

      // ✅ Fetch & Send FCM Token
      String? token = await messaging.getToken();
      if (token != null) {
        print("📲 Device FCM Token: $token");
        await sendTokenToServer(token);
      } else {
        print("❌ Failed to retrieve FCM token!");
      }
    } else {
      print("❌ Notifications permission denied!");
    }

    // ✅ Initialize Local Notifications
    var androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    var initializationSettings =
        InitializationSettings(android: androidSettings);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.payload != null && response.payload!.isNotEmpty) {
          print("📩 Notification Clicked: ${response.payload}");
        }
      },
    );

    // ✅ Handle Foreground Notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("🔥 Foreground Notification: ${message.notification?.title}");
      showLocalNotification(message);
    });

    // ✅ Handle Background/Terminated Notification Clicks
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    print("❌ Firebase failed to initialize: $e");
  }
}

// ✅ Function to Send FCM Token to Flask Backend
Future<void> sendTokenToServer(String token) async {
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? parentId = prefs.getString("parent_id");

    if (parentId == null) {
      print("❌ Error: Parent ID not found in SharedPreferences!");
      return;
    }

    final response = await http.post(
      Uri.parse("https://1a05-80-233-39-72.ngrok-free.app/register_token"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"parent_id": parentId, "token": token}),
    );

    if (response.statusCode == 200) {
      print("✅ Token sent successfully to backend!");
    } else {
      print("❌ Failed to send token: ${response.body}");
    }
  } catch (e) {
    print("❌ Error sending token: $e");
  }
}

// ✅ Function to Show Local Notification
void showLocalNotification(RemoteMessage message) async {
  var androidDetails = AndroidNotificationDetails(
    'channel_id',
    'General Notifications',
    importance: Importance.high,
    priority: Priority.high,
    showWhen: true,
  );

  var notificationDetails = NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    0, // Notification ID
    message.notification?.title ?? "New Notification",
    message.notification?.body ?? "Tap to open",
    notificationDetails,
  );
}

// ✅ Main Function
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebase();

  runApp(MyApp());
}

// ✅ Main App Widget
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),
      },
    );
  }
}
