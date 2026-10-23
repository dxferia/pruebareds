import 'package:flutter/material.dart';
import '../utils/route_names.dart';
import '../screens/access_screen.dart';
import '../screens/community_dashboard_screen.dart';
import '../screens/expired_publication_screen.dart';
import '../screens/filter_screen.dart';
import '../screens/history_screen.dart';
import '../screens/home_screen.dart';
import '../screens/jobs_screen.dart';
import '../screens/junta_publications_screen.dart';
import '../screens/more_screen.dart';
import '../screens/my_requests_screen.dart';
import '../screens/offline_screen.dart';
import '../screens/publish_screen.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';

class TravesiasApp extends StatefulWidget {
  const TravesiasApp({super.key, required this.state});
  final AppState state;
  @override State<TravesiasApp> createState() => _TravesiasAppState();
}

class _TravesiasAppState extends State<TravesiasApp> {
  @override
  void dispose() {
    widget.state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return MaterialApp(
      title: 'Travesías Conecta',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      initialRoute: Routes.home,
      routes: {
        Routes.home: (_) => HomeScreen(state: state),
        Routes.jobs: (_) => JobsScreen(state: state),
        Routes.filters: (_) => FilterScreen(state: state),
        Routes.myRequests: (_) => MyRequestsScreen(state: state),
        Routes.publish: (_) => PublishScreen(state: state),
        Routes.community: (_) => CommunityDashboardScreen(state: state),
        Routes.access: (_) => AccessScreen(state: state),
        Routes.juntaPublications: (_) => JuntaPublicationsScreen(state: state),
        Routes.more: (_) => MoreScreen(state: state),
        Routes.history: (_) => HistoryScreen(state: state),
        Routes.offline: (_) => OfflineScreen(state: state),
        Routes.expired: (_) => ExpiredPublicationScreen(state: state),
      },
    );
  }
}
