import UIKit
import Flutter
import CoreBluetooth

@main
@objc class AppDelegate: FlutterAppDelegate {

  private var centralManager: CBCentralManager?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    GeneratedPluginRegistrant.register(with: self)

    // Basic CoreBluetooth init (safe for iOS build)
    centralManager = CBCentralManager(delegate: self, queue: nil)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    super.applicationDidEnterBackground(application)
    print("📱 App entered background")
  }

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
      print("✅ Bluetooth ON")
    case .poweredOff:
      print("⚠️ Bluetooth OFF")
    case .unauthorized:
      print("❌ Bluetooth Unauthorized")
    case .unsupported:
      print("❌ Bluetooth Unsupported")
    case .resetting:
      print("⚠️ Bluetooth Resetting")
    case .unknown:
      print("⚠️ Bluetooth Unknown")
    @unknown default:
      print("⚠️ Bluetooth Unknown Default")
    }
  }

  func centralManager(
    _ central: CBCentralManager,
    willRestoreState dict: [String : Any]
  ) {
    print("📡 CoreBluetooth state restored")
  }

  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String : Any],
    rssi RSSI: NSNumber
  ) {
    print("📡 Beacon discovered: \(peripheral.name ?? "Unknown") RSSI: \(RSSI)")
  }
}
