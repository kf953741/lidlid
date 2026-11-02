import Foundation

public enum CompatibilityService {
    public static let version = 1
    public static let team = "63ALH54858"
    public static let group = "\(team).dev.kf.lidonce"
    public static let name = "\(group).sleep-service"
    public static let plist = "\(name).plist"
    public static let helperID = "dev.kf.lidonce.compatibility"
    public static let daemonID = "dev.kf.lidonce.sleep-service"
    public static let leaseSeconds: TimeInterval = 30
    public static let renewalSeconds: TimeInterval = 5
    public static let daemonRequirement = "anchor apple generic and identifier \"\(daemonID)\" and certificate leaf[subject.OU] = \"\(team)\""
    // The embedded agent inherits the parent's sandbox, including Mach lookup
    // access, but has its own signing identifier. No unrelated signed app qualifies.
    public static let clientRequirement = """
    anchor apple generic and certificate leaf[subject.OU] = "\(team)" and (
      identifier "dev.kf.lidonce" or identifier "dev.kf.lidonce.agent" or
      identifier "\(helperID)"
    )
    """
}

@objc public protocol LidLidSleepServiceProtocol {
    func status(reply: @escaping (Int, Bool, Bool) -> Void)
    func beginSession(minutes: Int, reply: @escaping (Bool, String?) -> Void)
    func renewSession(reply: @escaping (Bool, String?) -> Void)
    func endSession(reply: @escaping (Bool, String?) -> Void)
    func prepareForRemoval(reply: @escaping (Bool, String?) -> Void)
}
