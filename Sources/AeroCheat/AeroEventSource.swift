import AeroCheatCore

/// Where active mode gets its events from: the real `aerospace subscribe` stream, or the demo script.
/// Everything is delivered on the main queue.
protocol AeroEventSource: AnyObject {
    var onEvent: ((AeroEvent) -> Void)? { get set }
    var status: AeroSpaceEventStream.Status { get }
    func start()
    func stop()
}

extension AeroSpaceEventStream: AeroEventSource {}
