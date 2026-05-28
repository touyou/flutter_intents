import 'dart:io';

import 'package:app_intents/app_intents.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import 'entities/task_entity.dart';
import 'intents/complete_task_intent.dart';
import 'intents/create_task_intent.dart';
import 'intents/create_task_with_image_intent.dart';
import 'models/task.dart';
import 'repositories/task_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure App Group storage (iOS) for cross-process data sharing.
  // Must be called before any cache operations or handler registrations
  // that depend on persisted data.
  await AppIntents().configureStorage(
    appGroupIdentifier: 'group.com.example.taskapp',
  );

  // Load persisted tasks from App Group UserDefaults
  await TaskRepository.instance.loadFromStorage();

  // Initialize all App Intents handlers
  initializeCreateTaskAppIntents();
  initializeCompleteTaskAppIntents();
  initializeCreateTaskWithImageAppIntents();
  initializeTaskAppIntents();

  runApp(const TaskApp());
}

class TaskApp extends StatelessWidget {
  const TaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TaskListPage(),
    );
  }
}

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  List<Task> _tasks = [];
  late AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    TaskRepository.instance.tasksStream.listen((tasks) {
      if (mounted) {
        setState(() => _tasks = tasks);
      }
    });

    // Process pending cache-mode intent actions when notified by native side
    AppIntents().pendingActionsStream.listen((_) {
      AppIntents().processPendingActions();
    });

    _initAppLinks();
  }

  Future<void> _initAppLinks() async {
    _appLinks = AppLinks();

    // Handle link when app is started from terminated state
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _handleDeepLink(initialUri);
    }

    // Handle links when app is running
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Deep link received: $uri');

    switch (uri.host) {
      case 'create':
        _handleCreateTask(uri.queryParameters);
        break;
      case 'complete':
        _handleCompleteTask(uri.queryParameters);
        break;
      default:
        debugPrint('Unknown deep link action: ${uri.host}');
    }
  }

  Future<void> _handleCreateTask(Map<String, String> queryParams) async {
    try {
      final params = CreateTaskIntentParams.fromQueryParameters(queryParams);

      await TaskRepository.instance.createTask(
        title: params.title,
        description: params.description,
        dueDate: params.dueDate,
      );

      _showSnackBar('Task "${params.title}" created via Shortcut!');
    } catch (e) {
      _showSnackBar('Task title is required');
    }
  }

  Future<void> _handleCompleteTask(Map<String, String> queryParams) async {
    try {
      final params = CompleteTaskIntentParams.fromQueryParameters(queryParams);

      final task = TaskRepository.instance.getTask(params.task);
      if (task == null) {
        _showSnackBar('Task not found');
        return;
      }

      await TaskRepository.instance.toggleTaskCompletion(params.task);
      _showSnackBar('Task "${task.title}" completed via Shortcut!');
    } catch (e) {
      _showSnackBar('Task ID is required');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _loadTasks() {
    setState(() {
      _tasks = TaskRepository.instance.getAllTasks();
    });
  }

  Future<void> _addTask() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const AddTaskDialog(),
    );
    if (result != null && result.isNotEmpty) {
      await TaskRepository.instance.createTask(title: result);
    }
  }

  Future<void> _toggleTask(Task task) async {
    await TaskRepository.instance.toggleTaskCompletion(task.id);
  }

  Future<void> _deleteTask(Task task) async {
    await TaskRepository.instance.deleteTask(task.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _tasks.isEmpty
          ? const Center(
              child: Text(
                'No tasks yet.\nTap + to add one, or use Siri!',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return TaskTile(
                  task: task,
                  onToggle: () => _toggleTask(task),
                  onDelete: () => _deleteTask(task),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        tooltip: 'Add Task',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (_) => onToggle(),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: task.description != null ? Text(task.description!) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.file(
                  File(task.imagePath!),
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image, size: 40),
                ),
              ),
            if (task.dueDate != null)
              Padding(
                padding: EdgeInsets.only(left: task.imagePath != null ? 8 : 0),
                child: Text(
                  '${task.dueDate!.month}/${task.dueDate!.day}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AddTaskDialog extends StatefulWidget {
  const AddTaskDialog({super.key});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Task'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Enter task title',
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
