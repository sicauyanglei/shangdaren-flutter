class AnimationTask {
  final bool Function(double dt) update;

  AnimationTask(this.update);

  bool isComplete = false;
}

class DelayTask {
  double _remaining;
  final void Function() callback;

  DelayTask(this._remaining, this.callback);

  bool get isComplete => _remaining <= 0;
}

class GameTicker {
  final List<AnimationTask> _animationTasks = [];
  final List<DelayTask> _delayTasks = [];

  AnimationTask addAnimationTask(bool Function(double dt) update) {
    final task = AnimationTask(update);
    _animationTasks.add(task);
    return task;
  }

  DelayTask addDelayTask(double seconds, void Function() callback) {
    final task = DelayTask(seconds, callback);
    _delayTasks.add(task);
    return task;
  }

  void update(double dt) {
    for (int i = _animationTasks.length - 1; i >= 0; i--) {
      final task = _animationTasks[i];
      if (task.isComplete) {
        _animationTasks.removeAt(i);
        continue;
      }
      task.isComplete = !task.update(dt);
      if (task.isComplete) {
        _animationTasks.removeAt(i);
      }
    }

    for (int i = _delayTasks.length - 1; i >= 0; i--) {
      final task = _delayTasks[i];
      task._remaining -= dt;
      if (task.isComplete) {
        task.callback();
        _delayTasks.removeAt(i);
      }
    }
  }

  void removeTask(AnimationTask task) {
    task.isComplete = true;
    _animationTasks.remove(task);
  }

  void removeDelay(DelayTask task) {
    _delayTasks.remove(task);
  }

  void clear() {
    _animationTasks.clear();
    _delayTasks.clear();
  }
}
