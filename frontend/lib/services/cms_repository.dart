import '../core/api_client.dart';
import '../models/cms_models.dart';

class CmsRepository {
  CmsRepository(this.api);
  final ApiClient api;

  Future<CmsUser> login(String email, String password) async {
    final data = await api.post('/login', {'email': email.trim(), 'password': password})
        as Map<String, dynamic>;
    api.setToken(data['token'] as String);
    return CmsUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    await api.post('/logout');
    api.setToken(null);
  }

  void clearSession() => api.setToken(null);

  Future<List<CmsEvent>> events(CmsUser user, {bool mine = true}) async {
    final path = mine ? '/users/${user.id}/events' : '/events';
    final data = await api.get(path) as List<dynamic>;
    return data.map((item) => CmsEvent.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<EventDashboard> dashboard(String eventId) async =>
      EventDashboard.fromJson(await api.get('/events/$eventId/dashboard') as Map<String, dynamic>);

  Future<List<CmsTask>> tasks(String eventId) async {
    final data = await api.get('/events/$eventId/tasks') as List<dynamic>;
    return data.map((item) => CmsTask.fromJson(item as Map<String, dynamic>)).toList();
  }
}
