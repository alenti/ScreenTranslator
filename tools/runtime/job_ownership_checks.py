"""Compile and exercise the production ownership gate without a model or UIKit."""
import pathlib, subprocess, sys
repo = pathlib.Path(__file__).resolve().parents[2]
out = pathlib.Path(sys.argv[1]).resolve(); out.mkdir(parents=True, exist_ok=True)
source = (repo/'ScreenTranslatorNext/ScreenshotProcessor.swift').read_text()
gate = source[source.index('final class ScreenshotJobGate'):source.index('\nstruct ExactTranslationMemory')]
(out/'Gate.swift').write_text('import Foundation\n'+gate)
(out/'Checks.swift').write_text(r'''
import Foundation
actor Work {
    var active = 0, peak = 0, started = 0, stopped = 0
    func run(_ value: Int, delay: UInt64) async throws -> Int {
        active += 1; started += 1; peak = max(peak, active)
        do {
            try await Task.sleep(nanoseconds: delay)
            active -= 1; stopped += 1
            return value
        } catch { active -= 1; stopped += 1; throw error }
    }
    func snapshot() -> [String:Int] { ["active":active,"peak":peak,"started":started,"stopped":stopped] }
}
final class CancellationCount: @unchecked Sendable {
    let lock = NSLock(); var count = 0
    func increment() { lock.lock(); defer { lock.unlock() }; count += 1 }
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
}
@main struct Checks {
    static func main() async throws {
        let gate = ScreenshotJobGate(), work = Work(), cancels = CancellationCount()
        let oldID = UUID(), newID = UUID()
        let first = gate.start(id:oldID,cancelNative:{ cancels.increment() }) { try await work.run(1,delay:10_000_000_000) }
        try await Task.sleep(nanoseconds:20_000_000)
        let next = gate.start(id:newID,cancelNative:{ cancels.increment() }) { try await work.run(2,delay:30_000_000) }
        let count = cancels.value
        gate.cancel(oldID) // A stale task must not cancel the newer native owner.
        assert(cancels.value == count)
        do { _ = try await first.value; fatalError("Stale result published") } catch is CancellationError {}
        let nextValue = try await next.value; assert(nextValue == 2)
        assert(gate.isIdle && gate.isCurrent(newID) && !gate.isCurrent(oldID))
        var requests: [Task<Int,Error>] = []
        for i in 0..<100 {
            requests.append(gate.start(id:UUID(),cancelNative:{ cancels.increment() }) { try await work.run(i,delay:10_000_000) })
        }
        for task in requests.dropLast() { do { _ = try await task.value; fatalError("Superseded burst succeeded") } catch is CancellationError {} }
        let burstValue = try await requests.last!.value; assert(burstValue == 99)
        let delayedOld = gate.start(id:UUID(),receivedAt:0,cancelNative:{ cancels.increment() }) { try await work.run(-1,delay:1) }
        do { _ = try await delayedOld.value; fatalError("Old receipt overtook latest request") } catch is CancellationError {}
        let cancelledID = UUID()
        let cancelled = gate.start(id:cancelledID,cancelNative:{ cancels.increment() }) { try await work.run(3,delay:10_000_000_000) }
        gate.cancel(cancelledID)
        do { _ = try await cancelled.value; fatalError("Cancelled result published") } catch is CancellationError {}
        await gate.cancelAll()?.value
        let retry = gate.start(id:UUID(),cancelNative:{ cancels.increment() }) { try await work.run(4,delay:1_000_000) }
        let retryValue = try await retry.value; assert(retryValue == 4)
        let metrics = await work.snapshot()
        assert(metrics["peak"] == 1 && metrics["active"] == 0 && metrics["started"] == metrics["stopped"])
        let report: [String:Any] = ["passed":true,"work":metrics,"nativeCancellationSignals":cancels.value,
            "staleCancellationIgnored":true,"delayedOldReceiptRejected":true,"latestResultWins":true,"burstRequests":100,"cancelRetry":true,
            "provenance":"Host production gate correctness only; not OS cancellation or physical inference"]
        try JSONSerialization.data(withJSONObject:report,options:.prettyPrinted).write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
        print("PASS single job, safe join, scoped cancellation, 100 replacements and retry")
    }
}
''')
subprocess.run(['xcrun','swiftc','-parse-as-library',str(out/'Gate.swift'),str(out/'Checks.swift'),'-o',str(out/'checks')],check=True)
subprocess.run([str(out/'checks'),str(out/'report.json')],check=True)
