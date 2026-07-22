String buildCacheKey(Iterable<Object?> parts) {
  return parts
      .map((part) {
        if (part is DateTime) return part.toIso8601String();
        if (part is Iterable<int>) {
          final sorted = part.toList()..sort();
          return sorted.join(',');
        }
        if (part is Map) {
          final entries = part.entries.toList()
            ..sort((left, right) => left.key.toString().compareTo(
                  right.key.toString(),
                ));
          return entries
              .map((entry) => '${entry.key}:${entry.value}')
              .join(',');
        }
        return part?.toString() ?? '';
      })
      .map(Uri.encodeComponent)
      .join('|');
}

class TimedCache<K, V> {
  TimedCache({
    required this.validDuration,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration validDuration;
  final DateTime Function() _now;
  final Map<K, _TimedCacheEntry<V>> _entries = {};

  V? get(K key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (_now().difference(entry.cachedAt) >= validDuration) {
      _entries.remove(key);
      return null;
    }
    return entry.value;
  }

  void put(K key, V value) {
    _entries[key] = _TimedCacheEntry(value, _now());
  }

  void clear() {
    _entries.clear();
  }
}

class _TimedCacheEntry<V> {
  const _TimedCacheEntry(this.value, this.cachedAt);

  final V value;
  final DateTime cachedAt;
}
