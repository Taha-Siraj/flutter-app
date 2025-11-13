import Flutter
import UIKit
import CoreBluetooth

@main
@objc class AppDelegate: FlutterAppDelegate {
  // CoreBluetooth Central Manager for background BLE scanning
  private var centralManager: CBCentralManager?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // ⭐ Initialize CoreBluetooth for background restoration
    if launchOptions?[UIApplication.LaunchOptionsKey.bluetoothCentrals] != nil {
      print("📡 App launched for Bluetooth background event")
      // Initialize CoreBluetooth with restoration identifier
      let options = [CBCentralManagerOptionRestoreIdentifierKey: "com.smartattendance.app.ble"]
      centralManager = CBCentralManager(delegate: self, queue: nil, options: options)
    }
    
    // Register background tasks (iOS 13+)
    if #available(iOS 13.0, *) {
      BackgroundTaskManager.shared.registerBackgroundTasks()
      print("✅ Background tasks registered")
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle app entering background
  override func applicationDidEnterBackground(_ application: UIApplication) {
    super.applicationDidEnterBackground(application)
    print("📱 App entered background - BLE scanning continues")
    
    // Schedule background refresh task
    if #available(iOS 13.0, *) {
      BackgroundTaskManager.shared.scheduleAppRefresh()
    }
  }
  
  // Handle app becoming active
  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    print("📱 App became active")
  }
}

// MARK: - CBCentralManagerDelegate
extension AppDelegate: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
    case .poweredOn:
      print("✅ Bluetooth is powered on")
      // Start scanning for beacons if needed
    case .poweredOff:
      print("⚠️ Bluetooth is powered off")
    case .unauthorized:
      print("❌ Bluetooth unauthorized")
    case .unsupported:
      print("❌ Bluetooth unsupported")
    case .resetting:
      print("⚠️ Bluetooth resetting")
    case .unknown:
      print("⚠️ Bluetooth state unknown")
    @unknown default:
      print("⚠️ Bluetooth state unknown")
    }
  }
  
  // CoreBluetooth state restoration
  func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
    print("📡 CoreBluetooth state restoration triggered")
    
    if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
      print("📡 Restored \(peripherals.count) peripheral(s)")
      // Handle restored peripherals
    }
    
    if let scanServices = dict[CBCentralManagerRestoredStateScanServicesKey] as? [CBUUID] {
      print("📡 Restored scan services: \(scanServices)")
      // Resume scanning for services
    }
  }
  
  // Discovered peripheral
  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
    print("📡 Discovered beacon: \(peripheral.name ?? "Unknown") RSSI: \(RSSI)")
    // Pass to Flutter side via method channel if needed
  }
}
