import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/task.dart';
import '../widgets/task_form_sheet.dart';

enum TaskFilter { all, active, done }

enum SortBy { dueDate, priority, newest }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper.instance;
  List<Task> _tasks = [];
  bool _loading = true;
  TaskFilter _filter = TaskFilter.all;
  SortBy _sort = SortBy.dueDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tasks = await _db.getTasks();
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _loading = false;
    });
  }

  List<Task> get _visible {
    final list = _tasks.where((t) {
      switch (_filter) {
        case TaskFilter.all:
          return true;
        case TaskFilter.active:
          return !t.isCompleted;
        case TaskFilter.done:
          return t.isCompleted;
      }
    }).toList();

    list.sort((a, b) {
      // Completed tasks always sink to the bottom.
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      switch (_sort) {
        case SortBy.dueDate:
          if (a.dueDate == null && b.dueDate != null) return 1;
          if (a.dueDate != null && b.dueDate == null) return -1;
          if (a.dueDate != null && b.dueDate != null) {
            final c = a.dueDate!.compareTo(b.dueDate!);
            if (c != 0) return c;
          }
          break;
        case SortBy.priority:
          final c = b.priority.index.compareTo(a.priority.index);
          if (c != 0) return c;
          break;
        case SortBy.newest:
          break;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  Future<void> _openForm([Task? task]) async {
    final result = await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => TaskFormSheet(task: task),
    );
    if (result == null) return;
    if (result.id == null) {
      await _db.insert(result);
    } else {
      await _db.update(result);
    }
    _load();
  }

  Future<void> _toggle(Task task, bool? value) async {
    await _db.setCompleted(task.id!, value ?? false);
    _load();
  }

  Future<void> _delete(Task task) async {
    await _db.delete(task.id!);
    setState(() => _tasks.removeWhere((t) => t.id == task.id));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Deleted "${task.title}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await _db.insert(task); // keeps original id
            _load();
          },
        ),
      ));
  }

  Future<void> _clearCompleted() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear completed?'),
        content: const Text('All completed tasks will be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) {
      await _db.deleteCompleted();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _visible;
    final remaining = _tasks.where((t) => !t.isCompleted).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        actions: [
          PopupMenuButton<SortBy>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: SortBy.dueDate, child: Text('Due date')),
              PopupMenuItem(value: SortBy.priority, child: Text('Priority')),
              PopupMenuItem(value: SortBy.newest, child: Text('Newest')),
            ],
          ),
          IconButton(
            tooltip: 'Clear completed',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed:
                _tasks.any((t) => t.isCompleted) ? _clearCompleted : null,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                for (final f in TaskFilter.values) ...[
                  ChoiceChip(
                    label: Text(switch (f) {
                      TaskFilter.all => 'All',
                      TaskFilter.active => 'Active',
                      TaskFilter.done => 'Done',
                    }),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                Text('$remaining left',
                    style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : tasks.isEmpty
              ? _EmptyState(filter: _filter)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  itemCount: tasks.length,
                  itemBuilder: (context, i) {
                    final task = tasks[i];
                    return Dismissible(
                      key: ValueKey(task.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.delete,
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer),
                      ),
                      onDismissed: (_) => _delete(task),
                      child: _TaskTile(
                        task: task,
                        onToggle: (v) => _toggle(task, v),
                        onTap: () => _openForm(task),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('New task'),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final Task task;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onTap;

  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onTap,
  });

  Color _priorityColor() => switch (task.priority) {
        Priority.high => Colors.red,
        Priority.medium => Colors.orange,
        Priority.low => Colors.green,
      };

  bool get _overdue {
    if (task.dueDate == null || task.isCompleted) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return task.dueDate!.isBefore(today);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = task.isCompleted;
    final mutedColor = theme.colorScheme.onSurface.withOpacity(0.5);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: done ? mutedColor : _priorityColor()),
              Checkbox(value: done, onChanged: onToggle),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                          color: done ? mutedColor : null,
                        ),
                      ),
                      if (task.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            task.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: mutedColor),
                          ),
                        ),
                      if (task.dueDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.event,
                                size: 14,
                                color: _overdue
                                    ? theme.colorScheme.error
                                    : mutedColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('EEE, d MMM')
                                        .format(task.dueDate!) +
                                    (_overdue ? ' · Overdue' : ''),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: _overdue
                                      ? theme.colorScheme.error
                                      : mutedColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(Icons.flag,
                    size: 20, color: done ? mutedColor : _priorityColor()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final TaskFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final msg = switch (filter) {
      TaskFilter.all => 'No tasks yet.\nTap "New task" to add one.',
      TaskFilter.active => 'Nothing left to do. 🎉',
      TaskFilter.done => 'No completed tasks yet.',
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.checklist_rounded,
              size: 72,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text(msg,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
