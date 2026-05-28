import 'dart:async';
import 'dart:convert';

import 'package:app_intents/app_intents.dart';

import '../models/task.dart';

/// Repository for managing tasks with App Group UserDefaults persistence.
///
/// Uses the app_intents caching API (App Group UserDefaults) so that
/// task data is accessible from both the main app and App Intent
/// extension processes (e.g., WFIsolatedShortcutRunner).
class TaskRepository {
  TaskRepository._();

  /// Singleton instance.
  static final TaskRepository instance = TaskRepository._();

  static const _storageKey = 'tasks';

  /// Cache key that mirrors the entity list for EntityQuery cold-start fallback.
  ///
  /// Must match `TaskEntitySpec`'s `persistedCacheKey`. Generated Swift reads
  /// from this key (via `AppIntentsPlugin.getCached`) when Siri/Shortcuts
  /// fires an EntityQuery before the Flutter engine has finished initializing.
  static const _entityCacheKey = 'com.example.taskapp.cache.tasks';

  /// In-memory cache backed by App Group UserDefaults.
  final Map<String, Task> _tasks = {};

  /// Stream controller for task changes.
  final _tasksController = StreamController<List<Task>>.broadcast();

  /// Stream of all tasks.
  Stream<List<Task>> get tasksStream => _tasksController.stream;

  /// Loads tasks from App Group UserDefaults into memory.
  ///
  /// Call this once at startup, after `configureStorage()`.
  Future<void> loadFromStorage() async {
    final raw = await AppIntents().getCachedValue(_storageKey);
    if (raw is String && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _tasks.clear();
        for (final item in list) {
          final task = Task.fromJson(item as Map<String, dynamic>);
          _tasks[task.id] = task;
        }
        _notifyListeners();
      } catch (e) {
        // Corrupted data — start fresh but log it
        assert(() {
          // ignore: avoid_print
          print('[TaskRepository] Failed to load tasks from storage: $e');
          return true;
        }());
      }
    }
  }

  /// Persists current tasks to App Group UserDefaults.
  ///
  /// Writes both the full task list (`_storageKey`) and the
  /// entity-shaped projection used by the EntityQuery cold-start fallback
  /// (`_entityCacheKey`). Field names in the entity projection must match
  /// `TaskEntitySpec`'s `@EntityId`/`@EntityTitle`/etc. annotations.
  Future<void> _saveToStorage() async {
    final json = jsonEncode(_tasks.values.map((t) => t.toJson()).toList());
    await AppIntents().setCachedValue(_storageKey, json);

    final entityJson = jsonEncode(
      _tasks.values
          .map(
            (t) => {'id': t.id, 'title': t.title, 'description': t.description},
          )
          .toList(),
    );
    await AppIntents().setCachedValue(_entityCacheKey, entityJson);
  }

  /// Gets all tasks.
  List<Task> getAllTasks() {
    return _tasks.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Gets tasks by their IDs.
  Future<List<Task>> getTasksByIds(List<String> ids) async {
    return ids.map((id) => _tasks[id]).whereType<Task>().toList();
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
    String? imagePath,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final task = Task(
      id: id,
      title: title,
      description: description,
      dueDate: dueDate,
      imagePath: imagePath,
      createdAt: DateTime.now(),
    );
    _tasks[id] = task;
    _notifyListeners();
    await _saveToStorage();
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
    await _saveToStorage();
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
      await _saveToStorage();
      return true;
    }
    return false;
  }

  /// Clears all tasks.
  Future<void> clear() async {
    _tasks.clear();
    _notifyListeners();
    await _saveToStorage();
  }

  void _notifyListeners() {
    _tasksController.add(getAllTasks());
  }

  /// Disposes the repository.
  void dispose() {
    _tasksController.close();
  }
}
