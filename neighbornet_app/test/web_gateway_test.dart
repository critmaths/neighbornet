import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbornet_app/models/neighbornet_models.dart';
import 'package:neighbornet_app/services/neighbornet_bridge.dart';
import 'package:neighbornet_app/state/neighbornet_state.dart';
import 'package:neighbornet_app/views/settings_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WebGatewayStatus Model Tests', () {
    test('JSON deserialization with full data', () {
      final json = {
        'is_running': true,
        'port': 8080,
        'local_ip': '192.168.1.100',
        'gateway_url': 'http://192.168.1.100:8080',
        'requests_served': 42,
      };

      final status = WebGatewayStatus.fromJson(json);
      expect(status.isRunning, isTrue);
      expect(status.port, 8080);
      expect(status.localIp, '192.168.1.100');
      expect(status.gatewayUrl, 'http://192.168.1.100:8080');
      expect(status.requestsServed, 42);
    });

    test('JSON deserialization with fallback defaults', () {
      final status = WebGatewayStatus.fromJson({});
      expect(status.isRunning, isFalse);
      expect(status.port, 8080);
      expect(status.localIp, '127.0.0.1');
      expect(status.gatewayUrl, isEmpty);
      expect(status.requestsServed, 0);
    });

    test('JSON serialization roundtrip', () {
      final original = WebGatewayStatus(
        isRunning: true,
        port: 9090,
        localIp: '10.0.0.15',
        gatewayUrl: 'http://10.0.0.15:9090',
        requestsServed: 108,
      );

      final json = original.toJson();
      final reconstructed = WebGatewayStatus.fromJson(json);

      expect(reconstructed.isRunning, original.isRunning);
      expect(reconstructed.port, original.port);
      expect(reconstructed.localIp, original.localIp);
      expect(reconstructed.gatewayUrl, original.gatewayUrl);
      expect(reconstructed.requestsServed, original.requestsServed);
    });
  });

  group('DnsServerStatus Model Tests', () {
    test('JSON deserialization with full data', () {
      final json = {
        'is_running': true,
        'port': 53,
        'target_ip': '10.0.0.1',
        'queries_answered': 256,
      };

      final status = DnsServerStatus.fromJson(json);
      expect(status.isRunning, isTrue);
      expect(status.port, 53);
      expect(status.targetIp, '10.0.0.1');
      expect(status.queriesAnswered, 256);
    });

    test('JSON deserialization with fallback defaults', () {
      final status = DnsServerStatus.fromJson({});
      expect(status.isRunning, isFalse);
      expect(status.port, 53);
      expect(status.targetIp, '127.0.0.1');
      expect(status.queriesAnswered, 0);
    });

    test('JSON serialization roundtrip', () {
      final original = DnsServerStatus(
        isRunning: true,
        port: 5353,
        targetIp: '192.168.4.1',
        queriesAnswered: 77,
      );

      final json = original.toJson();
      final reconstructed = DnsServerStatus.fromJson(json);

      expect(reconstructed.isRunning, original.isRunning);
      expect(reconstructed.port, original.port);
      expect(reconstructed.targetIp, original.targetIp);
      expect(reconstructed.queriesAnswered, original.queriesAnswered);
    });
  });

  group('NeighborNetBridge Web Gateway & DNS FFI Tests', () {
    test('Uninitialized bridge returns null/false gracefully', () {
      final bridge = NeighborNetBridge();
      if (!bridge.isReady) {
        expect(bridge.startWebGateway(port: 8080), isNull);
        expect(bridge.stopWebGateway(), isFalse);
        expect(bridge.getWebGatewayStatus(), isNull);

        expect(bridge.startDnsServer(port: 53), isNull);
        expect(bridge.stopDnsServer(), isFalse);
        expect(bridge.getDnsServerStatus(), isNull);
      }
    });
  });

  group('NeighborNetState Web Gateway & DNS Integration', () {
    test('State properties and port configuration', () {
      final state = NeighborNetState();
      expect(state.isWebGatewayRunning, isFalse);
      expect(state.webGatewayPort, 8080);
      expect(state.webGatewayUrl, contains('8080'));

      state.setWebGatewayPort(8888);
      expect(state.webGatewayPort, 8888);

      state.setWebGatewayPort(-1);
      expect(state.webGatewayPort, 8888);
      state.setWebGatewayPort(70000);
      expect(state.webGatewayPort, 8888);

      // DNS state properties
      expect(state.isDnsServerRunning, isFalse);
      expect(state.dnsServerPort, 53);
      expect(state.dnsTargetIp, isNotEmpty);

      state.setDnsServerPort(5353);
      expect(state.dnsServerPort, 5353);

      state.setDnsServerPort(0);
      expect(state.dnsServerPort, 5353);

      state.setDnsTargetIp('192.168.4.1');
      expect(state.dnsTargetIp, '192.168.4.1');

      state.dispose();
    });
  });

  group('SettingsView Web Gateway & Captive DNS UI Widget Tests', () {
    testWidgets('Renders Zero-Install Web Gateway Card & Captive DNS in SettingsView', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 2400);
      tester.view.devicePixelRatio = 1.0;

      final state = NeighborNetState();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: SettingsView(state: state),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Zero-Install Web Gateway & Captive Portal'), findsOneWidget);
      expect(find.text('PORTAL STOPPED'), findsOneWidget);
      expect(find.text('Start Web Gateway'), findsOneWidget);
      expect(find.text('HTTP Port'), findsOneWidget);
      expect(find.textContaining('Captive Portal Probe Interception'), findsOneWidget);

      // Captive DNS section
      expect(find.text('Hotspot Captive DNS Auto-Redirect'), findsOneWidget);
      expect(find.text('DNS STOPPED'), findsOneWidget);
      expect(find.text('Start DNS Redirect'), findsOneWidget);
      expect(find.text('UDP DNS Port'), findsOneWidget);
      expect(find.textContaining('Embedded RFC 1035 UDP DNS server'), findsOneWidget);

      state.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
