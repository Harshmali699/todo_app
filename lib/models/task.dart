enum Priority { low, medium, high }

class Task {
  final int? id;
  final String title;
  final String description;
  final Priority priority;
  final DateTime? dueDate;
  final bool isCompleted;
  final DateTime createdAt;

  Task({
    this.id,
    required this.title,
    this.description = '',
    this.priority = Priority.medium,
    this.dueDate,
    this.isCompleted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Task copyWith({
    int? id,
    String? title,
    String? description,
    Priority? priority,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'description': description,
        'priority': priority.index,
        'due_date': dueDate?.millisecondsSinceEpoch,
        'is_completed': isCompleted ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Task.fromMap(Map<String, Object?> m) => Task(
        id: m['id'] as int?,
        title: m['title'] as String,
        description: (m['description'] as String?) ?? '',
        priority: Priority.values[(m['priority'] as int?) ?? 1],
        dueDate: m['due_date'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['due_date'] as int),
        isCompleted: (m['is_completed'] as int?) == 1,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}
