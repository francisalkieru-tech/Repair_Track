import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_links/app_links.dart';
import 'firebase_options.dart';
import 'screens/auth/Welcome_screen.dart';
import 'screens/tracking/tracking_screen.dart';
import 'screens/tracking/service_history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() async {
    _appLinks = AppLinks();

    // Kapag bukas na ang app at may incoming link
    _appLinks.uriLinkStream.listen((uri) {
      _handleLink(uri);
    });

    // Kapag binuksan ang app via link (cold start)
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _handleLink(initialUri);
    }
  }

  Future<void> _handleLink(Uri uri) async {
    String? trackingId;

    // Format A: repairtrack://track/TRACKINGID
    if (uri.scheme == 'repairtrack' && uri.host == 'track') {
      trackingId = uri.path.replaceAll('/', '').toUpperCase();
    }
    // Format B: https://repairtrack.app/track/TRACKINGID
    else {
      final segments = uri.pathSegments;
      if (segments.length >= 2 && segments[0] == 'track') {
        trackingId = segments[1].toUpperCase();
      }
    }

    if (trackingId == null || trackingId.isEmpty) return;

    // I-check muna sa Firestore kung Completed na ang record — kapag
    // Completed, ipapakita sa ServiceHistoryScreen (mas detalyado);
    // kapag hindi pa, ipapakita sa TrackingScreen (ongoing progress).
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('repairRequests')
          .where('trackingId', isEqualTo: trackingId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        // Hindi nahanap — ipakita na lang sa TrackingScreen
        // (magpapakita ng "not found" message doon)
        _pushScreen(TrackingScreen(trackingId: trackingId));
        return;
      }

      final data = snapshot.docs.first.data();
      final status = data['status'] as String? ?? '';

      if (status == 'Completed') {
        _pushScreen(ServiceHistoryScreen(trackingId: trackingId));
      } else {
        _pushScreen(TrackingScreen(trackingId: trackingId));
      }
    } catch (_) {
      // Kung may error sa Firestore lookup, fallback sa TrackingScreen
      _pushScreen(TrackingScreen(trackingId: trackingId));
    }
  }

  void _pushScreen(Widget screen) {
    _navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'RepairTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2563EB),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color(0xFF2563EB), width: 2),
          ),
        ),
      ),
      home: const WelcomeScreen(),
    );
  }
}