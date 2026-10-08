import CmuxNextDaemon
import CmuxNextSidebar

// Organization intents (group create, move, rename, collapse, order) before
// the home session's personal state is loaded. Groups are personal rows of
// the local daemon, which loads them with its first snapshot; an intent sent
// earlier waits for that snapshot instead of being refused, and runs then.
extension SidebarBridge {
    /// At most this many intents wait; later ones are refused with the reason.
    static let pendingOrganizationLimit = 32

    /// Queues `intent` while the local daemon may still bring personal state
    /// (it has not answered yet, or it serves `profiles-v1`); otherwise
    /// refuses it with the capability gate's reason and puts daemon truth back.
    func organizeBeforePersonalState(_ intent: SidebarIntent) {
        let local = services.machines.local
        if personalStateMayLoad, pendingOrganization.count < Self.pendingOrganizationLimit {
            pendingOrganization.append(intent)
            return
        }
        services.registry.refuse(local.personalStateUnavailableReason)
        resync()
    }

    /// The local daemon may still bring personal state: it has not answered
    /// yet, or it serves `profiles-v1` (its next snapshot carries it).
    var personalStateMayLoad: Bool {
        let local = services.machines.local
        return !local.startup.isUnavailable && (local.identity == nil || local.supports(DaemonCapabilities.shared.profiles))
    }

    /// Runs the waiting intents once personal state is loaded (each live
    /// sidebar update calls it); refuses them once it can no longer load
    /// (the daemon is unavailable or answered without `profiles-v1`).
    func replayPendingOrganization() {
        guard !pendingOrganization.isEmpty else { return }
        if !usesPersonalOrganization {
            guard !personalStateMayLoad else { return }
            pendingOrganization = []
            services.registry.refuse(services.machines.local.personalStateUnavailableReason)
            return resync()
        }
        let intents = pendingOrganization
        pendingOrganization = []
        for intent in intents { handle(intent) }
    }
}
