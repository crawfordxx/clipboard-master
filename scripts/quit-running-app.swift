import AppKit

// Ask only this installed bundle to quit normally, so unsaved-draft prompts can veto it.
guard CommandLine.arguments.count == 2, CommandLine.arguments[1].hasPrefix("/") else {
    fputs("Usage: quit-running-app.swift /absolute/path/to/App.app\n", stderr)
    exit(64)
}
let target = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL.resolvingSymlinksInPath()
let running = NSWorkspace.shared.runningApplications.filter {
    $0.bundleURL?.standardizedFileURL.resolvingSymlinksInPath() == target
}
for application in running {
    print("Requesting normal quit: PID \(application.processIdentifier)")
    guard application.terminate() else {
        fputs("应用未接受退出请求；安装已中止，未覆盖应用。请保存草稿后退出再试。\n", stderr)
        exit(1)
    }
}
let deadline = Date().addingTimeInterval(60)
while running.contains(where: { !$0.isTerminated }) && Date() < deadline {
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
}
guard running.allSatisfy(\.isTerminated) else {
    fputs("应用尚未退出（可能正在等待保存确认）；安装已中止，未覆盖应用。\n", stderr)
    exit(1)
}
print("PASS: no running process remains for \(target.path)")
