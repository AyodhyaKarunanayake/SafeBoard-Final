import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:safeboard/app.dart';
import 'package:safeboard/providers/auth_provider.dart';
import 'package:safeboard/providers/booking_provider.dart';
import 'package:safeboard/providers/journey_provider.dart';
import 'package:safeboard/providers/payment_provider.dart';
import 'package:safeboard/providers/tickets_provider.dart';
import 'package:safeboard/screens/onboarding/welcome_screen.dart';
import 'package:safeboard/screens/onboarding/register_screen.dart';
import 'package:safeboard/screens/onboarding/login_screen.dart';
import 'package:safeboard/screens/onboarding/preferences_screen.dart';
import 'package:safeboard/screens/home/home_screen.dart';
import 'package:safeboard/screens/home/notifications_screen.dart';
import 'package:safeboard/screens/search/search_screen.dart';
import 'package:safeboard/screens/search/route_detail_screen.dart';
import 'package:safeboard/screens/booking/booking_confirmation_screen.dart';
import 'package:safeboard/screens/booking/requesting_screen.dart';
import 'package:safeboard/screens/booking/allocation_result_screen.dart';
import 'package:safeboard/screens/payment/payment_options_screen.dart';
import 'package:safeboard/screens/payment/payment_portal_screen.dart';
import 'package:safeboard/screens/payment/pay_onboard_confirmation_screen.dart';
import 'package:safeboard/screens/ticket/my_ticket_screen.dart';
import 'package:safeboard/screens/ticket/track_bus_screen.dart';
import 'package:safeboard/screens/journey/journey_screen.dart';
import 'package:safeboard/screens/journey/incident_report_screen.dart';
import 'package:safeboard/screens/journey/incident_submitted_screen.dart';
import 'package:safeboard/screens/journey/incident_history_screen.dart';
import 'package:safeboard/screens/rating/rating_screen.dart';
import 'package:safeboard/screens/profile/history_screen.dart';
import 'package:safeboard/screens/profile/profile_screen.dart';
import 'package:safeboard/screens/profile/help_support_screen.dart';

Widget createTestApp(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => JourneyProvider()),
      ChangeNotifierProvider(create: (_) => BookingProvider()),
      ChangeNotifierProvider(create: (_) => PaymentProvider()),
      ChangeNotifierProvider(create: (_) => TicketsProvider()),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  testWidgets('SafeBoardApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SafeBoardApp());
    expect(find.text('SafeBoard'), findsWidgets);
  });

  testWidgets('WelcomeScreen renders properly and tapping Create Account navigates', (WidgetTester tester) async {
    await tester.pumpWidget(const SafeBoardApp());
    await tester.pumpAndSettle();

    final createBtn = find.text('Create account');
    expect(createBtn, findsOneWidget);
    await tester.tap(createBtn);
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
  });

  testWidgets('All screens render without runtime errors', (WidgetTester tester) async {
    // A couple of screens embed a live flutter_map (real OpenStreetMap
    // tiles). This test suite has no real network access, so those tile
    // fetches fail fast with HTTP 400, and Flutter's image-loading pipeline
    // reports each failed tile as a global error since nothing else is
    // listening. That's a sandbox artifact of testing a network image with
    // no network (in a real run the tiles simply load), not a bug in the
    // app - so it's filtered out here rather than silencing exceptions in
    // general. Installed AFTER pumping starts, since TestWidgetsFlutterBinding
    // installs its own FlutterError.onError at the start of each test body,
    // which would otherwise clobber a handler set any earlier (e.g. setUp).
    final testOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final isMapTileNetworkNoise = details.exception is NetworkImageLoadException ||
          details.exception.toString().contains('openstreetmap.org');
      if (isMapTileNetworkNoise) return;
      testOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = testOnError);

    final screens = <String, Widget>{
      'Welcome': const WelcomeScreen(),
      'Register': const RegisterScreen(),
      'Login': const LoginScreen(),
      'Preferences': const PreferencesScreen(),
      'Home': const HomeScreen(),
      'Notifications': const NotificationsScreen(),
      'Search': const SearchScreen(),
      'RouteDetail': const RouteDetailScreen(routeId: 'R_87'),
      'BookingConfirmation': const BookingConfirmationScreen(),
      'Requesting': const RequestingScreen(),
      'AllocationResult': const AllocationResultScreen(),
      'PaymentOptions': const PaymentOptionsScreen(),
      'PaymentPortal': const PaymentPortalScreen(),
      'PayOnboardConfirmation': const PayOnboardConfirmationScreen(),
      'MyTicket': const MyTicketScreen(),
      'TrackBus': const TrackBusScreen(),
      'Journey': const JourneyScreen(),
      'IncidentReport': const IncidentReportScreen(),
      'IncidentSubmitted': const IncidentSubmittedScreen(),
      'IncidentHistory': const IncidentHistoryScreen(),
      'Rating': const RatingScreen(),
      'History': const HistoryScreen(),
      'Profile': const ProfileScreen(),
      'HelpSupport': const HelpSupportScreen(),
    };

    for (final entry in screens.entries) {
      await tester.pumpWidget(createTestApp(entry.value));
      await tester.pump();
      // A couple of screens embed a live flutter_map (OpenStreetMap tiles).
      // In this sandboxed test environment there's no real network, so tile
      // fetches fail fast; a short extra pump lets those async failures
      // settle (they're swallowed as error tiles, not real app bugs)
      // before checking for genuine exceptions.
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: '${entry.key} screen threw an exception');
    }
  });
}
