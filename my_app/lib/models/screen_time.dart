class ScreenTime {
  final String childId;
  final int dailyLimitMinutes;
  final int usedMinutes;
  final bool autoPause;
  final int extraMinutes;

  ScreenTime({
    required this.childId,
    required this.dailyLimitMinutes,
    required this.usedMinutes,
    this.autoPause = true,
    this.extraMinutes = 0,
  });

  int get remainingMinutes {
    final remaining =
        dailyLimitMinutes + extraMinutes - usedMinutes;

    return remaining > 0 ? remaining : 0;
  }

  double get progress {
    final total = dailyLimitMinutes + extraMinutes;

    if (total == 0) {
      return 0;
    }

    return (usedMinutes / total).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() {
    return {
      'childId': childId,
      'dailyLimitMinutes': dailyLimitMinutes,
      'usedMinutes': usedMinutes,
      'autoPause': autoPause,
      'extraMinutes': extraMinutes,
    };
  }

  factory ScreenTime.fromJson(Map<String, dynamic> json) {
    return ScreenTime(
      childId: json['childId'] ?? '',
      dailyLimitMinutes: json['dailyLimitMinutes'] ?? 0,
      usedMinutes: json['usedMinutes'] ?? 0,
      autoPause: json['autoPause'] ?? true,
      extraMinutes: json['extraMinutes'] ?? 0,
    );
  }
}