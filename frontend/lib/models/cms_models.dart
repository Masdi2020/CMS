class CmsUser {
  const CmsUser({required this.id, required this.name, required this.email, required this.role});
  factory CmsUser.fromJson(Map<String, dynamic> json) => CmsUser(
    id: json['id'].toString(), name: json['name'] as String,
    email: json['email'] as String, role: json['role'] as String,
  );
  final String id;
  final String name;
  final String email;
  final String role;
  bool get isAdmin => role == 'admin';
}

class CmsEvent {
  const CmsEvent({
    required this.id, required this.title, required this.description,
    required this.location, required this.startDate, required this.endDate,
    required this.chairName, required this.eventRole,
  });
  factory CmsEvent.fromJson(Map<String, dynamic> json) => CmsEvent(
    id: json['id'].toString(), title: json['title'] as String,
    description: json['description'] as String? ?? '',
    location: json['location'] as String? ?? '-',
    startDate: json['start_date'] as String, endDate: json['end_date'] as String,
    chairName: json['ketua_panitia_name'] as String,
    eventRole: json['event_role'] as String,
  );
  final String id;
  final String title;
  final String description;
  final String location;
  final String startDate;
  final String endDate;
  final String chairName;
  final String eventRole;
  String get roleLabel => switch (eventRole) {
    'ketua' => 'Ketua Panitia',
    'anggota' => 'Anggota',
    _ => 'Administrator',
  };
}

class EventDashboard {
  EventDashboard.fromJson(Map<String, dynamic> json)
      : totalDivisions = _number(json['total_divisions']),
        totalMembers = _number(json['total_members']),
        totalTasks = _number(json['total_tasks']),
        toDo = _number(json['to_do']),
        inProgress = _number(json['in_progress']),
        done = _number(json['done']),
        progress = double.parse(json['progress'].toString());
  static int _number(dynamic value) => num.parse(value.toString()).toInt();
  final int totalDivisions;
  final int totalMembers;
  final int totalTasks;
  final int toDo;
  final int inProgress;
  final int done;
  final double progress;
}

class CmsTask {
  CmsTask.fromJson(Map<String, dynamic> json)
      : title = json['title'] as String,
        division = json['division_name'] as String,
        assignee = json['assigned_to_name'] as String,
        deadline = json['deadline'] as String,
        status = json['status'] as String;
  final String title;
  final String division;
  final String assignee;
  final String deadline;
  final String status;
  String get statusLabel => switch (status) {
    'done' => 'Done',
    'in_progress' => 'In Progress',
    _ => 'To Do',
  };
}
