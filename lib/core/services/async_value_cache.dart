/// Short-lived, single-flight cache. Failures are never cached.
class AsyncValueCache<T> {
  AsyncValueCache({required this.maxAge, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Duration maxAge;
  final DateTime Function() _now;
  T? _value;
  DateTime? _loadedAt;
  Future<T>? _pending;
  int _generation = 0;

  Future<T> get(Future<T> Function() load) {
    final loadedAt = _loadedAt;
    if (loadedAt != null && _now().difference(loadedAt) < maxAge) {
      return Future.value(_value as T);
    }
    if (_pending != null) return _pending!;
    final generation = _generation;
    late final Future<T> pending;
    pending = Future.sync(load)
        .then((value) {
          if (generation == _generation) {
            _value = value;
            _loadedAt = _now();
          }
          return value;
        })
        .whenComplete(() {
          if (identical(_pending, pending)) _pending = null;
        });
    _pending = pending;
    return pending;
  }

  void update(T Function(T) transform) {
    if (_loadedAt != null) {
      _value = transform(_value as T);
    }
    // A read already in flight must not replace a newer local update.
    _generation++;
    _pending = null;
  }

  void invalidate() {
    _generation++;
    _value = null;
    _loadedAt = null;
    _pending = null;
  }
}
