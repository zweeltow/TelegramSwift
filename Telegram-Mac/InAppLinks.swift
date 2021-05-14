//
//  GlobalLinks.swift
//  Telegram-Mac
//
//  Created by keepcoder on 18/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import Foundation
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import MtProtoKit
//import WalletCore

private let inapp:String = "chat://"
private let tgme:String = "tg://"




func resolveUsername(username: String, context: AccountContext) -> Signal<Peer?, NoError> {
    if username.hasPrefix("_private_"), let range = username.range(of: "_private_") {
        if let channelId = Int32(username[range.upperBound...]) {
            let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt32Value(channelId))
            
            let peerSignal: Signal<Peer?, NoError> = context.account.postbox.transaction { transaction -> Peer? in
                return transaction.getPeer(peerId)
                } |> mapToSignal { peer in
                    if let peer = peer {
                        return .single(peer)
                    } else {
                        return context.engine.peerNames.findChannelById(channelId: peerId.id._internalGetInt32Value())
                    }
            }
            
            return peerSignal |> deliverOnMainQueue |> map { peer in
                if let peer = peer {
                    if let peer = peer as? TelegramChannel {
                        if peer.participationStatus != .member {
                            return nil
                        }
                    }
                }
                return peer
            }
        } else {
            return .single(nil)
        }
    } else {
        return resolvePeerByName(account: context.account, name: username) |> mapToSignal { peerId -> Signal<Peer?, NoError> in
            if let peerId = peerId {
                return context.account.postbox.loadedPeerWithId(peerId) |> map(Optional.init)
            }
            return .single(nil)
        } |> deliverOnMainQueue
    }
    
}

enum InAppSettingsSection : String {
    case themes
    case devices
    case folders
    case privacy
}

enum ChatInitialActionBehavior : Equatable {
    case none
    case automatic
}

enum ChatInitialAction : Equatable {
    case start(parameter: String, behavior: ChatInitialActionBehavior)
    case inputText(text: String, behavior: ChatInitialActionBehavior)
    case files(list: [String], behavior: ChatInitialActionBehavior)
    case forward(messageIds: [MessageId], text: ChatTextInputState?, behavior: ChatInitialActionBehavior)
    case ad(PromoChatListItem.Kind)
    case source(MessageId)
    case closeAfter(Int32)
    case selectToReport(reason: ReportReasonValue)
    case joinVoiceChat(_ joinHash: String?)
    var selectionNeeded: Bool {
        switch self {
        case .selectToReport:
            return true
        default:
            return false
        }
    }
}



var globalLinkExecutor:TextViewInteractions {
    get {
        return TextViewInteractions(processURL:{(link) in
            if let link = link as? inAppLink {
                switch link {
                case .requestSecureId:
                    break // never execute from inapp
                default:
                    execute(inapp:link)
                }
            }
        }, isDomainLink: { value, origin in
            if let value = value as? inAppLink {
                switch value {
                case .external:
                    return true
                default:
                    if let origin = origin {
                        if origin != value.link, !origin.isEmpty && origin != "‌" {
                            return true
                        }
                    }
                    return false
                }
            }
            return false
        }, makeLinkType: { link, url in
            if let link = link as? inAppLink {
                switch link {
                case .botCommand:
                    return .command
                case .hashtag:
                    return .hashtag
                case .code:
                    return .code
                case .followResolvedName:
                    if url.hasPrefix("@") {
                        return .username
                    } else {
                        return .plain
                    }
                case let .external(link, _):
                    if isValidEmail(link) {
                        return .email
                    } else if telegram_me.first(where: {link.contains($0 + "joinchat/")}) != nil {
                        return .inviteLink
                    } else {
                        return .plain
                    }
                case .stickerPack:
                    return .stickerPack
                case .joinchat:
                    return .inviteLink
                default:
                    return .plain
                }
            }
            return .plain
        }, localizeLinkCopy: { type in
            return copyContextText(from: type)
        }, resolveLink: { link in
            return (link as? inAppLink)?.link
        }, copyAttributedString: { string in
            let pb = NSPasteboard.general

            if !FastSettings.enableRTF {
                pb.clearContents()
                pb.declareTypes([.string], owner: nil)
                pb.setString(string.string, forType: .string)
                return true
            }
            let modified: NSMutableAttributedString = string.mutableCopy() as! NSMutableAttributedString
            
            string.enumerateAttributes(in: string.range, options: [], using: { attr, range, _ in
                if let appLink = attr[NSAttributedString.Key.link] as? inAppLink {
                    switch appLink {
                    case .code, .hashtag, .callback:
                        break
                    default:
                        if appLink.link != modified.string.nsstring.substring(with: range) {
                            modified.addAttribute(NSAttributedString.Key.link, value: appLink.link, range: range)
                        }
                    }
                    
                } else if let appLink = attr[NSAttributedString.Key(TGCustomLinkAttributeName)] as? TGInputTextTag {
                    if (appLink.attachment as? String) != modified.string.nsstring.substring(with: range) {
                        modified.addAttribute(NSAttributedString.Key.link, value: appLink.attachment, range: range)
                    }
                } else if attr[.foregroundColor] != nil {
                    modified.removeAttribute(.foregroundColor, range: range)
                } else if let font = attr[.font] as? NSFont {
                    if let newFont = NSFont(name: font.fontName, size: 0) {
                        modified.setFont(font: newFont, range: range)
                    }
                } else if attr[.paragraphStyle] != nil {
                    modified.removeAttribute(.paragraphStyle, range: range)
                }
            })
            
            
            if !modified.string.isEmpty {
                pb.clearContents()
                
                let rtf = try? modified.data(from: modified.range, documentAttributes: [NSAttributedString.DocumentAttributeKey.documentType : NSAttributedString.DocumentType.rtf])
                if let rtf = rtf {
                    pb.declareTypes([.rtf], owner: nil)
                    pb.setData(rtf, forType: .rtf)
                    pb.setString(modified.string, forType: .string)
                    return true
                }
            }
            
            return false
        })
    }
}

func copyContextText(from type: LinkType) -> String {
    switch type {
    case .username:
        return L10n.textContextCopyUsername
    case .command:
        return L10n.textContextCopyCommand
    case .hashtag:
        return L10n.textContextCopyHashtag
    case .email:
        return L10n.textContextCopyEmail
    case .plain:
        return L10n.textContextCopyLink
    case .inviteLink:
        return L10n.textContextCopyInviteLink
    case .stickerPack:
        return L10n.textContextCopyStickerPack
    case .code:
        return L10n.textContextCopyCode
    }
}

func execute(inapp:inAppLink, afterComplete: @escaping(Bool)->Void = { _ in }) {
    
    switch inapp {
    case let .external(link, needConfirm):
        var url:String = link.trimmed



        var reversedUrl = String(url.reversed())
        while reversedUrl.components(separatedBy: "#").count > 2 {
            if let index = reversedUrl.range(of: "#") {
                reversedUrl.replaceSubrange(index, with: "32%")
            }
        }
        url = String(reversedUrl.reversed())
        if !url.hasPrefix("http") && !url.hasPrefix("ftp"), url.range(of: "://") == nil {
            if isValidEmail(link) {
              //  url = "mailto:" + url
            } else {
                url = "http://" + url
            }
        }
        let urlValue = url
        let escaped = escape(with:url)
        if let urlQueryAllowed = Optional(escaped) {
            if let url = URL(string: urlQueryAllowed) ?? URL(string: urlValue) {
                var needConfirm = needConfirm || url.host != URL(string: urlValue)?.host
                
                if needConfirm {
                    let allowed = ["telegram.org", "telegram.dog", "telegram.me", "telesco.pe"]
                    if let url = URL(string: urlValue) {
                        if let host = url.host, allowed.contains(host) {
                            needConfirm = false
                        }
                    }
                }

                if let withToken = appDelegate?.tryApplyAutologinToken(url.absoluteString), let url = URL(string: withToken) {
                    NSWorkspace.shared.open(url)
                    afterComplete(true)
                    return
                }
                
                let removePecentEncoding = url.host == URL(string: urlValue)?.host
                let success:()->Void = {
                    
                    var path = url.absoluteString
                    let supportSchemes:[String] = ["itunes.apple.com"]
                    for scheme in supportSchemes {
                        var url:URL? = nil
                        if path.contains(scheme) {
                            switch scheme {
                            case supportSchemes[0]: // itunes
                               path = "itms://" + path.nsstring.substring(from: path.nsstring.range(of: scheme).location)
                               url = URL(string: path)
                            default:
                                continue
                            }
                        }
                        if let url = url {
                            NSWorkspace.shared.open(url)
                            afterComplete(true)
                            return
                        }
                    }
                    afterComplete(true)
                    NSWorkspace.shared.open(url)
                }
                if needConfirm {
                    confirm(for: mainWindow, header: L10n.inAppLinksConfirmOpenExternalHeader, information: L10n.inAppLinksConfirmOpenExternalNew(removePecentEncoding ? (url.absoluteString.removingPercentEncoding ?? url.absoluteString) : escaped), okTitle: L10n.inAppLinksConfirmOpenExternalOK, successHandler: {_ in success()}, cancelHandler: { afterComplete(false) })
                } else {
                    success()
                }
            }
            
        }
    case let .peerInfo(_, peerId, action, openChat, postId, callback):
        let messageId:MessageId?
        if let postId = postId {
            messageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: MessageId.Id(postId))
        } else {
            messageId = nil
        }
        callback(peerId, openChat, messageId, action)
        afterComplete(true)
    case let .comments(_, username, context, threadId, commentId):
        
        enum Error {
            case doesntExists
            case privateAccess
            case generic
        }
        
        var peerSignal: Signal<Peer, Error> = .fail(.doesntExists)
        if username.hasPrefix("_private_"), let range = username.range(of: "_private_") {
            if let channelId = Int32(username[range.upperBound...]) {
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt32Value(channelId))
                peerSignal = context.account.postbox.transaction { transaction -> Peer? in
                    return transaction.getPeer(peerId)
                } |> mapToSignalPromotingError { peer in
                    if let peer = peer {
                        return .single(peer)
                    } else {
                        return context.engine.peerNames.findChannelById(channelId: peerId.id._internalGetInt32Value())
                            |> mapToSignalPromotingError { value in
                                if let value = value {
                                    return .single(value)
                                } else {
                                    return .fail(.privateAccess)
                                }
                            }
                        
                    }
                }
            }
        } else {
            peerSignal = resolvePeerByName(account: context.account, name: username) |> mapToSignalPromotingError { peerId -> Signal<Peer, Error> in
                if let peerId = peerId {
                    return context.account.postbox.loadedPeerWithId(peerId) |> mapError { _ in
                        return .doesntExists
                    }
                }
                return .fail(.doesntExists)
            } |> mapError { _ in
                return .doesntExists
            }
        }
        
        let signal:Signal<(ReplyThreadInfo, Peer), Error> = peerSignal |> mapToSignal { peer in
            let messageId: MessageId = MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: threadId)
            return fetchAndPreloadReplyThreadInfo(context: context, subject: peer.isChannel ? .channelPost(messageId) : .groupMessage(messageId))
                |> map {
                    return ($0, peer)
                } |> mapError { error in
                    switch error {
                    case .generic:
                        return .generic
                    }
            }
        } |> deliverOnMainQueue

        
        _ = showModalProgress(signal: signal |> take(1), for: context.window).start(next: { values in
            let (result, peer) = values
            let threadMessageId: MessageId = MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: threadId)
            let navigation = context.sharedContext.bindings.rootNavigation()
            let current = navigation.controller as? ChatController
            
            if let current = current, current.chatInteraction.mode.threadId == result.message.messageId {
                if let commentId = commentId {
                    let commentMessageId = MessageId(peerId: result.message.messageId.peerId, namespace: Namespaces.Message.Cloud, id: commentId)
                    current.chatInteraction.focusMessageId(nil, commentMessageId, .CenterEmpty)
                }
            } else {
                let mode: ReplyThreadMode
                if peer.isChannel {
                    mode = .comments(origin: threadMessageId)
                } else {
                    mode = .replies(origin: threadMessageId)
                }
                var commentMessageId: MessageId? = nil
                if let commentId = commentId {
                    commentMessageId = MessageId(peerId: result.message.messageId.peerId, namespace: Namespaces.Message.Cloud, id: commentId)
                }
                
                navigation.push(ChatAdditionController(context: context, chatLocation: .replyThread(result.message), mode: .replyThread(data: result.message, mode: mode), messageId: commentMessageId, initialAction: nil, chatLocationContextHolder: result.contextHolder))
            }
        }, error: { error in
            switch error {
            case .doesntExists:
                alert(for: context.window, info: L10n.alertUserDoesntExists)
            case .privateAccess:
                 alert(for: context.window, info: L10n.alertPrivateChannelAccessError)
            case .generic:
                break
            }
        })
        
        afterComplete(true)
    case let .followResolvedName(_, username, postId, context, action, callback):
        
        if username.hasPrefix("_private_"), let range = username.range(of: "_private_") {
            if let channelId = Int32(username[range.upperBound...]) {
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt32Value(channelId))
                
                let peerSignal: Signal<Peer?, NoError> = context.account.postbox.transaction { transaction -> Peer? in
                    return transaction.getPeer(peerId)
                    } |> mapToSignal { peer in
                        if let peer = peer {
                            return .single(peer)
                        } else {
                            return context.engine.peerNames.findChannelById(channelId: peerId.id._internalGetInt32Value())
                        }
                }
                
                _ = showModalProgress(signal: peerSignal |> deliverOnMainQueue, for: context.window).start(next: { peer in
                    if let peer = peer {
                        let messageId:MessageId?
                        if let postId = postId {
                            messageId = MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: postId)
                        } else {
                            messageId = nil
                        }
                        if let peer = peer as? TelegramChannel {
                            if peer.participationStatus == .kicked {
                                alert(for: context.window, info: L10n.alertPrivateChannelAccessError)
                                return
                            }
                        }
                        callback(peer.id, peer.isChannel || peer.isSupergroup || peer.isBot, messageId, action)
                    } else {
                        alert(for: context.window, info: L10n.alertPrivateChannelAccessError)
                    }
                })
            } else {
                alert(for: context.window, info: L10n.alertPrivateChannelAccessError)
            }
        } else {
            let _ = showModalProgress(signal: resolvePeerByName(account: context.account, name: username) |> mapToSignal { peerId -> Signal<Peer?, NoError> in
                if let peerId = peerId {
                    return context.account.postbox.loadedPeerWithId(peerId) |> map {Optional($0)}
                }
                return .single(nil)
            } |> deliverOnMainQueue, for: context.window).start(next: { peer in
                if let peer = peer {
                    let messageId:MessageId?
                    if let postId = postId {
                        messageId = MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: postId)
                    } else {
                        messageId = nil
                    }
                    callback(peer.id, peer.isChannel || peer.isSupergroup || peer.isBot, messageId, action)
                } else {
                    alert(for: context.window, info: tr(L10n.alertUserDoesntExists))
                }
                    
            })
        }
        afterComplete(true)
    case let .inviteBotToGroup(_, username, context, action, callback):
        let _ = showModalProgress(signal: resolvePeerByName(account: context.account, name: username) |> filter {$0 != nil} |> map{$0!} |> deliverOnMainQueue, for: context.window).start(next: { botPeerId in
            
            let selectedPeer = selectModalPeers(window: context.window, account: context.account, title: L10n.selectPeersTitleSelectChat, behavior: SelectChatsBehavior(limit: 1), confirmation: { peerIds -> Signal<Bool, NoError> in
                if let peerId = peerIds.first {
                    return context.account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue |> mapToSignal { peer -> Signal<Bool, NoError> in
                        return confirmSignal(for: context.window, information: L10n.confirmAddBotToGroup(peer.displayTitle))
                    }
                }
                return .single(false)
            }) |> deliverOnMainQueue |> filter { $0.first != nil } |> map { $0.first! }
            
            let signal:Signal<(StartBotInGroupResult, PeerId), NoError> = selectedPeer |> mapToSignal { peerId in
                var payload: String = ""
                if let action = action {
                    switch action {
                    case let .start(data, _):
                        payload = data
                    default:
                        break
                    }
                }
                if payload.isEmpty {
                    if peerId.namespace == Namespaces.Peer.CloudGroup {
                        return showModalProgress(signal: addGroupMember(account: context.account, peerId: peerId, memberId: botPeerId), for: context.window)
                            |> map { (.none, peerId) }
                            |> `catch` { _ -> Signal<(StartBotInGroupResult, PeerId), NoError> in return .single((.none, peerId)) }
                    } else {
                        return showModalProgress(signal: context.peerChannelMemberCategoriesContextsManager.addMember(account: context.account, peerId: peerId, memberId: botPeerId), for: context.window)
                            |> map { _ in (.none, peerId) }
                            |> then(.single((.none, peerId)))
                    }
                } else {
                    return showModalProgress(signal: requestStartBotInGroup(account: context.account, botPeerId: botPeerId, groupPeerId: peerId, payload: payload), for: context.window)
                        |> map {
                            ($0, peerId)
                        }
                        |> `catch` { _ -> Signal<(StartBotInGroupResult, PeerId), NoError> in return .single((.none, peerId)) }
                    
                }
                } |> deliverOnMainQueue
            
            _ = signal.start(next: { result, peerId in
                switch result {
                case let .channelParticipant(participant):
                    context.peerChannelMemberCategoriesContextsManager.externallyAdded(peerId: peerId, participant: participant)
                case .none:
                    break
                }
                callback(peerId, true, nil, nil)
            })
        })
        afterComplete(true)
    case let .botCommand(command, interaction):
        interaction(command)
        afterComplete(true)
    case let .hashtag(hashtag, interaction):
        interaction(hashtag)
        afterComplete(true)
    case let .joinchat(_, hash, context, interaction):
        _ = showModalProgress(signal: joinLinkInformation(hash, account: context.account), for: context.window).start(next: { (result) in
            switch result {
            case let .alreadyJoined(peerId):
                interaction(peerId, true, nil, nil)
            case .invite:
                showModal(with: JoinLinkPreviewModalController(context, hash: hash, join: result, interaction: { peerId in
                    if let peerId = peerId {
                        interaction(peerId, true, nil, nil)
                    }
                }), for: context.window)
            case let .peek(peerId, peek):
                 interaction(peerId, true, nil, .closeAfter(peek))
            case .invalidHash:
                alert(for: context.window, info: L10n.linkExpired)
            }
        })
        afterComplete(true)
    case let .callback(param, interaction):
        interaction(param)
        afterComplete(true)
    case let .code(param, interaction):
        interaction(param)
        afterComplete(true)
    case let .logout(interaction):
        interaction()
        afterComplete(true)
    case let .shareUrl(_, context, url):
        if !url.hasPrefix("@") {
            showModal(with: ShareModalController(ShareLinkObject(context, link: url)), for: context.window)
        }
        afterComplete(true)
    case let .wallpaper(_, context, preview):
        switch preview {
        case let .gradient(top, bottom, rotation):
            let wallpaper: TelegramWallpaper = .gradient(top.argb, bottom.rgb, WallpaperSettings(rotation: rotation))
            showModal(with: WallpaperPreviewController(context, wallpaper: Wallpaper(wallpaper), source: .link(wallpaper)), for: context.window)
        case let .color(color):
            let wallpaper: TelegramWallpaper = .color(color.argb)
            showModal(with: WallpaperPreviewController(context, wallpaper: Wallpaper(wallpaper), source: .link(wallpaper)), for: context.window)
        case let .slug(slug, settings):
            _ = showModalProgress(signal: getWallpaper(network: context.account.network, slug: slug) |> deliverOnMainQueue, for: context.window).start(next: { wallpaper in
                showModal(with: WallpaperPreviewController(context, wallpaper: Wallpaper(wallpaper).withUpdatedSettings(settings), source: .link(wallpaper)), for: context.window)
            }, error: { error in
                switch error {
                case .generic:
                    alert(for: context.window, info: L10n.wallpaperPreviewDoesntExists)
                }
            })
        }
        afterComplete(true)
    case let .stickerPack(_, reference, context, peerId):
        showModal(with: StickerPackPreviewModalController(context, peerId: peerId, reference: reference), for: context.window)
        afterComplete(true)
    case let .confirmPhone(_, context, phone, hash):
        _ = showModalProgress(signal: requestCancelAccountResetData(network: context.account.network, hash: hash) |> deliverOnMainQueue, for: context.window).start(next: { data in
            showModal(with: cancelResetAccountController(account: context.account, phone: phone, data: data), for: context.window)
        }, error: { error in
            switch error {
            case .limitExceeded:
                alert(for: context.window, info: L10n.loginFloodWait)
            case .generic:
                alert(for: context.window, info: L10n.unknownError)
            }
        })
        afterComplete(true)
    case let .socks(_, settings, applyProxy):
        applyProxy(settings)
        afterComplete(true)
    case .nothing:
        afterComplete(true)
    case let .requestSecureId(_, context, value):
        if value.nonce.isEmpty {
            alert(for: context.window, info: value.isModern ? "nonce is empty" : "payload is empty")
            return
        }
        _ = showModalProgress(signal: (requestSecureIdForm(postbox: context.account.postbox, network: context.account.network, peerId: value.peerId, scope: value.scope, publicKey: value.publicKey) |> mapToSignal { form in
            return context.account.postbox.loadedPeerWithId(context.peerId) |> mapError {_ in return .generic} |> map { peer in
                return (form, peer)
            }
        } |> deliverOnMainQueue), for: context.window).start(next: { form, peer in
            let passport = PassportWindowController(context: context, peer: peer, request: value, form: form)
            passport.show()
        }, error: { error in
            switch error {
            case .serverError(let text):
                alert(for: context.window, info: text)
            case .generic:
                alert(for: context.window, info: "An error occured")
            case .versionOutdated:
                updateAppAsYouWish(text: L10n.secureIdAppVersionOutdated, updateApp: true)
            }
        })
        afterComplete(true)
    case let .applyLocalization(_, context, value):
        _ = showModalProgress(signal: requestLocalizationPreview(network: context.account.network, identifier: value) |> deliverOnMainQueue, for: context.window).start(next: { info in
            if appAppearance.language.primaryLanguage.languageCode == info.languageCode {
                alert(for: context.window, info: L10n.applyLanguageChangeLanguageAlreadyActive(info.title))
            } else if info.totalStringCount == 0 {
                confirm(for: context.window, header: L10n.applyLanguageUnsufficientDataTitle, information: L10n.applyLanguageUnsufficientDataText(info.title), cancelTitle: "", thridTitle: L10n.applyLanguageUnsufficientDataOpenPlatform, successHandler: { result in
                    switch result {
                    case .basic:
                        break
                    case .thrid:
                        execute(inapp: inAppLink.external(link: info.platformUrl, false))
                    }
                })
            } else {
                showModal(with: LocalizationPreviewModalController(context, info: info), for: context.window)
            }
           
        }, error: { error in
            switch error {
            case .generic:
                alert(for: context.window, info: L10n.localizationPreviewErrorGeneric)
            }
        })
        afterComplete(true)
    case let .theme(_, context, name):
        _ = showModalProgress(signal: getTheme(account: context.account, slug: name), for: context.window).start(next: { value in
            if value.file == nil, let _ = value.settings {
                showModal(with: ThemePreviewModalController(context: context, source: .cloudTheme(value)), for: context.window)
            } else if value.file == nil {
                showEditThemeModalController(context: context, theme: value)
            } else {
                showModal(with: ThemePreviewModalController(context: context, source: .cloudTheme(value)), for: context.window)
            }
        }, error: { error in
            switch error {
            case .generic:
                alert(for: context.window, info: L10n.themeGetThemeError)
            case .unsupported:
                alert(for: context.window, info: L10n.themeGetThemeError)
            case .slugInvalid:
                alert(for: context.window, info: L10n.themeGetThemeError)
            }
        })
        afterComplete(true)
    case let .unsupportedScheme(_, context, path):
        _ = (getDeepLinkInfo(network: context.account.network, path: path) |> deliverOnMainQueue).start(next: { info in
            if let info = info {
               updateAppAsYouWish(text: info.message, updateApp: info.updateApp)
            }
        })
        afterComplete(true)
    case let .tonTransfer(_, context, data: data):
        if #available(OSX 10.12, *) {

        }
    case .instantView:
        afterComplete(true)
    case let .settings(_, context, section):
        let controller: ViewController
        switch section {
        case .themes:
            controller = AppAppearanceViewController(context: context)
        case .devices:
            controller = RecentSessionsController(context)
        case .folders:
            controller = ChatListFiltersListController(context: context)
        case .privacy:
            controller = PrivacyAndSecurityViewController(context, initialSettings: (nil, nil), focusOnItemTag: .autoArchive)
        }
        context.sharedContext.bindings.rootNavigation().push(controller)
        afterComplete(true)
    case let .joinGroupCall(_, context, peerId, callId):
        selectGroupCallJoiner(context: context, peerId: peerId, completion: { peerId, schedule in
            _ = showModalProgress(signal: requestOrJoinGroupCall(context: context, peerId: peerId, joinAs: context.peerId, initialCall: callId), for: context.window).start(next: { result in
                switch result {
                case let .success(callContext), let .samePeer(callContext):
                    applyGroupCallResult(context.sharedContext, callContext)
                default:
                    alert(for: context.window, info: L10n.errorAnError)
                }
            })
        })
       
        afterComplete(true)
    }
    
}

private func updateAppAsYouWish(text: String, updateApp: Bool) {
    //
    confirm(for: mainWindow, header: appName, information: text, okTitle: updateApp ? L10n.alertButtonOKUpdateApp : L10n.modalOK, cancelTitle: updateApp ? L10n.modalCancel : "", thridTitle: nil, successHandler: { _ in
        if updateApp {
            #if APP_STORE
            execute(inapp: inAppLink.external(link: "https://apps.apple.com/us/app/telegram/id747648890", false))
            #else
            (NSApp.delegate as? AppDelegate)?.checkForUpdates(updateApp)
            #endif
        }
    })
}

func escape(with link:String, addPercent: Bool = true) -> String {
    var escaped = addPercent ? link.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? link : link
    escaped = escaped.replacingOccurrences(of: "%21", with: "!")
    escaped = escaped.replacingOccurrences(of: "%24", with: "$")
    escaped = escaped.replacingOccurrences(of: "%26", with: "&")
    escaped = escaped.replacingOccurrences(of: "%2B", with: "+")
    escaped = escaped.replacingOccurrences(of: "%2C", with: ",")
    escaped = escaped.replacingOccurrences(of: "%2F", with: "/")
    escaped = escaped.replacingOccurrences(of: "%3A", with: ":")
    escaped = escaped.replacingOccurrences(of: "%3B", with: ";")
    escaped = escaped.replacingOccurrences(of: "%3D", with: "=")
    escaped = escaped.replacingOccurrences(of: "%3F", with: "?")
    escaped = escaped.replacingOccurrences(of: "%40", with: "@")
    escaped = escaped.replacingOccurrences(of: "%20", with: " ")
    escaped = escaped.replacingOccurrences(of: "%09", with: "\t")
    escaped = escaped.replacingOccurrences(of: "%23", with: "#")
    escaped = escaped.replacingOccurrences(of: "%3C", with: "<")
    escaped = escaped.replacingOccurrences(of: "%3E", with: ">")
    escaped = escaped.replacingOccurrences(of: "%22", with: "\"")
    escaped = escaped.replacingOccurrences(of: "%0A", with: "\n")
    escaped = escaped.replacingOccurrences(of: "%25", with: "%")
    escaped = escaped.replacingOccurrences(of: "%2E", with: ".")
    escaped = escaped.replacingOccurrences(of: "%2C", with: ",")
    escaped = escaped.replacingOccurrences(of: "%7D", with: "}")
    escaped = escaped.replacingOccurrences(of: "%7B", with: "{")
    escaped = escaped.replacingOccurrences(of: "%5B", with: "[")
    escaped = escaped.replacingOccurrences(of: "%5D", with: "]")
    return escaped
}


func urlVars(with url:String) -> ([String:String], Set<String>) {
    var vars:[String:String] = [:]
    let range = url.nsstring.range(of: "?")
    let ns:NSString = range.location != NSNotFound ? url.nsstring.substring(from: range.location + 1).nsstring : url.nsstring
    
    
    let hashes = ns.components(separatedBy: "&")
    var emptyVars:Set<String> = Set()
    for hash in hashes {
       
        let param = hash.components(separatedBy: "=")
        if param.count > 1 {
            if hashes.count == 1 {
                var value: String = param[1]
                for (i, p) in param.enumerated() {
                    if i > 1 {
                        value += "=\(p)"
                    }
                }
                vars[param[0]] = value
            } else {
                vars[param[0]] = param[1]
            }
        } else if param.count == 1 {
            emptyVars.insert(param[0])
        }
    }
    return (vars, emptyVars)
}


enum SecureIdPermission : String {
    case identity = "identity"
    case address = "address"
    case email = "email"
    case phone = "phone"
}

struct inAppSecureIdRequest {
    let peerId: PeerId
    let scope: String
    let callback: String?
    let publicKey: String
    let nonce: Data
    let isModern: Bool
}



enum WallpaperPreview {
    case color(NSColor)
    case slug(String, WallpaperSettings)
    case gradient(NSColor, NSColor, Int32?)
}

enum inAppLink {
    case external(link:String, Bool) // link, confirm
    case peerInfo(link: String, peerId:PeerId, action:ChatInitialAction?, openChat:Bool, postId:Int32?, callback:(PeerId, Bool, MessageId?, ChatInitialAction?)->Void)
    case followResolvedName(link: String, username:String, postId:Int32?, context: AccountContext, action:ChatInitialAction?, callback:(PeerId, Bool, MessageId?, ChatInitialAction?)->Void)
    case comments(link: String, username:String, context: AccountContext, threadId: Int32, commentId: Int32?)
    case inviteBotToGroup(link: String, username:String, context: AccountContext, action:ChatInitialAction?, callback:(PeerId, Bool, MessageId?, ChatInitialAction?)->Void)
    case botCommand(String, (String)->Void)
    case callback(String, (String)->Void)
    case code(String, (String)->Void)
    case hashtag(String, (String)->Void)
    case shareUrl(link: String, AccountContext, String)
    case joinchat(link: String, String, context: AccountContext, callback:(PeerId, Bool, MessageId?, ChatInitialAction?)->Void)
    case logout(()->Void)
    case stickerPack(link: String, StickerPackReference, context: AccountContext, peerId:PeerId?)
    case confirmPhone(link: String, context: AccountContext, phone: String, hash: String)
    case nothing
    case socks(link: String, ProxyServerSettings, applyProxy:(ProxyServerSettings)->Void)
    case requestSecureId(link: String, context: AccountContext, value: inAppSecureIdRequest)
    case unsupportedScheme(link: String, context: AccountContext, path: String)
    case applyLocalization(link: String, context: AccountContext, value: String)
    case wallpaper(link: String, context: AccountContext, preview: WallpaperPreview)
    case theme(link: String, context: AccountContext, name: String)
    case tonTransfer(link: String, context: AccountContext, data: ParsedWalletUrl)
    case instantView(link: String, webpage: TelegramMediaWebpage, anchor: String?)
    case settings(link: String, context: AccountContext, section: InAppSettingsSection)
    case joinGroupCall(link: String, context: AccountContext, peerId: PeerId, call: CachedChannelData.ActiveCall)
    var link: String {
        switch self {
        case let .external(link,_):
            if link.hasPrefix("mailto:") {
                return link.replacingOccurrences(of: "mailto:", with: "")
            }
            return link
        case let .peerInfo(values):
            return values.link
        case let .comments(values):
            return values.link
        case let .followResolvedName(values):
            return values.link
        case let .inviteBotToGroup(values):
            return values.link
        case let .botCommand(link, _), let .callback(link, _), let .code(link, _), let .hashtag(link, _):
            return link
        case let .shareUrl(values):
            return values.link
        case let .joinchat(values):
            return values.link
        case let .stickerPack(values):
            return values.link
        case let .confirmPhone(values):
            return values.link
        case let .socks(values):
            return values.link
        case let .requestSecureId(values):
            return values.link
        case let .unsupportedScheme(values):
            return values.link
        case let .applyLocalization(values):
            return values.link
        case let .wallpaper(values):
            return values.link
        case let .theme(values):
            return values.link
        case let .tonTransfer(link, _, _):
            return link
        case let .instantView(link, _, _):
            return link
        case let .settings(link, _, _):
            return link
        case let .joinGroupCall(link, _, _, _):
            return link
        case .nothing:
            return ""
        case .logout:
            return ""
        }
    }
}

let telegram_me:[String] = ["telegram.me/","telegram.dog/","t.me/"]
let actions_me:[String] = ["joinchat/","addstickers/","confirmphone","socks", "proxy", "setlanguage", "bg", "addtheme/"]

let telegram_scheme:String = "tg://"
let known_scheme:[String] = ["resolve","msg_url","join","addstickers","confirmphone", "socks", "proxy", "passport", "setlanguage", "bg", "privatepost", "addtheme", "settings"]

let ton_scheme:String = "ton://"

private let keyURLUsername = "domain";
private let keyURLPostId = "post";
private let keyURLCommentId = "comment";
private let keyURLThreadId = "thread";
private let keyURLInvite = "invite";
private let keyURLUrl = "url";
private let keyURLSet = "set";
private let keyURLText = "text";
private let keyURLStart = "start";
private let keyURLVoiceChat = "voicechat";
private let keyURLStartGroup = "startgroup";
private let keyURLSecret = "secret";

private let keyURLPhone = "phone";
private let keyURLHash = "hash";

private let keyURLHost = "server";
private let keyURLPort = "port";
private let keyURLUser = "user";
private let keyURLPass = "pass";

let legacyPassportUsername = "telegrampassport"

func inApp(for url:NSString, context: AccountContext? = nil, peerId:PeerId? = nil, openInfo:((PeerId, Bool, MessageId?, ChatInitialAction?)->Void)? = nil, hashtag:((String)->Void)? = nil, command:((String)->Void)? = nil, applyProxy:((ProxyServerSettings) -> Void)? = nil, confirm: Bool = false) -> inAppLink {
    let external = url
    let urlString = external as String
    let url = url.lowercased.nsstring
    

    
    for domain in telegram_me {
        let range = url.range(of: domain)
        if range.location != NSNotFound && (range.location == 0 || (range.location <= 8 && url.substring(from: range.location - 1).hasPrefix("/"))) {
            let string = external.substring(from: range.location + range.length)
            for action in actions_me {
                if string.hasPrefix(action) {
                    let value = String(string[string.index(string.startIndex, offsetBy: action.length) ..< string.endIndex])
                    switch action {
                    case actions_me[0]:
                        if let openInfo = openInfo, let context = context {
                            return .joinchat(link: urlString, value, context: context, callback: openInfo)
                        }
                    case actions_me[1]:
                        if let context = context {
                            return .stickerPack(link: urlString, StickerPackReference.name(value), context: context, peerId: peerId)
                        }
                    case actions_me[2]:
                        let (vars, _) = urlVars(with: string)
                        if let context = context, let phone = vars[keyURLPhone], let hash = vars[keyURLHash] {
                            return .confirmPhone(link: urlString, context: context, phone: phone, hash: hash)
                        }
                    case actions_me[3]:
                        let (vars, _) = urlVars(with: string)
                        if let applyProxy = applyProxy, let server = vars[keyURLHost], let maybePort = vars[keyURLPort], let port = Int32(maybePort) {
                            let server = escape(with: server)
                            let username = vars[keyURLUser] != nil ? escape(with: vars[keyURLUser]!) : nil
                            let pass = vars[keyURLPass] != nil ? escape(with: vars[keyURLPass]!) : nil
                            return .socks(link: urlString, ProxyServerSettings(host: server, port: port, connection: .socks5(username: username, password: pass)), applyProxy: applyProxy)
                        }
                    case actions_me[4]:
                        let (vars, _) = urlVars(with: string)
                        if let applyProxy = applyProxy, let server = vars[keyURLHost], let maybePort = vars[keyURLPort], let port = Int32(maybePort), let rawSecret = vars[keyURLSecret]  {
                            let server = escape(with: server)
                            if let secret = MTProxySecret.parse(rawSecret)?.serialize() {
                                return .socks(link: urlString, ProxyServerSettings(host: server, port: port, connection: .mtp(secret: secret)), applyProxy: applyProxy)
                            }
                        }
                    case actions_me[5]:
                        if let context = context, !value.isEmpty {
                            return .applyLocalization(link: urlString, context: context, value: String(value[value.index(after: value.startIndex) ..< value.endIndex]))
                        } else {
                            
                        }
                    case actions_me[6]:
                        if !value.isEmpty {
                            let component = String(value[value.index(after: value.startIndex) ..< value.endIndex])
                            if let context = context {
                                if component.count == 6, component.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789abcdefABCDEF").inverted) == nil, let color = NSColor(hexString: "#\(component)") {
                                    return .wallpaper(link: urlString, context: context, preview: .color(color))
                                } else {
                                    
                                    let (vars, emptyVars) = urlVars(with: value)

                                    var rotation:Int32? = vars["rotation"] != nil ? Int32(vars["rotation"]!) : nil
                                    
                                    if let r = rotation {
                                        let available:[Int32] = [0, 45, 90, 135, 180, 225, 270, 310]
                                        if !available.contains(r) {
                                            rotation = nil
                                        }
                                    }
                                    
                                    let components = component.components(separatedBy: "?").first?.components(separatedBy: "-") ?? []
                                    if components.count == 2, let topColor = NSColor(hexString: "#\(components[0])"), let bottomColor = NSColor(hexString: "#\(components[1])")  {
                                        return .wallpaper(link: urlString, context: context, preview: .gradient(topColor, bottomColor, rotation))
                                    }
                                    
                                    var blur: Bool = false
                                    var intensity: Int32? = 80
                                    var color: UInt32? = nil
                                    var bottomColor: UInt32? = nil

                                    if let bgcolor = vars["bg_color"], !bgcolor.isEmpty {
                                        let components = bgcolor.components(separatedBy: "-")
                                        if components.count == 2 {
                                            if let rgb = NSColor(hexString: "#\(components[0])")?.argb {
                                                color = rgb
                                            }
                                            if let rgb = NSColor(hexString: "#\(components[1])")?.argb {
                                                bottomColor = rgb
                                            }
                                        } else if components.count == 1 {
                                            if let rgb = NSColor(hexString: "#\(components[0])")?.argb {
                                                color = rgb
                                            }
                                        }
                                    }
                                    if let intensityString = vars["intensity"] {
                                        intensity = Int32(intensityString)
                                    }
                                    if let mode = vars["mode"] {
                                        blur = mode.contains("blur")
                                    }
                                    
                                    let settings: WallpaperSettings = WallpaperSettings(blur: blur, motion: false, color: color, bottomColor: bottomColor, intensity: intensity, rotation: rotation)
                                    
                                    var slug = component
                                    if let index = component.range(of: "?") {
                                        slug = String(component[component.startIndex ..< index.lowerBound])
                                    }

                                    return .wallpaper(link: urlString, context: context, preview: .slug(slug, settings))
                                }
                            }
                        }
                        return .external(link: url as String, false)
                    case actions_me[7]:
                        let userAndPost = string.components(separatedBy: "/")
                        if userAndPost.count == 2, let context = context {
                            return .theme(link: urlString, context: context, name: userAndPost[1])
                        }
                        return .external(link: url as String, false)
                    default:
                        break
                    }
                }
            }
             if string.range(of: "/") == nil {
                let userAndVariables = string.components(separatedBy: "?")
                let username:String = userAndVariables[0]
                var action:ChatInitialAction? = nil
                if userAndVariables.count == 2 {
                    let (vars, emptyVars) = urlVars(with: userAndVariables[1])
                    loop: for (key,value) in vars {
                        switch key {
                        case keyURLStart:
                            action = .start(parameter: value, behavior: .none)
                            break loop;
                        case keyURLStartGroup:
                            if let openInfo = openInfo, let context = context {
                                return .inviteBotToGroup(link: urlString, username: username, context: context, action: .start(parameter: value, behavior: .automatic), callback: openInfo)
                            }
                            break loop;
                        case keyURLVoiceChat:
                            action = .joinVoiceChat(value)
                            break loop;
                        default:
                            break
                        }
                    }
                    if vars.isEmpty && userAndVariables[1] == keyURLVoiceChat {
                        action = .joinVoiceChat(nil)
                    }
                }

                if let openInfo = openInfo {



                    if username == "iv" || username.isEmpty {
                        return .external(link: url as String, username.isEmpty)
                    } else if let context = context {

                        let joinKeys:[String] = ["+", "%20"]

                        for joinKey in joinKeys {
                            if username.hasPrefix(joinKey), username.length > joinKey.length {
                                return .joinchat(link: url as String, username.nsstring.substring(from: joinKey.length), context: context, callback: openInfo)
                            }
                        }
                        return .followResolvedName(link: urlString, username: username, postId: nil, context: context, action: action, callback: openInfo)
                    }
                }
            } else if let openInfo = openInfo {
                let userAndPost = string.components(separatedBy: "/")
                if userAndPost.count >= 2 {
                    let name = userAndPost[0]
                    
                    if name == "c" {
                        if let context = context {
                            var post = userAndPost.count >= 3 ? (userAndPost[2].isEmpty ? nil : Int32(userAndPost[2])) : nil
                            if userAndPost.count >= 3, let range = userAndPost[2].range(of: "?") {
                                post = Int32(userAndPost[2][..<range.lowerBound])
                            }
                            let (params, _) = urlVars(with: url as String)
                            if let thread = params[keyURLThreadId]?.nsstring.intValue, let post = post {
                                return .comments(link: urlString, username: "_private_\(userAndPost[1])", context: context, threadId: thread, commentId: post)
                            } else {
                                return .followResolvedName(link: urlString, username: "_private_\(userAndPost[1])", postId: post, context: context, action:nil, callback: openInfo)
                            }
                        }
                    } else if name == "s" {
                        return .external(link: url as String, false)
                    } else if name == "addtheme" {
                        if let context = context {
                            return .theme(link: url as String, context: context, name: userAndPost[1])
                        }
                    } else {
                        var post = userAndPost[1].isEmpty ? nil : Int32(userAndPost[1])//.intValue
                        if let range = userAndPost[1].range(of: "?") {
                            post = Int32(userAndPost[1][..<range.lowerBound])
                        }
                        if name.hasPrefix("iv?") {
                            return .external(link: url as String, false)
                        } else if name.hasPrefix("share?") || name == "share" {
                            let (params, _) = urlVars(with: url as String)
                            if let url = params["url"], let context = context {
                                return .shareUrl(link: urlString, context, url)
                            }
                            return .external(link: url as String, false)
                        } else if let context = context {
                            let (params, _) = urlVars(with: url as String)
                            if let comment = params[keyURLCommentId]?.nsstring.intValue, let post = post {
                                return .comments(link: urlString, username: name, context: context, threadId: post, commentId: comment)
                            } else if let thread = params[keyURLThreadId]?.nsstring.intValue, let comment = post {
                                 return .comments(link: urlString, username: name, context: context, threadId: thread, commentId: comment)
                            } else {
                                return .followResolvedName(link: urlString, username: name, postId: post, context: context, action:nil, callback: openInfo)
                            }
                        }
                    }
                }
            }
        }
    }
    
    if url.hasPrefix("@"), let openInfo = openInfo, let context = context {
        return .followResolvedName(link: urlString, username: url.substring(from: 1), postId: nil, context: context, action:nil, callback: openInfo)
    }
    
    if url.hasPrefix("/"), let command = command {
        return .botCommand(url as String, command)
    }
    if url.hasPrefix("#"), let hashtag = hashtag {
        return .hashtag(url as String, hashtag)
    }
    
    if url.hasPrefix(telegram_scheme) {
        let action = url.substring(from: telegram_scheme.length)
        
        let (vars, emptyVars) = urlVars(with: external as String)
        
        for i in 0 ..< known_scheme.count {
            let known = known_scheme[i]
            if action.hasPrefix(known) {
                
                switch known {
                case known_scheme[0]:
                    if let username = vars[keyURLUsername], let openInfo = openInfo {
                        let post = vars[keyURLPostId]?.nsstring.intValue
                        let comment = vars[keyURLCommentId]?.nsstring.intValue
                        let thread = vars[keyURLThreadId]?.nsstring.intValue
                        var action:ChatInitialAction? = nil
                        loop: for (key,value) in vars {
                            switch key {
                            case keyURLStart:
                                action = .start(parameter: value, behavior: .none)
                                break loop;
                            case keyURLStartGroup:
                                if let context = context {
                                    return .inviteBotToGroup(link: urlString, username: username, context: context, action: .start(parameter: value, behavior: .none), callback: openInfo)
                                }
                            case keyURLVoiceChat:
                                action = .joinVoiceChat(value)
                                break loop;
                            default:
                                break
                            }
                        }
                        if action == nil && emptyVars.contains(keyURLVoiceChat) {
                            action = .joinVoiceChat(nil)
                        }
                        if username == legacyPassportUsername {
                            return inApp(for: external.replacingOccurrences(of: "tg://resolve", with: "tg://passport").nsstring, context: context, peerId: peerId, openInfo: openInfo, hashtag: hashtag, command: command, applyProxy: applyProxy, confirm: confirm)
                            //return inapp
                        } else if username == "addtheme", let context = context {
                            return .theme(link: urlString, context: context, name:"")
                        } else if let context = context {
                            if let comment = comment, let post = post {
                                return .comments(link: urlString, username: username, context: context, threadId: post, commentId: comment)
                            } else if let thread = thread, let comment = post {
                                return .comments(link: urlString, username: username, context: context, threadId: thread, commentId: comment)
                            } else {
                                return .followResolvedName(link: urlString, username: username, postId: post, context: context, action: action, callback:openInfo)
                            }
                        }
                    }
                case known_scheme[1]:
                    if let url = vars[keyURLUrl] {
                        let url = url.nsstring.replacingOccurrences(of: "+", with: " ").removingPercentEncoding
                        let text = vars[keyURLText]?.replacingOccurrences(of: "+", with: " ").removingPercentEncoding
                        if let url = url, let context = context {
                            var applied = url
                            if let text = text {
                                applied += "\n" + text
                            }
                            return .shareUrl(link: urlString, context, applied)
                            
                        }
                    }
                case known_scheme[2]:
                    if let invite = vars[keyURLInvite], let openInfo = openInfo, let context = context {
                        return .joinchat(link: urlString, invite, context: context, callback: openInfo)
                    }
                case known_scheme[3]:
                    if let set = vars[keyURLSet], let context = context {
                        return .stickerPack(link: urlString, .name(set), context: context, peerId:nil)
                    }
                case known_scheme[4]:
                    if let context = context, let phone = vars[keyURLPhone], let hash = vars[keyURLHash] {
                        return .confirmPhone(link: urlString, context: context, phone: phone, hash: hash)
                    }
                case known_scheme[5]:
                    if let applyProxy = applyProxy, let server = vars[keyURLHost], let maybePort = vars[keyURLPort], let port = Int32(maybePort) {
                        let server = escape(with: server)
                        return .socks(link: urlString, ProxyServerSettings(host: server, port: port, connection: .socks5(username: vars[keyURLUser], password: vars[keyURLPass])), applyProxy: applyProxy)
                    }
                case known_scheme[6]:
                    if let applyProxy = applyProxy, let server = vars[keyURLHost], let maybePort = vars[keyURLPort], let port = Int32(maybePort), let rawSecret = vars[keyURLSecret] {
                        let server = escape(with: server)
                        if let secret = MTProxySecret.parse(rawSecret)?.serialize() {
                            return .socks(link: urlString, ProxyServerSettings(host: server, port: port, connection: .mtp(secret: secret)), applyProxy: applyProxy)
                        }
                    }
                case known_scheme[7]:
                    if let scope = vars["scope"], let publicKey = vars["public_key"], let rawBotId = vars["bot_id"], let botId = Int32(rawBotId), let context = context {
                        
                        
                        let scope = escape(with: scope, addPercent: false)
                        

                        let isModern: Bool = scope.hasPrefix("{")
                        
                        let nonceString = (isModern ? vars["nonce"] : vars["payload"]) ?? ""

                        let nonce = escape(with: nonceString, addPercent: false).data(using: .utf8) ?? Data()
                        
                        let callbackUrl = vars["callback_url"] != nil ? escape(with: vars["callback_url"]!, addPercent: false) : nil
                        return .requestSecureId(link: urlString, context: context, value: inAppSecureIdRequest(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt32Value(botId)), scope: scope, callback: callbackUrl, publicKey: escape(with: publicKey, addPercent: false), nonce: nonce, isModern: isModern))
                    }
                case known_scheme[8]:
                    if let context = context, let value = vars["lang"] {
                        return .applyLocalization(link: urlString, context: context, value: value)
                    }
                case known_scheme[9]:
                    if let context = context, let value = vars["slug"] {
                        
                        var blur: Bool = false
                        var intensity: Int32? = 80
                        var color: UInt32? = nil
                        var bottomColor: UInt32? = nil
                        
                        var rotation:Int32? = vars["rotation"] != nil ? Int32(vars["rotation"]!) : nil
                        
                        if let r = rotation {
                            let available:[Int32] = [0, 45, 90, 135, 180, 225, 270, 310]
                            if !available.contains(r) {
                                rotation = nil
                            }
                        }

                        
                        if let bgcolor = vars["bg_color"], !bgcolor.isEmpty {
                            let components = bgcolor.components(separatedBy: "-")
                            if components.count == 2 {
                                if let rgb = NSColor(hexString: "#\(components[0])")?.argb {
                                    color = rgb
                                }
                                if let rgb = NSColor(hexString: "#\(components[1])")?.argb {
                                    bottomColor = rgb
                                }
                            } else if components.count == 1 {
                                if let rgb = NSColor(hexString: "#\(components[0])")?.argb {
                                    color = rgb
                                }
                            }
                        }
                        if let mode = vars["mode"] {
                            blur = mode.contains("blur")
                        }
                        if let intensityString = vars["intensity"] {
                            intensity = Int32(intensityString)
                        }
                        
                        let settings: WallpaperSettings = WallpaperSettings(blur: blur, motion: false, color: color, bottomColor: bottomColor, intensity: intensity, rotation: rotation)
                        
                        return .wallpaper(link: urlString, context: context, preview: .slug(value, settings))
                    }
                    if let context = context, let value = vars["color"] {
                        return .wallpaper(link: urlString, context: context, preview: .slug(value, WallpaperSettings()))
                    } else if let context = context, let component = vars["gradient"] {
                        
                        var rotation:Int32? = vars["rotation"] != nil ? Int32(vars["rotation"]!) : nil
                        
                        if let r = rotation {
                            let available:[Int32] = [0, 45, 90, 135, 180, 225, 270, 310]
                            if !available.contains(r) {
                                rotation = nil
                            }
                        }
                        
                        let components = component.components(separatedBy: "?").first?.components(separatedBy: "-") ?? []
                        if components.count == 2, let topColor = NSColor(hexString: "#\(components[0])"), let bottomColor = NSColor(hexString: "#\(components[1])")  {
                            return .wallpaper(link: urlString, context: context, preview: .gradient(topColor, bottomColor, rotation))
                        }
                    }
                case known_scheme[10]:
                    if let username = vars["channel"], let openInfo = openInfo {
                        let post = vars[keyURLPostId]?.nsstring.intValue
                        let threadId = vars[keyURLThreadId]?.nsstring.intValue
                        if let threadId = threadId, let post = post, let context = context {
                            return .comments(link: urlString, username: "_private_\(username)", context: context, threadId: threadId, commentId: post)
                        } else if let context = context {
                            return .followResolvedName(link: urlString, username: "_private_\(username)", postId: post, context: context, action:nil, callback: openInfo)
                        }
                    }
                case known_scheme[11]:
                    if let context = context, let value = vars["slug"] {
                        return .theme(link: urlString, context: context, name: value)
                    }
                case known_scheme[12]:
                    if let context = context, let range = action.range(of: known_scheme[12] + "/") {
                        let section = String(action[range.upperBound...])
                        if let section = InAppSettingsSection(rawValue: section) {
                            return .settings(link: urlString, context: context, section: section)
                        }
                    }
                default:
                    break
                }
               
                return .nothing

            }
        }
        if let context = context {
            var path = url.substring(from: telegram_scheme.length)
            let qLocation = path.nsstring.range(of: "?").location
            path = path.nsstring.substring(to: qLocation != NSNotFound ? qLocation : path.length)
            return .unsupportedScheme(link: urlString, context: context, path: path)
        }
       
    } else if url.hasPrefix(ton_scheme), let context = context {
        return .external(link: url as String, false)
//        let action = url.substring(from: ton_scheme.length)
//        if action.hasPrefix("transfer/") {
//            let (vars, emptyVars) = urlVars(with: url as String)
//            let preAddressLength = ton_scheme.length + "transfer/".length + walletAddressLength
//            let address = urlString.prefix(preAddressLength)
//            if address.length == preAddressLength {
//                let address = String(address.suffix(walletAddressLength))
//                var amount: Int64? = nil
//                var comment: String? = nil
//                if let varAmount = vars["amount"], !varAmount.isEmpty, let intAmount = Int64(varAmount) {
//                    amount = intAmount
//                }
//                if let varComment = vars["text"], !varComment.isEmpty  {
//                    comment = escape(with: varComment, addPercent: false)
//                }
//                return .tonTransfer(link: urlString, context: context, data: ParsedWalletUrl(address: address, amount: amount, comment: comment))
//            }
//        }
        return .nothing
    }
    
    return .external(link: urlString as String, confirm)
}

func addUrlParameter(value: String, to url: String) -> String {
    if let _ = url.range(of: "?") {
        return url + "&" + value
    } else {
        if url.hasSuffix("/") {
            return url + value
        } else {
            return url + "/" + value
        }
    }
}

func makeInAppLink(with action:String, params:[String:Any]) -> String {
    var link = "chat://\(action)/?"
    var first:Bool = true
    for (key,value) in params {
        if !first {
            link += "&"
        } else {
            first = true
        }
        link += "\(key) = \(value)"
    }
    return link
}

func proxySettings(from url:String) -> (ProxyServerSettings?, Bool) {
    let url = url.nsstring
    if url.hasPrefix(telegram_scheme), let _ = URL(string: url as String) {
        let action = url.substring(from: telegram_scheme.length)
        
        let (vars, emptyVars) = urlVars(with: url as String)
        if action.hasPrefix("socks") {
            if let server = vars[keyURLHost], let maybePort = vars[keyURLPort], let port = Int32(maybePort) {
                let server = escape(with: server)
                return (ProxyServerSettings(host: server, port: port, connection: .socks5(username: vars[keyURLUser], password: vars[keyURLPass])), true)
            }
            return (nil , true)
        } else if action.hasPrefix("proxy") {
            if let server = vars[keyURLHost], let maybePort = vars[keyURLPort], let port = Int32(maybePort), let rawSecret = vars[keyURLSecret] {
                let server = escape(with: server)
                if let secret = MTProxySecret.parse(rawSecret)?.serialize() {
                    return (ProxyServerSettings(host: server, port: port, connection: .mtp(secret: secret)), true)
                }
            }
        }
        
    } else if let _ = URL(string: url as String) {
        let link = inApp(for: url, applyProxy: {_ in})
        switch link {
        case let .socks(_, settings, _):
            return (settings, true)
        default:
            break
        }
    }
    return (nil, false)
}

public struct ParsedWalletUrl {
    public let address: String
    public let amount: Int64?
    public let comment: String?
}

//
//public func parseWalletUrl(_ url: URL) -> ParsedWalletUrl? {
//    guard url.scheme == "ton" && url.host == "transfer" else {
//        return nil
//    }
//    var address: String?
//    let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
//    if isValidAddress(path) {
//        address = path
//    }
//    var amount: Int64?
//    var comment: String?
//    if let query = url.query, let components = URLComponents(string: "/?" + query), let queryItems = components.queryItems {
//        for queryItem in queryItems {
//            if let value = queryItem.value {
//                if queryItem.name == "amount", !value.isEmpty, let amountValue = Int64(value) {
//                    amount = amountValue
//                } else if queryItem.name == "text", !value.isEmpty {
//                    comment = value
//                }
//            }
//        }
//    }
//    return address.flatMap { ParsedWalletUrl(address: $0, amount: amount, comment: comment) }
//}



func resolveInstantViewUrl(account: Account, url: String) -> Signal<inAppLink, NoError> {
    return webpagePreview(account: account, url: url)
        |> mapToSignal { webpage -> Signal<inAppLink, NoError> in
            if let webpage = webpage {
                
                if case let .Loaded(content) = webpage.content {
                    if content.instantPage != nil {
                        var anchorValue: String?
                        if let anchorRange = url.range(of: "#") {
                            let anchor = url[anchorRange.upperBound...]
                            if !anchor.isEmpty {
                                anchorValue = String(anchor)
                            }
                        }
                        return .single(.instantView(link: url, webpage: webpage, anchor: anchorValue))
                    } else {
                        return .single(.external(link: url, false))
                    }
                } else {
                    return .complete()
                }
            } else {
                return .single(.external(link: url, false))
            }
    }
}
