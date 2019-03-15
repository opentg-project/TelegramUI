import Foundation
import Postbox
import SwiftSignalKit

public struct FlagSettings: Equatable, PreferencesEntry {
    public var ignoreChatFlags: Bool
    
    public static var defaultSettings: FlagSettings {
        return FlagSettings(ignoreChatFlags: false)
    }
    
    public init(ignoreChatFlags: Bool) {
        self.ignoreChatFlags = ignoreChatFlags
    }
    
    public init(decoder: PostboxDecoder) {
        self.ignoreChatFlags = decoder.decodeInt32ForKey("ignoreChatFlags", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.ignoreChatFlags ? 1 : 0, forKey: "ignoreChatFlags")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? FlagSettings {
            return self == to
        } else {
            return false
        }
    }
}

func updateFlagSettingsInteractively(accountManager: AccountManager, _ f: @escaping (FlagSettings) -> FlagSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.flagSettings, { entry in
            let currentSettings: FlagSettings
            if let entry = entry as? FlagSettings {
                currentSettings = entry
            } else {
                currentSettings = .defaultSettings
            }
            return f(currentSettings)
        })
    }
}
