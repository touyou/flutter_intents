class Task {
  final String id;
  final String title;
  final DateTime? dueDate;

  const Task({required this.id, required this.title, this.dueDate});
}

class TaskRepository {
  static final TaskRepository instance = TaskRepository();

  final List<Task> _tasks = [
      Task(id: '1', title: 'Buy groceries', dueDate: DateTime.now().add(Duration(days: 1))),
      Task(id: '2', title: 'Walk the dog', dueDate: DateTime.now().add(Duration(days: 2))),
    ];

  Future<List<Task>> getAllTasks() async {
    return _tasks;
  }

  Future<void> addTask(Task task) async {
    _tasks.add(task);
  }

  Future<Task?> getTaskById(String id) async {
    return _tasks.where((task) => task.id == id).firstOrNull;
  }

  Future<void> removeTask(String id) async {
    _tasks.removeWhere((task) => task.id == id);
  }
}
