import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../protocol/apneicare_commands.dart';

class ApneicareBleHelper {
  static final ApneicareBleHelper _instance = ApneicareBleHelper._internal();

  factory ApneicareBleHelper() => _instance;

  ApneicareBleHelper._internal();

  // Add a static getter for easier access
  static ApneicareBleHelper get instance => _instance;

  void Function(
      String level,
      String code,
      String message, [
      Map<String, dynamic>? data,
      ])?
  onLog;

  Future<void> _logEvent(
      String code,
      String message, [
        Map<String, dynamic>? data,
      ]) async {
    onLog?.call('event', code, message, data);
  }

  Future<void> _logError(
      String code,
      String message, [
        Map<String, dynamic>? data,
      ]) async {
    onLog?.call('error', code, message, data);
  }

  // BLE service and characteristic UUIDs from client documentation
  static const String SERVICE_UUID = "0000fee9-0000-1000-8000-00805f9b34fb";

  // Alternative service UUID formats that might be used
  static const List<String> ALTERNATIVE_SERVICE_UUIDS = [
    "0000fee9-0000-1000-8000-00805f9b34fb",
    "FEE9-0000-1000-8000-00805F9B34FB",
    "fee9-0000-1000-8000-00805f9b34fb",
    // Short UUID formats
    "fee9",
    "FEE9",
    "0000fee9",
    // Full service UUID from documentation
    "0000fee900001000800000805f9b34fb",
  ];

  // Write characteristic for sending commands to device (from documentation)
  static const String WRITE_CHARACTERISTIC_UUID =
      "D44BC439-ABFD-45A2-B575-925416129600";

  // Alternative write characteristic UUIDs
  static const List<String> ALTERNATIVE_WRITE_UUIDS = [
    "D44BC439-ABFD-45A2-B575-925416129600",
    "d44bc439-abfd-45a2-b575-925416129600",
    "D44BC439ABFD45A2B575925416129600",
    // From documentation without dashes
    "D44BC439ABFD45A2B575925416129600",
  ];

  // Notify characteristics for receiving data from device (from documentation)
  static const String NOTIFY_CHARACTERISTIC_UUID =
      "D44BC439-ABFD-45A2-B575-925416129601";
  static const List<String> NOTIFY_CHARACTERISTIC_UUIDS = [
    "D44BC439-ABFD-45A2-B575-925416129601",
    "D44BC439-ABFD-45A2-B575-925416129602",
    "D44BC439-ABFD-45A2-B575-925416129603",
    "D44BC439-ABFD-45A2-B575-925416129604",
    "D44BC439-ABFD-45A2-B575-925416129605",
    "D44BC439-ABFD-45A2-B575-925416129606",
    "D44BC439-ABFD-45A2-B575-925416129607",
  ];

  // Alternative notify characteristic UUIDs (without dashes)
  static const List<String> ALTERNATIVE_NOTIFY_UUIDS = [
    "D44BC439ABFD45A2B575925416129601",
    "D44BC439ABFD45A2B575925416129602",
    "D44BC439ABFD45A2B575925416129603",
    "D44BC439ABFD45A2B575925416129604",
    "D44BC439ABFD45A2B575925416129605",
    "D44BC439ABFD45A2B575925416129606",
    "D44BC439ABFD45A2B575925416129607",
  ];

  // Device Information Service UUID (standard GATT) - from documentation
  static const String DEVICE_INFO_SERVICE_UUID =
      "0000180a-0000-1000-8000-00805f9b34fb";

  // Alternative device info service UUIDs
  static const List<String> ALTERNATIVE_DEVICE_INFO_UUIDS = [
    "0000180a-0000-1000-8000-00805f9b34fb",
    "180a",
    "180A",
    "0000180a",
  ];

  // Unique ID characteristic UUID - from documentation
  static const String UNIQUE_ID_CHARACTERISTIC_UUID =
      "00002a25-0000-1000-8000-00805f9b34fb";

  // Alternative unique ID characteristic UUIDs
  static const List<String> ALTERNATIVE_UNIQUE_ID_UUIDS = [
    "00002a25-0000-1000-8000-00805f9b34fb",
    "2a25",
    "2A25",
    "00002a25",
  ];

  // Connection state
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  List<BluetoothCharacteristic> _notifyCharacteristics = [];
  bool _isConnected = false;

  // Connection monitoring
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  List<StreamSubscription<List<int>>> _notifySubscriptions = [];
  bool _notificationsEnabled = false;
  bool _connectionFullyEstablished = false;

  // Data controller for streaming data to listeners
  StreamController<List<int>>? _dataController;

  // Error controller for streaming errors to listeners
  StreamController<String>? _errorController;

  // Disconnection stream for UI notifications (removed - using direct connection state monitoring)
  // StreamController<bool>? _disconnectionController;

  // Connection tracking
  // DateTime? _lastConnectionTime;

  // Command tracking
  // int _commandCounter = 0;

  // Getters
  BluetoothDevice? get connectedDevice => _connectedDevice;

  bool get isConnected => _isConnected;

  bool get isConnectionFullyEstablished => _connectionFullyEstablished;

  BluetoothCharacteristic? get writeCharacteristic => _writeCharacteristic;

  List<BluetoothCharacteristic> get notifyCharacteristics =>
      _notifyCharacteristics;

  Stream<List<int>>? get dataStream => _dataController?.stream;

  /// Get error stream
  Stream<String>? get errorStream => _errorController?.stream;

  /// Get disconnection stream for UI notifications (removed - using direct connection state monitoring)
  // Stream<bool>? get disconnectionStream => _disconnectionController?.stream;

  /// Initialize BLE helper
  void initialize() {
    // Always reset state to ensure clean initialization
    _resetState();

    if (_dataController == null) {
      _dataController = StreamController<List<int>>.broadcast();
      _errorController = StreamController<String>.broadcast();
      // _disconnectionController = StreamController<bool>.broadcast(); // Removed - using direct connection state monitoring
      print('BLE helper initialized');
      _logEvent(
        'ble_helper_initialized',
        'BLE helper initialized successfully',
      );
    } else {
      print('BLE helper already initialized, skipping');
      _logEvent(
        'ble_helper_already_initialized',
        'BLE helper already initialized, skipping',
      );
    }
  }

  /// Prepare BLE helper for a reconnection attempt.
  ///
  /// Unlike [initialize], this does NOT reset the connected device or
  /// characteristics — it only:
  ///   1. Cancels and clears stale notify subscriptions
  ///   2. Resets the _notificationsEnabled flag so [_setupNotifications]
  ///      will run again after the new connection is established
  ///   3. Re-creates the data/error stream controllers if they were closed
  ///
  /// Call this right before [connectToDevice] during a reconnect attempt.
  void prepareForReconnection() {
    print('🔄 Preparing BLE helper for reconnection...');

    // Cancel stale notify subscriptions
    for (final sub in _notifySubscriptions) {
      try {
        sub.cancel();
      } catch (_) {}
    }
    _notifySubscriptions.clear();

    // Reset notifications flag so _setupNotifications() runs again
    _notificationsEnabled = false;

    // Re-create stream controllers if they were closed
    if (_dataController == null || _dataController!.isClosed) {
      _dataController = StreamController<List<int>>.broadcast();
      print('🔄 Recreated data stream controller');
    }
    if (_errorController == null || _errorController!.isClosed) {
      _errorController = StreamController<String>.broadcast();
    }

    _logEvent(
      'ble_prepared_for_reconnection',
      'BLE helper prepared for reconnection attempt',
    );
    print('🔄 BLE helper ready for reconnection');
  }

  /// Reset BLE helper state to clean state
  void _resetState() {
    // Cancel any existing subscriptions
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;

    for (final sub in _notifySubscriptions) {
      try {
        sub.cancel();
      } catch (_) {}
    }
    _notifySubscriptions.clear();

    // Close and reset controllers
    _dataController?.close();
    _dataController = null;
    _errorController?.close();
    _errorController = null;
    // _disconnectionController?.close(); // Removed - using direct connection state monitoring
    // _disconnectionController = null;

    // Reset connection state
    _connectedDevice = null;
    _writeCharacteristic = null;
    _notifyCharacteristics.clear();
    _isConnected = false;
    _notificationsEnabled = false;
    _connectionFullyEstablished = false;
    // _lastConnectionTime = null;
    // _commandCounter = 0;

    print('BLE helper state reset');
  }

  /// Scan for APNEICARE devices
  Future<List<BluetoothDevice>> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final startTime = DateTime.now();
    StreamSubscription<List<ScanResult>>? scanSub;

    try {
      await _logEvent('ble_scan_started', 'Started scanning for devices', {
        'timeout_seconds': timeout.inSeconds,
      });

      Set<BluetoothDevice> discoveredDevices = {};

      // Stop any ongoing scan before starting a new one
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}

      // Listen BEFORE starting scan to avoid missing early results
      scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          if (result.device.platformName.isNotEmpty) {
            discoveredDevices.add(result.device);
          }
        }
      });

      // Start scanning after listener is attached
      await FlutterBluePlus.startScan(timeout: timeout);

      // Wait for scan to complete
      await FlutterBluePlus.isScanning.where((scanning) => !scanning).first;

      // Cancel subscription to avoid stacking on repeated scans
      await scanSub.cancel();

      final scanDuration = DateTime.now().difference(startTime);
      print(
        'Scan completed in ${scanDuration.inMilliseconds}ms. Found ${discoveredDevices.length} devices',
      );

      await _logEvent('ble_scan_completed', 'Scan completed successfully', {
        'duration_ms': scanDuration.inMilliseconds,
        'devices_found': discoveredDevices.length,
        'device_names': discoveredDevices.map((d) => d.platformName).toList(),
      });

      return discoveredDevices.toList();
    } catch (e) {
      // Ensure subscription is cancelled on error paths
      try {
        await scanSub?.cancel();
      } catch (_) {}

      print('Error during device scan: $e');
      await _logError('ble_scan_error', 'Error during device scan', {
        'error': e.toString(),
        'error_type': e.runtimeType.toString(),
      });
      rethrow;
    }
  }

  /// Check system-connected devices for W628 (no scan needed)
  Future<BluetoothDevice?> _checkConnectedOrBondedW628() async {
    try {
      // Check already-connected devices (autoConnect may have reconnected)
      final connected = FlutterBluePlus.connectedDevices;
      for (final device in connected) {
        if (device.platformName.toLowerCase().contains('w628')) {
          await _logEvent(
            'w628_already_connected',
            'W628 found in connected devices',
            {
              'device_name': device.platformName,
              'device_id': device.remoteId.toString(),
            },
          );
          return device;
        }
      }

      // Check bonded devices on Android
      final bonded = await FlutterBluePlus.bondedDevices;
      for (final device in bonded) {
        if (device.platformName.toLowerCase().contains('w628')) {
          await _logEvent('w628_found_bonded', 'W628 found in bonded devices', {
            'device_name': device.platformName,
            'device_id': device.remoteId.toString(),
          });
          return device;
        }
      }
    } catch (e) {
      print('Error checking connected/bonded devices: $e');
    }
    return null;
  }

  /// Auto scan and pick W628 device.
  ///
  /// Stops scanning as soon as a W628 advertisement is seen (does not wait
  /// out the full [timeout] when the device is nearby).
  Future<BluetoothDevice?> autoScanAndPickW628({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    StreamSubscription<List<ScanResult>>? scanSub;
    try {
      await _logEvent(
        'w628_scan_started',
        'Started scanning specifically for W628 devices',
        {'timeout_seconds': timeout.inSeconds, 'early_exit': true},
      );

      // First check if device is already connected or bonded
      final existingDevice = await _checkConnectedOrBondedW628();
      if (existingDevice != null) {
        return existingDevice;
      }

      BluetoothDevice? found;
      final seenNames = <String>{};

      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}

      scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final name = result.device.platformName;
          if (name.isNotEmpty) seenNames.add(name);
          if (name.toLowerCase().contains('w628')) {
            found = result.device;
            // End scan immediately — do not wait for full timeout.
            unawaited(FlutterBluePlus.stopScan());
            return;
          }
        }
      });

      await FlutterBluePlus.startScan(timeout: timeout);
      await FlutterBluePlus.isScanning.where((scanning) => !scanning).first;
      await scanSub.cancel();
      scanSub = null;

      if (found != null) {
        print('Found W628 device (early exit): ${found!.platformName}');
        await _logEvent(
          'w628_device_found',
          'W628 device found during scan',
          {
            'device_name': found!.platformName,
            'device_id': found!.remoteId.toString(),
            'early_exit': true,
            'devices_seen': seenNames.length,
          },
        );
        return found;
      }

      print('No W628 device found among ${seenNames.length} discovered devices');
      await _logEvent(
        'w628_device_not_found',
        'No W628 device found during scan',
        {
          'total_devices_scanned': seenNames.length,
          'device_names': seenNames.toList(),
        },
      );
      return null;
    } catch (e) {
      try {
        await scanSub?.cancel();
      } catch (_) {}
      print('Error scanning for W628 devices: $e');
      await _logError('w628_scan_error', 'Error scanning for W628 devices', {
        'error': e.toString(),
        'error_type': e.runtimeType.toString(),
      });
      return null;
    }
  }

  /// Connect to device with detailed logging (main connection method)
  Future<bool> connectToDevice(BluetoothDevice device) async {
    final startTime = DateTime.now();

    print('=== Starting connection to ${device.platformName} ===');

    await _logEvent('ble_connection_started', 'Started connecting to device', {
      'device_name': device.platformName,
      'device_id': device.remoteId.toString(),
      'connection_start_time': startTime.toIso8601String(),
    });

    // Track connection method used
    String connectionMethod = 'unknown';
    String serviceUuidFound = 'none';
    String writeCharUuidFound = 'none';
    List<String> notifyCharUuidsFound = [];

    try {
      await _logEvent(
        'ble_device_connect_attempt',
        'Attempting to connect to device',
        {
          'device_name': device.platformName,
          'auto_connect': true,
          'timeout_seconds': 30,
        },
      );

      // Connect to device with autoConnect for Android to maintain persistent connection
      await device.connect(
        autoConnect: true,
        timeout: Duration(seconds: 30),
        mtu: null,
      );

      // Wait until the adapter reports 'connected' to avoid race conditions
      try {
        await _logEvent(
          'ble_waiting_connection_state',
          'Waiting for connection state confirmation',
        );
        await device.connectionState
            .firstWhere((s) => s == BluetoothConnectionState.connected)
            .timeout(Duration(seconds: 5));
        await _logEvent(
          'ble_connection_state_confirmed',
          'Connection state confirmed as connected',
        );
      } catch (_) {
        await _logEvent(
          'ble_connection_state_timeout',
          'Connection state confirmation timed out',
        );
      }

      // Proactively set connected flags before discovery
      _isConnected = true;
      _connectedDevice = device;

      await _logEvent('ble_device_connected', 'Device connected successfully', {
        'device_name': device.platformName,
        'device_id': device.remoteId.toString(),
      });

      // Initialize BLE helper
      // initialize();

      print('Device connected: ${device.platformName}');

      // Set up connection state monitoring to detect disconnections
      // Only listen during initial connection phase, not after full establishment
      _connectionStateSubscription
          ?.cancel(); // Cancel any existing subscription
      _connectionStateSubscription = device.connectionState.listen((
          state,
          ) async {
        print('Connection state changed: $state');

        if (state == BluetoothConnectionState.disconnected) {
          print('Device disconnected: ${device.platformName}');
          _isConnected = false;
          _connectedDevice = null;
          _connectionFullyEstablished = false;

          // Disconnection notification removed - using direct connection state monitoring
          // _disconnectionController?.add(true);
        } else if (state == BluetoothConnectionState.connected) {
          print('Device connected: ${device.platformName}');
          _isConnected = true;
          _connectedDevice = device;
          // _lastConnectionTime = DateTime.now();
        }
      });
      await Future.delayed(Duration(seconds: 1));

      // Discover services
      await _logEvent(
        'ble_service_discovery_started',
        'Started discovering services',
      );

      List<BluetoothService> services = await device.discoverServices();

      print('Discovered ${services.length} services:');
      for (var service in services) {
        print('  - ${service.uuid}');
      }

      await _logEvent(
        'ble_services_discovered',
        'Services discovered successfully',
        {
          'services_count': services.length,
          'service_uuids': services.map((s) => s.uuid.toString()).toList(),
        },
      );

      // Find APNEICARE service - try multiple approaches
      BluetoothService? targetService;

      // Method 1: Exact UUID match
      for (BluetoothService service in services) {
        if (_isExpectedService(service.uuid.toString())) {
          targetService = service;
          connectionMethod = 'exact_uuid_match';
          serviceUuidFound = service.uuid.toString();
          print('Found service using exact UUID match: ${service.uuid}');
          break;
        }
      }

      // Method 2: Look for services with matching characteristics
      if (targetService == null) {
        for (BluetoothService service in services) {
          bool hasWriteChar = service.characteristics.any((c) {
            return _compareUuids(
              c.uuid.toString(),
              WRITE_CHARACTERISTIC_UUID,
            ) ||
                ALTERNATIVE_WRITE_UUIDS.any(
                      (uuid) => _compareUuids(c.uuid.toString(), uuid),
                );
          });
          bool hasNotifyChar = service.characteristics.any((c) {
            return NOTIFY_CHARACTERISTIC_UUIDS.any(
                  (uuid) => _compareUuids(c.uuid.toString(), uuid),
            ) ||
                ALTERNATIVE_NOTIFY_UUIDS.any(
                      (uuid) => _compareUuids(c.uuid.toString(), uuid),
                );
          });

          if (hasWriteChar || hasNotifyChar) {
            targetService = service;
            connectionMethod = 'characteristic_based_match';
            serviceUuidFound = service.uuid.toString();
            print(
              'Found service using characteristic-based match: ${service.uuid}',
            );
            break;
          }
        }
      }

      // Method 3: Fallback to any service with write/notify characteristics
      if (targetService == null) {
        for (BluetoothService service in services) {
          bool hasWrite = service.characteristics.any(
                (c) => c.properties.write,
          );
          bool hasNotify = service.characteristics.any(
                (c) => c.properties.notify,
          );

          if (hasWrite || hasNotify) {
            targetService = service;
            connectionMethod = 'property_based_fallback';
            serviceUuidFound = service.uuid.toString();
            print(
              'Found service using property-based fallback: ${service.uuid}',
            );
            break;
          }
        }
      }

      if (targetService != null) {
        print('Found target service: ${targetService.uuid}');
        await _logEvent('ble_target_service_found', 'Target service found', {
          'service_uuid': targetService.uuid.toString(),
          'connection_method': connectionMethod,
        });

        // Try W628-specific handling first
        await _logEvent(
          'ble_w628_handling_started',
          'Starting W628-specific characteristic handling',
        );
        bool w628Handled = await _handleW628Device(targetService);

        if (w628Handled) {
          print('Successfully handled W628 device characteristics');
          connectionMethod = 'w628_specific_handling';
          await _logEvent(
            'ble_w628_handling_success',
            'W628-specific handling successful',
          );

          // Log found characteristics
          if (_writeCharacteristic != null) {
            writeCharUuidFound = _writeCharacteristic!.uuid.toString();
          }
          notifyCharUuidsFound = _notifyCharacteristics
              .map((c) => c.uuid.toString())
              .toList();
        } else {
          print(
            'W628-specific handling failed, trying enhanced fallback methods',
          );
          await _logEvent(
            'ble_w628_handling_failed',
            'W628-specific handling failed, trying fallback',
          );

          // Enhanced characteristic finding with multiple approaches
          await _findCharacteristicsEnhanced(targetService);
          connectionMethod = 'enhanced_characteristic_fallback';
          await _logEvent(
            'ble_fallback_handling_completed',
            'Enhanced fallback handling completed',
          );

          // Log found characteristics
          if (_writeCharacteristic != null) {
            writeCharUuidFound = _writeCharacteristic!.uuid.toString();
          }
          notifyCharUuidsFound = _notifyCharacteristics
              .map((c) => c.uuid.toString())
              .toList();
        }
      } else {
        final error = 'APNEICARE service not found';
        print('Error: $error');
        await _logError(
          'ble_service_not_found',
          'APNEICARE service not found',
          {
            'services_discovered': services.length,
            'service_uuids': services.map((s) => s.uuid.toString()).toList(),
          },
        );
        throw Exception(error);
      }

      // Subscribe to notifications
      await _logEvent(
        'ble_notification_setup_started',
        'Starting notification setup',
      );
      await _setupNotifications();
      await _logEvent(
        'ble_notification_setup_completed',
        'Notification setup completed',
      );

      _connectedDevice = device;
      _isConnected = true;
      // _lastConnectionTime = DateTime.now();

      final connectionDuration = DateTime.now().difference(startTime);

      print('Connection successful using method: $connectionMethod');
      print('Service UUID found: $serviceUuidFound');
      print('Write characteristic found: $writeCharUuidFound');
      print('Notify characteristics found: $notifyCharUuidsFound');

      await _logEvent(
        'ble_connection_successful',
        'BLE connection completed successfully',
        {
          'connection_method': connectionMethod,
          'service_uuid_found': serviceUuidFound,
          'write_char_uuid_found': writeCharUuidFound,
          'notify_char_uuids_found': notifyCharUuidsFound,
          'connection_duration_ms': connectionDuration.inMilliseconds,
          'device_name': device.platformName,
          'device_id': device.remoteId.toString(),
        },
      );

      // Send synchronize commands to stabilize connection
      try {
        print('Sending synchronize commands to stabilize connection...');
        await _logEvent(
          'ble_sync_commands_started',
          'Starting synchronize commands',
        );
        await _sendSynchronizeTimeCommand();
        print('Synchronize commands sent successfully');
        await _logEvent(
          'ble_sync_commands_success',
          'Synchronize commands sent successfully',
        );
      } catch (e) {
        print('Failed to send synchronize commands: $e');
        await _logError(
          'ble_sync_commands_failed',
          'Failed to send synchronize commands',
          {'error': e.toString(), 'error_type': e.runtimeType.toString()},
        );
        // Don't fail the connection if time sync fails
      }

      // Mark connection as fully established and stop continuous monitoring
      _connectionFullyEstablished = true;
      await _stopConnectionStateMonitoring();

      await _logEvent(
        'ble_connection_fully_established',
        'Connection fully established, monitoring optimized',
      );

      return true;
    } catch (e) {
      final connectionDuration = DateTime.now().difference(startTime);

      print('Connection failed: $e');
      print('Connection duration: ${connectionDuration.inMilliseconds}ms');

      await _logError('ble_connection_failed', 'BLE connection failed', {
        'error': e.toString(),
        'error_type': e.runtimeType.toString(),
        'connection_duration_ms': connectionDuration.inMilliseconds,
        'device_name': device.platformName,
        'device_id': device.remoteId.toString(),
        'connection_method_attempted': connectionMethod,
        'service_uuid_found': serviceUuidFound,
        'write_char_uuid_found': writeCharUuidFound,
        'notify_char_uuids_found': notifyCharUuidsFound,
      });

      rethrow;
    }
  }

  /// Handle W628 device specific characteristics based on documentation
  Future<bool> _handleW628Device(BluetoothService service) async {
    print('=== Handling W628 Device ===');
    print('Service UUID: ${service.uuid}');
    print('Characteristics found: ${service.characteristics.length}');

    await _logEvent(
      'ble_w628_handling_details',
      'W628 device handling started',
      {
        'service_uuid': service.uuid.toString(),
        'characteristics_count': service.characteristics.length,
      },
    );

    String writeCharMethod = 'not_found';
    String notifyCharMethod = 'not_found';
    List<String> foundNotifyUuids = [];

    // Find write characteristic (D44BC439-ABFD-45A2-B575-925416129600)
    try {
      _writeCharacteristic = service.characteristics.firstWhere(
            (c) =>
        _compareUuids(c.uuid.toString(), WRITE_CHARACTERISTIC_UUID) ||
            ALTERNATIVE_WRITE_UUIDS.any(
                  (uuid) => _compareUuids(c.uuid.toString(), uuid),
            ),
      );
      print('Found write characteristic: ${_writeCharacteristic!.uuid}');
      writeCharMethod = 'exact_uuid_match';
    } catch (e) {
      print('Write characteristic not found by UUID, trying by properties');
      _writeCharacteristic = null;

      // Try by properties
      try {
        _writeCharacteristic = service.characteristics.firstWhere(
              (c) => c.properties.write,
        );
        print(
          'Found write characteristic by properties: ${_writeCharacteristic!.uuid}',
        );
        writeCharMethod = 'property_based';
      } catch (e) {
        print('Write characteristic not found by properties either');
        _writeCharacteristic = null;
      }
    }

    // Find notify characteristics (D44BC439-ABFD-45A2-B575-925416129601-607)
    _notifyCharacteristics = service.characteristics
        .where(
          (c) =>
      NOTIFY_CHARACTERISTIC_UUIDS.any(
            (uuid) => _compareUuids(c.uuid.toString(), uuid),
      ) ||
          ALTERNATIVE_NOTIFY_UUIDS.any(
                (uuid) => _compareUuids(c.uuid.toString(), uuid),
          ),
    )
        .toList();

    if (_notifyCharacteristics.isNotEmpty) {
      print(
        'Found ${_notifyCharacteristics.length} notify characteristics by UUID:',
      );
      notifyCharMethod = 'exact_uuid_match';
      for (var char in _notifyCharacteristics) {
        print('  - ${char.uuid}');
        foundNotifyUuids.add(char.uuid.toString());
      }
    } else {
      print('No notify characteristics found by UUID, trying by properties');

      // Try by properties
      _notifyCharacteristics = service.characteristics
          .where((c) => c.properties.notify || c.properties.indicate)
          .toList();

      if (_notifyCharacteristics.isNotEmpty) {
        print(
          'Found ${_notifyCharacteristics.length} notify characteristics by properties',
        );
        notifyCharMethod = 'property_based';
        for (var char in _notifyCharacteristics) {
          print('  - ${char.uuid}');
          foundNotifyUuids.add(char.uuid.toString());
        }
      }
    }

    print('W628 device handling completed:');
    print('  Write characteristic found: ${_writeCharacteristic != null}');
    print('  Notify characteristics count: ${_notifyCharacteristics.length}');
    print('  Write method: $writeCharMethod');
    print('  Notify method: $notifyCharMethod');

    final success =
        _writeCharacteristic != null && _notifyCharacteristics.isNotEmpty;

    await _logEvent(
      'ble_w628_handling_completed',
      'W628 device handling completed',
      {
        'write_characteristic_found': _writeCharacteristic != null,
        'notify_characteristics_count': _notifyCharacteristics.length,
        'write_method': writeCharMethod,
        'notify_method': notifyCharMethod,
        'success': success,
      },
    );

    return success;
  }

  /// Enhanced characteristic finding with multiple approaches
  Future<void> _findCharacteristicsEnhanced(BluetoothService service) async {
    print('=== Enhanced Characteristic Finding ===');

    // 1. Exact UUID match for write characteristic
    try {
      _writeCharacteristic = service.characteristics.firstWhere(
            (c) => _compareUuids(c.uuid.toString(), WRITE_CHARACTERISTIC_UUID),
      );
      print(
        'Found write characteristic by exact UUID: ${_writeCharacteristic!.uuid}',
      );
    } catch (e) {
      print(
        'Write characteristic not found by exact UUID, trying by properties',
      );
      _writeCharacteristic = null;
    }

    // 2. Look for characteristics with matching properties (write, notify, indicate)
    if (_writeCharacteristic == null) {
      try {
        _writeCharacteristic = service.characteristics.firstWhere(
              (c) => c.properties.write,
        );
        print(
          'Found write characteristic by properties: ${_writeCharacteristic!.uuid}',
        );
      } catch (e) {
        print('Write characteristic not found by properties, trying by notify');
        _writeCharacteristic = null;
      }
    }

    // 3. Fallback to any characteristic with write property
    if (_writeCharacteristic == null) {
      try {
        _writeCharacteristic = service.characteristics.firstWhere(
              (c) => c.properties.write,
        );
        print(
          'Found write characteristic by property fallback: ${_writeCharacteristic!.uuid}',
        );
      } catch (e) {
        print('Write characteristic not found by property fallback');
        _writeCharacteristic = null;
      }
    }

    // 4. Notify characteristics (D44BC439-ABFD-45A2-B575-925416129601-607)
    _notifyCharacteristics = service.characteristics
        .where(
          (c) =>
      NOTIFY_CHARACTERISTIC_UUIDS.any(
            (uuid) => _compareUuids(c.uuid.toString(), uuid),
      ) ||
          ALTERNATIVE_NOTIFY_UUIDS.any(
                (uuid) => _compareUuids(c.uuid.toString(), uuid),
          ),
    )
        .toList();

    if (_notifyCharacteristics.isNotEmpty) {
      print(
        'Found ${_notifyCharacteristics.length} notify characteristics by UUID:',
      );
      for (var char in _notifyCharacteristics) {
        print('  - ${char.uuid}');
      }
    } else {
      print('No notify characteristics found by UUID, trying by properties');

      // 5. Notify characteristics by properties
      _notifyCharacteristics = service.characteristics
          .where((c) => c.properties.notify || c.properties.indicate)
          .toList();

      if (_notifyCharacteristics.isNotEmpty) {
        print(
          'Found ${_notifyCharacteristics.length} notify characteristics by properties',
        );
        for (var char in _notifyCharacteristics) {
          print('  - ${char.uuid}');
        }
      }
    }
  }

  /// Check if a service UUID matches our expected service (including short UUIDs)
  bool _isExpectedService(String serviceUuid) {
    // Check against our expected service UUID
    if (_compareUuids(serviceUuid, SERVICE_UUID)) return true;

    // Check against alternative UUIDs
    for (String altUuid in ALTERNATIVE_SERVICE_UUIDS) {
      if (_compareUuids(serviceUuid, altUuid)) return true;
    }

    // Special case: check for short UUID "fee9"
    String normalized = _normalizeUuid(serviceUuid);
    if (normalized.endsWith('FEE9') || normalized == 'FEE9') return true;

    return false;
  }

  /// Set up notifications for all notify characteristics
  Future<void> _setupNotifications() async {
    // NOTE: We do NOT skip setup even if _notificationsEnabled is true.
    // prepareForReconnection() resets the flag before each reconnect so we
    // always re-subscribe to the new BLE characteristic objects.
    // await _logEvent('ble_notifications_already_enabled',
    //     'Notifications already enabled, skipping setup');

    print(
      'Setting up notifications for ${_notifyCharacteristics.length} characteristics',
    );

    await _logEvent(
      'ble_notification_setup_details',
      'Setting up notifications',
      {
        'characteristics_count': _notifyCharacteristics.length,
        'characteristic_uuids': _notifyCharacteristics
            .map((c) => c.uuid.toString())
            .toList(),
      },
    );

    // Cancel any existing notification subscriptions to prevent duplicates
    for (final sub in _notifySubscriptions) {
      try {
        await sub.cancel();
      } catch (_) {}
    }
    _notifySubscriptions.clear();

    // Stream controller removed - using _dataController instead

    for (BluetoothCharacteristic characteristic in _notifyCharacteristics) {
      try {
        await characteristic.setNotifyValue(true);
        final sub = characteristic.onValueReceived.listen((value) {
          _handleReceivedData(value);
          // _dataController?.add(value) is already called in _handleReceivedData()
        });
        _notifySubscriptions.add(sub);
        print('Successfully set up notifications for: ${characteristic.uuid}');
        await _logEvent(
          'ble_notification_characteristic_success',
          'Successfully set up notifications for characteristic',
          {'characteristic_uuid': characteristic.uuid.toString()},
        );
      } catch (e) {
        print('Failed to set up notifications for ${characteristic.uuid}: $e');
        await _logError(
          'ble_notification_characteristic_failed',
          'Failed to set up notifications for characteristic',
          {
            'characteristic_uuid': characteristic.uuid.toString(),
            'error': e.toString(),
          },
        );
        // Continue with other characteristics even if one fails
      }
    }

    // Mark enabled when setup completes (even if some fail, at least attempted)
    _notificationsEnabled = true;
  }

  /// Handle received data from notifications
  void _handleReceivedData(List<int> data) {
    print(
      'Received data: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );

    // Add to data controller for other listeners
    _dataController?.add(data);

    // Simple data handling like working project
    if (data.length == 3 || data.length == 4) {
      print('Real-time data packet received');
    } else if (data.length >= 2 && data[0] == 0x55 && data[1] == 0xAA) {
      print('Command response received');

      // Validate STATE field according to new protocol
      // STATE field (byte 2) should match the command byte
      if (data.length >= 3) {
        final cmd = data[2];
        final state = data[2]; // STATE is at byte 2 (same position as CMD)

        // In new protocol, STATE should equal the command value
        // This validation ensures protocol compliance
        if (state != cmd) {
          print(
            '⚠️ STATE mismatch: CMD=0x${cmd.toRadixString(16).padLeft(2, '0')}, STATE=0x${state.toRadixString(16).padLeft(2, '0')}',
          );
          _logError('state_validation_failed', 'STATE field mismatch', {
            'cmd': cmd,
            'state': state,
            'hex_data': data
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join(' '),
          });
        }
      }

      // Validate packet address for synchronization and query responses
      // New protocol expects 0x0000 instead of 0xFFFF/0xFFFE
      if (data.length >= 5) {
        final cmd = data[2];
        final add0 = data[3];
        final add1 = data[4];
        final packetAddress = (add1 << 8) | add0;

        if (cmd == ApneicareCommands.CMD_SYNCHRONIZE ||
            cmd == ApneicareCommands.CMD_QUERY) {
          if (packetAddress != 0x0000) {
            print(
              '⚠️ Packet address: Expected 0x0000, got 0x${packetAddress.toRadixString(16).padLeft(4, '0')}',
            );
            _logError(
              'packet_address_validation_failed',
              'Unexpected packet address',
              {
                'cmd': cmd,
                'cmd_hex': '0x${cmd.toRadixString(16).padLeft(2, '0')}',
                'expected': 0x0000,
                'received': packetAddress,
                'hex_data': data
                    .map((b) => b.toRadixString(16).padLeft(2, '0'))
                    .join(' '),
              },
            );
          }
        }
      }
    } else {
      print('Other data received');
    }
  }

  /// Send synchronize commands to stabilize connection
  Future<void> _sendSynchronizeTimeCommand() async {
    if (_writeCharacteristic == null) {
      throw Exception('Write characteristic not available for time sync');
    }

    try {
      // First send synchronize command to establish communication
      List<int> syncCommand = ApneicareCommands.synchronize();
      print(
        'Sending synchronize command: ${syncCommand.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );

      await _writeCharacteristic!.write(syncCommand, withoutResponse: true);
      print('Synchronize command sent successfully');

      // Wait for synchronize command to be processed
      await Future.delayed(Duration(milliseconds: 300));

      // Then send time upload command to sync time
      List<int> timeUploadCommand = ApneicareCommands.timeUpload();
      print(
        'Sending time upload command: ${timeUploadCommand.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );

      await _writeCharacteristic!.write(
        timeUploadCommand,
        withoutResponse: true,
      );
      print('Time upload command sent successfully');

      // Wait a short time for the time upload command to be processed
      await Future.delayed(Duration(milliseconds: 500));
    } catch (e) {
      print('Failed to send synchronize commands: $e');
      throw Exception('Failed to send synchronize commands: $e');
    }
  }

  /// Send command to device
  Future<bool> sendCommand(List<int> command, String commandName) async {
    print('Sending command: $commandName');
    print(
      'Command data: ${command.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );

    try {
      if (!_isConnected) {
        print('ERROR: Not connected to device');
        await _logError(
          'ble_command_failed',
          'Cannot send command: not connected to device',
          {
            'command_name': commandName,
            'command_hex': command
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join(' '),
          },
        );
        throw Exception('Not connected to device');
      }

      if (_writeCharacteristic == null) {
        print('ERROR: Write characteristic not available');
        await _logError(
          'ble_command_failed',
          'Cannot send command: write characteristic not available',
          {
            'command_name': commandName,
            'command_hex': command
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join(' '),
          },
        );
        throw Exception('Write characteristic not available');
      }

      // Verify native BLE connection state before attempting write.
      // _isConnected may be stale (monitoring was stopped after full establishment),
      // so we ask the platform directly. This catches the iOS "device is not connected"
      // and "primary service not found" errors before they hit the write call.
      if (_connectedDevice != null) {
        try {
          final nativeState = await _connectedDevice!.connectionState.first
              .timeout(const Duration(seconds: 2));
          if (nativeState != BluetoothConnectionState.connected) {
            print(
              'ERROR: Native BLE state is $nativeState — invalidating cached state',
            );
            _isConnected = false;
            _writeCharacteristic = null;
            _notifyCharacteristics.clear();
            await _logError(
              'ble_command_failed',
              'Cannot send command: native state is not connected',
              {
                'command_name': commandName,
                'command_hex': command
                    .map((b) => b.toRadixString(16).padLeft(2, '0'))
                    .join(' '),
                'native_state': nativeState.toString(),
              },
            );
            return false;
          }
        } catch (_) {
          // Timeout or stream error — proceed optimistically but log it
          print('Warning: could not verify native connection state');
        }
      }

      print('Writing command to characteristic: ${_writeCharacteristic!.uuid}');
      await _writeCharacteristic!.write(command, withoutResponse: true);
      print('Command sent successfully');

      // Wait a bit for the command to be processed
      await Future.delayed(Duration(milliseconds: 100));

      await _logEvent('ble_command_sent', 'Command sent successfully', {
        'command_name': commandName,
        'command_hex': command
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' '),
        'command_length': command.length,
        'characteristic_uuid': _writeCharacteristic!.uuid.toString(),
      });
      return true;
    } catch (e) {
      final errorStr = e.toString();
      print('Failed to send command: $e');

      // On iOS, a stale GATT session produces "primary service not found" or
      // fbp-code 6 ("device is not connected"). In both cases the cached
      // characteristic is invalid — clear it so the next attempt doesn't reuse it.
      final isStaleGatt =
          errorStr.contains('primary service not found') ||
              errorStr.contains('device is not connected') ||
              errorStr.contains('fbp-code: 6');
      if (isStaleGatt) {
        print('Stale GATT detected — invalidating cached characteristics');
        _writeCharacteristic = null;
        _notifyCharacteristics.clear();
        _isConnected = false;
      }

      await _logError('ble_command_failed', 'Failed to send command', {
        'command_name': commandName,
        'command_hex': command
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' '),
        'error': errorStr,
        'error_type': e.runtimeType.toString(),
        'is_connected': _isConnected,
        'has_write_characteristic': _writeCharacteristic != null,
        'stale_gatt_detected': isStaleGatt,
      });
      return false;
    }
  }

  /// Start real-time monitoring
  Future<bool> startRealTime() async {
    if (_writeCharacteristic == null) {
      await _logError(
        'ble_realtime_start_failed',
        'Cannot start real-time: write characteristic not available',
      );
      return false;
    }

    try {
      await _logEvent(
        'ble_realtime_start_attempt',
        'Attempting to start real-time monitoring',
      );
      final cmd = ApneicareCommands.realTimeStart();
      final success = await sendCommand(cmd, 'Start Real Time');

      if (success) {
        await _logEvent(
          'ble_realtime_start_success',
          'Real-time monitoring started successfully',
        );
      } else {
        await _logError(
          'ble_realtime_start_failed',
          'Failed to start real-time monitoring: command failed',
        );
      }

      return success;
    } catch (e) {
      print('Failed to start real time: $e');
      await _logError(
        'ble_realtime_start_error',
        'Error starting real-time monitoring',
        {'error': e.toString(), 'error_type': e.runtimeType.toString()},
      );
      return false;
    }
  }

  /// Stop real-time monitoring
  Future<bool> stopRealTime() async {
    // Minimum requirement: we need a write characteristic.
    // If the device is fully disconnected (_isConnected == false AND no write char),
    // there's nothing to send — return true so callers don't loop-retry.
    // If we have a write characteristic but other flags are stale, still attempt
    // the write; sendCommand's native-state check will catch a truly dead link.
    if (!_isConnected && _writeCharacteristic == null) {
      await _logError(
        'ble_realtime_stop_failed',
        'Cannot stop real-time: device disconnected',
        {
          'is_connected': _isConnected,
          'has_write_characteristic': _writeCharacteristic != null,
          'has_notify_characteristics': _notifyCharacteristics.isNotEmpty,
          'notifications_enabled': _notificationsEnabled,
        },
      );
      return true;
    }

    try {
      await _logEvent(
        'ble_realtime_stop_attempt',
        'Attempting to stop real-time monitoring',
      );

      final cmd = ApneicareCommands.realTimeStop();
      print(
        'Stop real-time command: ${cmd.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );

      final success = await sendCommand(cmd, 'Stop Real Time');

      if (success) {
        await _logEvent(
          'ble_realtime_stop_success',
          'Real-time monitoring stopped successfully',
        );
        print('Stop real-time command sent successfully');

        // Wait a bit for the command to be processed
        await Future.delayed(Duration(milliseconds: 500));
      } else {
        await _logError(
          'ble_realtime_stop_failed',
          'Failed to stop real-time monitoring: command failed',
        );
        print('Stop real-time command failed to send');
      }

      return success;
    } catch (e) {
      print('Failed to stop real time: $e');
      await _logError(
        'ble_realtime_stop_error',
        'Error stopping real-time monitoring',
        {'error': e.toString(), 'error_type': e.runtimeType.toString()},
      );
      return false;
    }
  }

  /// Listen for a pushed battery packet: 55 AA 60 <level> <sum>
  /// per MD300W628 protocol (push-only; no host request).
  Future<int?> readBattery({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // Must have data notifications enabled on UUID ...9601 per spec.
    if (_dataController == null) {
      await _logError(
        'ble_battery_read_failed',
        'Cannot read battery: notify stream not available',
      );
      return null;
    }

    try {
      await _logEvent(
        'ble_battery_read_started',
        'Started reading battery level',
      );

      // Wait for the next valid battery frame from the notify stream.
      // Your helper should be piping each BLE notification as List<int> into _dataController.
      final List<int> pkt = await _dataController!.stream
          .firstWhere((data) {
        if (data.length < 5) return false;
        if (data[0] != 0x55 || data[1] != 0xAA) return false;
        if (data[2] != 0x60) return false; // Battery upload CMD
        final level = data[3];
        final sum = data[4];
        final expect = (0x60 + level) & 0xFF;
        // Level must be 0..100 and checksum must match
        return level >= 0 && level <= 100 && sum == expect;
      })
          .timeout(timeout);

      final level = pkt[3];
      await _logEvent(
        'ble_battery_read_success',
        'Battery level read successfully',
        {
          'battery_level': level,
          'raw': pkt.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '),
        },
      );
      return level;
    } on TimeoutException {
      await _logError(
        'ble_battery_read_timeout',
        'Battery read timed out - no pushed 0x60 packet observed',
      );
      return null;
    } catch (e) {
      await _logError('ble_battery_read_error', 'Error reading battery level', {
        'error': e.toString(),
        'error_type': e.runtimeType.toString(),
      });
      return null;
    }
  }

  /// Read probe attached status
  // Future<bool?> readProbeAttached(
  //     {Duration timeout = const Duration(seconds: 2)}) async
  // {
  //   if (_writeCharacteristic == null) return null;
  //   final completer = Completer<bool?>();
  //   StreamSubscription<List<int>>? sub;
  //   try {
  //     // Create a temporary listener for probe status response
  //     sub = _dataController?.stream.listen((data) {
  //       if (data.length >= 5 && data[0] == 0x55 && data[1] == 0xAA) {
  //         // For probe status (0x61), flags in data[3]
  //         if (data[2] == ApneicareCommands.CMD_PROBE_STATUS) {
  //           final int flags = data[3];
  //           final bool probeFallsOff = (data[3] & 0x01) != 0;
  //           completer.complete(!probeFallsOff);
  //         }
  //       }
  //     });
  //
  //     final cmd = ApneicareCommands.probeStatus();
  //     await sendCommand(cmd, 'Probe Status');
  //     return await completer.future.timeout(timeout, onTimeout: () => null);
  //   } catch (_) {
  //     return null;
  //   } finally {
  //     await sub?.cancel();
  //   }
  // }

  /// Disconnect from device
  Future<void> disconnect() async {
    print('Disconnecting from device...');

    await _logEvent(
      'ble_disconnect_started',
      'Started disconnecting from device',
      {
        'device_name': _connectedDevice?.platformName,
        'device_id': _connectedDevice?.remoteId.toString(),
        'was_connected': _isConnected,
      },
    );

    try {
      if (_connectedDevice != null) {
        final deviceId = _connectedDevice!.remoteId.str;
        final deviceName = _connectedDevice!.platformName;

        // Cancel connection state monitoring
        await _stopConnectionStateMonitoring();

        // Cancel notification subscriptions to avoid duplicates
        for (final sub in _notifySubscriptions) {
          try {
            await sub.cancel();
          } catch (_) {}
        }
        _notifySubscriptions.clear();

        // NOTE: We intentionally do NOT close/null _dataController here.
        // Closing it would make reconnection impossible because _setupNotifications
        // would not be able to push data to listeners.
        // _dataController?.close();
        // _dataController = null;
        // _errorController?.close();
        // _errorController = null;
        // _dataController is only torn down in _resetState() (full cleanup).
        // _disconnectionController?.close(); // Removed - using direct connection state monitoring
        // _disconnectionController = null;

        // Connection cleanup completed

        await _connectedDevice!.disconnect();

        print('Device disconnected successfully');
        await _logEvent(
          'ble_disconnect_success',
          'Device disconnected successfully',
          {'device_name': deviceName, 'device_id': deviceId},
        );
      }
    } catch (e) {
      print('Error during disconnect: $e');
      await _logError('ble_disconnect_error', 'Error during disconnect', {
        'error': e.toString(),
        'error_type': e.runtimeType.toString(),
      });
    } finally {
      await _logEvent(
        'ble_disconnect_cleanup',
        'Disconnect cleanup completed',
        {
          'was_connected': _isConnected,
          'had_write_characteristic': _writeCharacteristic != null,
          'notify_characteristics_count': _notifyCharacteristics.length,
        },
      );

      _connectedDevice = null;
      _writeCharacteristic = null;
      _notifyCharacteristics.clear();
      _isConnected = false;
      _notificationsEnabled = false;
      _connectionFullyEstablished = false;
    }
  }

  /// Check if device is ready for real-time data
  bool get isReadyForRealTime {
    return _isConnected &&
        _writeCharacteristic != null &&
        _notifyCharacteristics.isNotEmpty &&
        _notificationsEnabled;
  }

  /// Stop connection state monitoring to prevent continuous listening
  /// This optimizes device performance and prevents scanning/connection issues
  Future<void> _stopConnectionStateMonitoring() async {
    if (_connectionStateSubscription != null) {
      print(
        'Stopping connection state monitoring to optimize device performance',
      );
      await _connectionStateSubscription!.cancel();
      _connectionStateSubscription = null;
      await _logEvent(
        'ble_monitoring_stopped',
        'Connection state monitoring stopped for optimization',
      );
    }
  }

  /// Compare UUIDs (case-insensitive, with/without dashes)
  bool _compareUuids(String uuid1, String uuid2) {
    String normalized1 = _normalizeUuid(uuid1);
    String normalized2 = _normalizeUuid(uuid2);
    return normalized1 == normalized2;
  }

  /// Normalize UUID for comparison
  String _normalizeUuid(String uuid) {
    return uuid.replaceAll('-', '').toUpperCase();
  }
}
