import Cocoa
import ScreenCaptureKit.SCShareableContent

// macOS has some privacy restrictions. The user needs to grant certain permissions, app by app, in System Preferences > Security & Privacy
class SystemPermissions {
    static var preStartupPermissionsPassed = false
    private static var timer: DispatchSourceTimer!
    private static var timerIsFrequent = false
    // After permissions are granted at startup, we listen for `com.apple.accessibility.api`
    // on the distributed notification center to learn about revocation, instead of polling
    // every 5s. The notification name is undocumented by Apple and its firing behaviour across
    // every System Settings action (toggle off, remove from list, etc.) is not reliably
    // characterised in public sources, so we also keep a sparse 60s backstop timer below.
    // Infra requirements: NSDistributedNotificationCenter since 10.15 ignores nil-name
    // observers (we pass a name) and since macOS 15 silently fails for unsigned binaries
    // (AltTab is Developer ID signed). macOS 13+ has a known bug where `AXIsProcessTrusted`
    // can return stale values right after a toggle; we call `AccessibilityPermission.update()`
    // which re-runs the API rather than caching.
    private static let axRevokeNotificationName = "com.apple.accessibility.api"
    private static var distributedObserver: NSObjectProtocol?

    static func ensurePermissionsAreGranted() {
        timer = DispatchSource.makeTimerSource(queue: BackgroundWork.permissionsCheckOnTimerQueue.strongUnderlyingQueue)
        timer.setEventHandler(handler: checkPermissionsOnTimer)
        setImmediateTimer()
        timer.resume()
    }

    private static func startListeningForDistributedRevoke() {
        guard distributedObserver == nil else { return }
        distributedObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(axRevokeNotificationName),
            object: nil,
            queue: nil
        ) { _ in
            BackgroundWork.permissionsCheckOnTimerQueue.addOperation {
                _ = AccessibilityPermission.update()
            }
        }
    }

    private static func checkPermissionsOnTimer() {
        AccessibilityPermission.update()
        let isPermissionsWindowVisible = PermissionsWindow.shared?.isVisible ?? false
        if !preStartupPermissionsPassed || isPermissionsWindowVisible {
            ScreenRecordingPermission.update()
        }
        Logger.debug { "accessibility:\(AccessibilityPermission.status) screenRecording:\(ScreenRecordingPermission.status)" }
        if !preStartupPermissionsPassed {
            checkPermissionsPreStartup()
        } else {
            checkPermissionsPostStartup()
            if isPermissionsWindowVisible && !timerIsFrequent {
                setFrequentTimer()
            } else if !isPermissionsWindowVisible && timerIsFrequent {
                setInfrequentTimer()
            }
        }
        DispatchQueue.main.async {
            Menubar.refreshPermissionCallout()
            if PermissionsWindow.shared != nil {
                PermissionsWindow.updatePermissionViews()
            }
        }
    }

    private static var hasShownPermissionsWindowOnce = false

    private static func checkPermissionsPreStartup() {
        if AccessibilityPermission.status != .notGranted {
            DispatchQueue.main.async {
                preStartupPermissionsPassed = true
                PermissionsWindow.shared?.close()
                setInfrequentTimer()
                startListeningForDistributedRevoke()
                App.continueAppLaunchAfterPermissionsAreGranted()
            }
        } else {
            if !hasShownPermissionsWindowOnce {
                hasShownPermissionsWindowOnce = true
                DispatchQueue.main.async {
                    App.showPermissionsWindow()
                }
            }
        }
    }

    private static func checkPermissionsPostStartup() {
        // Do not force restart on permission changes — keep running and report status cleanly
    }

    static func setInfrequentTimer() {
        timerIsFrequent = false
        if preStartupPermissionsPassed && distributedObserver != nil {
            timer.schedule(deadline: .now() + 60, repeating: 60, leeway: .seconds(10))
            return
        }
        timer.schedule(deadline: .now() + 5, repeating: 5, leeway: .seconds(1))
    }

    static func setFrequentTimer() {
        timerIsFrequent = true
        timer.schedule(deadline: .now() + 1, repeating: 2, leeway: .milliseconds(500))
    }

    private static func setImmediateTimer() {
        timerIsFrequent = false
        timer.schedule(deadline: .now(), repeating: .never, leeway: .never)
    }
}

class AccessibilityPermission {
    static var status = PermissionStatus.notGranted
    private static var hasPrompted = false

    @discardableResult
    static func update() -> PermissionStatus {
        status = detect()
        return status
    }

    private static func detect() -> PermissionStatus {
        return AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeRetainedValue(): false] as CFDictionary) ? .granted : .notGranted
    }
}

class ScreenRecordingPermission {
    static var status = PermissionStatus.notGranted

    @discardableResult
    static func update() -> PermissionStatus {
        status = detect()
        return status
    }

    private static func detect() -> PermissionStatus {
        if #available(macOS 10.15, *) {
            return CGPreflightScreenCaptureAccess() ? .granted : .notGranted
        }
        return .granted
    }

    // workaround: public API CGPreflightScreenCaptureAccess and private API SLSRequestScreenCaptureAccess exist, but
    // their return value is not updated during the app lifetime
    // note: shows the system prompt if there's no permission
    private static func isGrantedOnSomeDisplay() -> Bool {
        if #available(macOS 12.3, *) {
            return checkWithSCShareableContent()
        } else {
            let mainDisplayID = CGMainDisplayID()
            if checkWithCGDisplayStream(mainDisplayID) {
                return true
            }
            // maybe the main screen can't produce a CGDisplayStream, but another screen can
            // a positive on any screen must mean that the permission is granted; we try on the other screens
            for screen in NSScreen.screens {
                if let id = screen.number(), id != mainDisplayID {
                    if checkWithCGDisplayStream(id) {
                        return true
                    }
                }
            }
            return false
        }
    }

    @available(macOS 12.3, *)
    private static func checkWithSCShareableContent() -> Bool {
        return runWithTimeout { completion in
            SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: false) { shareableContent, error in
                // this callback runs on a GCD queue, not on the thread that called getWithCompletionHandler
                if #available(macOS 14.0, *), let shareableContent, error == nil {
                    BackgroundWork.screenshotsQueue.addOperation {
                        WindowCaptureScreenshots.cachedSCWindows.withLock { $0 = shareableContent.windows }
                    }
                }
                completion(error != nil ? false : (shareableContent != nil))
            }
        }
    }

    private static func checkWithCGDisplayStream(_ id: CGDirectDisplayID) -> Bool {
        return runWithTimeout { completion in
            // this initializer can actually block for a while
            // it's undocumented but has been proven by spindumps shared by AltTab users
            let displayStream = CGDisplayStream(
                dispatchQueueDisplay: id,
                outputWidth: 1,
                outputHeight: 1,
                pixelFormat: Int32(kCVPixelFormatType_32BGRA),
                properties: nil,
                queue: .global()
            ) { _, _, _, _ in }
            completion(displayStream != nil)
        }
    }

    private static func runWithTimeout(_ block: @escaping (@escaping (Bool) -> Void) -> Void) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var result = false
        BackgroundWork.permissionsSystemCallsQueue.addOperation {
            block { r in
                result = r
                semaphore.signal()
            }
        }
        let timeoutResult = semaphore.wait(timeout: .now() + 6)
        if timeoutResult == .timedOut {
            Logger.error { "Screen-recording permission call timed out after 6s" }
            return false
        }
        return result
    }
}
