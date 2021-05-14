//
//  PrivacySettingsViewController.swift
//  TelegramMac
//
//  Created by keepcoder on 10/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox

/*
 
 struct InteractiveEmojiConfiguration : Equatable {
 static var defaultValue: InteractiveEmojiConfiguration {
 return InteractiveEmojiConfiguration(emojis: [], confettiCompitable: [:])
 }
 
 let emojis: [String]
 private let confettiCompitable: [String: InteractiveEmojiConfetti]
 
 fileprivate init(emojis: [String], confettiCompitable: [String: InteractiveEmojiConfetti]) {
 self.emojis = emojis.map { $0.fixed }
 self.confettiCompitable = confettiCompitable
 }
 
 static func with(appConfiguration: AppConfiguration) -> InteractiveEmojiConfiguration {
 if let data = appConfiguration.data, let value = data["emojies_send_dice"] as? [String] {
 let dict:[String : Any]? = data["emojies_send_dice_success"] as? [String:Any]
 
 var confetti:[String: InteractiveEmojiConfetti] = [:]
 if let dict = dict {
 for (key, value) in dict {
 if let data = value as? [String: Any], let frameStart = data["frame_start"] as? Double, let value = data["value"] as? Double {
 confetti[key] = InteractiveEmojiConfetti(playAt: Int32(frameStart), value: Int32(value))
 }
 }
 }
 return InteractiveEmojiConfiguration(emojis: value, confettiCompitable: confetti)
 } else {
 return .defaultValue
 }
 }
 
 func playConfetti(_ emoji: String) -> InteractiveEmojiConfetti? {
 return confettiCompitable[emoji]
 }
 }
 */

private struct AutoarchiveConfiguration : Equatable {
    let autoarchive_setting_available: Bool
    init(autoarchive_setting_available: Bool) {
        self.autoarchive_setting_available = autoarchive_setting_available
    }
    static func with(appConfiguration: AppConfiguration) -> AutoarchiveConfiguration {
        return AutoarchiveConfiguration(autoarchive_setting_available: appConfiguration.data?["autoarchive_setting_available"] as? Bool ?? false)
    }
}


enum PrivacyAndSecurityEntryTag: ItemListItemTag {
    case accountTimeout
    case topPeers
    case cloudDraft
    case autoArchive
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? PrivacyAndSecurityEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
    
    fileprivate var stableId: AnyHashable {
        switch self {
        case .accountTimeout:
            return PrivacyAndSecurityEntry.accountTimeout(sectionId: 0, "", viewType: .singleItem).stableId
        case .topPeers:
            return PrivacyAndSecurityEntry.togglePeerSuggestions(sectionId: 0, enabled: false, viewType: .singleItem).stableId
        case .cloudDraft:
            return PrivacyAndSecurityEntry.clearCloudDrafts(sectionId: 0, viewType: .singleItem).stableId
        case .autoArchive:
            return PrivacyAndSecurityEntry.autoArchiveToggle(sectionId: 0, value: false, viewType: .singleItem).stableId
        }
    }
}

private final class PrivacyAndSecurityControllerArguments {
    let context: AccountContext
    let openBlockedUsers: () -> Void
    let openLastSeenPrivacy: () -> Void
    let openGroupsPrivacy: () -> Void
    let openVoiceCallPrivacy: () -> Void
    let openProfilePhotoPrivacy: () -> Void
    let openForwardPrivacy: () -> Void
    let openPhoneNumberPrivacy: () -> Void
    let openPasscode: () -> Void
    let openTwoStepVerification: (TwoStepVeriticationAccessConfiguration?) -> Void
    let openActiveSessions: ([RecentAccountSession]?) -> Void
    let openWebAuthorizations: () -> Void
    let setupAccountAutoremove: () -> Void
    let openProxySettings:() ->Void
    let togglePeerSuggestions:(Bool)->Void
    let clearCloudDrafts: () -> Void
    let toggleSensitiveContent:(Bool)->Void
    let toggleSecretChatWebPreview: (Bool)->Void
    let toggleAutoArchive: (Bool)->Void
    init(context: AccountContext, openBlockedUsers: @escaping () -> Void, openLastSeenPrivacy: @escaping () -> Void, openGroupsPrivacy: @escaping () -> Void, openVoiceCallPrivacy: @escaping () -> Void, openProfilePhotoPrivacy: @escaping () -> Void, openForwardPrivacy: @escaping () -> Void, openPhoneNumberPrivacy: @escaping() -> Void, openPasscode: @escaping () -> Void, openTwoStepVerification: @escaping (TwoStepVeriticationAccessConfiguration?) -> Void, openActiveSessions: @escaping ([RecentAccountSession]?) -> Void, openWebAuthorizations: @escaping() -> Void, setupAccountAutoremove: @escaping () -> Void, openProxySettings:@escaping() ->Void, togglePeerSuggestions:@escaping(Bool)->Void, clearCloudDrafts: @escaping() -> Void, toggleSensitiveContent: @escaping(Bool)->Void, toggleSecretChatWebPreview: @escaping(Bool)->Void, toggleAutoArchive: @escaping(Bool)->Void) {
        self.context = context
        self.openBlockedUsers = openBlockedUsers
        self.openLastSeenPrivacy = openLastSeenPrivacy
        self.openGroupsPrivacy = openGroupsPrivacy
        self.openVoiceCallPrivacy = openVoiceCallPrivacy
        self.openPasscode = openPasscode
        self.openTwoStepVerification = openTwoStepVerification
        self.openActiveSessions = openActiveSessions
        self.openWebAuthorizations = openWebAuthorizations
        self.setupAccountAutoremove = setupAccountAutoremove
        self.openProxySettings = openProxySettings
        self.togglePeerSuggestions = togglePeerSuggestions
        self.clearCloudDrafts = clearCloudDrafts
        self.openProfilePhotoPrivacy = openProfilePhotoPrivacy
        self.openForwardPrivacy = openForwardPrivacy
        self.openPhoneNumberPrivacy = openPhoneNumberPrivacy
        self.toggleSensitiveContent = toggleSensitiveContent
        self.toggleSecretChatWebPreview = toggleSecretChatWebPreview
        self.toggleAutoArchive = toggleAutoArchive
    }
}


private enum PrivacyAndSecurityEntry: Comparable, Identifiable {
    case privacyHeader(sectionId:Int)
    case blockedPeers(sectionId:Int, Int?, viewType: GeneralViewType)
    case phoneNumberPrivacy(sectionId: Int, String, viewType: GeneralViewType)
    case lastSeenPrivacy(sectionId: Int, String, viewType: GeneralViewType)
    case groupPrivacy(sectionId: Int, String, viewType: GeneralViewType)
    case profilePhotoPrivacy(sectionId: Int, String, viewType: GeneralViewType)
    case forwardPrivacy(sectionId: Int, String, viewType: GeneralViewType)
    case voiceCallPrivacy(sectionId: Int, String, viewType: GeneralViewType)
    case securityHeader(sectionId:Int)
    case passcode(sectionId:Int, enabled: Bool, viewType: GeneralViewType)
    case twoStepVerification(sectionId:Int, configuration: TwoStepVeriticationAccessConfiguration?, viewType: GeneralViewType)
    case activeSessions(sectionId:Int, [RecentAccountSession]?, viewType: GeneralViewType)
    case webAuthorizationsHeader(sectionId: Int)
    case webAuthorizations(sectionId:Int, viewType: GeneralViewType)
    case accountHeader(sectionId:Int)
    case accountTimeout(sectionId: Int, String, viewType: GeneralViewType)
    case accountInfo(sectionId:Int)
    case proxyHeader(sectionId:Int)
    case proxySettings(sectionId:Int, String, viewType: GeneralViewType)
    case togglePeerSuggestions(sectionId: Int, enabled: Bool, viewType: GeneralViewType)
    case togglePeerSuggestionsDesc(sectionId: Int)
    case sensitiveContentHeader(sectionId: Int)
    case autoArchiveToggle(sectionId: Int, value: Bool?, viewType: GeneralViewType)
    case autoArchiveDesc(sectionId: Int)
    case autoArchiveHeader(sectionId: Int)
    case sensitiveContentToggle(sectionId: Int, value: Bool?, viewType: GeneralViewType)
    case sensitiveContentDesc(sectionId: Int)
    case clearCloudDraftsHeader(sectionId: Int)
    case clearCloudDrafts(sectionId: Int, viewType: GeneralViewType)

    case secretChatWebPreviewHeader(sectionId: Int)
    case secretChatWebPreviewToggle(sectionId: Int, value: Bool?, viewType: GeneralViewType)
    case secretChatWebPreviewDesc(sectionId: Int)
    
    case section(sectionId:Int)

    var sectionId: Int {
        switch self {
        case let .privacyHeader(sectionId):
            return sectionId
        case let .blockedPeers(sectionId, _, _):
            return sectionId
        case let .phoneNumberPrivacy(sectionId, _, _):
            return sectionId
        case let .lastSeenPrivacy(sectionId, _, _):
            return sectionId
        case let .groupPrivacy(sectionId, _, _):
            return sectionId
        case let .profilePhotoPrivacy(sectionId, _, _):
            return sectionId
        case let .forwardPrivacy(sectionId, _, _):
            return sectionId
        case let .voiceCallPrivacy(sectionId, _, _):
            return sectionId
        case let .securityHeader(sectionId):
            return sectionId
        case let .passcode(sectionId, _, _):
            return sectionId
        case let .twoStepVerification(sectionId, _, _):
            return sectionId
        case let .activeSessions(sectionId, _, _):
            return sectionId
        case let .webAuthorizationsHeader(sectionId):
            return sectionId
        case let .webAuthorizations(sectionId, _):
            return sectionId
        case let .autoArchiveHeader(sectionId):
            return sectionId
        case let .autoArchiveToggle(sectionId, _, _):
            return sectionId
        case let .autoArchiveDesc(sectionId):
            return sectionId
        case let .accountHeader(sectionId):
            return sectionId
        case let .accountTimeout(sectionId, _, _):
            return sectionId
        case let .accountInfo(sectionId):
            return sectionId
        case let .togglePeerSuggestions(sectionId, _, _):
            return sectionId
        case let .togglePeerSuggestionsDesc(sectionId):
            return sectionId
        case let .clearCloudDraftsHeader(sectionId):
            return sectionId
        case let .clearCloudDrafts(sectionId, _):
            return sectionId
        case let .proxyHeader(sectionId):
            return sectionId
        case let .proxySettings(sectionId, _, _):
            return sectionId
        case let .sensitiveContentHeader(sectionId):
            return sectionId
        case let .sensitiveContentToggle(sectionId, _, _):
            return sectionId
        case let .sensitiveContentDesc(sectionId):
            return sectionId
        case let .secretChatWebPreviewHeader(sectionId):
            return sectionId
        case let .secretChatWebPreviewToggle(sectionId, _, _):
            return sectionId
        case let .secretChatWebPreviewDesc(sectionId):
            return sectionId
        case let .section(sectionId):
            return sectionId
        }
    }
    

    var stableId:Int {
        switch self {
        case .blockedPeers:
            return 0
        case .activeSessions:
            return 1
        case .passcode:
            return 2
        case .twoStepVerification:
            return 3
        case .privacyHeader:
            return 4
        case .phoneNumberPrivacy:
            return 5
        case .lastSeenPrivacy:
            return 6
        case .groupPrivacy:
            return 7
        case .voiceCallPrivacy:
            return 8
        case .forwardPrivacy:
            return 9
        case .profilePhotoPrivacy:
            return 10
        case .securityHeader:
            return 11
        case .autoArchiveHeader:
            return 12
        case .autoArchiveToggle:
            return 13
        case .autoArchiveDesc:
            return 14
        case .accountHeader:
            return 15
        case .accountTimeout:
            return 16
        case .accountInfo:
            return 17
        case .webAuthorizationsHeader:
            return 18
        case .webAuthorizations:
            return 19
        case .proxyHeader:
            return 20
        case .proxySettings:
            return 21
        case .togglePeerSuggestions:
            return 22
        case .togglePeerSuggestionsDesc:
            return 23
        case .clearCloudDraftsHeader:
            return 24
        case .clearCloudDrafts:
            return 25
        case .sensitiveContentHeader:
            return 26
        case .sensitiveContentToggle:
            return 27
        case .sensitiveContentDesc:
            return 28
        case .secretChatWebPreviewHeader:
            return 29
        case .secretChatWebPreviewToggle:
            return 30
        case .secretChatWebPreviewDesc:
            return 31
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }


    private var stableIndex:Int {
        switch self {
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        default:
            return (sectionId * 1000) + stableId
        }

    }

    static func <(lhs: PrivacyAndSecurityEntry, rhs: PrivacyAndSecurityEntry) -> Bool {
        return lhs.stableIndex < rhs.stableIndex
    }
    func item(_ arguments: PrivacyAndSecurityControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .privacyHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacySettingsPrivacyHeader, viewType: .textTopItem)
        case let .blockedPeers(_, count, viewType):
            let text: String
            if let count = count, count > 0 {
                text = L10n.privacyAndSecurityBlockedUsers("\(count)")
            } else {
                text = ""
            }
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsBlockedUsers, icon: theme.icons.privacySettings_blocked, type: .nextContext(text), viewType: viewType, action: {
                arguments.openBlockedUsers()
            })
        case let .phoneNumberPrivacy(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsPhoneNumber, type: .nextContext(text), viewType: viewType, action: {
                arguments.openPhoneNumberPrivacy()
            })
        case let .lastSeenPrivacy(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsLastSeen, type: .nextContext(text), viewType: viewType, action: {
                arguments.openLastSeenPrivacy()
            })
        case let .groupPrivacy(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsGroups, type: .nextContext(text), viewType: viewType, action: {
                arguments.openGroupsPrivacy()
            })
        case let .profilePhotoPrivacy(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsProfilePhoto, type: .nextContext(text), viewType: viewType, action: {
                arguments.openProfilePhotoPrivacy()
            })
        case let .forwardPrivacy(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsForwards, type: .nextContext(text), viewType: viewType, action: {
                arguments.openForwardPrivacy()
            })
        case let .voiceCallPrivacy(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsVoiceCalls, type: .nextContext(text), viewType: viewType, action: {
                arguments.openVoiceCallPrivacy()
            })
        case .securityHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacySettingsSecurityHeader, viewType: .textTopItem)
        case let .passcode(_, enabled, viewType):
            let desc = enabled ? L10n.privacyAndSecurityItemOn : L10n.privacyAndSecurityItemOff
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsPasscode, icon: theme.icons.privacySettings_passcode, type: .nextContext(desc), viewType: viewType, action: {
                arguments.openPasscode()
            })
        case let .twoStepVerification(_, configuration, viewType):
            let desc: String 
            if let configuration = configuration {
                switch configuration {
                case .set:
                    desc = L10n.privacyAndSecurityItemOn
                case .notSet:
                    desc = L10n.privacyAndSecurityItemOff
                }
            } else {
                desc = ""
            }
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsTwoStepVerification, icon: theme.icons.privacySettings_twoStep, type: .nextContext(desc), viewType: viewType, action: {
                arguments.openTwoStepVerification(configuration)
            })
        case let .activeSessions(_, sessions, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsActiveSessions, icon: theme.icons.privacySettings_activeSessions, type: .nextContext(sessions != nil ? "\(sessions!.count)" : ""), viewType: viewType, action: {
                arguments.openActiveSessions(sessions)
            })
        case .webAuthorizationsHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacyAndSecurityWebAuthorizationHeader, viewType: .textTopItem)
        case let .webAuthorizations(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.telegramWebSessionsController, viewType: viewType, action: {
                arguments.openWebAuthorizations()
            })
        case .accountHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacySettingsDeleteAccountHeader, viewType: .textTopItem)
        case let .accountTimeout(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsDeleteAccount, type: .context(text), viewType: viewType, action: {
                arguments.setupAccountAutoremove()
            })
        case .accountInfo:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacySettingsDeleteAccountDescription, viewType: .textBottomItem)
        case .proxyHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacySettingsProxyHeader, viewType: .textTopItem)
        case let .proxySettings(_, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacySettingsUseProxy, type: .nextContext(text), viewType: viewType, action: {
                arguments.openProxySettings()
            })
        case let .togglePeerSuggestions(_, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.suggestFrequentContacts, type: .switchable(enabled), viewType: viewType, action: {
                if enabled {
                    confirm(for: mainWindow, information: L10n.suggestFrequentContactsAlert, successHandler: { _ in
                        arguments.togglePeerSuggestions(!enabled)
                    })
                } else {
                    arguments.togglePeerSuggestions(!enabled)
                }
            }, autoswitch: false)
        case .togglePeerSuggestionsDesc:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.suggestFrequentContactsDesc, viewType: .textBottomItem)
        case .clearCloudDraftsHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacyAndSecurityClearCloudDraftsHeader, viewType: .textTopItem)
        case let .clearCloudDrafts(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacyAndSecurityClearCloudDrafts, type: .none, viewType: viewType, action: {
                arguments.clearCloudDrafts()
            })
        case .autoArchiveHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacyAndSecurityAutoArchiveHeader, viewType: .textTopItem)
        case let .autoArchiveToggle(_, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacyAndSecurityAutoArchiveText, type: enabled != nil ? .switchable(enabled!) : .loading, viewType: viewType, action: {
                if let enabled = enabled {
                    arguments.toggleAutoArchive(!enabled)
                } else {
                    arguments.toggleAutoArchive(true)
                }
            }, autoswitch: true)
        case .autoArchiveDesc:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacyAndSecurityAutoArchiveDesc, viewType: .textBottomItem)
        case .sensitiveContentHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacyAndSecuritySensitiveHeader, viewType: .textTopItem)
        case let .sensitiveContentToggle(_, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacyAndSecuritySensitiveText, type: enabled != nil ? .switchable(enabled!) : .loading, viewType: viewType, action: {
                if let enabled = enabled {
                    arguments.toggleSensitiveContent(!enabled)
                }
            }, autoswitch: true)
        case .sensitiveContentDesc:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacyAndSecuritySensitiveDesc, viewType: .textBottomItem)
        case .secretChatWebPreviewHeader:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacyAndSecuritySecretChatWebPreviewHeader, viewType: .textTopItem)
        case let .secretChatWebPreviewToggle(_, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.privacyAndSecuritySecretChatWebPreviewText, type: enabled != nil ? .switchable(enabled!) : .loading, viewType: viewType, action: {
                if let enabled = enabled {
                    arguments.toggleSecretChatWebPreview(!enabled)
                }
            }, autoswitch: true)
        case .secretChatWebPreviewDesc:
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.privacyAndSecuritySecretChatWebPreviewDesc, viewType: .textBottomItem)
        case .section:
            return GeneralRowItem(initialSize, height: 30, stableId: stableId, viewType: .separator)
        }
    }
}

func countForSelectivePeers(_ peers: [PeerId: SelectivePrivacyPeer]) -> Int {
    var result = 0
    for (_, peer) in peers {
        result += peer.userCount
    }
    return result
}


private func stringForSelectiveSettings(settings: SelectivePrivacySettings) -> String {
    switch settings {
    case let .disableEveryone(enableFor):
        if enableFor.isEmpty {
            return L10n.privacySettingsControllerNobody
        } else {
            return L10n.privacySettingsLastSeenNobodyPlus("\(countForSelectivePeers(enableFor))")
        }
    case let .enableEveryone(disableFor):
        if disableFor.isEmpty {
            return L10n.privacySettingsControllerEverbody
        } else {
            return L10n.privacySettingsLastSeenEverybodyMinus("\(countForSelectivePeers(disableFor))")
        }
    case let .enableContacts(enableFor, disableFor):
        if !enableFor.isEmpty && !disableFor.isEmpty {
            return L10n.privacySettingsLastSeenContactsMinusPlus("\(countForSelectivePeers(disableFor))", "\(countForSelectivePeers(enableFor))")
        } else if !enableFor.isEmpty {
            return L10n.privacySettingsLastSeenContactsPlus("\(countForSelectivePeers(enableFor))")
        } else if !disableFor.isEmpty {
            return L10n.privacySettingsLastSeenContactsMinus("\(countForSelectivePeers(disableFor))")
        } else {
            return L10n.privacySettingsControllerMyContacts
        }
    }
}

private struct PrivacyAndSecurityControllerState: Equatable {
    let updatingAccountTimeoutValue: Int32?

    init() {
        self.updatingAccountTimeoutValue = nil
    }

    init(updatingAccountTimeoutValue: Int32?) {
        self.updatingAccountTimeoutValue = updatingAccountTimeoutValue
    }

    static func ==(lhs: PrivacyAndSecurityControllerState, rhs: PrivacyAndSecurityControllerState) -> Bool {
        if lhs.updatingAccountTimeoutValue != rhs.updatingAccountTimeoutValue {
            return false
        }

        return true
    }

    func withUpdatedUpdatingAccountTimeoutValue(_ updatingAccountTimeoutValue: Int32?) -> PrivacyAndSecurityControllerState {
        return PrivacyAndSecurityControllerState(updatingAccountTimeoutValue: updatingAccountTimeoutValue)
    }
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<PrivacyAndSecurityEntry>], right: [AppearanceWrapperEntry<PrivacyAndSecurityEntry>], initialSize:NSSize, arguments:PrivacyAndSecurityControllerArguments) -> TableUpdateTransition {

    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }

    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

private func privacyAndSecurityControllerEntries(state: PrivacyAndSecurityControllerState, contentConfiguration: ContentSettingsConfiguration?, privacySettings: AccountPrivacySettings?, webSessions: ([WebAuthorization], [PeerId : Peer])?, blockedState: BlockedPeersContextState, proxy: ProxySettings, recentPeers: RecentPeers, configuration: TwoStepVeriticationAccessConfiguration?, activeSessions: [RecentAccountSession]?, passcodeData: PostboxAccessChallengeData, context: AccountContext) -> [PrivacyAndSecurityEntry] {
    var entries: [PrivacyAndSecurityEntry] = []

    var sectionId:Int = 1
    entries.append(.section(sectionId: sectionId))
    sectionId += 1

    entries.append(.blockedPeers(sectionId: sectionId, blockedState.totalCount, viewType: .firstItem))
   // entries.append(.activeSessions(sectionId: sectionId, activeSessions, viewType: .innerItem))
    
    let hasPasscode: Bool
    switch passcodeData {
    case .none:
        hasPasscode = false
    default:
        hasPasscode = context.sharedContext.appEncryptionValue.hasPasscode()
    }
    
    entries.append(.passcode(sectionId: sectionId, enabled: hasPasscode, viewType: .innerItem))
    entries.append(.twoStepVerification(sectionId: sectionId, configuration: configuration, viewType: .lastItem))

    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    entries.append(.privacyHeader(sectionId: sectionId))
    if let privacySettings = privacySettings {
        entries.append(.phoneNumberPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.phoneNumber), viewType: .firstItem))
        entries.append(.lastSeenPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.presence), viewType: .innerItem))
        entries.append(.groupPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.groupInvitations), viewType: .innerItem))
        entries.append(.voiceCallPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.voiceCalls), viewType: .innerItem))
        entries.append(.profilePhotoPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.profilePhoto), viewType: .innerItem))
        entries.append(.forwardPrivacy(sectionId: sectionId, stringForSelectiveSettings(settings: privacySettings.forwards), viewType: .lastItem))
    } else {
        entries.append(.phoneNumberPrivacy(sectionId: sectionId, "", viewType: .firstItem))
        entries.append(.lastSeenPrivacy(sectionId: sectionId, "", viewType: .innerItem))
        entries.append(.groupPrivacy(sectionId: sectionId, "", viewType: .innerItem))
        entries.append(.voiceCallPrivacy(sectionId: sectionId, "", viewType: .innerItem))
        entries.append(.profilePhotoPrivacy(sectionId: sectionId, "", viewType: .innerItem))
        entries.append(.forwardPrivacy(sectionId: sectionId, "", viewType: .lastItem))
    }


    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    
    let autoarchiveConfiguration = AutoarchiveConfiguration.with(appConfiguration: context.appConfiguration)

    
    if autoarchiveConfiguration.autoarchive_setting_available {
        entries.append(.autoArchiveHeader(sectionId: sectionId))
        entries.append(.autoArchiveToggle(sectionId: sectionId, value: privacySettings?.automaticallyArchiveAndMuteNonContacts, viewType: .singleItem))
        entries.append(.autoArchiveDesc(sectionId: sectionId))
        
        entries.append(.section(sectionId: sectionId))
        sectionId += 1
    }

    entries.append(.accountHeader(sectionId: sectionId))


    if let privacySettings = privacySettings {
        let value: Int32
        if let updatingAccountTimeoutValue = state.updatingAccountTimeoutValue {
            value = updatingAccountTimeoutValue
        } else {
            value = privacySettings.accountRemovalTimeout
        }
        entries.append(.accountTimeout(sectionId: sectionId, timeIntervalString(Int(value)), viewType: .singleItem))

    } else {
        entries.append(.accountTimeout(sectionId: sectionId, "", viewType: .singleItem))
    }
    entries.append(.accountInfo(sectionId: sectionId))


    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    if let contentConfiguration = contentConfiguration, contentConfiguration.canAdjustSensitiveContent {
        #if !APP_STORE
        entries.append(.sensitiveContentHeader(sectionId: sectionId))
        entries.append(.sensitiveContentToggle(sectionId: sectionId, value: contentConfiguration.sensitiveContentEnabled, viewType: .singleItem))
        entries.append(.sensitiveContentDesc(sectionId: sectionId))
        
        entries.append(.section(sectionId: sectionId))
        sectionId += 1
        #endif
    }
    

    let enabled: Bool
    switch recentPeers {
    case .disabled:
        enabled = false
    case .peers:
        enabled = true
    }

    entries.append(.togglePeerSuggestions(sectionId: sectionId, enabled: enabled, viewType: .singleItem))
    entries.append(.togglePeerSuggestionsDesc(sectionId: sectionId))

    entries.append(.section(sectionId: sectionId))
    sectionId += 1

    entries.append(.clearCloudDraftsHeader(sectionId: sectionId))
    entries.append(.clearCloudDrafts(sectionId: sectionId, viewType: .singleItem))

    entries.append(.section(sectionId: sectionId))
    sectionId += 1

    if let webSessions = webSessions, !webSessions.0.isEmpty {
        entries.append(.webAuthorizationsHeader(sectionId: sectionId))
        entries.append(.webAuthorizations(sectionId: sectionId, viewType: .singleItem))
        
        if FastSettings.isSecretChatWebPreviewAvailable(for: context.account.id.int64) != nil {
            entries.append(.section(sectionId: sectionId))
            sectionId += 1
        }
    }
    
    if let value = FastSettings.isSecretChatWebPreviewAvailable(for: context.account.id.int64) {
        entries.append(.secretChatWebPreviewHeader(sectionId: sectionId))
        entries.append(.secretChatWebPreviewToggle(sectionId: sectionId, value: value, viewType: .singleItem))
        entries.append(.secretChatWebPreviewDesc(sectionId: sectionId))
    }

    entries.append(.section(sectionId: sectionId))
    sectionId += 1

    return entries
}





class PrivacyAndSecurityViewController: TableViewController {
    private let privacySettingsPromise = Promise<(AccountPrivacySettings?, ([WebAuthorization], [PeerId : Peer])?)>()


    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        twoStepAccessConfiguration.set(twoStepVerificationConfiguration(account: context.account) |> map { TwoStepVeriticationAccessConfiguration(configuration: $0, password: nil)})
        activeSessions.set(requestRecentAccountSessions(account: context.account) |> map(Optional.init))
    }

    private let twoStepAccessConfiguration: Promise<TwoStepVeriticationAccessConfiguration?> = Promise(nil)
    private let activeSessions: Promise<[RecentAccountSession]?> = Promise(nil)

    override func viewDidLoad() {
        super.viewDidLoad()

        
        
        let statePromise = ValuePromise(PrivacyAndSecurityControllerState(), ignoreRepeated: true)
        let stateValue = Atomic(value: PrivacyAndSecurityControllerState())
        let updateState: ((PrivacyAndSecurityControllerState) -> PrivacyAndSecurityControllerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }

        let actionsDisposable = DisposableSet()
        let context = self.context

        let pushControllerImpl: (ViewController) -> Void = { [weak self] c in
            self?.navigationController?.push(c)
        }


        let settings:Signal<ProxySettings, NoError> = proxySettings(accountManager: context.sharedContext.accountManager)

        let currentInfoDisposable = MetaDisposable()
        actionsDisposable.add(currentInfoDisposable)

        let updateAccountTimeoutDisposable = MetaDisposable()
        actionsDisposable.add(updateAccountTimeoutDisposable)

        let privacySettingsPromise = self.privacySettingsPromise

        let arguments = PrivacyAndSecurityControllerArguments(context: context, openBlockedUsers: { [weak self] in
            if let context = self?.context {
                pushControllerImpl(BlockedPeersViewController(context))
            }
        }, openLastSeenPrivacy: {
            let signal = privacySettingsPromise.get()
                |> take(1)
                |> deliverOnMainQueue
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info, _ in
                if let info = info {
                    pushControllerImpl(SelectivePrivacySettingsController(context, kind: .presence, current: info.presence, callSettings: nil, phoneDiscoveryEnabled: nil, updated: { updated, _, _ in
                        if let currentInfoDisposable = currentInfoDisposable {
                            let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                                |> filter { $0.0 != nil }
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { value, sessions -> Signal<Void, NoError> in
                                    if let value = value {
                                        privacySettingsPromise.set(.single((AccountPrivacySettings(presence: updated, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, automaticallyArchiveAndMuteNonContacts: value.automaticallyArchiveAndMuteNonContacts, accountRemovalTimeout: value.accountRemovalTimeout), sessions)))
                                    }
                                    return .complete()
                            }
                            currentInfoDisposable.set(applySetting.start())
                        }
                    }))
                }
            }))
        }, openGroupsPrivacy: {
            let signal = privacySettingsPromise.get()
                |> take(1)
                |> deliverOnMainQueue
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info, _ in
                if let info = info {
                    pushControllerImpl(SelectivePrivacySettingsController(context, kind: .groupInvitations, current: info.groupInvitations, callSettings: nil, phoneDiscoveryEnabled: nil, updated: { updated, _, _ in
                        if let currentInfoDisposable = currentInfoDisposable {
                            let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                                |> filter { $0.0 != nil }
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { value, sessions -> Signal<Void, NoError> in
                                    if let value = value {
                                        privacySettingsPromise.set(.single((AccountPrivacySettings(presence: value.presence, groupInvitations: updated, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, automaticallyArchiveAndMuteNonContacts: value.automaticallyArchiveAndMuteNonContacts, accountRemovalTimeout: value.accountRemovalTimeout), sessions)))
                                    }
                                    return .complete()
                            }
                            currentInfoDisposable.set(applySetting.start())
                        }
                    }))
                }
            }))
        }, openVoiceCallPrivacy: {
            let signal = privacySettingsPromise.get()
                |> take(1)
                |> deliverOnMainQueue
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info, _ in
                if let info = info {
                    pushControllerImpl(SelectivePrivacySettingsController(context, kind: .voiceCalls, current: info.voiceCalls, callSettings: info.voiceCallsP2P, phoneDiscoveryEnabled: nil, updated: { updated, p2pUpdated, _ in
                        if let currentInfoDisposable = currentInfoDisposable {
                            let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                                |> filter { $0.0 != nil }
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { value, sessions -> Signal<Void, NoError> in
                                    if let value = value {
                                        privacySettingsPromise.set(.single((AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: updated, voiceCallsP2P: p2pUpdated ?? value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, automaticallyArchiveAndMuteNonContacts: value.automaticallyArchiveAndMuteNonContacts, accountRemovalTimeout: value.accountRemovalTimeout), sessions)))
                                    }
                                    return .complete()
                            }
                            currentInfoDisposable.set(applySetting.start())
                        }
                    }))
                }
            }))
        }, openProfilePhotoPrivacy: {
            let signal = privacySettingsPromise.get()
                |> take(1)
                |> deliverOnMainQueue
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info, _ in
                if let info = info {
                    pushControllerImpl(SelectivePrivacySettingsController(context, kind: .profilePhoto, current: info.profilePhoto, phoneDiscoveryEnabled: nil, updated: { updated, _, _ in
                        if let currentInfoDisposable = currentInfoDisposable {
                            let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                                |> filter { $0.0 != nil }
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { value, sessions -> Signal<Void, NoError> in
                                    if let value = value {
                                        privacySettingsPromise.set(.single((AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: updated, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, automaticallyArchiveAndMuteNonContacts: value.automaticallyArchiveAndMuteNonContacts, accountRemovalTimeout: value.accountRemovalTimeout), sessions)))
                                    }
                                    return .complete()
                            }
                            currentInfoDisposable.set(applySetting.start())
                        }
                    }))
                }
            }))
        }, openForwardPrivacy: {
            let signal = privacySettingsPromise.get()
                |> take(1)
                |> deliverOnMainQueue
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info, _ in
                if let info = info {
                    pushControllerImpl(SelectivePrivacySettingsController(context, kind: .forwards, current: info.forwards, phoneDiscoveryEnabled: nil, updated: { updated, _, _ in
                        if let currentInfoDisposable = currentInfoDisposable {
                            let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                                |> filter { $0.0 != nil }
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { value, sessions -> Signal<Void, NoError> in
                                    if let value = value {
                                        privacySettingsPromise.set(.single((AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: updated, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, automaticallyArchiveAndMuteNonContacts: value.automaticallyArchiveAndMuteNonContacts, accountRemovalTimeout: value.accountRemovalTimeout), sessions)))
                                    }
                                    return .complete()
                            }
                            currentInfoDisposable.set(applySetting.start())
                        }
                    }))
                }
            }))
        }, openPhoneNumberPrivacy: {
            let signal = privacySettingsPromise.get()
                |> take(1)
                |> deliverOnMainQueue
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] info, _ in
                if let info = info {
                    pushControllerImpl(SelectivePrivacySettingsController(context, kind: .phoneNumber, current: info.phoneNumber, phoneDiscoveryEnabled: info.phoneDiscoveryEnabled, updated: { updated, _, phoneDiscoveryEnabled in
                        if let currentInfoDisposable = currentInfoDisposable {
                            let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                                |> filter { $0.0 != nil }
                                |> take(1)
                                |> deliverOnMainQueue
                                |> mapToSignal { value, sessions -> Signal<Void, NoError> in
                                    if let value = value {
                                        privacySettingsPromise.set(.single((AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: updated, phoneDiscoveryEnabled: phoneDiscoveryEnabled!, automaticallyArchiveAndMuteNonContacts: value.automaticallyArchiveAndMuteNonContacts, accountRemovalTimeout: value.accountRemovalTimeout), sessions)))
                                    }
                                    return .complete()
                            }
                            currentInfoDisposable.set(applySetting.start())
                        }
                    }))
                }
            }))
        }, openPasscode: { [weak self] in
            if let context = self?.context {
                self?.navigationController?.push(PasscodeSettingsViewController(context))
            }
        }, openTwoStepVerification: { [weak self] configuration in
            if let context = self?.context, let `self` = self {
                self.navigationController?.push(twoStepVerificationUnlockController(context: context, mode: .access(configuration), presentController: { [weak self] controller, isRoot, animated in
                    guard let `self` = self, let navigation = self.navigationController else {return}
                    if isRoot {
                        navigation.removeUntil(PrivacyAndSecurityViewController.self)
                    }

                    if !animated {
                        navigation.stackInsert(controller, at: navigation.stackCount)
                    } else {
                        navigation.push(controller)
                    }
                }))
            }
        }, openActiveSessions: { [weak self] sessions in
            if let context = self?.context {
                self?.navigationController?.push(RecentSessionsController(context))
            }
        }, openWebAuthorizations: {

            let signal = privacySettingsPromise.get()
                |> take(1)
                |> deliverOnMainQueue
            currentInfoDisposable.set(signal.start(next: { [weak currentInfoDisposable] _, sessions in
                pushControllerImpl(WebSessionsController(context, sessions, updated: { updated in
                    if let currentInfoDisposable = currentInfoDisposable {
                        let applySetting: Signal<Void, NoError> = privacySettingsPromise.get()
                            |> take(1)
                            |> deliverOnMainQueue
                            |> mapToSignal { privacy, _ -> Signal<Void, NoError> in
                                privacySettingsPromise.set(.single((privacy, updated)))
                                return .complete()
                        }
                        currentInfoDisposable.set(applySetting.start())
                    }
                }))
            }))

        }, setupAccountAutoremove: { [weak self] in

            if let strongSelf = self {

                let signal = privacySettingsPromise.get()
                    |> take(1)
                    |> deliverOnMainQueue
                updateAccountTimeoutDisposable.set(signal.start(next: { [weak updateAccountTimeoutDisposable, weak strongSelf] privacySettingsValue, _ in
                    if let _ = privacySettingsValue, let strongSelf = strongSelf {

                        let timeoutAction: (Int32) -> Void = { timeout in
                            if let updateAccountTimeoutDisposable = updateAccountTimeoutDisposable {
                                updateState {
                                    return $0.withUpdatedUpdatingAccountTimeoutValue(timeout)
                                }
                                let applyTimeout: Signal<Void, NoError> = privacySettingsPromise.get()
                                    |> filter { $0.0 != nil }
                                    |> take(1)
                                    |> deliverOnMainQueue
                                    |> mapToSignal { value, sessions -> Signal<Void, NoError> in
                                        if let value = value {
                                            privacySettingsPromise.set(.single((AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, automaticallyArchiveAndMuteNonContacts: value.automaticallyArchiveAndMuteNonContacts, accountRemovalTimeout: timeout), sessions)))
                                        }
                                        return .complete()
                                }
                                updateAccountTimeoutDisposable.set((updateAccountRemovalTimeout(account: context.account, timeout: timeout)
                                    |> then(applyTimeout)
                                    |> deliverOnMainQueue).start(completed: {
//                                        updateState {
//                                            return $0.withUpdatedUpdatingAccountTimeoutValue(nil)
//                                        }
                                    }))
                            }
                        }
                        let timeoutValues: [Int32] = [
                            1 * 30 * 24 * 60 * 60,
                            3 * 30 * 24 * 60 * 60,
                            180 * 24 * 60 * 60,
                            365 * 24 * 60 * 60
                        ]
                        var items: [SPopoverItem] = []

                        items.append(SPopoverItem(tr(L10n.timerMonthsCountable(1)), {
                            timeoutAction(timeoutValues[0])
                        }))
                        items.append(SPopoverItem(tr(L10n.timerMonthsCountable(3)), {
                            timeoutAction(timeoutValues[1])
                        }))
                        items.append(SPopoverItem(tr(L10n.timerMonthsCountable(6)), {
                            timeoutAction(timeoutValues[2])
                        }))
                        items.append(SPopoverItem(tr(L10n.timerYearsCountable(1)), {
                            timeoutAction(timeoutValues[3])
                        }))

                        if let index = strongSelf.genericView.index(hash: PrivacyAndSecurityEntry.accountTimeout(sectionId: 0, "", viewType: .singleItem).stableId) {
                            if let view = (strongSelf.genericView.viewNecessary(at: index) as? GeneralInteractedRowView)?.textView {
                                showPopover(for: view, with: SPopoverViewController(items: items))
                            }
                        }
                    }
                }))


            }

        }, openProxySettings: { [weak self] in
            if let context = self?.context {

                let controller = proxyListController(accountManager: context.sharedContext.accountManager, network: context.account.network, share: { servers in
                    var message: String = ""
                    for server in servers {
                        message += server.link + "\n\n"
                    }
                    message = message.trimmed

                    showModal(with: ShareModalController(ShareLinkObject(context, link: message)), for: mainWindow)
                }, pushController: { controller in
                    pushControllerImpl(controller)
                })
                pushControllerImpl(controller)
            }
        }, togglePeerSuggestions: { enabled in
            _ = (updateRecentPeersEnabled(postbox: context.account.postbox, network: context.account.network, enabled: enabled) |> then(enabled ? managedUpdatedRecentPeers(accountPeerId: context.account.peerId, postbox: context.account.postbox, network: context.account.network) : Signal<Void, NoError>.complete())).start()
        }, clearCloudDrafts: {
            confirm(for: context.window, information: L10n.privacyAndSecurityConfirmClearCloudDrafts, successHandler: { _ in
                _ = showModalProgress(signal: clearCloudDraftsInteractively(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId), for: context.window).start()
            })
        }, toggleSensitiveContent: { value in
            _ = updateRemoteContentSettingsConfiguration(postbox: context.account.postbox, network: context.account.network, sensitiveContentEnabled: value).start()
        }, toggleSecretChatWebPreview: { value in
            FastSettings.setSecretChatWebPreviewAvailable(for: context.account.id.int64, value: value)
        }, toggleAutoArchive: { value in
            _ = showModalProgress(signal: updateAccountAutoArchiveChats(account: context.account, value: value), for: context.window).start()
        })


        let previous:Atomic<[AppearanceWrapperEntry<PrivacyAndSecurityEntry>]> = Atomic(value: [])
        let initialSize = self.atomicSize

        let contentConfiguration: Signal<ContentSettingsConfiguration?, NoError> = .single(nil) |> then(contentSettingsConfiguration(network: context.account.network) |> map(Optional.init))

        
        let signal = combineLatest(queue: .mainQueue(), statePromise.get(), contentConfiguration, appearanceSignal, settings, privacySettingsPromise.get(), combineLatest(queue: .mainQueue(), recentPeers(account: context.account), twoStepAccessConfiguration.get(), activeSessions.get(), context.sharedContext.accountManager.accessChallengeData()), context.blockedPeersContext.state)
        |> map { state, contentConfiguration, appearance, proxy, values, additional, blockedState -> TableUpdateTransition in
            let entries = privacyAndSecurityControllerEntries(state: state, contentConfiguration: contentConfiguration, privacySettings: values.0, webSessions: values.1, blockedState: blockedState, proxy: proxy, recentPeers: additional.0, configuration: additional.1, activeSessions: additional.2, passcodeData: additional.3.data, context: context).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify {$0}, arguments: arguments)
        } |> afterDisposed {
            actionsDisposable.dispose()
        } |> deliverOnMainQueue
        
        disposable.set(signal.start(next: { [weak self] transition in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
            if let focusOnItemTag = self?.focusOnItemTag {
                self?.genericView.scroll(to: .center(id: focusOnItemTag.stableId, innerId: nil, animated: true, focus: .init(focus: true), inset: 0), inset: NSEdgeInsets())
                self?.focusOnItemTag = nil
            }
        }))
        
    }
    
    deinit {
        disposable.dispose()
    }
    
    private var focusOnItemTag: PrivacyAndSecurityEntryTag?
    private let disposable = MetaDisposable()
    init(_ context: AccountContext, initialSettings: (AccountPrivacySettings?, ([WebAuthorization], [PeerId : Peer])?), focusOnItemTag: PrivacyAndSecurityEntryTag? = nil) {
        self.focusOnItemTag = focusOnItemTag
        super.init(context)
        
        let thenSignal:Signal<(AccountPrivacySettings?, ([WebAuthorization], [PeerId : Peer])?), NoError> = requestAccountPrivacySettings(account: context.account) |> map {
            return ($0, initialSettings.1)
        }
        
        self.privacySettingsPromise.set(.single(initialSettings) |> then(thenSignal))
    }
}

