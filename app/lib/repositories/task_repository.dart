import 'dart:async';

import '../models/task.dart';

/// Repository for managing tasks in memory.
///
/// In a real app, this would persist to a database or API.
class TaskRepository {
  TaskRepository._();

  /// Singleton instance.
  static final TaskRepository instance = TaskRepository._();

  /// In-memory storage for tasks.
  final Map<String, Task> _tasks = {};

  /// Stream controller for task changes.
  final _tasksController = StreamController<List<Task>>.broadcast();

  /// Stream of all tasks.
  Stream<List<Task>> get tasksStream => _tasksController.stream;

  /// Gets all tasks.
  List<Task> getAllTasks() {
    return _tasks.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Gets tasks by their IDs.
  Future<List<Task>> getTasksByIds(List<String> ids) async {
    return ids
        .map((id) => _tasks[id])
        .whereType<Task>()
        .toList();
  }

  /// Gets recent tasks for suggestions.
  Future<List<Task>> getRecentTasks({int limit = 5}) async {
    final tasks = getAllTasks();
    return tasks.take(limit).toList();
  }

  /// Gets a task by ID.
  Task? getTask(String id) {
    return _tasks[id];
  }

  /// Creates a new task.
  Future<Task> createTask({
    required String title,
    String? description,
    DateTime? dueDate,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final task = Task(
      id: id,
      title: title,
      description: description,
      dueDate: dueDate,
      createdAt: DateTime.now(),
    );
    _tasks[id] = task;
    _notifyListeners();
    return task;
  }

  /// Updates an existing task.
  Future<Task?> updateTask({
    required String id,
    String? title,
    String? description,
    DateTime? dueDate,
    bool? isCompleted,
  }) async {
    final existing = _tasks[id];
    if (existing == null) return null;

    final updated = existing.copyWith(
      title: title,
      description: description,
      dueDate: dueDate,
      isCompleted: isCompleted,
    );
    _tasks[id] = updated;
    _notifyListeners();
    return updated;
  }

  /// Toggles the completion status of a task.
  Future<Task?> toggleTaskCompletion(String id) async {
    final task = _tasks[id];
    if (task == null) return null;

    return updateTask(id: id, isCompleted: !task.isCompleted);
  }

  /// Deletes a task by ID.
  Future<bool> deleteTask(String id) async {
    final removed = _tasks.remove(id);
    if (removed != null) {
      _notifyListeners();
      return true;
    }
    return false;
  }

  /// Clears all tasks.
  void clear() {
    _tasks.clear();
    _notifyListeners();
  }

  void _notifyListeners() {
    _tasksController.add(getAllTasks());
  }

  /// Disposes the repository.
  void dispose() {
    _tasksController.close();
  }
}
