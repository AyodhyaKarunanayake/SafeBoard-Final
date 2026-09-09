import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'constants/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/journey_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/tickets_provider.dart';

import 'screens/onboarding/welcome_screen.dart';
import 'screens/onboarding/login_screen.dart';
import 'screens/onboarding/register_screen.dart';
import 'screens/onboarding/preferences_screen.dart';

import 'screens/home/home_screen.dart';
import 'screens/home/notifications_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/search/route_detail_screen.dart';

import 'screens/booking/booking_confirmation_screen.dart';
import 'screens/booking/requesting_screen.dart';
import 'screens/booking/allocation_result_screen.dart';

import 'screens/payment/payment_options_screen.dart';
import 'screens/payment/payment_portal_screen.dart';
import 'screens/payment/pay_onboard_confirmation_screen.dart';

import 'screens/ticket/my_ticket_screen.dart';
import 'screens/ticket/track_bus_screen.dart';

import 'screens/journey/journey_screen.dart';
import 'screens/journey/incident_report_screen.dart';
import 'screens/journey/incident_submitted_screen.dart';
import 'screens/journey/incident_history_screen.dart';

import 'screens/rating/rating_screen.dart';

import 'screens/profile/history_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/help_support_screen.dart';

final GoRouter _router = GoRouter(
  initialLocation: '/welcome',
  routes: [
    GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
    GoRoute(path: '/preferences', builder: (context, state) => const PreferencesScreen()),

    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
    GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
    GoRoute(
      path: '/route/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? 'R_87';
        return RouteDetailScreen(routeId: id);
      },
    ),

    GoRoute(path: '/stop-select', builder: (context, state) => const BookingConfirmationScreen()),
    GoRoute(path: '/requesting', builder: (context, state) => const RequestingScreen()),
    GoRoute(path: '/allocation', builder: (context, state) => const AllocationResultScreen()),

    GoRoute(path: '/payment-options', builder: (context, state) => const PaymentOptionsScreen()),
    GoRoute(path: '/payment-portal', builder: (context, state) => const PaymentPortalScreen()),
    GoRoute(path: '/pay-onboard-confirmed', builder: (context, state) => const PayOnboardConfirmationScreen()),

    GoRoute(
      path: '/my-ticket/:ticketId',
      builder: (context, state) => MyTicketScreen(ticketId: state.pathParameters['ticketId']),
    ),
    GoRoute(
      path: '/track-bus/:ticketId',
      builder: (context, state) => TrackBusScreen(ticketId: state.pathParameters['ticketId']),
    ),

    GoRoute(path: '/journey', builder: (context, state) => const JourneyScreen()),
    GoRoute(
      path: '/incident',
      builder: (context, state) {
        final type = state.uri.queryParameters['type'];
        final severity = state.uri.queryParameters['severity'];
        return IncidentReportScreen(initialType: type, initialSeverity: severity);
      },
    ),
    GoRoute(path: '/submitted', builder: (context, state) => const IncidentSubmittedScreen()),
    GoRoute(path: '/incident-history', builder: (context, state) => const IncidentHistoryScreen()),

    GoRoute(
      path: '/rating/:ticketId',
      builder: (context, state) => RatingScreen(ticketId: state.pathParameters['ticketId']),
    ),

    GoRoute(path: '/history', builder: (context, state) => const HistoryScreen()),
    GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
    GoRoute(path: '/help-support', builder: (context, state) => const HelpSupportScreen()),
  ],
);

class SafeBoardApp extends StatelessWidget {
  const SafeBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => JourneyProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => TicketsProvider()),
      ],
      child: MaterialApp.router(
        title: 'SafeBoard',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: _router,
      ),
    );
  }
}
