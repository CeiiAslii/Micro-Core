import 'package:core_monitor/core/mikrotik_api.dart';
import 'package:core_monitor/providers/app_provider.dart';
import 'package:core_monitor/screens/about/about_screen.dart';
import 'package:core_monitor/screens/dashboard/dashboard_screen.dart';
import 'package:core_monitor/screens/health/health_center_screen.dart';
import 'package:core_monitor/screens/hotspot/hotspot_screen.dart';
import 'package:core_monitor/screens/interface/interface_screen.dart';
import 'package:core_monitor/screens/ip/ip_screen.dart';
import 'package:core_monitor/screens/loadbalance/loadbalance_screen.dart';
import 'package:core_monitor/screens/logs/router_log_screen.dart';
import 'package:core_monitor/screens/network_tools/network_tools_screen.dart';
import 'package:core_monitor/screens/pppoe/pppoe_screen.dart';
import 'package:core_monitor/screens/storage/storage_screen.dart';
import 'package:core_monitor/screens/system/system_control_screen.dart';
import 'package:core_monitor/screens/terminal/safe_terminal_screen.dart';
import 'package:core_monitor/screens/tools/diagnostic_tools_screen.dart';
import 'package:core_monitor/screens/winbox/router_config_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SmokeApi extends MikrotikApi {
  _SmokeApi() : super(host: '127.0.0.1', username: 'admin', password: 'test') {
    isConnected = true;
  }

  @override
  Future<bool> connect() async => true;

  @override
  Future<List<Map<String, String>>> query(
    List<String> command, {
    Duration timeout = const Duration(seconds: 15),
  }) => queryOrThrow(command, timeout: timeout);

  @override
  Future<List<Map<String, String>>> queryPageOrThrow(
    List<String> command, {
    required int offset,
    required int limit,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final rows = await queryOrThrow(command, timeout: timeout);
    return rows.skip(offset).take(limit).toList();
  }

  @override
  Future<List<Map<String, String>>> queryOrThrow(
    List<String> command, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final path = command.first;
    if (path == '/interface/monitor-traffic') {
      return [
        {'rx-bits-per-second': '1200', 'tx-bits-per-second': '800'},
      ];
    }
    if (path.endsWith('/add') ||
        path.endsWith('/set') ||
        path.endsWith('/remove') ||
        path.endsWith('/enable') ||
        path.endsWith('/disable') ||
        path.endsWith('/run') ||
        path == '/ping' ||
        path == '/tool/traceroute' ||
        path == '/tool/bandwidth-test' ||
        path == '/export') {
      return [
        {'status': 'ok'},
      ];
    }

    final rows = switch (path) {
      '/system/identity/print' => [
        {'.id': '*1', 'name': 'Router Test'},
      ],
      '/system/resource/print' => [
        {
          'board-name': 'RB450Gx4',
          'version': '7.16.1',
          'platform': 'MikroTik',
          'uptime': '4d17h',
          'cpu-load': '14',
          'total-memory': '1000000',
          'free-memory': '880000',
          'total-hdd-space': '512000000',
          'free-hdd-space': '460000000',
        },
      ],
      '/system/health/print' => [
        {'name': 'temperature', 'value': '42', 'type': 'C'},
      ],
      '/system/clock/print' => [
        {'time': '07:30:00', 'date': 'jun/15/2026'},
      ],
      '/system/note/print' => [
        {'note': 'Core Monitor smoke test'},
      ],
      '/system/routerboard/print' => [
        {'routerboard': 'true', 'model': 'RB450Gx4'},
      ],
      '/system/package/update/print' => [
        {'status': 'System is already up to date'},
      ],
      '/interface/print' => [
        {
          '.id': '*1',
          'name': 'ether1 WAN',
          'type': 'ether',
          'running': 'true',
          'disabled': 'false',
          'mtu': '1500',
          'mac-address': '00:11:22:33:44:55',
          'tx-byte': '19895654321',
          'rx-byte': '1002345678',
        },
        {
          '.id': '*2',
          'name': 'ether5 HOTSPOT',
          'type': 'ether',
          'running': 'true',
          'disabled': 'false',
          'mtu': '1500',
        },
        {
          '.id': '*3',
          'name': '<pppoe-amat>',
          'type': 'pppoe-in',
          'running': 'true',
          'disabled': 'false',
          'mtu': '1480',
          'tx-byte': '19895654321',
          'rx-byte': '1002345678',
        },
      ],
      '/interface/vlan/print' => [
        {
          '.id': '*10',
          'name': 'PPPoE',
          'vlan-id': '10',
          'interface': 'ether5 HOTSPOT',
        },
      ],
      '/interface/bridge/print' => [
        {'.id': '*20', 'name': 'bridge1', 'protocol-mode': 'rstp'},
      ],
      '/interface/bridge/port/print' => [
        {'.id': '*21', 'interface': 'ether2', 'bridge': 'bridge1'},
      ],
      '/interface/bridge/vlan/print' => [
        {'.id': '*22', 'bridge': 'bridge1', 'vlan-ids': '10'},
      ],
      '/interface/bridge/filter/print' => [
        {
          '.id': '*23',
          'chain': 'forward',
          'action': 'accept',
          'in-interface': 'ether2',
        },
      ],
      '/interface/bridge/nat/print' => [
        {
          '.id': '*24',
          'chain': 'srcnat',
          'action': 'accept',
          'out-interface': 'ether2',
        },
      ],
      '/interface/bridge/host/print' => [
        {
          '.id': '*25',
          'mac-address': '00:11:22:33:44:66',
          'bridge': 'bridge1',
          'interface': 'ether2',
        },
      ],
      '/interface/bridge/mdb/print' => [
        {
          '.id': '*26',
          'group': '239.1.1.1',
          'bridge': 'bridge1',
          'port': 'ether2',
        },
      ],
      '/interface/bridge/msti/print' => [
        {
          '.id': '*27',
          'identifier': '1',
          'bridge': 'bridge1',
          'vlan-mapping': '10',
        },
      ],
      '/interface/bridge/port/mst-override/print' => [
        {
          '.id': '*28',
          'interface': 'ether2',
          'identifier': '1',
          'priority': '128',
        },
      ],
      '/ip/address/print' => [
        {
          '.id': '*30',
          'address': '10.10.0.1/22',
          'interface': 'ether5 HOTSPOT',
        },
      ],
      '/ip/pool/print' => [
        {
          '.id': '*31',
          'name': 'IP-POOL-USER-HS',
          'ranges': '10.10.0.10-10.10.1.254',
        },
      ],
      '/ip/dhcp-server/print' => [
        {
          '.id': '*32',
          'name': 'dhcp1',
          'interface': 'ether5 HOTSPOT',
          'address-pool': 'IP-POOL-USER-HS',
        },
      ],
      '/ip/dhcp-server/lease/print' => [
        {
          '.id': '*33',
          'address': '10.10.0.50',
          'mac-address': 'AA:BB:CC:DD:EE:FF',
          'status': 'bound',
        },
      ],
      '/ip/dns/print' => [
        {'servers': '8.8.8.8,8.8.4.4', 'allow-remote-requests': 'true'},
      ],
      '/ip/dns/static/print' => [
        {'.id': '*34', 'name': 'login.hotspot', 'address': '10.10.0.1'},
      ],
      '/ip/firewall/filter/print' ||
      '/ip/firewall/nat/print' ||
      '/ip/firewall/mangle/print' ||
      '/ip/firewall/raw/print' => [
        {
          '.id': '*40',
          'chain': 'forward',
          'action': 'accept',
          'comment': 'smoke',
        },
      ],
      '/ip/route/print' => [
        {'.id': '*50', 'dst-address': '0.0.0.0/0', 'gateway': '10.0.0.1'},
      ],
      '/routing/table/print' => [
        {'.id': '*51', 'name': 'main', 'fib': 'true'},
      ],
      '/ip/arp/print' => [
        {
          '.id': '*52',
          'address': '10.10.0.2',
          'mac-address': '00:AA:BB:CC:DD:EE',
        },
      ],
      '/ip/neighbor/print' => [
        {'.id': '*53', 'address': '10.10.0.2', 'identity': 'neighbor'},
      ],
      '/ip/hotspot/print' => [
        {
          '.id': '*60',
          'name': 'hotspot1',
          'interface': 'ether5 HOTSPOT',
          'profile': 'hsprof1',
        },
      ],
      '/ip/hotspot/profile/print' => [
        {'.id': '*61', 'name': 'hsprof1', 'dns-name': 'datuwifi.net'},
      ],
      '/ip/hotspot/user/profile/print' => [
        {
          '.id': '*62',
          'name': 'Harian',
          'rate-limit': '4M/7M',
          'shared-users': '1',
        },
      ],
      '/ip/hotspot/user/print' => [
        {
          '.id': '*63',
          'name': 'voucher1',
          'profile': 'Harian',
          'server': 'all',
        },
      ],
      '/ip/hotspot/active/print' => [
        {
          '.id': '*64',
          'user': 'voucher1',
          'address': '10.10.0.60',
          'uptime': '1h',
        },
      ],
      '/ppp/active/print' => [
        {
          '.id': '*70',
          'name': 'amat',
          'service': 'pppoe',
          'address': '172.22.0.1',
        },
      ],
      '/ppp/secret/print' => [
        {'.id': '*71', 'name': 'amat', 'service': 'pppoe', 'profile': '13 mb'},
      ],
      '/ppp/profile/print' => [
        {'.id': '*72', 'name': '13 mb', 'rate-limit': '13M/13M'},
      ],
      '/interface/pppoe-server/server/print' => [
        {
          '.id': '*73',
          'service-name': 'PPPoE',
          'interface': 'ether5 HOTSPOT',
          'default-profile': 'default',
        },
      ],
      '/queue/simple/print' => [
        {
          '.id': '*80',
          'name': 'client-1',
          'target': '10.10.0.50',
          'max-limit': '3M/7M',
        },
      ],
      '/queue/interface/print' => [
        {
          '.id': '*83',
          'interface': 'ether1 WAN',
          'queue': 'default-small',
          'active-queue': 'default-small',
        },
      ],
      '/queue/tree/print' => [
        {
          '.id': '*84',
          'name': 'tree-client',
          'parent': 'global',
          'packet-mark': 'no-mark',
        },
      ],
      '/queue/type/print' => [
        {'.id': '*85', 'name': 'pcq-download', 'kind': 'pcq'},
      ],
      '/tool/netwatch/print' => [
        {'.id': '*81', 'host': '8.8.8.8', 'status': 'up'},
      ],
      '/snmp/community/print' => [
        {'.id': '*82', 'name': 'public', 'addresses': '0.0.0.0/0'},
      ],
      '/system/script/print' => [
        {'.id': '*90', 'name': 'script1', 'source': ':put test'},
      ],
      '/system/scheduler/print' => [
        {'.id': '*91', 'name': 'scheduler1', 'interval': '1d'},
      ],
      '/user/print' => [
        {'.id': '*92', 'name': 'admin', 'group': 'full'},
      ],
      '/ip/service/print' => [
        {'.id': '*93', 'name': 'api', 'port': '8728', 'disabled': 'false'},
      ],
      '/system/package/print' => [
        {'.id': '*94', 'name': 'routeros', 'version': '7.16.1'},
      ],
      '/certificate/print' => [
        {'.id': '*95', 'name': 'cert1', 'trusted': 'true'},
      ],
      '/file/print' => [
        {'.id': '*96', 'name': 'backup.rsc', 'type': 'file', 'size': '1024'},
      ],
      '/log/print' => [
        {
          '.id': '*97',
          'time': '07:30:00',
          'topics': 'system,info',
          'message': 'smoke log',
        },
      ],
      '/interface/wireguard/print' => [
        {
          '.id': '*98',
          'name': 'wireguard1',
          'listen-port': '13231',
          'mtu': '1420',
        },
      ],
      '/interface/wireguard/peers/print' => [
        {'.id': '*99', 'interface': 'wireguard1', 'public-key': 'abc'},
      ],
      '/ip/ipsec/peer/print' => [
        {'.id': '*100', 'name': 'peer1', 'address': '1.1.1.1'},
      ],
      '/ip/ipsec/identity/print' => [
        {'.id': '*101', 'peer': 'peer1', 'auth-method': 'pre-shared-key'},
      ],
      _ => throw UnimplementedError('Endpoint smoke belum dimock: $path'),
    };
    final nameFilter = command
        .where((word) => word.startsWith('?name='))
        .map((word) => word.substring('?name='.length))
        .firstOrNull;
    if (nameFilter != null) {
      return rows.where((row) => row['name'] == nameFilter).toList();
    }
    return rows;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSmoke(
    WidgetTester tester,
    Widget child, {
    String name = '',
  }) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = AppProvider()
      ..setApi(_SmokeApi())
      ..setRouterInfo(name: 'Server RDP', model: 'RB450Gx4', version: '7.16.1');

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));

    final exception = tester.takeException();
    expect(exception, isNull, reason: name);
  }

  final api = _SmokeApi();
  final smokeCases = <String, Widget>{
    'Dashboard': DashboardScreen(api: api, onOpenInterface: () {}),
    'Health Center': HealthCenterScreen(api: api),
    'Interface Traffic': InterfaceScreen(api: api, subIndex: 0),
    'Interface Status': InterfaceScreen(api: api, subIndex: 1),
    'IP Address': IpScreen(api: api, subIndex: 0),
    'IP Pool': IpScreen(api: api, subIndex: 1),
    'DHCP Server': IpScreen(api: api, subIndex: 2),
    'DHCP Lease': IpScreen(api: api, subIndex: 3),
    'DNS Settings': IpScreen(api: api, subIndex: 4),
    'Firewall': NetworkToolsScreen(api: api),
    'Load Balance': LoadBalanceScreen(api: api),
    'Hotspot Active': HotspotScreen(api: api, subIndex: 0),
    'Hotspot Voucher': HotspotScreen(api: api, subIndex: 1),
    'Hotspot Generate': HotspotScreen(api: api, subIndex: 2),
    'Hotspot Backup': HotspotScreen(api: api, subIndex: 3),
    'Hotspot Servers': HotspotScreen(api: api, subIndex: 4),
    'Hotspot Server Profiles': HotspotScreen(api: api, subIndex: 5),
    'Hotspot User Profiles': HotspotScreen(api: api, subIndex: 6),
    'PPP Active': PppoeScreen(api: api, subIndex: 0),
    'PPP Secrets': PppoeScreen(api: api, subIndex: 1),
    'PPP Profiles': PppoeScreen(api: api, subIndex: 2),
    'PPP Add Secret': PppoeScreen(api: api, subIndex: 3),
    'PPPoE Servers': PppoeScreen(api: api, subIndex: 4),
    'Storage': StorageScreen(api: api),
    'Router Log': RouterLogScreen(api: api),
    'Terminal': SafeTerminalScreen(api: api),
    'Diagnostics': DiagnosticToolsScreen(api: api),
    'System Control': SystemControlScreen(api: api),
    'About': const AboutScreen(),
    for (var i = 0; i < 30; i++)
      'Router Config $i': RouterConfigScreen(api: api, moduleIndex: i),
  };

  for (final entry in smokeCases.entries) {
    testWidgets('${entry.key} renders without Flutter errors', (tester) async {
      await pumpSmoke(tester, entry.value, name: entry.key);
    });
  }
}
