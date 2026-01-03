import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import 'entities/task_entity.dart';
import 'intents/complete_task_intent.dart';
import 'intents/create_task_intent.dart';
import 'models/task.dart';
import 'repositories/task_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize all App Intents handlers
  initializeCreateTaskAppIntents();
  initializeCompleteTaskAppIntents();
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

    // Initialize app links handler
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

  Future<void> _handleCreateTask(Map<String, String> params) async {
    final title = params['title'];
    if (title == null || title.isEmpty) {
      _showSnackBar('Task title is required');
      return;
    }

    final description = params['description'];
    DateTime? dueDate;
    if (params['dueDate'] != null) {
      dueDate = DateTime.tryParse(params['dueDate']!);
    }

    await TaskRepository.instance.createTask(
      title: title,
      description: description,
      dueDate: dueDate,
    );

    _showSnackBar('Task "$title" created via Shortcut!');
  }

  Future<void> _handleCompleteTask(Map<String, String> params) async {
    final taskId = params['taskId'];
    if (taskId == null || taskId.isEmpty) {
      _showSnackBar('Task ID is required');
      return;
    }

    final task = TaskRepository.instance.getTask(taskId);
    if (task == null) {
      _showSnackBar('Task not found');
      return;
    }

    await TaskRepository.instance.toggleTaskCompletion(taskId);
    _showSnackBar('Task "${task.title}" completed via Shortcut!');
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
        trailing: task.dueDate != null
            ? Text(
                '${task.dueDate!.month}/${task.dueDate!.day}',
                style: Theme.of(context).textTheme.bodySmall,
              )
            : null,
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
