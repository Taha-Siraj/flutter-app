import Foundation
import BackgroundTasks
import UIKit

@available(iOS 13.0, *)
class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    // Background task identifiers
    private let appRefreshTaskIdentifier = "com.smartattendance.app.refresh"
    private let processingTaskIdentifier = "com.smartattendance.app.bleProcessing"
    
    private init() {}
    
    // Register background tasks
    func registerBackgroundTasks() {
        print("📋 Registering background tasks...")
        
        // Register app refresh task (runs every 15 minutes)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: appRefreshTaskIdentifier,
            using: nil
        ) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        
        // Register processing task (for longer BLE operations)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: processingTaskIdentifier,
            using: nil
        ) { task in
            self.handleProcessing(task: task as! BGProcessingTask)
        }
        
        print("✅ Background tasks registered successfully")
    }
    
    // Schedule app refresh task
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: appRefreshTaskIdentifier)
        
        // Schedule to run in 15 minutes (minimum allowed)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ App refresh task scheduled")
        } catch {
            print("❌ Could not schedule app refresh: \(error)")
        }
    }
    
    // Schedule processing task
    func scheduleProcessing() {
        let request = BGProcessingTaskRequest(identifier: processingTaskIdentifier)
        
        // Allow device to charge if needed
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        // Schedule to run in 20 minutes
        request.earliestBeginDate = Date(timeIntervalSinceNow: 20 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Processing task scheduled")
        } catch {
            print("❌ Could not schedule processing task: \(error)")
        }
    }
    
    // Handle app refresh task
    private func handleAppRefresh(task: BGAppRefreshTask) {
        print("🔄 App refresh task started")
        
        // Schedule next refresh
        scheduleAppRefresh()
        
        // Create background task operation
        let operation = BLEScanOperation()
        
        // Set expiration handler
        task.expirationHandler = {
            print("⚠️ App refresh task expired")
            operation.cancel()
        }
        
        // Set completion handler
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
            print("✅ App refresh task completed")
        }
        
        // Start operation
        OperationQueue().addOperation(operation)
    }
    
    // Handle processing task
    private func handleProcessing(task: BGProcessingTask) {
        print("🔄 Processing task started")
        
        // Schedule next processing task
        scheduleProcessing()
        
        // Create background processing operation
        let operation = BLEProcessingOperation()
        
        // Set expiration handler
        task.expirationHandler = {
            print("⚠️ Processing task expired")
            operation.cancel()
        }
        
        // Set completion handler
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
            print("✅ Processing task completed")
        }
        
        // Start operation
        OperationQueue().addOperation(operation)
    }
}

// MARK: - BLE Scan Operation
class BLEScanOperation: Operation {
    private var isFinished = false
    private var isExecuting = false
    
    override var isAsynchronous: Bool {
        return true
    }
    
    override var isExecuting: Bool {
        return isExecuting
    }
    
    override var isFinished: Bool {
        return isFinished
    }
    
    override func main() {
        guard !isCancelled else { return }
        
        willChangeValue(forKey: "isExecuting")
        isExecuting = true
        didChangeValue(forKey: "isExecuting")
        
        print("📡 BLE scan operation running (REAL IMPLEMENTATION)...")
        
        // ⭐ REAL BLE SCANNING IMPLEMENTATION:
        // Note: In iOS background mode, BLE scanning is limited to ~10 minutes
        // For continuous background BLE, the app needs to be scanning when backgrounded
        
        // Create a semaphore to keep operation alive during async BLE scan
        let semaphore = DispatchSemaphore(value: 0)
        
        // Perform BLE scan on main thread (required for CoreBluetooth)
        DispatchQueue.main.async {
            // Use Flutter method channel to trigger BLE scan from Dart side
            if let flutterViewController = UIApplication.shared.windows.first?.rootViewController as? FlutterViewController {
                let channel = FlutterMethodChannel(name: "com.smartattendance.app/ble", 
                                                   binaryMessenger: flutterViewController.binaryMessenger)
                
                // Trigger Flutter-side BLE scan
                channel.invokeMethod("performBackgroundScan", arguments: nil) { result in
                    if let error = result as? FlutterError {
                        print("❌ BLE scan error: \(error.message ?? "Unknown error")")
                    } else {
                        print("✅ Background BLE scan completed successfully")
                    }
                    semaphore.signal()
                }
            } else {
                print("⚠️ Could not access Flutter view controller")
                semaphore.signal()
            }
        }
        
        // Wait for scan to complete (with 25 second timeout for iOS background task limits)
        _ = semaphore.wait(timeout: .now() + 25)
        
        guard !isCancelled else {
            print("⚠️ BLE scan operation cancelled")
            self.finish()
            return
        }
        
        print("✅ BLE scan operation completed")
        self.finish()
    }
    
    private func finish() {
        willChangeValue(forKey: "isExecuting")
        willChangeValue(forKey: "isFinished")
        isExecuting = false
        isFinished = true
        didChangeValue(forKey: "isExecuting")
        didChangeValue(forKey: "isFinished")
    }
}

// MARK: - BLE Processing Operation
class BLEProcessingOperation: Operation {
    private var isFinished = false
    private var isExecuting = false
    
    override var isAsynchronous: Bool {
        return true
    }
    
    override var isExecuting: Bool {
        return isExecuting
    }
    
    override var isFinished: Bool {
        return isFinished
    }
    
    override func main() {
        guard !isCancelled else { return }
        
        willChangeValue(forKey: "isExecuting")
        isExecuting = true
        didChangeValue(forKey: "isExecuting")
        
        print("📡 BLE processing operation running (REAL IMPLEMENTATION)...")
        
        // ⭐ LONGER RUNNING BLE OPERATIONS (up to 30 seconds on iOS):
        // 1. Scan for beacons
        // 2. Connect to beacons if needed
        // 3. Read beacon data
        // 4. Trigger API calls
        // 5. Update local storage
        
        let semaphore = DispatchSemaphore(value: 0)
        
        DispatchQueue.main.async {
            if let flutterViewController = UIApplication.shared.windows.first?.rootViewController as? FlutterViewController {
                let channel = FlutterMethodChannel(name: "com.smartattendance.app/ble", 
                                                   binaryMessenger: flutterViewController.binaryMessenger)
                
                // Trigger extended Flutter-side BLE processing
                channel.invokeMethod("performExtendedBackgroundScan", arguments: nil) { result in
                    if let error = result as? FlutterError {
                        print("❌ Extended BLE processing error: \(error.message ?? "Unknown error")")
                    } else {
                        print("✅ Extended background BLE processing completed")
                    }
                    semaphore.signal()
                }
            } else {
                print("⚠️ Could not access Flutter view controller")
                semaphore.signal()
            }
        }
        
        // Wait for processing to complete (with 25 second timeout)
        _ = semaphore.wait(timeout: .now() + 25)
        
        guard !isCancelled else {
            print("⚠️ BLE processing operation cancelled")
            self.finish()
            return
        }
        
        print("✅ BLE processing operation completed")
        self.finish()
    }
    
    private func finish() {
        willChangeValue(forKey: "isExecuting")
        willChangeValue(forKey: "isFinished")
        isExecuting = false
        isFinished = true
        didChangeValue(forKey: "isExecuting")
        didChangeValue(forKey: "isFinished")
    }
}

