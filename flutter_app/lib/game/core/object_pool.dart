class ObjectPool<T> {
  final List<T> _pool = [];
  final T Function() _factory;
  final void Function(T) _reset;

  ObjectPool(this._factory, this._reset);

  T acquire() {
    if (_pool.isNotEmpty) return _pool.removeLast();
    return _factory();
  }

  void release(T obj) {
    _reset(obj);
    _pool.add(obj);
  }

  void clear() => _pool.clear();

  int get size => _pool.length;
}
