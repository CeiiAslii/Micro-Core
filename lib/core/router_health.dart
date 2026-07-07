enum HealthSeverity { critical, warning, good }

class HealthFinding {
  final String title;
  final String detail;
  final String recommendation;
  final HealthSeverity severity;

  const HealthFinding({
    required this.title,
    required this.detail,
    required this.recommendation,
    required this.severity,
  });
}

class RouterHealthReport {
  final int score;
  final int cpu;
  final int ram;
  final int storage;
  final int interfacesDown;
  final int boundLeases;
  final int recentErrors;
  final List<HealthFinding> findings;

  const RouterHealthReport({
    required this.score,
    required this.cpu,
    required this.ram,
    required this.storage,
    required this.interfacesDown,
    required this.boundLeases,
    required this.recentErrors,
    required this.findings,
  });

  String get status {
    if (score >= 90) return 'Sangat Baik';
    if (score >= 75) return 'Baik';
    if (score >= 55) return 'Perlu Perhatian';
    return 'Kritis';
  }
}

class RouterHealthEvaluator {
  const RouterHealthEvaluator();

  RouterHealthReport evaluate({
    required Map<String, String> resource,
    required List<Map<String, String>> interfaces,
    required List<Map<String, String>> leases,
    required List<Map<String, String>> logs,
  }) {
    final cpu = _integer(resource['cpu-load']);
    final totalMemory = _integer(resource['total-memory']);
    final freeMemory = _integer(resource['free-memory']);
    final totalStorage = _integer(resource['total-hdd-space']);
    final freeStorage = _integer(resource['free-hdd-space']);
    final ram = _usage(totalMemory, freeMemory);
    final storage = _usage(totalStorage, freeStorage);
    final interfacesDown = interfaces.where(_isImportantInterfaceDown).length;
    final boundLeases = leases
        .where((lease) => lease['status'] == 'bound')
        .length;
    final recentErrors = logs.where(_isErrorLog).length;
    final findings = <HealthFinding>[];
    var score = 100;

    score -= _resourceFinding(
      findings,
      label: 'CPU',
      value: cpu,
      warningAt: 70,
      criticalAt: 85,
      warningPenalty: 8,
      criticalPenalty: 20,
      recommendation:
          'Periksa process, firewall rule, queue, dan traffic yang membebani CPU.',
    );
    score -= _resourceFinding(
      findings,
      label: 'RAM',
      value: ram,
      warningAt: 75,
      criticalAt: 90,
      warningPenalty: 8,
      criticalPenalty: 18,
      recommendation:
          'Kurangi service yang tidak digunakan dan periksa kemungkinan memory leak.',
    );
    score -= _resourceFinding(
      findings,
      label: 'Storage',
      value: storage,
      warningAt: 75,
      criticalAt: 90,
      warningPenalty: 8,
      criticalPenalty: 18,
      recommendation:
          'Hapus backup atau log lama dan pindahkan file yang tidak diperlukan.',
    );

    if (interfacesDown > 0) {
      final penalty = (interfacesDown * 8).clamp(8, 24);
      score -= penalty;
      findings.add(
        HealthFinding(
          title: '$interfacesDown interface penting down',
          detail: 'Interface ethernet atau wireless aktif tidak running.',
          recommendation:
              'Periksa kabel, perangkat lawan, power, dan konfigurasi interface.',
          severity: interfacesDown >= 2
              ? HealthSeverity.critical
              : HealthSeverity.warning,
        ),
      );
    }

    if (recentErrors > 0) {
      final penalty = recentErrors >= 5 ? 15 : 7;
      score -= penalty;
      findings.add(
        HealthFinding(
          title: '$recentErrors log error terdeteksi',
          detail: 'Router mencatat error atau kegagalan pada log saat ini.',
          recommendation:
              'Buka menu Log Router dan prioritaskan pesan error terbaru.',
          severity: recentErrors >= 5
              ? HealthSeverity.critical
              : HealthSeverity.warning,
        ),
      );
    }

    if (findings.isEmpty) {
      findings.add(
        const HealthFinding(
          title: 'Router dalam kondisi sehat',
          detail: 'Resource dan interface utama berada dalam batas normal.',
          recommendation: 'Pertahankan monitoring dan backup berkala.',
          severity: HealthSeverity.good,
        ),
      );
    }

    findings.sort(
      (a, b) =>
          _severityWeight(b.severity).compareTo(_severityWeight(a.severity)),
    );

    return RouterHealthReport(
      score: score.clamp(0, 100),
      cpu: cpu,
      ram: ram,
      storage: storage,
      interfacesDown: interfacesDown,
      boundLeases: boundLeases,
      recentErrors: recentErrors,
      findings: findings,
    );
  }

  int _resourceFinding(
    List<HealthFinding> findings, {
    required String label,
    required int value,
    required int warningAt,
    required int criticalAt,
    required int warningPenalty,
    required int criticalPenalty,
    required String recommendation,
  }) {
    if (value >= criticalAt) {
      findings.add(
        HealthFinding(
          title: '$label sangat tinggi',
          detail: 'Penggunaan $label mencapai $value%.',
          recommendation: recommendation,
          severity: HealthSeverity.critical,
        ),
      );
      return criticalPenalty;
    }
    if (value >= warningAt) {
      findings.add(
        HealthFinding(
          title: '$label mulai tinggi',
          detail: 'Penggunaan $label mencapai $value%.',
          recommendation: recommendation,
          severity: HealthSeverity.warning,
        ),
      );
      return warningPenalty;
    }
    return 0;
  }

  bool _isImportantInterfaceDown(Map<String, String> row) {
    final type = (row['type'] ?? '').toLowerCase();
    final disabled = row['disabled'] == 'true';
    final running = row['running'] == 'true';
    final important =
        type.contains('ether') ||
        type.contains('wlan') ||
        type.contains('wifi');
    return important && !disabled && !running;
  }

  bool _isErrorLog(Map<String, String> row) {
    final topics = (row['topics'] ?? '').toLowerCase();
    return topics.contains('error') ||
        topics.contains('critical') ||
        topics.contains('failed');
  }

  int _integer(String? value) => int.tryParse(value ?? '0') ?? 0;

  int _usage(int total, int free) {
    if (total <= 0) return 0;
    return (((total - free) / total) * 100).round().clamp(0, 100);
  }

  int _severityWeight(HealthSeverity severity) => switch (severity) {
    HealthSeverity.critical => 3,
    HealthSeverity.warning => 2,
    HealthSeverity.good => 1,
  };
}
