import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../models/cms_models.dart';
import '../../services/cms_repository.dart';

class EventPage extends StatefulWidget {
  const EventPage({
    super.key, required this.repository, required this.event, required this.onSessionExpired,
  });
  final CmsRepository repository;
  final CmsEvent event;
  final VoidCallback onSessionExpired;
  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage> {
  EventDashboard? _dashboard;
  List<CmsTask> _tasks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait<Object>([
        widget.repository.dashboard(widget.event.id),
        widget.repository.tasks(widget.event.id),
      ]);
      if (mounted) setState(() {
        _dashboard = results[0] as EventDashboard;
        _tasks = results[1] as List<CmsTask>;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.status == 401) { widget.onSessionExpired(); return; }
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = _dashboard;
    return Scaffold(
      appBar: AppBar(title: Text(widget.event.title)),
      body: _loading ? const Center(child: CircularProgressIndicator()) :
      _error != null ? Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, textAlign: TextAlign.center),
          FilledButton(onPressed: _load, child: const Text('Coba lagi')),
        ]),
      )) : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Text(widget.event.title, style: Theme.of(context).textTheme.headlineSmall),
            Text('${widget.event.location} | ${widget.event.roleLabel}'),
            Text('${widget.event.startDate} - ${widget.event.endDate}'),
            const SizedBox(height: 8),
            Text('Ketua: ${widget.event.chairName}'),
            if (widget.event.description.isNotEmpty) Text(widget.event.description),
            const SizedBox(height: 24),
            if (dashboard != null) ...[
              Text('Progres ${dashboard.progress.toStringAsFixed(0)}%', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: (dashboard.progress / 100).clamp(0.0, 1.0)),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                Chip(label: Text('${dashboard.totalDivisions} Divisi')),
                Chip(label: Text('${dashboard.totalMembers} Anggota')),
                Chip(label: Text('${dashboard.totalTasks} Tugas')),
                Chip(label: Text('${dashboard.toDo} To Do')),
                Chip(label: Text('${dashboard.inProgress} In Progress')),
                Chip(label: Text('${dashboard.done} Done')),
              ]),
            ],
            const SizedBox(height: 24),
            Text('Daftar Tugas', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (_tasks.isEmpty) const Text('Belum ada tugas pada event ini.'),
            for (final task in _tasks) Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(task.title, style: Theme.of(context).textTheme.titleMedium),
                  Text('${task.division} | ${task.assignee}'),
                  Text('Deadline: ${task.deadline} UTC'),
                  const SizedBox(height: 8),
                  Chip(label: Text(task.statusLabel)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
