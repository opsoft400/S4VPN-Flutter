/// The ad reward system.
///
/// A connection costs one credit. Watching an ad pays two, so the balance is
/// never time-boxed -- only the number of connections it can buy is. A code
/// handed out by the server switches the same balance off for a while: for as
/// long as it lasts the ad section is simply not part of the app, and when it
/// runs out it comes back exactly as it was.
///
/// The word the server calls that state never reaches a label. The app knows
/// it only as a timestamp in the future.
import 'dart:convert';

/// Where a credit came from.
enum CreditSource { ad, code, bonus }

/// One movement of the credit balance, kept so the rewards screen can show a
/// history instead of only a number.
class RewardTransaction {
  const RewardTransaction({
    required this.id,
    required this.source,
    required this.amount,
    required this.timestamp,
    this.note,
  });

  final String id;
  final CreditSource source;
  final int amount;
  final DateTime timestamp;
  final String? note;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'source': source.name,
        'amount': amount,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'note': note,
      };

  factory RewardTransaction.fromJson(Map<String, Object?> json) {
    final String source = (json['source'] ?? 'ad').toString();
    return RewardTransaction(
      id: (json['id'] ?? '').toString(),
      source: CreditSource.values.firstWhere(
        (CreditSource value) => value.name == source,
        orElse: () => CreditSource.ad,
      ),
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['timestamp'] as num?)?.toInt() ?? 0,
      ),
      note: json['note'] as String?,
    );
  }
}

/// The whole reward balance, as it is persisted.
///
/// [adFreeUntil] is a plain instant in the future. Nothing in this app names
/// what that state is called; the settings screen, the home screen and the
/// navigation only ask whether it has passed.
class RewardState {
  RewardState({
    this.credits = 0,
    this.adFreeUntil = 0,
    this.totalEarned = 0,
    this.totalSpent = 0,
    List<RewardTransaction>? history,
  }) : history = history ?? <RewardTransaction>[];

  int credits;
  int adFreeUntil;
  int totalEarned;
  int totalSpent;
  final List<RewardTransaction> history;

  /// Connections one ad buys. Fixed by the brief: one ad, three connections.
  static const int connectionsPerAd = 3;

  /// One connection costs one credit.
  static const int creditsPerConnection = 1;

  /// True while the time handed out by a code has not run out.
  bool get adFreeActive =>
      adFreeUntil > DateTime.now().millisecondsSinceEpoch;

  /// Remaining whole seconds, or 0.
  int get adFreeRemainingSeconds {
    final int left = adFreeUntil - DateTime.now().millisecondsSinceEpoch;
    return left > 0 ? left ~/ 1000 : 0;
  }

  /// `1d 4h`, `4h 12m`, `12m 5s` -- whichever is the largest that is not
  /// zero, so the line stays short.
  String get adFreeRemainingLabel {
    int seconds = adFreeRemainingSeconds;
    if (seconds <= 0) return '';
    final int days = seconds ~/ 86400;
    seconds %= 86400;
    final int hours = seconds ~/ 3600;
    seconds %= 3600;
    final int minutes = seconds ~/ 60;
    seconds %= 60;
    if (days > 0) return '${days}d ${hours}h';
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  /// Whether a connection can be paid for right now.
  bool get canAffordConnection => credits >= creditsPerConnection;

  RewardTransaction add({
    required CreditSource source,
    required int amount,
    String? note,
  }) {
    final RewardTransaction entry = RewardTransaction(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      source: source,
      amount: amount,
      timestamp: DateTime.now(),
      note: note,
    );
    if (amount > 0) {
      credits += amount;
      totalEarned += amount;
    } else {
      credits += amount; // negative when spent
      if (amount < 0) totalSpent += -amount;
    }
    history.insert(0, entry);
    if (history.length > 100) history.removeLast();
    return entry;
  }

  /// Pay for one connection. Returns false when the balance will not cover it.
  bool spendOne() {
    if (credits < creditsPerConnection) return false;
    credits -= creditsPerConnection;
    totalSpent += creditsPerConnection;
    history.insert(
      0,
      RewardTransaction(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        source: CreditSource.ad,
        amount: -creditsPerConnection,
        timestamp: DateTime.now(),
      ),
    );
    if (history.length > 100) history.removeLast();
    return true;
  }

  /// Hand out time from a code. Longer codes extend what is already running
  /// rather than restarting it, so a user is never worse off for redeeming
  /// early.
  void grantAdFree(Duration duration) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int base = adFreeUntil > now ? adFreeUntil : now;
    adFreeUntil = base + duration.inMilliseconds;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'credits': credits,
        'adFreeUntil': adFreeUntil,
        'totalEarned': totalEarned,
        'totalSpent': totalSpent,
        'history': history.map((RewardTransaction e) => e.toJson()).toList(),
      };

  factory RewardState.fromJson(Map<String, Object?> json) {
    final List<dynamic> raw =
        (json['history'] as List?) ?? const <dynamic>[];
    return RewardState(
      credits: (json['credits'] as num?)?.toInt() ?? 0,
      adFreeUntil: (json['adFreeUntil'] as num?)?.toInt() ?? 0,
      totalEarned: (json['totalEarned'] as num?)?.toInt() ?? 0,
      totalSpent: (json['totalSpent'] as num?)?.toInt() ?? 0,
      history: raw
          .whereType<Map>()
          .map((Map e) =>
              RewardTransaction.fromJson(e.cast<String, Object?>()))
          .toList(),
    );
  }

  String encode() => jsonEncode(toJson());

  factory RewardState.decode(String source) {
    try {
      final Object? decoded = jsonDecode(source);
      if (decoded is Map<String, Object?>) return RewardState.fromJson(decoded);
      if (decoded is Map) {
        return RewardState.fromJson(decoded.cast<String, Object?>());
      }
    } on Exception {
      // A corrupt balance must not stop the app from opening; start again.
    }
    return RewardState();
  }
}

/// Give a credit back, for a connection that never came up.
extension RewardRefund on RewardState {
  void refund(int amount) {
    if (amount <= 0) return;
    credits += amount;
    if (totalSpent >= amount) totalSpent -= amount;
  }
}
