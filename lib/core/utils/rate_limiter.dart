class RateLimitException implements Exception {
  final String message;
  final int retryAfterSeconds;

  RateLimitException(this.message, {this.retryAfterSeconds = 60});

  @override
  String toString() => message;
}

class RateLimiter {
  final int maxRequestsPerWindow;
  final Duration windowDuration;
  final List<DateTime> _requestTimestamps = [];
  final DateTime Function() _clock;
  DateTime? _cooldownUntil;

  RateLimiter({
    this.maxRequestsPerWindow = 10,
    this.windowDuration = const Duration(seconds: 60),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  DateTime? get cooldownUntil => _cooldownUntil;

  void parseAndSetCooldown(String? retryAfterHeader) {
    if (retryAfterHeader == null || retryAfterHeader.trim().isEmpty) return;
    final now = _clock();
    final trimmed = retryAfterHeader.trim();

    // 1. Check if integer seconds (e.g., "120")
    final seconds = int.tryParse(trimmed);
    if (seconds != null && seconds > 0) {
      _cooldownUntil = now.add(Duration(seconds: seconds));
      return;
    }

    // 2. Check if HTTP-date (e.g., "Wed, 21 Oct 2026 07:28:00 GMT")
    try {
      final parsedDate = DateTime.parse(trimmed);
      if (parsedDate.isAfter(now)) {
        _cooldownUntil = parsedDate;
      }
    } catch (_) {
      // Default to 60s cooldown if header is unparseable
      _cooldownUntil = now.add(const Duration(seconds: 60));
    }
  }

  bool checkAndRecord({bool enforce = false}) {
    final now = _clock();

    // 1. Check Cooldown
    if (_cooldownUntil != null && now.isBefore(_cooldownUntil!)) {
      final waitSec = _cooldownUntil!.difference(now).inSeconds + 1;
      if (enforce) {
        throw RateLimitException(
          'AFAD sunucu bekleme süresi (cooldown) aktif. Kalan süre: $waitSec sn.',
          retryAfterSeconds: waitSec,
        );
      }
      return false;
    }

    // 2. Sliding window check
    final cutoff = now.subtract(windowDuration);
    _requestTimestamps.removeWhere((timestamp) => timestamp.isBefore(cutoff));

    if (_requestTimestamps.length >= maxRequestsPerWindow) {
      if (enforce) {
        final oldestInWindow = _requestTimestamps.first;
        final resetTime = oldestInWindow.add(windowDuration);
        final waitSeconds = resetTime.difference(now).inSeconds + 1;
        throw RateLimitException(
          'Çok fazla HTTP isteği gönderildi. Lütfen dakikada maksimum $maxRequestsPerWindow sorgu limitine uyun.',
          retryAfterSeconds: waitSeconds > 0 ? waitSeconds : 60,
        );
      }
      return false;
    }

    _requestTimestamps.add(now);
    return true;
  }

  int get remainingRequests {
    final now = _clock();
    final cutoff = now.subtract(windowDuration);
    _requestTimestamps.removeWhere((timestamp) => timestamp.isBefore(cutoff));
    return maxRequestsPerWindow - _requestTimestamps.length;
  }

  int get secondsUntilReset {
    final now = _clock();
    if (_cooldownUntil != null && now.isBefore(_cooldownUntil!)) {
      return _cooldownUntil!.difference(now).inSeconds;
    }
    if (_requestTimestamps.isEmpty) return 0;
    final oldest = _requestTimestamps.first;
    final resetTime = oldest.add(windowDuration);
    final diff = resetTime.difference(now).inSeconds;
    return diff > 0 ? diff : 0;
  }

  void reset() {
    _requestTimestamps.clear();
    _cooldownUntil = null;
  }
}
