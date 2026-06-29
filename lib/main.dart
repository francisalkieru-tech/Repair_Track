import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:app_links/app_links.dart';
import 'firebase_options.dart';
import 'screens/auth/Welcome_screen.dart';
import 'screens/tracking/tracking_screen.dart';

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

  void _handleLink(Uri uri) {
    // Format: repairtrack://track/TRACKINGID
    // o https://repairtrack.app/track/TRACKINGID
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments[0] == 'track') {
      final trackingId = segments[1].toUpperCase();
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => TrackingScreen(trackingId: trackingId),
        ),
      );
    } else if (uri.host == 'track' && uri.scheme == 'repairtrack') {
      // repairtrack://track/TRACKINGID
      final trackingId = uri.path.replaceAll('/', '').toUpperCase();
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => TrackingScreen(trackingId: trackingId),
        ),
      );
    }
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