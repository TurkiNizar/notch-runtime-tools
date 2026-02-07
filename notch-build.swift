import Foundation

// Swift CLI wrapper for builds that streams output and emits events to the notch listener.
// Usage: swift notch-build.swift [--host HOST] [--port PORT] <command> [args...]

struct Payload: Codable {
    enum EventType: String, Codable {
        case buildStarted, phaseChanged, buildFailed, buildSucceeded, progressUpdated
    }
    enum Tool: String, Codable {
        case maven, gradle, npm, yarn, pnpm, unknown
    }
    let event: EventType
    let tool: Tool
    let phase: String?
    let timestamp: TimeInterval
    let progress: Double?
}

final class EventSender {
    private let host: String
    private let port: Int

    init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    func send(_ payload: Payload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        var input: InputStream?
        var output: OutputStream?
        Stream.getStreamsToHost(withName: host, port: port, inputStream: &input, outputStream: &output)
        guard let out = output else { return }
        out.open()
        let packet = data + Data([0x0A])
        _ = packet.withUnsafeBytes { ptr in
            guard let base = ptr.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return out.write(base, maxLength: packet.count)
        }
        out.close()
    }
}

func detectTool(command: String) -> Payload.Tool {
    let name = URL(fileURLWithPath: command).lastPathComponent.lowercased()
    if name.contains("mvn") { return .maven }
    if name.contains("gradle") || name.contains("gradlew") { return .gradle }
    if name == "npm" { return .npm }
    if name == "yarn" { return .yarn }
    if name.contains("pnpm") { return .pnpm }
    return .unknown
}

func now() -> TimeInterval { Date().timeIntervalSince1970 }

func resolveCommandPath(_ command: String) -> String? {
    // If command contains a slash, trust it as-is.
    if command.contains("/") {
        return command
    }
    // Otherwise search PATH.
    let paths = (ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin").split(separator: ":")
    for p in paths {
        let candidate = String(p) + "/" + command
        if FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }
    }
    return nil
}

func runCLI() {
    let args = Array(CommandLine.arguments.dropFirst())
    var host = ProcessInfo.processInfo.environment["NOTCH_BUILD_HOST"] ?? "127.0.0.1"
    var port = Int(ProcessInfo.processInfo.environment["NOTCH_BUILD_PORT"] ?? "") ?? 34345

    var cleaned: [String] = []
    var idx = 0
    while idx < args.count {
        let arg = args[idx]
        if arg == "--host", idx + 1 < args.count {
            host = args[idx + 1]
            idx += 2
        } else if arg == "--port", idx + 1 < args.count, let p = Int(args[idx + 1]) {
            port = p
            idx += 2
        } else if arg.hasPrefix("--") {
            idx += 1 // ignore unknown flags
        } else {
            cleaned.append(contentsOf: args[idx...])
            break
        }
    }

    guard let command = cleaned.first else {
        fputs("Usage: notch-build.swift [--host HOST] [--port PORT] <command> [args...]\n", stderr)
        exit(1)
    }
    let commandArgs = Array(cleaned.dropFirst())
    let tool = detectTool(command: command)
    let sender = EventSender(host: host, port: port)
    var progressValue: Double = 0.05
    var seenMavenPlugins = Set<String>()
    var seenGradleTasks = Set<String>()

    let ts = now()
    sender.send(Payload(event: .buildStarted, tool: tool, phase: nil, timestamp: ts, progress: nil))
    sender.send(Payload(event: .progressUpdated, tool: tool, phase: nil, timestamp: ts, progress: progressValue))

    let process = Process()
    guard let resolved = resolveCommandPath(command) else {
        fputs("notch-build: command not found: \(command)\n", stderr)
        sender.send(Payload(event: .buildFailed, tool: tool, phase: nil, timestamp: now(), progress: nil))
        exit(127)
    }
    process.executableURL = URL(fileURLWithPath: resolved)
    process.arguments = commandArgs
    process.standardInput = FileHandle.standardInput
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    func processLine(_ line: String) {
        let lower = line.lowercased()
        if lower.contains("test") || lower.contains("surefire") || lower.contains(":test") {
            progressValue = max(progressValue, 0.6)
            sender.send(Payload(event: .phaseChanged, tool: tool, phase: "test", timestamp: now(), progress: progressValue))
            sender.send(Payload(event: .progressUpdated, tool: tool, phase: "test", timestamp: now(), progress: progressValue))
        } else {
            switch tool {
            case .maven:
                if let range = lower.range(of: "[info] --- ") {
                    let tail = lower[range.upperBound...]
                    if let end = tail.range(of: " ---") {
                        let plugin = String(tail[..<end.lowerBound]).trimmingCharacters(in: .whitespaces)
                        if !plugin.isEmpty && seenMavenPlugins.insert(plugin).inserted {
                            progressValue = min(progressValue + 0.05, 0.85)
                            sender.send(Payload(event: .progressUpdated, tool: tool, phase: plugin, timestamp: now(), progress: progressValue))
                        }
                    }
                }
            case .gradle:
                if line.hasPrefix(":") {
                    let task = line.split(separator: " ").first.map(String.init) ?? line
                    if !task.isEmpty && seenGradleTasks.insert(task).inserted {
                        progressValue = min(progressValue + 0.05, 0.85)
                        sender.send(Payload(event: .progressUpdated, tool: tool, phase: task, timestamp: now(), progress: progressValue))
                    }
                }
            case .npm, .yarn, .pnpm:
                // Keep indeterminate; optional small nudge halfway through output.
                progressValue = min(progressValue + 0.02, 0.6)
                sender.send(Payload(event: .progressUpdated, tool: tool, phase: nil, timestamp: now(), progress: progressValue))
            default:
                break
            }
        }
    }

    stdoutPipe.fileHandleForReading.readabilityHandler = { fh in
        let data = fh.availableData
        guard !data.isEmpty else { return }
        if let text = String(data: data, encoding: .utf8) {
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                print(line)
                processLine(String(line))
            }
        }
    }

    stderrPipe.fileHandleForReading.readabilityHandler = { fh in
        let data = fh.availableData
        guard !data.isEmpty else { return }
        if let text = String(data: data, encoding: .utf8) {
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                FileHandle.standardError.write((line + "\n").data(using: .utf8)!)
                processLine(String(line))
            }
        }
    }

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        fputs("Failed to start command: \(error)\n", stderr)
        sender.send(Payload(event: .buildFailed, tool: tool, phase: nil, timestamp: now(), progress: nil))
        exit(1)
    }

    stdoutPipe.fileHandleForReading.readabilityHandler = nil
    stderrPipe.fileHandleForReading.readabilityHandler = nil

    if process.terminationStatus == 0 {
        sender.send(Payload(event: .progressUpdated, tool: tool, phase: nil, timestamp: now(), progress: 1.0))
        sender.send(Payload(event: .buildSucceeded, tool: tool, phase: nil, timestamp: now(), progress: 1.0))
        exit(0)
    } else {
        sender.send(Payload(event: .progressUpdated, tool: tool, phase: nil, timestamp: now(), progress: 1.0))
        sender.send(Payload(event: .buildFailed, tool: tool, phase: nil, timestamp: now(), progress: 1.0))
        exit(Int32(process.terminationStatus))
    }
}

// For script-style execution with `swift notch-build.swift ...`
runCLI()
