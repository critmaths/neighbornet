import 'package:flutter_test/flutter_test.dart';
import 'package:neighbornet_app/models/neighbornet_models.dart';
import 'package:neighbornet_app/services/neighbornet_bridge.dart';
import 'package:neighbornet_app/state/neighbornet_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoRa Tactical Radio Model Tests', () {
    test('SerialDeviceInfo serializes from JSON correctly', () {
      final json = {
        'port_name': 'COM3',
        'port_type': 'USB',
        'vid': 0x10c4,
        'pid': 0xea60,
        'manufacturer': 'Silicon Labs',
        'product': 'CP2102 USB to UART Bridge',
      };
      final dev = SerialDeviceInfo.fromJson(json);
      expect(dev.portName, 'COM3');
      expect(dev.portType, 'USB');
      expect(dev.vid, 0x10c4);
      expect(dev.pid, 0xea60);
      expect(dev.displayName, 'COM3 (CP2102 USB to UART Bridge)');
    });

    test('LoraRadioStatus serializes from JSON correctly and computes frequencies', () {
      final json = {
        'is_connected': true,
        'port_name': 'COM3',
        'baud_rate': 115200,
        'freq_hz': 915000000,
        'bw_hz': 125000,
        'sf': 10,
        'cr': 5,
        'tx_packets': 42,
        'rx_packets': 18,
        'last_rssi': -88,
        'last_snr': 8,
        'last_activity_epoch_sec': 1700000000,
      };
      final status = LoraRadioStatus.fromJson(json);
      expect(status.isConnected, isTrue);
      expect(status.portName, 'COM3');
      expect(status.frequencyMhz, '915.0');
      expect(status.bandwidthKhz, '125');
      expect(status.txPackets, 42);
      expect(status.rxPackets, 18);
      expect(status.lastRssi, -88);
      expect(status.lastSnr, 8);
    });
  });

  group('NeighborNetBridge LoRa Fallbacks', () {
    test('Bridge handles uninitialized LoRa calls gracefully', () {
      final bridge = NeighborNetBridge();
      expect(bridge.listSerialPorts(), isEmpty);
      expect(bridge.connectLora(portName: 'COM1'), isFalse);
      expect(bridge.disconnectLora(), isFalse);
      expect(bridge.getLoraStatus(), isNull);
      expect(bridge.sendLoraPacket('test'), isFalse);
    });
  });

  group('NeighborNetState LoRa State Management', () {
    test('Initial LoRa state is uninitialized and inactive', () {
      final state = NeighborNetState();
      expect(state.serialPorts, isEmpty);
      expect(state.loraStatus, isNull);
      expect(state.isLoraScanning, isFalse);
    });

    test('refreshSerialPorts executes without crashing', () async {
      final state = NeighborNetState();
      await state.refreshSerialPorts();
      expect(state.isLoraScanning, isFalse);
    });
  });
}
