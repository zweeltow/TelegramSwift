//
//  ChannelAdminController.swift
//  Telegram
//
//  Created by keepcoder on 06/06/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit

private final class ChannelAdminControllerArguments {
    let context: AccountContext
    let toggleRight: (TelegramChatAdminRightsFlags, TelegramChatAdminRightsFlags) -> Void
    let dismissAdmin: () -> Void
    let cantEditError: () -> Void
    let transferOwnership:()->Void
    let updateRank:(String)->Void
    init(context: AccountContext, toggleRight: @escaping (TelegramChatAdminRightsFlags, TelegramChatAdminRightsFlags) -> Void, dismissAdmin: @escaping () -> Void, cantEditError: @escaping() -> Void, transferOwnership: @escaping()->Void, updateRank: @escaping(String)->Void) {
        self.context = context
        self.toggleRight = toggleRight
        self.dismissAdmin = dismissAdmin
        self.cantEditError = cantEditError
        self.transferOwnership = transferOwnership
        self.updateRank = updateRank
    }
}

private enum ChannelAdminEntryStableId: Hashable {
    case info
    case right(TelegramChatAdminRightsFlags)
    case description(Int32)
    case changeOwnership
    case section(Int32)
    case roleHeader
    case role
    case roleDesc
    case dismiss
    var hashValue: Int {
        return 0
    }

}

private enum ChannelAdminEntry: TableItemListNodeEntry {
    case info(Int32, Peer, TelegramUserPresence?, GeneralViewType)
    case rightItem(Int32, Int, String, TelegramChatAdminRightsFlags, TelegramChatAdminRightsFlags, Bool, Bool, GeneralViewType)
    case roleHeader(Int32, GeneralViewType)
    case roleDesc(Int32, GeneralViewType)
    case role(Int32, String, String, GeneralViewType)
    case description(Int32, Int32, String, GeneralViewType)
    case changeOwnership(Int32, Int32, String, GeneralViewType)
    case dismiss(Int32, Int32, String, GeneralViewType)
    case section(Int32)
    
    
    var stableId: ChannelAdminEntryStableId {
        switch self {
        case .info:
            return .info
        case let .rightItem(_, _, _, right, _, _, _, _):
            return .right(right)
        case .description(_, let index, _, _):
            return .description(index)
        case .changeOwnership:
            return .changeOwnership
        case .dismiss:
            return .dismiss
        case .roleHeader:
            return .roleHeader
        case .roleDesc:
            return .roleDesc
        case .role:
            return .role
        case .section(let sectionId):
            return .section(sectionId)
        }
    }
    
    static func ==(lhs: ChannelAdminEntry, rhs: ChannelAdminEntry) -> Bool {
        switch lhs {
        case let .info(sectionId, lhsPeer, presence, viewType):
            if case .info(sectionId, let rhsPeer, presence, viewType) = rhs {
                if !arePeersEqual(lhsPeer, rhsPeer) {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .rightItem(sectionId, index, text, right, flags, value, enabled, viewType):
            if case .rightItem(sectionId, index, text, right, flags, value, enabled, viewType) = rhs {
                return true
            } else {
                return false
            }
        case let .description(sectionId, index, text, viewType):
            if case .description(sectionId, index, text, viewType) = rhs{
                return true
            } else {
                return false
            }
        case let .changeOwnership(sectionId, index, text, viewType):
            if case .changeOwnership(sectionId, index, text, viewType) = rhs{
                return true
            } else {
                return false
            }
            case let .dismiss(sectionId, index, text, viewType):
            if case .dismiss(sectionId, index, text, viewType) = rhs{
                return true
            } else {
                return false
            }
        case let .roleHeader(section, viewType):
            if case .roleHeader(section, viewType) = rhs {
                return true
            } else {
                return false
            }
        case let .roleDesc(section, viewType):
            if case .roleDesc(section, viewType) = rhs {
                return true
            } else {
                return false
            }
        case let .role(section, text, placeholder, viewType):
            if case .role(section, text, placeholder, viewType) = rhs {
                return true
            } else {
                return false
            }
        case let .section(sectionId):
            if case .section(sectionId) = rhs {
                return true
            } else {
                return false
            }
        }
    }

    var index:Int32 {
        switch self {
        case .info(let sectionId, _, _, _):
            return (sectionId * 1000) + 0
        case .description(let sectionId, let index, _, _):
            return (sectionId * 1000) + index
        case let .changeOwnership(sectionId, index, _, _):
            return (sectionId * 1000) + index
            case let .dismiss(sectionId, index, _, _):
            return (sectionId * 1000) + index
        case .rightItem(let sectionId, let index, _, _, _, _, _, _):
            return (sectionId * 1000) + Int32(index) + 10
        case let .roleHeader(sectionId, _):
             return (sectionId * 1000)
        case let .role(sectionId, _, _, _):
            return (sectionId * 1000) + 1
        case let .roleDesc(sectionId, _):
            return (sectionId * 1000) + 2
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    static func <(lhs: ChannelAdminEntry, rhs: ChannelAdminEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(_ arguments: ChannelAdminControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .section:
            return GeneralRowItem(initialSize, height: 30, stableId: stableId, viewType: .separator)
        case let .info(_, peer, presence, viewType):
            var string:String = peer.isBot ? L10n.presenceBot : L10n.peerStatusRecently
            var color:NSColor = theme.colors.grayText
            if let presence = presence, !peer.isBot {
                let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                (string, _, color) = stringAndActivityForUserPresence(presence, timeDifference: arguments.context.timeDifference, relativeTo: Int32(timestamp))
            }
            return ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, stableId: stableId, enabled: true, height: 60, photoSize: NSMakeSize(40, 40), statusStyle: ControlStyle(font: .normal(.title), foregroundColor: color), status: string, inset: NSEdgeInsets(left: 30, right: 30), viewType: viewType, action: {})
        case let .rightItem(_, _, name, right, flags, value, enabled, viewType):
            //ControlStyle(font: NSFont.)
            
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: name, nameStyle: ControlStyle(font: .normal(.title), foregroundColor: enabled ? theme.colors.text : theme.colors.grayText), type: .switchable(value), viewType: viewType, action: {
                arguments.toggleRight(right, flags)
            }, enabled: enabled, switchAppearance: SwitchViewAppearance(backgroundColor: theme.colors.background, stateOnColor: enabled ? theme.colors.accent : theme.colors.accent.withAlphaComponent(0.6), stateOffColor: enabled ? theme.colors.redUI : theme.colors.redUI.withAlphaComponent(0.6), disabledColor: .grayBackground, borderColor: .clear), disabledAction: {
                arguments.cantEditError()
            })
        case let .changeOwnership(_, _, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, nameStyle: blueActionButton, type: .next, viewType: viewType, action: arguments.transferOwnership)
        case let .dismiss(_, _, text, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: text, nameStyle: redActionButton, type: .next, viewType: viewType, action: arguments.dismissAdmin)
        case let .roleHeader(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: L10n.channelAdminRoleHeader, viewType: viewType)
        case let .role(_, text, placeholder, viewType):
            return InputDataRowItem(initialSize, stableId: stableId, mode: .plain, error: nil, viewType: viewType, currentText: text, placeholder: nil, inputPlaceholder: placeholder, filter: { text in
                let filtered = text.filter { character -> Bool in
                    return !String(character).containsOnlyEmoji
                }
                return filtered
            }, updated: arguments.updateRank, limit: 16)
        case let .roleDesc(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: "", viewType: viewType)
        case let .description(_, _, name, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: name, viewType: viewType)
        }
        //return TableRowItem(initialSize)
    }
}

private struct ChannelAdminControllerState: Equatable {
    let updatedFlags: TelegramChatAdminRightsFlags?
    let updating: Bool
    let editable:Bool
    let rank:String?
    let initialRank:String?
    init(updatedFlags: TelegramChatAdminRightsFlags? = nil, updating: Bool = false, editable: Bool = false, rank: String?, initialRank: String?) {
        self.updatedFlags = updatedFlags
        self.updating = updating
        self.editable = editable
        self.rank = rank
        self.initialRank = initialRank
    }
    
    func withUpdatedUpdatedFlags(_ updatedFlags: TelegramChatAdminRightsFlags?) -> ChannelAdminControllerState {
        return ChannelAdminControllerState(updatedFlags: updatedFlags, updating: self.updating, editable: self.editable, rank: self.rank, initialRank: self.initialRank)
    }
    
    func withUpdatedEditable(_ editable:Bool) -> ChannelAdminControllerState {
        return ChannelAdminControllerState(updatedFlags: updatedFlags, updating: self.updating, editable: editable, rank: self.rank, initialRank: self.initialRank)
    }
    
    func withUpdatedUpdating(_ updating: Bool) -> ChannelAdminControllerState {
        return ChannelAdminControllerState(updatedFlags: self.updatedFlags, updating: updating, editable: self.editable, rank: self.rank, initialRank: self.initialRank)
    }
    
    func withUpdatedRank(_ rank: String?) -> ChannelAdminControllerState {
        return ChannelAdminControllerState(updatedFlags: self.updatedFlags, updating: updating, editable: self.editable, rank: rank, initialRank: self.initialRank)
    }
}

private func stringForRight(right: TelegramChatAdminRightsFlags, isGroup: Bool, defaultBannedRights: TelegramChatBannedRights?) -> String {
    if right.contains(.canChangeInfo) {
        return isGroup ? L10n.groupEditAdminPermissionChangeInfo : L10n.channelEditAdminPermissionChangeInfo
    } else if right.contains(.canPostMessages) {
        return L10n.channelEditAdminPermissionPostMessages
    } else if right.contains(.canEditMessages) {
        return L10n.channelEditAdminPermissionEditMessages
    } else if right.contains(.canDeleteMessages) {
        return L10n.channelEditAdminPermissionDeleteMessages
    } else if right.contains(.canBanUsers) {
        return L10n.channelEditAdminPermissionBanUsers
    } else if right.contains(.canInviteUsers) {
        if isGroup {
            if let defaultBannedRights = defaultBannedRights, defaultBannedRights.flags.contains(.banAddMembers) {
                return L10n.channelEditAdminPermissionInviteMembers
            } else {
                return L10n.channelEditAdminPermissionInviteViaLink
            }
        } else {
            return L10n.channelEditAdminPermissionInviteSubscribers
        }

    } else if right.contains(.canPinMessages) {
        return L10n.channelEditAdminPermissionPinMessages
    } else if right.contains(.canAddAdmins) {
        return L10n.channelEditAdminPermissionAddNewAdmins
    } else if right.contains(.canBeAnonymous) {
        return L10n.channelEditAdminPermissionAnonymous
    } else if right.contains(.canManageCalls) {
        return L10n.channelEditAdminManageCalls
    } else {
        return ""
    }
}

private func rightDependencies(_ right: TelegramChatAdminRightsFlags) -> [TelegramChatAdminRightsFlags] {
    if right.contains(.canChangeInfo) {
        return []
    } else if right.contains(.canPostMessages) {
        return []
    } else if right.contains(.canEditMessages) {
        return []
    } else if right.contains(.canDeleteMessages) {
        return []
    } else if right.contains(.canBanUsers) {
        return []
    } else if right.contains(.canInviteUsers) {
        return []
    } else if right.contains(.canPinMessages) {
        return []
    } else if right.contains(.canAddAdmins) {
        return []
    } else {
        return []
    }
}

private func canEditAdminRights(accountPeerId: PeerId, channelView: PeerView, initialParticipant: ChannelParticipant?) -> Bool {
    if let channel = channelView.peers[channelView.peerId] as? TelegramChannel {
        if channel.flags.contains(.isCreator) {
            return true
        } else if let initialParticipant = initialParticipant {
            switch initialParticipant {
            case .creator:
                return false
            case let .member(_, _, adminInfo, _, _):
                if let adminInfo = adminInfo {
                    return adminInfo.canBeEditedByAccountPeer || adminInfo.promotedBy == accountPeerId
                } else {
                    return channel.hasPermission(.addAdmins)
                }
            }
        } else {
            return channel.hasPermission(.addAdmins)
        }
    } else if let group = channelView.peers[channelView.peerId] as? TelegramGroup {
        if case .creator = group.role {
            return true
        } else {
            return false
        }
    } else {
        return false
    }
}


private func channelAdminControllerEntries(state: ChannelAdminControllerState, accountPeerId: PeerId, channelView: PeerView, adminView: PeerView, initialParticipant: ChannelParticipant?) -> [ChannelAdminEntry] {
    var entries: [ChannelAdminEntry] = []
    
    var sectionId:Int32 = 1
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    var descId: Int32 = 0
    
    var addAdminsEnabled: Bool = false
    if let channel = channelView.peers[channelView.peerId] as? TelegramChannel, let admin = adminView.peers[adminView.peerId] {
        entries.append(.info(sectionId, admin, adminView.peerPresences[admin.id] as? TelegramUserPresence, .singleItem))
        
        let isGroup: Bool
        let maskRightsFlags: TelegramChatAdminRightsFlags
        let rightsOrder: [TelegramChatAdminRightsFlags]
        
        switch channel.info {
        case .broadcast:
            isGroup = false
            maskRightsFlags = .broadcastSpecific
            rightsOrder = [
                .canChangeInfo,
                .canPostMessages,
                .canEditMessages,
                .canDeleteMessages,
                .canManageCalls,
                .canInviteUsers,
                .canAddAdmins
            ]
        case .group:
            isGroup = true
            maskRightsFlags = .groupSpecific
            rightsOrder = [
                .canChangeInfo,
                .canDeleteMessages,
                .canBanUsers,
                .canInviteUsers,
                .canPinMessages,
                .canManageCalls,
                .canBeAnonymous,
                .canAddAdmins
            ]
        }
        
        if canEditAdminRights(accountPeerId: accountPeerId, channelView: channelView, initialParticipant: initialParticipant) {
            
            var isCreator = false
            if let initialParticipant = initialParticipant, case .creator = initialParticipant {
                isCreator = true
            }
            
            if channel.isSupergroup {
                entries.append(.section(sectionId))
                sectionId += 1
                let placeholder = isCreator ? L10n.channelAdminRolePlaceholderOwner : L10n.channelAdminRolePlaceholderAdmin
                entries.append(.roleHeader(sectionId, .textTopItem))
                entries.append(.role(sectionId, state.rank ?? "", placeholder, .singleItem))
                entries.append(.description(sectionId, descId, isCreator ? L10n.channelAdminRoleOwnerDesc : L10n.channelAdminRoleAdminDesc, .textBottomItem))
                descId += 1
            }
            entries.append(.section(sectionId))
            sectionId += 1
            
           
            if (channel.isSupergroup) || channel.isChannel {
                if !isCreator || channel.isChannel {
                    entries.append(.description(sectionId, descId, L10n.channelAdminWhatCanAdminDo, .textTopItem))
                    descId += 1
                }
               
                
                var accountUserRightsFlags: TelegramChatAdminRightsFlags
                if channel.flags.contains(.isCreator) {
                    accountUserRightsFlags = maskRightsFlags
                } else if let adminRights = channel.adminRights {
                    accountUserRightsFlags = maskRightsFlags.intersection(adminRights.rights)
                } else {
                    accountUserRightsFlags = []
                }
                
                let currentRightsFlags: TelegramChatAdminRightsFlags
                if let updatedFlags = state.updatedFlags {
                    currentRightsFlags = updatedFlags
                } else if let initialParticipant = initialParticipant, case let .member(_, _, maybeAdminRights, _, _) = initialParticipant, let adminRights = maybeAdminRights {
                    currentRightsFlags = adminRights.rights.rights
                } else if let adminRights = channel.adminRights {
                    currentRightsFlags = adminRights.rights
                } else {
                    currentRightsFlags = accountUserRightsFlags.subtracting([.canAddAdmins, .canBeAnonymous])
                }
                
                if accountUserRightsFlags.contains(.canAddAdmins) {
                    addAdminsEnabled = currentRightsFlags.contains(.canAddAdmins)
                }
                
                var index = 0
                
                
                let list = rightsOrder.filter {
                    accountUserRightsFlags.contains($0)
                }.filter { right in
                    if channel.isSupergroup, isCreator, right != .canBeAnonymous {
                        return false
                    }
                    return true
                }
                
                
                
                for (i, right) in list.enumerated() {
                    entries.append(.rightItem(sectionId, index, stringForRight(right: right, isGroup: isGroup, defaultBannedRights: channel.defaultBannedRights), right, currentRightsFlags, currentRightsFlags.contains(right), !state.updating, bestGeneralViewType(list, for: i)))
                    index += 1
                }
                if !isCreator || channel.isChannel {
                    entries.append(.description(sectionId, descId, addAdminsEnabled ? L10n.channelAdminAdminAccess : L10n.channelAdminAdminRestricted, .textBottomItem))
                    descId += 1
                }
                if channel.flags.contains(.isCreator), !admin.isBot && currentRightsFlags.contains(TelegramChatAdminRightsFlags.all)  {
                    if admin.id != accountPeerId {
                        entries.append(.section(sectionId))
                        sectionId += 1
                        entries.append(.changeOwnership(sectionId, descId, channel.isChannel ? L10n.channelAdminTransferOwnershipChannel : L10n.channelAdminTransferOwnershipGroup, .singleItem))
                    }
                }
            }

            
        } else if let initialParticipant = initialParticipant, case let .member(_, _, maybeAdminInfo, _, _) = initialParticipant, let adminInfo = maybeAdminInfo {
            
            entries.append(.section(sectionId))
            sectionId += 1
            
            if let rank = state.rank {
                entries.append(.section(sectionId))
                sectionId += 1
                entries.append(.roleHeader(sectionId, .textTopItem))
                entries.append(.description(sectionId, descId, rank, .textTopItem))
                descId += 1
                entries.append(.section(sectionId))
                sectionId += 1
            }
            
            var index = 0
            for (i, right) in rightsOrder.enumerated() {
                entries.append(.rightItem(sectionId, index, stringForRight(right: right, isGroup: isGroup, defaultBannedRights: channel.defaultBannedRights), right, adminInfo.rights.rights, adminInfo.rights.rights.contains(right), false, bestGeneralViewType(rightsOrder, for: i)))
                index += 1
            }
            entries.append(.description(sectionId, descId, L10n.channelAdminCantEditRights, .textBottomItem))
            descId += 1
        } else if let initialParticipant = initialParticipant, case .creator = initialParticipant {
            
            entries.append(.section(sectionId))
            sectionId += 1
            
            if let rank = state.rank {
                entries.append(.section(sectionId))
                sectionId += 1
                entries.append(.roleHeader(sectionId, .textTopItem))
                entries.append(.description(sectionId, descId, rank, .textBottomItem))
                descId += 1
                entries.append(.section(sectionId))
                sectionId += 1
            }
            
            var index = 0
            for right in rightsOrder {
                entries.append(.rightItem(sectionId, index, stringForRight(right: right, isGroup: isGroup, defaultBannedRights: channel.defaultBannedRights), right, TelegramChatAdminRightsFlags(rightsOrder), true, false, bestGeneralViewType(rightsOrder, for: right)))
                index += 1
            }
            entries.append(.description(sectionId, descId, L10n.channelAdminCantEditRights, .textBottomItem))
            descId += 1
        }
        
        
        
    } else if let group = channelView.peers[channelView.peerId] as? TelegramGroup, let admin = adminView.peers[adminView.peerId] {
        entries.append(.info(sectionId, admin, adminView.peerPresences[admin.id] as? TelegramUserPresence, .singleItem))

        var isCreator = false
        if let initialParticipant = initialParticipant, case .creator = initialParticipant {
            isCreator = true
        }
        
        let placeholder = isCreator ? L10n.channelAdminRolePlaceholderOwner : L10n.channelAdminRolePlaceholderAdmin
        
        
        entries.append(.section(sectionId))
        sectionId += 1
        
        entries.append(.roleHeader(sectionId, .textTopItem))
        entries.append(.role(sectionId, state.rank ?? "", placeholder, .singleItem))
        entries.append(.description(sectionId, descId, isCreator ? L10n.channelAdminRoleOwnerDesc : L10n.channelAdminRoleAdminDesc, .textBottomItem))
        descId += 1
        
        entries.append(.section(sectionId))
        sectionId += 1
        
        if !isCreator {
            entries.append(.description(sectionId, descId, L10n.channelAdminWhatCanAdminDo, .textTopItem))
            descId += 1
            
            let isGroup = true
            let maskRightsFlags: TelegramChatAdminRightsFlags = .groupSpecific
            let rightsOrder: [TelegramChatAdminRightsFlags] = [
                .canChangeInfo,
                .canDeleteMessages,
                .canBanUsers,
                .canInviteUsers,
                .canManageCalls,
                .canPinMessages,
                .canBeAnonymous,
                .canAddAdmins
            ]
            
            let accountUserRightsFlags: TelegramChatAdminRightsFlags = maskRightsFlags
            
            let currentRightsFlags: TelegramChatAdminRightsFlags
            if let updatedFlags = state.updatedFlags {
                currentRightsFlags = updatedFlags
            } else if let initialParticipant = initialParticipant, case let .member(_, _, maybeAdminRights, _, _) = initialParticipant, let adminRights = maybeAdminRights {
                currentRightsFlags = adminRights.rights.rights.subtracting(.canAddAdmins)
            } else {
                currentRightsFlags = accountUserRightsFlags.subtracting([.canAddAdmins, .canBeAnonymous])
            }
            
            var index = 0
            
            let list = rightsOrder.filter {
                accountUserRightsFlags.contains($0)
            }
            
            for (i, right) in list.enumerated() {
                entries.append(.rightItem(sectionId, index, stringForRight(right: right, isGroup: isGroup, defaultBannedRights: group.defaultBannedRights), right, currentRightsFlags, currentRightsFlags.contains(right), !state.updating, bestGeneralViewType(list, for: i)))
                index += 1
            }
            
            if accountUserRightsFlags.contains(.canAddAdmins) {
                entries.append(.description(sectionId, descId, currentRightsFlags.contains(.canAddAdmins) ? L10n.channelAdminAdminAccess : L10n.channelAdminAdminRestricted, .textBottomItem))
                descId += 1
            }
            
            if case .creator = group.role, !admin.isBot {
                if currentRightsFlags.contains(maskRightsFlags) {
                    if admin.id != accountPeerId {
                        entries.append(.section(sectionId))
                        sectionId += 1
                        entries.append(.changeOwnership(sectionId, descId, L10n.channelAdminTransferOwnershipGroup, .singleItem))
                    }
                }
            }
        }
    }
    
    var canDismiss: Bool = false
    if let channel = peerViewMainPeer(channelView) as? TelegramChannel {
        
        if let initialParticipant = initialParticipant {
            if channel.flags.contains(.isCreator) {
                canDismiss = initialParticipant.adminInfo != nil
            } else {
                switch initialParticipant {
                case .creator:
                    break
                case let .member(_, _, adminInfo, _, _):
                    if let adminInfo = adminInfo {
                        if adminInfo.promotedBy == accountPeerId || adminInfo.canBeEditedByAccountPeer {
                            canDismiss = true
                        }
                    }
                }
            }
        }
    }
    
    if canDismiss {
        entries.append(.section(sectionId))
        sectionId += 1
        
        entries.append(.dismiss(sectionId, descId, L10n.channelAdminDismiss, .singleItem))
        descId += 1
    }
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    return entries
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<ChannelAdminEntry>], right: [AppearanceWrapperEntry<ChannelAdminEntry>], initialSize:NSSize, arguments:ChannelAdminControllerArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}


class ChannelAdminController: TableModalViewController {
    private var arguments: ChannelAdminControllerArguments?
    private let context:AccountContext
    private let peerId:PeerId
    private let adminId:PeerId
    private let initialParticipant:ChannelParticipant?
    private let updated:(TelegramChatAdminRights?) -> Void
    private let disposable = MetaDisposable()
    private let upgradedToSupergroup: (PeerId, @escaping () -> Void) -> Void
    private var okClick: (()-> Void)?
    
    init(_ context: AccountContext, peerId: PeerId, adminId: PeerId, initialParticipant: ChannelParticipant?, updated: @escaping (TelegramChatAdminRights?) -> Void, upgradedToSupergroup: @escaping (PeerId, @escaping () -> Void) -> Void) {
        self.context = context
        self.peerId = peerId
        self.upgradedToSupergroup = upgradedToSupergroup
        self.adminId = adminId
        self.initialParticipant = initialParticipant
        self.updated = updated
        super.init(frame: NSMakeRect(0, 0, 350, 360))
        bar = .init(height : 0)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.getBackgroundColor = {
            theme.colors.listBackground
        }
        
        let combinedPromise: Promise<CombinedView> = Promise()
        
        let context = self.context
        var peerId = self.peerId
        let adminId = self.adminId
        let initialParticipant = self.initialParticipant
        let updated = self.updated
        let upgradedToSupergroup = self.upgradedToSupergroup


        let initialValue = ChannelAdminControllerState(rank: initialParticipant?.rank, initialRank: initialParticipant?.rank)
        let stateValue = Atomic(value: initialValue)
        let statePromise = ValuePromise(initialValue, ignoreRepeated: true)
        let updateState: ((ChannelAdminControllerState) -> ChannelAdminControllerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }
        
        let dismissImpl:()-> Void = { [weak self] in
            self?.close()
        }
        
        let actionsDisposable = DisposableSet()
        
        let updateRightsDisposable = MetaDisposable()
        actionsDisposable.add(updateRightsDisposable)
        
        let arguments = ChannelAdminControllerArguments(context: context, toggleRight: { right, flags in
            updateState { current in
                var updated = flags
                if flags.contains(right) {
                    updated.remove(right)
                } else {
                    updated.insert(right)
                }
                
                return current.withUpdatedUpdatedFlags(updated)
            }
        }, dismissAdmin: {
            updateState { current in
                return current.withUpdatedUpdating(true)
            }
            if peerId.namespace == Namespaces.Peer.CloudGroup {
                updateRightsDisposable.set((removeGroupAdmin(account: context.account, peerId: peerId, adminId: adminId)
                    |> deliverOnMainQueue).start(error: { _ in
                    }, completed: {
                        updated(nil)
                        dismissImpl()
                    }))
            } else {
                updateRightsDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(account: context.account, peerId: peerId, memberId: adminId, adminRights: nil, rank: stateValue.with { $0.rank }) |> deliverOnMainQueue).start(error: { _ in
                    
                }, completed: {
                    updated(nil)
                    dismissImpl()
                }))
            }
        }, cantEditError: { [weak self] in
            self?.show(toaster: ControllerToaster(text: L10n.channelAdminCantEdit))
        }, transferOwnership: {
            _ = (combineLatest(queue: .mainQueue(), context.account.postbox.loadedPeerWithId(peerId), context.account.postbox.loadedPeerWithId(adminId))).start(next: { peer, admin in
                
                let header: String
                let text: String
                if peer.isChannel {
                    header = L10n.channelAdminTransferOwnershipConfirmChannelTitle
                    text = L10n.channelAdminTransferOwnershipConfirmChannelText(peer.displayTitle, admin.displayTitle)
                } else {
                    header = L10n.channelAdminTransferOwnershipConfirmGroupTitle
                    text = L10n.channelAdminTransferOwnershipConfirmGroupText(peer.displayTitle, admin.displayTitle)
                }
                
                let checkPassword:(PeerId)->Void = { peerId in
                    showModal(with: InputPasswordController(context: context, title: L10n.channelAdminTransferOwnershipPasswordTitle, desc: L10n.channelAdminTransferOwnershipPasswordDesc, checker: { pwd in
                        return context.peerChannelMemberCategoriesContextsManager.transferOwnership(account: context.account, peerId: peerId, memberId: admin.id, password: pwd)
                            |> deliverOnMainQueue
                            |> ignoreValues
                            |> `catch` { error -> Signal<Never, InputPasswordValueError> in
                            switch error {
                            case .generic:
                                return .fail(.generic)
                            case .invalidPassword:
                                return .fail(.wrong)
                            default:
                                return .fail(.generic)
                            }
                        }  |> afterCompleted {
                            dismissImpl()
                            _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 2.0)
                        }
                    }), for: context.window)
                }
                
                let transfer:(PeerId, Bool, Bool)->Void = { _peerId, isGroup, convert in
                    actionsDisposable.add(showModalProgress(signal: checkOwnershipTranfserAvailability(postbox: context.account.postbox, network: context.account.network, accountStateManager: context.account.stateManager, memberId: adminId), for: context.window).start(error: { error in
                        let errorText: String?
                        var install2Fa = false
                        switch error {
                        case .generic:
                            errorText = L10n.unknownError
                        case .tooMuchJoined:
                            errorText = L10n.inviteChannelsTooMuch
                        case .authSessionTooFresh:
                            errorText = L10n.channelTransferOwnerErrorText
                        case .twoStepAuthMissing:
                            errorText = L10n.channelTransferOwnerErrorText
                            install2Fa = true
                        case .twoStepAuthTooFresh:
                            errorText = L10n.channelTransferOwnerErrorText
                        case .invalidPassword:
                            preconditionFailure()
                        case .requestPassword:
                            errorText = nil
                        case .restricted, .userBlocked:
                            errorText = isGroup ? L10n.groupTransferOwnerErrorPrivacyRestricted : L10n.channelTransferOwnerErrorPrivacyRestricted
                        case .adminsTooMuch:
                             errorText = isGroup ? L10n.groupTransferOwnerErrorAdminsTooMuch : L10n.channelTransferOwnerErrorAdminsTooMuch
                        case .userPublicChannelsTooMuch:
                            errorText = L10n.channelTransferOwnerErrorPublicChannelsTooMuch
                        case .limitExceeded:
                            errorText = L10n.loginFloodWait
                        case .userLocatedGroupsTooMuch:
                            errorText = L10n.groupOwnershipTransferErrorLocatedGroupsTooMuch
                        }
                        
                        if let errorText = errorText {
                            confirm(for: context.window, header: L10n.channelTransferOwnerErrorTitle, information: errorText, okTitle: L10n.modalOK, cancelTitle: L10n.modalCancel, thridTitle: install2Fa ? L10n.channelTransferOwnerErrorEnable2FA : nil, successHandler: { result in
                                switch result {
                                case .basic:
                                    break
                                case .thrid:
                                    dismissImpl()
                                    context.sharedContext.bindings.rootNavigation().removeUntil(EmptyChatViewController.self)
                                    context.sharedContext.bindings.rootNavigation().push(twoStepVerificationUnlockController(context: context, mode: .access(nil), presentController: { (controller, isRoot, animated) in
                                        let navigation = context.sharedContext.bindings.rootNavigation()
                                        if isRoot {
                                            navigation.removeUntil(EmptyChatViewController.self)
                                        }
                                        if !animated {
                                            navigation.stackInsert(controller, at: navigation.stackCount)
                                        } else {
                                            navigation.push(controller)
                                        }
                                    }))
                                }
                            })
                        } else {
                            if convert {
                                actionsDisposable.add(showModalProgress(signal: convertGroupToSupergroup(account: context.account, peerId: peer.id), for: context.window).start(next: { upgradedPeerId in
                                    upgradedToSupergroup(upgradedPeerId, {
                                        peerId = upgradedPeerId
                                        combinedPromise.set(context.account.postbox.combinedView(keys: [.peer(peerId: upgradedPeerId, components: .all), .peer(peerId: adminId, components: .all)]))
                                        checkPassword(upgradedPeerId)
                                    })
                                }, error: { error in
                                    switch error {
                                    case .tooManyChannels:
                                        showInactiveChannels(context: context, source: .upgrade)
                                    case .generic:
                                        alert(for: context.window, info: L10n.unknownError)
                                    }
                                }))
                            } else {
                               checkPassword(peer.id)
                            }
                        }
                    }))
                }
                
                confirm(for: context.window, header: header, information: text, okTitle: L10n.channelAdminTransferOwnershipConfirmOK, successHandler: { _ in
                    transfer(peerId, peer.isSupergroup || peer.isGroup, peer.isGroup)
                })
            })
        }, updateRank: { rank in
            updateState {
                $0.withUpdatedRank(rank)
            }
        })
        
        self.arguments = arguments
        
        
        combinedPromise.set(context.account.postbox.combinedView(keys: [.peer(peerId: peerId, components: .all), .peer(peerId: adminId, components: .all)]))
        
        let previous:Atomic<[AppearanceWrapperEntry<ChannelAdminEntry>]> = Atomic(value: [])
        let initialSize = atomicSize
        
        let signal = combineLatest(statePromise.get(), combinedPromise.get(), appearanceSignal)
            |> deliverOn(prepareQueue)
            |> map { state, combinedView, appearance -> (transition: TableUpdateTransition, canEdit: Bool, canDismiss: Bool, channelView: PeerView) in
                let channelView = combinedView.views[.peer(peerId: peerId, components: .all)] as! PeerView
                let adminView = combinedView.views[.peer(peerId: adminId, components: .all)] as! PeerView
                var canEdit = canEditAdminRights(accountPeerId: context.account.peerId, channelView: channelView, initialParticipant: initialParticipant)
                
                
                var canDismiss = false

                if let channel = peerViewMainPeer(channelView) as? TelegramChannel {
                    
                    if let initialParticipant = initialParticipant {
                        if channel.flags.contains(.isCreator) {
                            canDismiss = initialParticipant.adminInfo != nil
                        } else {
                            switch initialParticipant {
                            case .creator:
                                break
                            case let .member(_, _, adminInfo, _, _):
                                if let adminInfo = adminInfo {
                                    if adminInfo.promotedBy == context.account.peerId || adminInfo.canBeEditedByAccountPeer {
                                        canDismiss = true
                                    }
                                }
                            }
                        }
                    }
                }
                let result = channelAdminControllerEntries(state: state, accountPeerId: context.account.peerId, channelView: channelView, adminView: adminView, initialParticipant: initialParticipant)
                let entries = result.map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
                _ = stateValue.modify({$0.withUpdatedEditable(canEdit)})
                return (transition: prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments), canEdit: canEdit, canDismiss: canDismiss, channelView: channelView)
                
        } |> afterDisposed {
            actionsDisposable.dispose()
        } |> deliverOnMainQueue
        
        let updatedSize:Atomic<Bool> = Atomic(value: false)
        
        disposable.set(signal.start(next: { [weak self] values in
            self?.genericView.merge(with: values.transition)
            self?.readyOnce()
            self?.updateSize(updatedSize.swap(true))
            
            self?.modal?.interactions?.updateDone { button in
                
                button.isEnabled = values.canEdit
                button.set(text: L10n.navigationDone, for: .Normal)
            }
            
            self?.okClick = {
                if let channel = values.channelView.peers[values.channelView.peerId] as? TelegramChannel {
                    if let initialParticipant = initialParticipant {
                        var updateFlags: TelegramChatAdminRightsFlags?
                        updateState { current in
                            updateFlags = current.updatedFlags
                            if let _ = updateFlags {
                                return current.withUpdatedUpdating(true)
                            } else {
                                return current
                            }
                        }
                        
                        if updateFlags == nil {
                            switch initialParticipant {
                            case let .creator(_, info, _):
                                if stateValue.with ({ $0.rank != $0.initialRank }) {
                                    updateFlags = info?.rights.rights ?? .groupSpecific
                                }
                            case let .member(member):
                                if member.adminInfo?.rights == nil {
                                    let maskRightsFlags: TelegramChatAdminRightsFlags
                                    switch channel.info {
                                    case .broadcast:
                                        maskRightsFlags = .broadcastSpecific
                                    case .group:
                                        maskRightsFlags = .groupSpecific
                                    }
                                    
                                    if channel.flags.contains(.isCreator) {
                                        updateFlags = maskRightsFlags.subtracting([.canAddAdmins, .canBeAnonymous])
                                    } else if let adminRights = channel.adminRights {
                                        updateFlags = maskRightsFlags.intersection(adminRights.rights).subtracting([.canAddAdmins, .canBeAnonymous])
                                    } else {
                                        updateFlags = []
                                    }
                                }
                            }
                        }
                        if updateFlags == nil && stateValue.with ({ $0.rank != $0.initialRank }) {
                            updateFlags = initialParticipant.adminInfo?.rights.rights
                        }
                        
                        if let updateFlags = updateFlags {
                            updateState { current in
                                return current.withUpdatedUpdating(true)
                            }
                            updateRightsDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(account: context.account, peerId: peerId, memberId: adminId, adminRights: TelegramChatAdminRights(rights: updateFlags), rank: stateValue.with { $0.rank }) |> deliverOnMainQueue).start(error: { error in
                                
                            }, completed: {
                                updated(TelegramChatAdminRights(rights: updateFlags))
                                dismissImpl()
                            }))
                        } else {
                            dismissImpl()
                        }
                    } else if values.canEdit {
                        var updateFlags: TelegramChatAdminRightsFlags?
                        updateState { current in
                            updateFlags = current.updatedFlags
                            return current.withUpdatedUpdating(true)
                        }
                        
                        if updateFlags == nil {
                            let maskRightsFlags: TelegramChatAdminRightsFlags
                            switch channel.info {
                            case .broadcast:
                                maskRightsFlags = .broadcastSpecific
                            case .group:
                                maskRightsFlags = .groupSpecific
                            }
                            
                            if channel.flags.contains(.isCreator) {
                                updateFlags = maskRightsFlags.subtracting(.canAddAdmins)
                            } else if let adminRights = channel.adminRights {
                                updateFlags = maskRightsFlags.intersection(adminRights.rights).subtracting(.canAddAdmins)
                            } else {
                                updateFlags = []
                            }
                        }
                        
                        
                        
                        if let updateFlags = updateFlags {
                            updateState { current in
                                return current.withUpdatedUpdating(true)
                            }
                            updateRightsDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(account: context.account, peerId: peerId, memberId: adminId, adminRights: TelegramChatAdminRights(rights: updateFlags), rank: stateValue.with { $0.rank }) |> deliverOnMainQueue).start(error: { _ in
                                
                            }, completed: {
                                updated(TelegramChatAdminRights(rights: updateFlags))
                                dismissImpl()
                            }))
                        }
                    }
                } else if let _ = values.channelView.peers[values.channelView.peerId] as? TelegramGroup {
                    var updateFlags: TelegramChatAdminRightsFlags?
                    updateState { current in
                        updateFlags = current.updatedFlags
                        return current
                    }
                    
                    let maskRightsFlags: TelegramChatAdminRightsFlags = .groupSpecific
                    let defaultFlags = maskRightsFlags.subtracting(.canAddAdmins)
                    
                    if updateFlags == nil {
                        updateFlags = defaultFlags
                    }
                    
                    if let updateFlags = updateFlags {
                        if initialParticipant?.adminInfo == nil && updateFlags == defaultFlags && stateValue.with ({ $0.rank == $0.initialRank }) {
                            updateState { current in
                                return current.withUpdatedUpdating(true)
                            }
                            updateRightsDisposable.set((addGroupAdmin(account: context.account, peerId: peerId, adminId: adminId)
                                |> deliverOnMainQueue).start(completed: {
                                    dismissImpl()
                                }))
                        } else if updateFlags != defaultFlags || stateValue.with ({ $0.rank != $0.initialRank }) {
                            let signal = convertGroupToSupergroup(account: context.account, peerId: peerId)
                                |> map(Optional.init)
                                |> deliverOnMainQueue
                                |> `catch` { error -> Signal<PeerId?, NoError> in
                                    switch error {
                                    case .tooManyChannels:
                                        showInactiveChannels(context: context, source: .upgrade)
                                    case .generic:
                                        alert(for: context.window, info: L10n.unknownError)
                                    }
                                    updateState { current in
                                        return current.withUpdatedUpdating(false)
                                    }
                                    return .single(nil)
                                }
                                |> mapToSignal { upgradedPeerId -> Signal<PeerId?, NoError> in
                                    guard let upgradedPeerId = upgradedPeerId else {
                                        return .single(nil)
                                    }
                                    
                                    return  context.peerChannelMemberCategoriesContextsManager.updateMemberAdminRights(account: context.account, peerId: upgradedPeerId, memberId: adminId, adminRights: TelegramChatAdminRights(rights: updateFlags), rank: stateValue.with { $0.rank })
                                        |> mapToSignal { _ -> Signal<PeerId?, NoError> in
                                            return .complete()
                                        }
                                        |> then(.single(upgradedPeerId))
                                }
                                |> deliverOnMainQueue
                            
                            updateState { current in
                                return current.withUpdatedUpdating(true)
                            }
                            
                            
                            updateRightsDisposable.set(showModalProgress(signal: signal, for: mainWindow).start(next: { upgradedPeerId in
                                if let upgradedPeerId = upgradedPeerId {
                                    let (disposable, _) = context.peerChannelMemberCategoriesContextsManager.admins(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: upgradedPeerId, updated: { state in
                                       
                                        if case .ready = state.loadingState {
                                            upgradedToSupergroup(upgradedPeerId, {
                                                
                                            })
                                            dismissImpl()
                                        }  
                                    })
                                    actionsDisposable.add(disposable)
                                    
                                }
                            }, error: { _ in
                                updateState { current in
                                    return current.withUpdatedUpdating(false)
                                }
                            }))
                        } else {
                            dismissImpl()
                        }
                    } else {
                        dismissImpl()
                    }
                }
            }
        }))
        
        
    }
    
    
    deinit {
        disposable.dispose()
    }
    
    
    
    override func close(animationType: ModalAnimationCloseBehaviour = .common) {
        disposable.set(nil)
        super.close(animationType: animationType)
    }
    
    override func firstResponder() -> NSResponder? {
        let view = self.genericView.item(stableId: ChannelAdminEntryStableId.role)?.view as? InputDataRowView
        return view?.textView
    }
    
    
    override func returnKeyAction() -> KeyHandlerResult {
        self.okClick?()
        return .invoked
    }
    
    override var modalHeader: (left: ModalHeaderData?, center: ModalHeaderData?, right: ModalHeaderData?)? {
        return (left: nil, center: ModalHeaderData(title: L10n.adminsAdmin), right: nil)
    }
    
    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: tr(L10n.modalOK), accept: { [weak self] in
             self?.okClick?()
        }, drawBorder: true, height: 50, singleButton: true)
    }
}

