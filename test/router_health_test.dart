import 'package:core_monitor/core/router_health.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const evaluator = RouterHealthEvaluator();

  test('healthy router receives a perfect score', () {
    final report = evaluator.evaluate(
      resource: {
        'cpu-load': '20',
        'total-memory': '1000',
        'free-memory': '700',
        'total-hdd-space': '1000',
        'free-hdd-space': '800',
      },
      interfaces: [
        {'type': 'ether', 'running': 'true', 'disabled': 'false'},
      ],
      leases: [
        {'status': 'bound'},
        {'status': 'bound'},
      ],
      logs: const [],
    );

    expect(report.score, 100);
    expect(report.status, 'Sangat Baik');
    expect(report.boundLeases, 2);
    expect(report.findings.single.severity, HealthSeverity.good);
  });

  test('critical resource usage and failures reduce score', () {
    final report = evaluator.evaluate(
      resource: {
        'cpu-load': '92',
        'total-memory': '1000',
        'free-memory': '50',
        'total-hdd-space': '1000',
        'free-hdd-space': '40',
      },
      interfaces: [
        {'type': 'ether', 'running': 'false', 'disabled': 'false'},
        {'type': 'wifi', 'running': 'false', 'disabled': 'false'},
      ],
      leases: const [],
      logs: List.generate(6, (_) => {'topics': 'system,error'}),
    );

    expect(report.score, lessThan(30));
    expect(report.interfacesDown, 2);
    expect(report.recentErrors, 6);
    expect(report.findings.first.severity, HealthSeverity.critical);
  });
}
