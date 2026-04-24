import AppKit
import OSLog

// MARK: - ScreenshotCapturer

/// Runs the screencapture(1) process and writes output to a temp file.
/// Returns the temp URL on success, or nil on failure.
final class ScreenshotCapturer {
    private let fm = FileManager.default

    // Текущий процесс и флаг отмены сериализованы через один lock:
    // captureToTemp идёт на background-очереди, terminateCurrentCapture — с main.
    private let processLock = NSLock()
    private var _currentProcess: Process?
    private var _wasCancelled: Bool = false

    /// True если последний вызов captureToTemp/captureRectToTemp/captureWindowIDToTemp
    /// вернул nil из-за явной отмены (sleep/wake), а не из-за сбоя screencapture.
    /// ScreenshotService читает это чтобы не показывать ошибку пользователю.
    private(set) var lastCaptureWasCancelled: Bool = false

    /// Прерывает текущий запущенный screencapture(1).
    /// Безопасно вызывать с любого потока.
    func terminateCurrentCapture() {
        processLock.withLock {
            _wasCancelled = true
            _currentProcess?.terminate()
        }
    }

    func captureToTemp(mode: CaptureMode, preferredScreen: NSScreen?) -> URL? {
        let tmpURL = makeTempURL()
        var args: [String] = ["-x"]
        appendFormatFlag(to: &args)

        switch mode {
        case .selection:
            if AppSettings.includeCursor { args.append("-C") }
            args.append(contentsOf: ["-i", "-s"])
        case .window:
            if AppSettings.includeCursor        { args.append("-C") }
            if !AppSettings.includeWindowShadow { args.append("-o") }
            if let id = FrontmostWindowResolver.frontmostWindowID() {
                args.append(contentsOf: ["-l", String(id)])
            } else {
                args.append(contentsOf: ["-i", "-w"])
            }
        case .screen:
            if AppSettings.includeCursor { args.append("-C") }
            if let id = preferredScreen?.displayID {
                args.append(contentsOf: ["-D", String(id)])
            }
        }

        args.append(tmpURL.path)
        return run(args) && fm.fileExists(atPath: tmpURL.path) ? tmpURL : nil
    }

    func captureRectToTemp(_ rect: CGRect) -> URL? {
        let tmpURL = makeTempURL()
        var args = [
            "-x", "-R",
            "\(Int(rect.minX)),\(Int(rect.minY)),\(Int(rect.width)),\(Int(rect.height))"
        ]
        appendFormatFlag(to: &args)
        if AppSettings.includeCursor { args.append("-C") }
        args.append(tmpURL.path)
        return run(args) && fm.fileExists(atPath: tmpURL.path) ? tmpURL : nil
    }

    func captureWindowIDToTemp(_ windowID: CGWindowID) -> URL? {
        let tmpURL = makeTempURL()
        var args = ["-x", "-l", String(windowID)]
        appendFormatFlag(to: &args)
        if AppSettings.includeCursor { args.append("-C") }
        args.append(tmpURL.path)
        return run(args) && fm.fileExists(atPath: tmpURL.path) ? tmpURL : nil
    }

    // MARK: - Private

    private func makeTempURL() -> URL {
        fm.temporaryDirectory.appendingPathComponent("notchshot-\(UUID().uuidString).\(fileExtension())")
    }

    @discardableResult
    private func run(_ arguments: [String]) -> Bool {
        // (#2) Запрещаем параллельный запуск: второй capture молча отклоняется.
        // Кейсы: hotkey spam, delayed + direct capture, thumbnail/overlay race.
        let alreadyRunning = processLock.withLock { _currentProcess != nil }
        if alreadyRunning {
            Log.capture.warning("screencapture: ignored concurrent launch — already running")
            lastCaptureWasCancelled = true
            return false
        }

        return autoreleasepool {
            // Сбрасываем флаги перед новым запуском.
            processLock.withLock { _wasCancelled = false }
            lastCaptureWasCancelled = false

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError  = pipe

            // (#3) Сохраняем ДО process.run(), чтобы terminateCurrentCapture()
            // мог добраться до процесса сразу после запуска, без race-окна.
            processLock.withLock { _currentProcess = process }

            do {
                try process.run()
                process.waitUntilExit()

                let wasCancelled = processLock.withLock {
                    _currentProcess = nil
                    return _wasCancelled
                }

                // (#1) Отмена через terminate() — это не failure, просто cancel.
                if wasCancelled || process.terminationReason == .uncaughtSignal {
                    lastCaptureWasCancelled = true
                    return false
                }

                if process.terminationStatus != 0 {
                    Log.capture.error("screencapture exited \(process.terminationStatus), args: \(arguments)")
                    return false
                }
                return true
            } catch {
                processLock.withLock { _currentProcess = nil }
                Log.capture.error("screencapture launch failed: \(error), args: \(arguments)")
                return false
            }
        }
    }

    private func appendFormatFlag(to args: inout [String]) {
        args.append(contentsOf: ["-t", AppSettings.fileFormat])
    }

    private func fileExtension() -> String {
        let fmt = AppSettings.fileFormat
        return fmt == "jpg" ? "jpg" : (fmt == "tiff" ? "tiff" : "png")
    }
}
