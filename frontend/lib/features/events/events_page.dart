import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../models/cms_models.dart';
import '../../services/cms_repository.dart';
import 'event_page.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({
    super.key, required this.repository, required this.user,
    required this.onLogout, required this.onSessionExpired,
  });
  final CmsRepository repository;
  final CmsUser user;
  final Future<void> Function() onLogout;
  final VoidCallback onSessionExpired;
  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  List<CmsEvent> _events = [];
  bool _loading = true;
  bool _loggingOut = false;
  bool _mine = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final events = await widget.repository.events(widget.user, mine: _mine);
      if (mounted) setState(() => _events = events);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.status == 401) { widget.onSessionExpired(); return; }
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await widget.onLogout();
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_mine ? 'Event Saya' : 'Seluruh Event'),
      actions: [
        IconButton(
          tooltip: 'Profil',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(widget.user.name),
              content: Text('${widget.user.email}\n${widget.user.isAdmin ? 'Administrator' : 'Pengguna'}'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
            ),
          ),
          icon: const Icon(Icons.account_circle_outlined),
        ),
        IconButton(
          tooltip: 'Keluar', onPressed: _loggingOut ? null : _logout,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: Column(
      children: [
        if (widget.user.isAdmin) Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Event Saya')),
              ButtonSegment(value: false, label: Text('Semua Event')),
            ],
            selected: {_mine},
            onSelectionChanged: _loading ? null : (selection) {
              setState(() => _mine = selection.first);
              _load();
            },
          ),
        ),
        Expanded(
          child: _loading ? const Center(child: CircularProgressIndicator()) :
          _error != null ? Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Coba lagi')),
            ]),
          )) :
          RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text('Halo, ${widget.user.name}', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('Pilih acara untuk melihat progres kepanitiaan.'),
                const SizedBox(height: 16),
                if (_events.isEmpty) const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Text('Belum ada event. Penugasan acara akan muncul di sini.', textAlign: TextAlign.center),
                ),
                for (final event in _events) Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(event.title),
                    subtitle: Text('${event.roleLabel}\n${event.location}\n${event.startDate} - ${event.endDate}'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push<void>(context, MaterialPageRoute(
                      builder: (_) => EventPage(
                        repository: widget.repository, event: event,
                        onSessionExpired: widget.onSessionExpired,
                      ),
                    )),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
