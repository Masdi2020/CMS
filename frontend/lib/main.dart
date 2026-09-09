import 'package:flutter/material.dart';
import 'core/api_client.dart';
import 'features/auth/login_page.dart';
import 'features/events/events_page.dart';
import 'models/cms_models.dart';
import 'services/cms_repository.dart';

void main() => runApp(const CmsApp());

class CmsApp extends StatefulWidget {
  const CmsApp({super.key});
  @override
  State<CmsApp> createState() => _CmsAppState();
}

class _CmsAppState extends State<CmsApp> {
  final _api = ApiClient();
  late final _repository = CmsRepository(_api);
  final _navigator = GlobalKey<NavigatorState>();
  CmsUser? _user;

  void _clearSession() {
    _repository.clearSession();
    _navigator.currentState?.popUntil((route) => route.isFirst);
    setState(() => _user = null);
  }

  Future<void> _logout() async {
    try {
      await _repository.logout();
    } on ApiException catch (error) {
      if (error.status != 401) rethrow;
    }
    if (mounted) _clearSession();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigator,
    title: 'CMS',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF245B50)),
      scaffoldBackgroundColor: const Color(0xFFF7F9F8),
    ),
    home: _user == null
      ? LoginPage(repository: _repository, onLogin: (user) => setState(() => _user = user))
      : EventsPage(
          repository: _repository, user: _user!,
          onLogout: _logout, onSessionExpired: _clearSession,
        ),
  );
}
