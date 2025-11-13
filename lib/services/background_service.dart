import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:logger/logger.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:io';
import 'notification_service.dart';
import 'ble_service.dart';
import 'api_service.dart';
import 'local_storage.dart';

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  final Logger _logger = Logger();
  final service = FlutterBackgroundService();

  // Initialize and configure background service
  Future<void> initialize() async {
    if (!Platform.isAndroid) {
      _logger.i('Background service is Android-only (iOS support pending)');
      return;
    }

    _logger.i('🚀 Initializing background service...');

    try {
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: true, // ✅ Enable auto-restart
          isForegroundMode: true, // Foreground service
          notificationChannelId: 'attendance_background',
          initialNotificationTitle: 'Smart Attendance',
          initialNotificationContent: 'Initializing BLE scanning...',
          foregroundServiceNotificationId: 888,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );

      _logger.i('✅ Background service configured');
    } catch (e) {
      _logger.e('❌ Background service configuration error: $e');
    }
  }

  // Start background service
  Future<void> startService() async {
    if (!Platform.isAndroid) {
      _logger.w('Background service not available on iOS yet');
      return;
    }

    try {
      final isRunning = await service.isRunning();
      if (isRunning) {
        _logger.w('Background service already running');
        return;
      }

      await service.startService();
      _logger.i('✅ Background service started');
    } catch (e) {
      _logger.e('❌ Error starting background service: $e');
    }
  }

  // Stop background service
  Future<void> stopService() async {
    if (!Platform.isAndroid) return;

    try {
      final isRunning = await service.isRunning();
      if (!isRunning) {
        _logger.w('Background service not running');
        return;
      }

      service.invoke('stop');
      _logger.i('🛑 Background service stopped');
    } catch (e) {
      _logger.e('❌ Error stopping background service: $e');
    }
  }

  // Check if service is running
  Future<bool> isServiceRunning() async {
    try {
      return await service.isRunning();
    } catch (e) {
      _logger.e('Error checking service status: $e');
      return false;
    }
  }

  // Update notification from main app
  void updateNotification(String beaconId, int rssi, String status) {
    service.invoke('update_notification', {
      'beacon_id': beaconId,
      'rssi': rssi,
      'status': status,
    });
  }
}

// 🎯 MAIN BACKGROUND SERVICE ENTRY POINT (Android)
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final logger = Logger();
  logger.i('🚀 Background service STARTED');

  // ⭐ Enable wakelock to keep device awake during scanning
  try {
    await WakelockPlus.enable();
    logger.i('✅ Wakelock enabled - device will stay awake during BLE scanning');
  } catch (e) {
    logger.w('⚠️ Wakelock enable failed: $e');
  }

  // Initialize services
  final notificationService = NotificationService();
  await notificationService.initialize();

  final bleService = BleService();
  await bleService.initialize();

  final apiService = ApiService().init();
  final localStorage = LocalStorageService();
  await localStorage.init();

  // Variables to track beacon state
  String? lastBeaconId;
  String lastStatus = 'Scanning';
  DateTime? lastApiCall;

  // Show initial foreground notification
  if (service is ServiceInstance) {
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
    }
    await notificationService.showForegroundNotification(
      title: 'Smart Attendance Active',
      body: 'Scanning for BLE beacons...',
    );
  }

  // Start BLE scanning
  await bleService.startScanning();
  logger.i('✅ BLE scanning started in background service');

  // Background scanning loop
  bool serviceRunning = true;
  service.on('stopService').listen((event) {
    serviceRunning = false;
  });
  
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (!serviceRunning) {
      timer.cancel();
      await bleService.stopScanning();
      logger.i('Background service stopped, canceling timer');
      return;
    }

    try {
      final currentBeaconId = bleService.currentBeaconId;
      final currentRssi = bleService.currentRssi;
      final currentStatus = bleService.currentStatus;

      // Update notification
      if (service is AndroidServiceInstance) {
        await notificationService.updateForegroundNotification(
          beaconId: currentBeaconId,
          rssi: currentRssi,
          status: currentStatus,
        );
      }

      // 🎯 TRIGGER DUMMY API CALL WHEN:
      // 1. Beacon disappears (was connected, now not found)
      // 2. Signal drops below threshold (moved out of range)
      // 3. New beacon detected

      bool shouldCallApi = false;
      String apiReason = '';

      // Beacon disappeared
      if (lastBeaconId != null && lastBeaconId != 'N/A' && currentBeaconId == 'N/A') {
        shouldCallApi = true;
        apiReason = 'Beacon disappeared: $lastBeaconId';
      }

      // Moved out of range (RSSI dropped)
      if (lastStatus == 'Connected' && currentStatus == 'Disconnected') {
        shouldCallApi = true;
        apiReason = 'Moved out of range: $currentBeaconId (RSSI: $currentRssi)';
      }

      // New beacon detected
      if (lastBeaconId != currentBeaconId && currentBeaconId != 'N/A') {
        shouldCallApi = true;
        apiReason = 'New beacon detected: $currentBeaconId';
      }

      // Throttle API calls (max once per 30 seconds)
      if (shouldCallApi) {
        final now = DateTime.now();
        if (lastApiCall == null || now.difference(lastApiCall!).inSeconds > 30) {
          logger.i('🎯 API TRIGGER: $apiReason');

          // Call dummy API
          final studentId = localStorage.getStudentId();
          await apiService.updateAttendance(
            studentId: studentId,
            beaconId: currentBeaconId != 'N/A' ? currentBeaconId : lastBeaconId ?? 'UNKNOWN',
            status: currentStatus == 'Connected' ? 'Present' : 'Absent',
            rssi: currentRssi,
          );

          // Show notification about API call
          await notificationService.showAttendanceNotification(
            title: 'Attendance Updated',
            body: apiReason,
          );

          lastApiCall = now;
        }
      }

      // Update tracking variables
      lastBeaconId = currentBeaconId;
      lastStatus = currentStatus;

      logger.i('Background scan: Beacon=$currentBeaconId, RSSI=$currentRssi, Status=$currentStatus');

    } catch (e) {
      logger.e('❌ Error in background service loop: $e');
    }
  });

  // Listen for stop command
  service.on('stop').listen((event) async {
    logger.i('🛑 Stop command received');
    
    // Disable wakelock when stopping
    try {
      await WakelockPlus.disable();
      logger.i('✅ Wakelock disabled');
    } catch (e) {
      logger.w('⚠️ Wakelock disable failed: $e');
    }
    
    service.stopSelf();
  });

  // Listen for notification updates from main app
  service.on('update_notification').listen((event) async {
    if (event != null) {
      final data = event as Map<String, dynamic>;
      await notificationService.updateForegroundNotification(
        beaconId: data['beacon_id'] ?? 'N/A',
        rssi: data['rssi'] ?? 0,
        status: data['status'] ?? 'Unknown',
      );
    }
  });
}

// ⭐ iOS background handler
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  
  final logger = Logger();
  logger.i('🍎 iOS background task started');
  
  // Initialize services for iOS background task
  final bleService = BleService();
  await bleService.initialize();
  
  final apiService = ApiService().init();
  final localStorage = LocalStorageService();
  await localStorage.init();
  
  // Perform quick BLE scan (iOS background tasks are time-limited)
  try {
    logger.i('📡 Starting iOS background BLE scan...');
    
    // Start scanning
    await bleService.startScanning();
    
    // Scan for a short duration (iOS allows ~30 seconds for BGAppRefreshTask)
    await Future.delayed(const Duration(seconds: 20));
    
    // Check if beacon detected
    final beaconId = bleService.currentBeaconId;
    final rssi = bleService.currentRssi;
    final status = bleService.currentStatus;
    
    logger.i('📡 iOS scan result: Beacon=$beaconId, RSSI=$rssi, Status=$status');
    
    // If beacon detected and in range, trigger API
    if (beaconId != 'N/A' && bleService.isInRange()) {
      final studentId = localStorage.getStudentId();
      await apiService.updateAttendance(
        studentId: studentId,
        beaconId: beaconId,
        status: 'Present',
        rssi: rssi,
      );
      logger.i('✅ iOS background attendance update sent');
    }
    
    // Stop scanning
    await bleService.stopScanning();
    
    logger.i('✅ iOS background task completed successfully');
    return true;
  } catch (e) {
    logger.e('❌ iOS background task error: $e');
    return false;
  }
}

