//
//  ChatRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 08/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit



let simpleDif:Int32 = 10 * 60
let forwardDif:Int32 = 10 * 60

func makeChatItems(items:[(Int,TableRowItem)], maxHeight:CGFloat? = nil) -> [(Int,TableRowItem)] {
    var mapped:[(Int,TableRowItem)] = []
    var currentHeight:CGFloat = 0
    for (idx,item) in items {
        let _ = item.makeSize(item.width)
        currentHeight += item.height
        mapped.append((idx, item))
        if let maxHeight = maxHeight {
            if maxHeight < currentHeight {
                break
            }
        }
     }
    return mapped
}





enum ForwardItemType {
    case FullHeader;
    case ShortHeader;
    case Inside;
    case Bottom;
}

enum ChatItemType : Equatable {
    case Full(rank: String?)
    case Short
}

enum ChatItemRenderType {
    case bubble
    case list
}



class ChatRowItem: TableRowItem {
    
    struct RowCaption {
        let id: UInt32
        let offset: NSPoint
        let layout: TextViewLayout
        
        func withUpdatedOffset(_ offset: CGFloat) -> RowCaption {
            return RowCaption(id: self.id, offset: .init(x: 0, y: offset), layout: self.layout)
        }
    }
    
    private(set) var chatInteraction:ChatInteraction
    
    let context: AccountContext
    private(set) var peer:Peer?
    private(set) var entry:ChatHistoryEntry
    private(set) var message:Message?
    
    private var updateCountDownTimer: SwiftSignalKit.Timer?
    var updateTooltip:((String)->Void)? = nil
    var firstMessage: Message? {
        return messages.first
    }
    var lastMessage: Message? {
        return messages.last
    }
    
    var messages: [Message] {
        if let message = message {
            return [message]
        }
        return []
    }
    
    private(set) var itemType:ChatItemType = .Full(rank: nil)
    
    var isFullItemType: Bool {
        if case .Full = itemType {
            return true
        } else {
            return false
        }
    }

    //right view
    private(set) var date:(TextNodeLayout,TextNode)?
    
    private(set) var likesNode:TextNode?
    private(set) var likes:(TextNodeLayout,TextNode)?
    private(set) var likesAttributed:NSAttributedString?
    
    private(set) var channelViewsNode:TextNode?
    private(set) var channelViews:(TextNodeLayout,TextNode)?
    private(set) var channelViewsAttributed:NSAttributedString?
    
    private(set) var replyCountNode:TextNode?
    private(set) var replyCount:(TextNodeLayout,TextNode)?
    private(set) var replyCountAttributed:NSAttributedString?

    
    
    private(set) var postAuthorNode:TextNode?
    private(set) var postAuthor:(TextNodeLayout,TextNode)?
    private(set) var postAuthorAttributed:NSAttributedString?
    
    private(set) var editedLabel:(TextNodeLayout,TextNode)?
   
    private(set) var fullDate:String?
    private(set) var forwardHid: String?
    private(set) var nameHide: String?

	var forwardType:ForwardItemType? {
        didSet {
            
        }
    }
    
    var selectableLayout:[TextViewLayout] {
        return self.captionLayouts.map { $0.layout }
    }
    
    var sending: Bool {
        return message?.flags.contains(.Unsent) ?? false
    }

    private var forwardHeaderNode:TextNode?
    private(set) var forwardHeader:(TextNodeLayout, TextNode)?
    var forwardNameLayout:TextViewLayout?
    var captionLayouts:[RowCaption] = []
    private(set) var authorText:TextViewLayout?
    private(set) var adminBadge:TextViewLayout?

    var replyModel:ReplyModel?
    var replyMarkupModel:ReplyMarkupNode?

    var messageIndex:MessageIndex? {
        if let message = message {
            return MessageIndex(message)
        }
        return nil
    }
    
    var topInset:CGFloat   {
        return 2
    }
    var defaultContentTopOffset:CGFloat {
        if isBubbled {
            return 10
        } else {
            return 6
        }
    }
    
    var rightInset:CGFloat {
        if isBubbled {
            return 15
        } else {
            return chatInteraction.presentation.selectionState != nil ? 42.0 : 20.0
        }
    }
    let leftInset:CGFloat = 20

    
    var _defaultHeight:CGFloat {
        return self.contentOffset.y + defaultContentTopOffset
    }
    
    var _contentSize:NSSize = NSZeroSize;
    var previousBlockWidth:CGFloat = 0;

    var bubbleDefaultInnerInset: CGFloat {
        return bubbleContentInset * 2 + additionBubbleInset
    }
    
    var blockWidth:CGFloat {
        
        var widthForContent: CGFloat = 0
        
        if isBubbled {
            
            var tempWidth: CGFloat = width - self.contentOffset.x - bubbleDefaultInnerInset - (20 + 10 + additionBubbleInset) - 20
            
            if isSharable || hasSource {
                tempWidth -= 35
            }
            if isLikable {
                tempWidth -= 35
            }
            widthForContent = min(tempWidth, 450)

            
        } else {
            if case .Full = itemType {
                let additionWidth:CGFloat = date?.0.size.width ?? 20
                widthForContent = width - self.contentOffset.x - 44 - additionWidth
            } else {
                widthForContent = width - self.contentOffset.x - rightSize.width - 44
            }
        }
        
        if forwardType != nil {
            widthForContent -= leftContentInset
        }
        
        return widthForContent
    }
    
    public var rightSize:NSSize {
        
        var size:NSSize = NSZeroSize
        
        if let date = date {
            size = NSMakeSize(date.0.size.width, isBubbled && !isFailed ? 15 : 16)
        }
        
        if let peer = peer as? TelegramChannel, case .broadcast = peer.info, (!isUnsent && !isFailed) {
            size.width += 0
        } else {
            if (!isIncoming || (isUnsent || isFailed)) && date != nil {
                if isBubbled  {
                    size.width += 16
                    if isFailed {
                        size.width += 4
                    }
                } else {
                    size.width += 20
                }
            }
        }
        
        
        
        if let channelViews = channelViews {
            size.width += channelViews.0.size.width + 8 + 16
        }
        if let replyCount = replyCount {
            size.width += replyCount.0.size.width + 18
        }
        if let likes = likes {
            size.width += likes.0.size.width + 18
        }
        if isPinned {
            if self.isStateOverlayLayout {
                size.width += 14
            } else {
                size.width += 18
            }
        }
        
        if let postAuthor = postAuthor {
            size.width += postAuthor.0.size.width + 8
        }
        
        if let editedLabel = editedLabel {
            size.width += editedLabel.0.size.width + 7
        }
        
        size.width = max(isBubbled ? size.width : 54, size.width)
        
        size.width += stateOverlayAdditionCorner * 2
        size.height = isStateOverlayLayout ? 17 : size.height
        return size
        
    }
    
    var stateOverlayAdditionCorner: CGFloat {
        return isStateOverlayLayout ? 5 : 0
    }
    
    var contentSize:NSSize {
        return _contentSize
    }
    
    var realContentSize: NSSize {
        return _contentSize
    }
    
    var isSticker: Bool {
        let file = message?.media.first as? TelegramMediaFile
        return file?.isStaticSticker == true || file?.isAnimatedSticker == true
    }
    

    override var height: CGFloat  {
        var height:CGFloat = self.contentSize.height + _defaultHeight
        
        if !isBubbled, case .Full = self.itemType, self is ChatMessageItem {
            height += 2
        }
        
        if !captionLayouts.isEmpty {
            let captionHeight: CGFloat = captionLayouts.reduce(0, { $0 + $1.layout.layoutSize.height }) + defaultContentInnerInset * CGFloat(captionLayouts.count)
            if let item = self as? ChatGroupedItem {
                switch item.layoutType {
                case .photoOrVideo:
                    height += captionHeight
                case .files:
                    break
                }
            } else {
                height += captionHeight
            }
        }
        if let replyMarkupModel = replyMarkupModel {
            height += replyMarkupModel.size.height + defaultReplyMarkupInset
        }
        
        if isBubbled {
            if let additional = additionalLineForDateInBubbleState {
                height += additional
            }
   
            if hasPhoto || replyModel?.isSideAccessory == true {
                height = max(48, height)
            }
            
            if let _ = commentsBubbleData, hasBubble {
                height += ChatRowItem.channelCommentsBubbleHeight
            }
        }
        

        return max(rightSize.height + 8, height)
    }
    
    var defaultReplyMarkupInset: CGFloat {
        return  (isBubbled ? 4 : defaultContentInnerInset)
    }
    
    var defaultContentInnerInset: CGFloat {
        return 6
    }
    
    var elementsContentInset: CGFloat {
        return 0
    }
    
    var replyOffset:CGFloat {
        var top:CGFloat = defaultContentTopOffset
        if isBubbled && authorText != nil {
            top -= topInset
        } 
        if let author = authorText {
            top += author.layoutSize.height + defaultContentInnerInset
        }
        
        return top
    }
    
    var isBubbleFullFilled: Bool {
        return false
    }
    
    var isStateOverlayLayout: Bool {
        if let message = message, let media = message.media.first {
            if let file = media as? TelegramMediaFile {
                if file.isStaticSticker || file.isAnimatedSticker {
                    return isBubbled
                }
            }
            if media is TelegramMediaDice {
                return isBubbled
            }
            if let media = media as? TelegramMediaMap {
                if let liveBroadcastingTimeout = media.liveBroadcastingTimeout {
                    var time:TimeInterval = Date().timeIntervalSince1970
                    time -= context.timeDifference
                    if Int32(time) < message.timestamp + liveBroadcastingTimeout {
                        return false
                    }
                }
                return media.venue == nil
            }
            return isBubbled && media.isInteractiveMedia && captionLayouts.isEmpty
        }
        return false
    }
    
    private(set) var isForceRightLine: Bool = false
    
    var forwardHeaderInset:NSPoint {
        
        var top:CGFloat = defaultContentTopOffset
        
        if !isBubbled, forwardHeader == nil {
            top -= topInset
        }
        
        if let author = authorText {
            top += author.layoutSize.height
        }
        
        return NSMakePoint(defLeftInset, top)
    }
    
    var forwardNameInset:NSPoint {
        var top:CGFloat = forwardHeaderInset.y
        
        if let header = forwardHeader, !isBubbled {
            top += header.0.size.height + defaultContentInnerInset
        }
        
        return NSMakePoint(self.contentOffset.x, top)
    }
    
    var gameInset: NSPoint {
        return NSMakePoint(contentOffset.x - 10, contentOffset.y)
    }
    
    var defLeftInset:CGFloat {
        var inset: CGFloat = leftInset
        if isBubbled {
            if hasPhoto {
                inset += 36 + 6
            }
        } else {
            inset += 36 + 10
        }
        
        return inset
    }
    
    var hasPhoto: Bool {
        if !isBubbled {
            if case .Full = itemType {
                return true
            } else {
                return false
            }
        } else {
            if case .Full = itemType, let message = message, let peer = message.peers[message.id.peerId] {
                switch chatInteraction.chatLocation {
                case .peer, .replyThread:
                    if chatInteraction.mode.threadId == effectiveCommentMessage?.id {
                        return false
                    }
                    if (isIncoming && message.id.peerId == context.peerId) {
                        return true
                    }
                    if message.id.peerId == repliesPeerId && message.author?.id != context.peerId {
                        return true
                    }
                    if !peer.isUser && !peer.isSecretChat && !peer.isChannel && isIncoming {
                        return true
                    }
                }
            }
        }
        if chatInteraction.isGlobalSearchMessage {
            return true
        }
        return false
    }
    
    var isInstantVideo: Bool {
        if let media = message?.media.first as? TelegramMediaFile {
            return media.isInstantVideo
        }
        return false
    }
    
    var contentOffset:NSPoint {
        
        var left:CGFloat = defLeftInset
        
        var top:CGFloat = defaultContentTopOffset
        
        
        if let author = authorText {
            top += author.layoutSize.height
            if !isBubbled {
                top += topInset
            }
        }
        
        if let replyModel = replyModel {
            var apply: Bool = true
            if isBubbled {
                if !hasBubble {
                    apply = false
                }
            }
            if apply {
                top += max(34, replyModel.size.height) + ((!isBubbleFullFilled && isBubbled && self is ChatMediaItem) ? 0 : 8)
                if (authorText != nil) && self is ChatMessageItem {
                    top += topInset
                    //top -= defaultContentInnerInset
                } else if hasBubble && self is ChatMessageItem {
                    top -= topInset
                }
            }
        }
        
        if let forwardNameLayout = forwardNameLayout, !isBubbled || !isInstantVideo  {
            top += forwardNameLayout.layoutSize.height
            //if !isBubbled {
                top += 2
            //}
        }
        
        if let forwardType = forwardType, !isBubbled {
            if forwardType == .FullHeader || forwardType == .ShortHeader {
                if let forwardHeader = forwardHeader {
                    top += forwardHeader.0.size.height + defaultContentInnerInset
                } else {
                    top += bubbleDefaultInnerInset
                }
            }
        }
        
        if isBubbled, self is ChatMessageItem {
            top -= 1
        }
        
        
        if forwardNameLayout != nil {
            left += leftContentInset
        }
        
        if let item = self as? ChatMessageItem, item.containsBigEmoji {
            if commentsBubbleDataOverlay != nil || isSharable || hasSource {
                top += 20
            }
        }
        
        return NSMakePoint(left, top)
    }
    
    var leftContentInset: CGFloat {
        return 10
    }
    
    private(set) var isRead:Bool = false
    
    override var stableId: AnyHashable {
        return entry.stableId
    }
    
    var hasSource: Bool {
        switch chatInteraction.mode {
        case .pinned:
            return true
        default:
            if let message = message {
                for attr in message.attributes {
                    if let attr = attr as? SourceReferenceMessageAttribute {
                        if authorIsChannel {
                            return true
                        }
                        return (chatInteraction.peerId == context.peerId && context.peerId != attr.messageId.peerId) || message.id.peerId == repliesPeerId
                    }
                }
            }
        }
        return false
    }
    
    var isSelectedMessage: Bool {
        if let message = message {
            return chatInteraction.presentation.isSelectedMessageId(message.id)
        }
        return false
    }
    
    override var isSelectable: Bool {
        switch chatInteraction.mode {
        case .preview:
            return false
        default:
            return chatInteraction.mode.threadId != effectiveCommentMessage?.id
        }
    }
    
    var disableInteractions: Bool {
        switch chatInteraction.mode {
        case .preview:
            return true
        default:
            return false
        }
    }
    
    
    func openReplyMessage() {
        if let message = message {
            if let replyAttribute = message.replyAttribute {
                if message.id.peerId == repliesPeerId, let threadMessageId = message.replyAttribute?.threadMessageId {
                    chatInteraction.openReplyThread(threadMessageId, false, true, .comments(origin: replyAttribute.messageId))
                } else {
                    chatInteraction.focusMessageId(message.id, replyAttribute.messageId, .CenterEmpty)
                }
            }
        }
        
    }
    
    func gotoSourceMessage() {
        if let message = message {
            switch chatInteraction.mode {
            case .pinned:
                let navigation = chatInteraction.context.sharedContext.bindings.rootNavigation()
                let controller = navigation.previousController as? ChatController
                controller?.chatInteraction.focusPinnedMessageId(message.id)
                navigation.back()
            default:
                for attr in message.attributes {
                    if let attr = attr as? SourceReferenceMessageAttribute {
                        if message.id.peerId == repliesPeerId, let threadMessageId = message.replyAttribute?.threadMessageId {
                            chatInteraction.openReplyThread(threadMessageId, false, true, .comments(origin: attr.messageId))
                        } else {
                            switch chatInteraction.mode {
                            case .replyThread:
                                chatInteraction.focusMessageId(nil, attr.messageId, .CenterEmpty)
                            default:
                                chatInteraction.openInfo(attr.messageId.peerId, true, attr.messageId, nil)
                            }
                        }
                    }
                }
            }
            
        }
    }
    
    var isVideoOrBigEmoji: Bool {
        return self is ChatVideoMessageItem || (message != nil && bigEmojiMessage(context.sharedContext, message: message!))
    }
    
    func share() {
        if let message = message {
            showModal(with: ShareModalController(ShareMessageObject(context, message)), for: mainWindow)
        }
    }
    
    var authorIsChannel: Bool {
        guard let message = message else {
            return false
        }
        return ChatRowItem.authorIsChannel(message: message, account: context.account)
    }
    
    private static func authorIsChannel(message: Message, account: Account) -> Bool {
        
        let isCrosspostFromChannel = message.isCrosspostFromChannel(account: account)
        
        var sourceReference: SourceReferenceMessageAttribute?
        for attribute in message.attributes {
            if let attribute = attribute as? SourceReferenceMessageAttribute {
                sourceReference = attribute
                break
            }
        }
        
        var authorIsChannel: Bool = false
        if let peer = message.peers[message.id.peerId] as? TelegramChannel {
            if case .broadcast = peer.info {
                
            } else {
                if isCrosspostFromChannel, let sourceReference = sourceReference, let _ = message.peers[sourceReference.messageId.peerId] as? TelegramChannel {
                    authorIsChannel = true
                }
            }
        } else {
            if isCrosspostFromChannel, let _ = message.forwardInfo?.source as? TelegramChannel {
                authorIsChannel = true
            }
        }
        
        
        return authorIsChannel
    }
    
    var isLikable: Bool {
        return false
    }
    
    var isLiked: Bool {
        return false
    }
    
    func toggleLike() {
        
    }
    
    override func copyAndUpdate(animated: Bool) {
        if let table = self.table {
            let item = ChatRowItem.item(table.frame.size, from: self.entry, interaction: self.chatInteraction, downloadSettings: self.downloadSettings, theme: self.presentation)
            _ = item.makeSize(table.frame.width, oldWidth: 0)
            let transaction = TableUpdateTransition(deleted: [], inserted: [], updated: [(self.index, item)], animated: animated)
            table.merge(with: transaction)
        }
    }
    
    var shareVisible: Bool {
        
        guard let message = message else {
            return false
        }
        
        if isSharable {
            if message.isScheduledMessage || message.flags.contains(.Sending) || message.flags.contains(.Failed) || message.flags.contains(.Unsent) {
                return false
            } else {
                return true
            }
        }
        return false
    }
    
    var isSharable: Bool {
        var peers:[Peer] = []
        if let peer = peer {
            peers.append(peer)
        }
        
        guard let message = message else {
            return false
        }
        
        if authorIsChannel {
            return false
        }
        
        
        if let info = message.forwardInfo {
            if let author = info.author {
                peers.append(author)
            }
            
            if let peer = info.source {
                peers.append(peer)
            }
        }
        
        for peer in peers {
            if let peer = peer as? TelegramChannel {
                switch peer.info {
                case .broadcast:
                    return !chatInteraction.isLogInteraction
                default:
                    break
                }
            }
            if let peer = peer as? TelegramUser {
                if peer.botInfo != nil {
                    if self is ChatMediaItem && !chatInteraction.isLogInteraction {
                        return true
                    } else if let item = self as? ChatMessageItem {
                        return item.webpageLayout != nil
                    }
                    return false
                }
            }
        }
        
        
        return false
    }
    
    let isScam: Bool
    let isFake: Bool
    private(set) var isForwardScam: Bool
    private(set) var isForwardFake: Bool

    var isFailed: Bool {
        for message in messages {
            if message.flags.contains(.Failed) {
                return true
            }
        }
        return false
    }
    
    var isPinned: Bool {
        for message in messages {
            if message.tags.contains(.pinned) {
                return true
            }
        }
        return false
    }
    
    let isIncoming: Bool
    
    var isUnsent: Bool {
        if entry.additionalData.updatingMedia != nil {
            return true
        }
        if let message = message {
            return message.flags.contains(.Unsent)
        }
        return false
    }
    
    var isEditMarkVisible: Bool {
        var peers:[Peer] = []
        if let peer = peer {
            peers.append(peer)
        }
        if let info = message?.forwardInfo?.author {
            peers.append(info)
        }
        
        for peer in peers {
            if let peer = peer as? TelegramUser {
                if peer.botInfo != nil {
                    return false
                }
            }
        }
        
        for message in messages {
            if message.isScheduledMessage {
                return false
            }
            for attr in message.attributes {
                if attr is InlineBotMessageAttribute {
                    return false
                }
            }
            for media in message.media {
                if media is TelegramMediaMap {
                    return false
                }
            }
            if message.isImported {
                return true
            }
        }
        
        return !chatInteraction.isLogInteraction && message?.id.peerId != context.peerId
    }
    
    private static func canFillAuthorName(_ message: Message, chatInteraction: ChatInteraction, renderType: ChatItemRenderType, isIncoming: Bool, hasBubble: Bool) -> Bool {
        var canFillAuthorName: Bool = true
        switch chatInteraction.chatLocation {
        case .peer, .replyThread:
            if renderType == .bubble, let peer = messageMainPeer(message) {
                canFillAuthorName = isIncoming && (peer.isGroup || peer.isSupergroup || message.id.peerId == chatInteraction.context.peerId || message.id.peerId == repliesPeerId)
                if let media = message.media.first {
                    canFillAuthorName = canFillAuthorName && !media.isInteractiveMedia && hasBubble && isIncoming
                } else if bigEmojiMessage(chatInteraction.context.sharedContext, message: message) {
                    canFillAuthorName = false
                }
                if message.isAnonymousMessage, !isIncoming {
                    var disable: Bool = false
                    if let media = message.media.first as? TelegramMediaFile {
                        if media.isSticker || media.isAnimatedSticker {
                            disable = true
                        }
                    }
                    if !disable {
                        canFillAuthorName = true
                    }
                }
            }
        }
        return canFillAuthorName
    }
    
    var canFillAuthorName: Bool {
        if let message = message {
            return ChatRowItem.canFillAuthorName(message, chatInteraction: chatInteraction, renderType: renderType, isIncoming: isIncoming, hasBubble: hasBubble)
        }
        return true
    }
    
    var isBubbled: Bool {
        return renderType == .bubble
    }
    
    var psaButton: NSAttributedString? {
        if let info = message?.forwardInfo?.psaType {
            let text = localizedPsa("psa.text", type: info)
            
            let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: .white), bold: MarkdownAttributeSet(font: .bold(.text), textColor: .white), link: MarkdownAttributeSet(font: .normal(.text), textColor: .link), linkAttribute: { contents in
                return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents, { url in
                    execute(inapp: .external(link: url, false))
                }))
            }))
            return attributedText
        }
        return nil
    }
    
    var isPsa: Bool {
        return message?.forwardInfo?.psaType != nil
    }
    
    var hasHeader: Bool {
        return !(hasBubble && authorText == nil && replyModel == nil && forwardNameLayout == nil)
    }
    
    var hasBubble: Bool 
    
    static func hasBubble(_ message: Message?, entry: ChatHistoryEntry, type: ChatItemType, sharedContext: SharedAccountContext) -> Bool {
        if let message = message, let media = message.media.first {
            
            if let file = media as? TelegramMediaFile {
                if file.isStaticSticker {
                    return false
                }
                if file.isAnimatedSticker {
                    return false
                }
                if file.isInstantVideo {
                    return false //!message.text.isEmpty || (message.replyAttribute != nil && !file.isInstantVideo) || (message.forwardInfo != nil && !file.isInstantVideo)
                }
            }
            if media is TelegramMediaDice {
                return false
            }
            
            for attr in message.attributes {
                if let _ = attr as? InlineBotMessageAttribute {
                    return true
                }
            }
            
            var peer: Peer?
            for attr in message.attributes {
                if let _ = attr as? SourceReferenceMessageAttribute {
                    if let info = message.forwardInfo {
                        peer = info.author
                    }
                    break
                }
            }
            
            if let _peer = messageMainPeer(message) as? TelegramChannel, case let .broadcast(info) = _peer.info {
                if info.flags.contains(.hasDiscussionGroup) {
                    return true
                }
                peer = _peer
            } else if let author = message.effectiveAuthor, peer == nil {
                if author is TelegramSecretChat {
                    peer = messageMainPeer(message)
                } else {
                    peer = author
                }
            }
            
            if message.groupInfo != nil {
                switch entry {
                case .groupedPhotos(let entries, _):
                    let prettyCount = entries.filter { $0.message?.media.first?.isInteractiveMedia ?? false }.count
                    return !message.text.isEmpty || message.replyAttribute != nil || message.forwardInfo != nil || entries.count == 1 || prettyCount != entries.count
                default:
                    return true
                }
            }
        
        } else if let message = message {
            return !bigEmojiMessage(sharedContext, message: message)
        }
        return true
    }
    
    let renderType: ChatItemRenderType
    var bubbleImage:(CGImage, NSEdgeInsets)? = nil
    var bubbleBorderImage:(CGImage, NSEdgeInsets)? = nil
    
    let downloadSettings: AutomaticMediaDownloadSettings
    
    let presentation: TelegramPresentationTheme


    
    private var _approximateSynchronousValue: Bool = false
    var approximateSynchronousValue: Bool {
        get {
            let result = _approximateSynchronousValue
            _approximateSynchronousValue = false
            return result
        }
    }
    
    private var _avatarSynchronousValue: Bool = false
    var avatarSynchronousValue: Bool {
        get {
            let result = _avatarSynchronousValue
            _avatarSynchronousValue = false
            return result
        }
    }
    
    static var channelCommentsBubbleHeight: CGFloat {
        return 42
    }
    static var channelCommentsHeight: CGFloat {
        return 16
    }
    
    var effectiveCommentMessage: Message? {
        switch entry {
        case let .MessageEntry(message, _, _, _, _, _, _):
            return message
        case let .groupedPhotos(entries, groupInfo: _):
            return entries.first?.message
        default:
            return nil
        }
    }
    
    var channelHasCommentButton: Bool {
        if chatInteraction.mode == .scheduled || chatInteraction.isLogInteraction {
            return false
        }
        if let message = effectiveCommentMessage, let peer = message.peers[message.id.peerId] as? TelegramChannel {
            switch peer.info {
            case let .broadcast(info):
                if info.flags.contains(.hasDiscussionGroup) {
                    if message.flags.contains(.Sending) || message.flags.contains(.Failed) || message.flags.contains(.Unsent) {
                        switch chatInteraction.presentation.discussionGroupId {
                        case .unknown:
                            return false
                        case .known:
                            return true
                        }
                    }
                    for attr in message.attributes {
                        if let attr = attr as? ReplyThreadMessageAttribute {
                            switch chatInteraction.presentation.discussionGroupId {
                            case .unknown:
                                return true
                            case let .known(peerId):
                                return attr.commentsPeerId == peerId
                            }
                        }
                    }
                    
                }
            default:
                break
            }
        }
        
        return false
    }
    
    private var _commentsBubbleData: ChannelCommentsRenderData?
    private var _commentsBubbleDataOverlay: ChannelCommentsRenderData?
    
    var commentsBubbleDataOverlay: ChannelCommentsRenderData? {
        if let commentsBubbleDataOverlay = _commentsBubbleDataOverlay {
            return commentsBubbleDataOverlay
        }
        
        if chatInteraction.isLogInteraction {
            return nil
        }
        
        if !isStateOverlayLayout || hasBubble || !channelHasCommentButton {
            return nil
        }
        if let message = effectiveCommentMessage, let peer = message.peers[message.id.peerId] as? TelegramChannel {
            switch peer.info {
            case let .broadcast(info):
                if info.flags.contains(.hasDiscussionGroup) {
                    var count: Int32 = 0
                    var hasUnread: Bool = false
                    for attr in message.attributes {
                        if let attribute = attr as? ReplyThreadMessageAttribute {
                            count = attribute.count
                            if let maxMessageId = attribute.maxMessageId, let maxReadMessageId = attribute.maxReadMessageId {
                                hasUnread = maxReadMessageId < maxMessageId
                            }
                            break
                        }
                    }
                    let title: String = "\(Int(count).prettyRounded)"
                    let textColor = isBubbled && presentation.backgroundMode.hasWallpaper ? presentation.chatServiceItemTextColor : presentation.colors.accent
                    
                    var texts:[ChannelCommentsRenderData.Text] = []
                    if count > 0 {
                        texts.append(ChannelCommentsRenderData.Text.init(text: .initialize(string: title, color: textColor, font: .normal(.short)), animation: .numeric, index: 0))
                    }
                    
                    _commentsBubbleDataOverlay = ChannelCommentsRenderData(context: chatInteraction.context, message: message, hasUnread: hasUnread, title: texts, peers: [], drawBorder: true, isLoading: entry.additionalData.isThreadLoading, handler: { [weak self] in
                        self?.chatInteraction.openReplyThread(message.id, true, false, .comments(origin: message.id))
                    })
                }
            default:
                break
            }
        }
        return _commentsBubbleDataOverlay
    }
    
    var commentsBubbleData: ChannelCommentsRenderData? {
        if let commentsBubbleData = _commentsBubbleData {
            return commentsBubbleData
        }
        if chatInteraction.isLogInteraction {
            return nil
        }
        if !isBubbled || !channelHasCommentButton {
            return nil
        }
        if isStateOverlayLayout, let media = effectiveCommentMessage?.media.first, !media.isInteractiveMedia || (self is ChatVideoMessageItem) {
            return nil
        }
        if let message = effectiveCommentMessage, let peer = message.peers[message.id.peerId] as? TelegramChannel {
            
            if let messageItem = self as? ChatMessageItem, messageItem.containsBigEmoji  {
                return nil
            }
            
            switch peer.info {
            case let .broadcast(info):
                if info.flags.contains(.hasDiscussionGroup) {
                    
                    var latestPeers:[Peer] = []
                    var count: Int32 = 0
                    var hasUnread = false
                    for attr in message.attributes {
                        if let attribute = attr as? ReplyThreadMessageAttribute {
                            count = attribute.count
                            if let maxMessageId = attribute.maxMessageId {
                                if let maxReadMessageId = attribute.maxReadMessageId {
                                    hasUnread = maxReadMessageId < maxMessageId
                                } else {
                                    hasUnread = false
                                }
                            }
                            latestPeers = message.peers.filter { peerId, _ -> Bool in
                                return attribute.latestUsers.contains(peerId)
                            }.map { $0.1 }
                            break
                        }
                    }
                    
                    var title: [(String, ChannelCommentsRenderData.Text.Animation, Int)] = []
                    if count == 0 {
                        title = [(L10n.channelCommentsLeaveComment, .crossFade, 0)]
                    } else {
                        var text = L10n.channelCommentsCountCountable(Int(count))
                        let pretty = "\(Int(count).formattedWithSeparator)"
                        text = text.replacingOccurrences(of: "\(count)", with: pretty)
                        
                        let range = text.nsstring.range(of: pretty)
                        if range.location != NSNotFound {
                            title.append((text.nsstring.substring(to: range.location), .crossFade, 0))
                            var index: Int = 0
                            for _ in range.lowerBound ..< range.upperBound {
                                let symbol = text.nsstring.substring(with: NSMakeRange(range.location + index, 1))
                                title.append((symbol, .numeric, index + 1))
                                index += 1
                            }
                            title.append((text.nsstring.substring(from: range.upperBound), .crossFade, range.length + 1))
                        } else {
                            title.append((text, .crossFade, 0))
                        }
                    }
                    
                    title = title.filter { !$0.0.isEmpty }
                    
                    let texts:[ChannelCommentsRenderData.Text] = title.map {
                        return ChannelCommentsRenderData.Text(text: .initialize(string: $0.0, color: presentation.colors.accentIcon, font: .normal(.title)), animation: $0.1, index: $0.2)
                    }
                    
                    _commentsBubbleData = ChannelCommentsRenderData(context: chatInteraction.context, message: message, hasUnread: hasUnread, title: texts, peers: latestPeers, drawBorder: !isBubbleFullFilled || !captionLayouts.isEmpty, isLoading: entry.additionalData.isThreadLoading, handler: { [weak self] in
                        self?.chatInteraction.openReplyThread(message.id, true, false, .comments(origin: message.id))
                    })
                }
            default:
                break
            }
        }
        return _commentsBubbleData
    }
    
    private var _commentsData: ChannelCommentsRenderData?
    var commentsData: ChannelCommentsRenderData? {
        if let commentsData = _commentsData {
            return commentsData
        }
        if chatInteraction.isLogInteraction {
            return nil
        }
        if isBubbled || !channelHasCommentButton {
            return nil
        }
        if let message = effectiveCommentMessage, let peer = message.peers[message.id.peerId] as? TelegramChannel {
            switch peer.info {
            case let .broadcast(info):
                if info.flags.contains(.hasDiscussionGroup) {
                    var count: Int32 = 0
                    var hasUnread: Bool = false
                    for attr in message.attributes {
                        if let attribute = attr as? ReplyThreadMessageAttribute {
                            count = attribute.count
                            if let maxMessageId = attribute.maxMessageId, let maxReadMessageId = attribute.maxReadMessageId {
                                hasUnread = maxReadMessageId < maxMessageId
                            }
                            break
                        }
                    }
                    var title: [(String, ChannelCommentsRenderData.Text.Animation, Int)] = []
                    if count == 0 {
                        title = [(L10n.channelCommentsShortLeaveComment, .crossFade, 0)]
                    } else {
                        var text = L10n.channelCommentsShortCountCountable(Int(count))
                        let pretty = "\(Int(count).prettyRounded)"
                        text = text.replacingOccurrences(of: "\(count)", with: pretty)
                        
                        let range = text.nsstring.range(of: pretty)
                        if range.location != NSNotFound {
                            title.append((text.nsstring.substring(to: range.location), .crossFade, 0))
                            title.append((text.nsstring.substring(with: range), .numeric, 1))
                            title.append((text.nsstring.substring(from: range.upperBound), .crossFade, 2))
                        } else {
                            title.append((text, .crossFade, 0))
                        }
                    }
                    
                    title = title.filter { !$0.0.isEmpty }
                    
                    let texts:[ChannelCommentsRenderData.Text] = title.map {
                        return ChannelCommentsRenderData.Text(text: .initialize(string: $0.0, color: presentation.colors.accent, font: .normal(.short)), animation: $0.1, index: $0.2)
                    }
                    
                    _commentsData = ChannelCommentsRenderData(context: chatInteraction.context, message: message, hasUnread: hasUnread, title: texts, peers: [], drawBorder: false, isLoading: entry.additionalData.isThreadLoading, handler: { [weak self] in
                        self?.chatInteraction.openReplyThread(message.id, true, false, .comments(origin: message.id))
                    })
                }
            default:
                break
            }
        }
        return _commentsData
    }
    
    var forceBackgroundColor: NSColor? = nil
    
    init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings, theme: TelegramPresentationTheme) {
        self.entry = object
        self.context = chatInteraction.context
        self.presentation = theme
        self.chatInteraction = chatInteraction
        self.downloadSettings = downloadSettings
        self._approximateSynchronousValue = Thread.isMainThread
        self._avatarSynchronousValue = Thread.isMainThread
        var message: Message?
        var isRead: Bool = true
        var itemType: ChatItemType = .Full(rank: nil)
        var fwdType: ForwardItemType? = nil
        var renderType:ChatItemRenderType = .list
        var object = object
        
        var hiddenFwdTooltip:(()->Void)? = nil
        
        var captionMessage: Message? = object.message
        
        var hasGroupCaption: Bool = object.message?.text.isEmpty == false
        if case let .groupedPhotos(entries, _) = object {
            object = entries.filter({!$0.message!.media.isEmpty}).last!
            
            loop: for entry in entries {
                if let _ = captionMessage, !entry.message!.text.isEmpty {
                    captionMessage = nil
                    hasGroupCaption = false
                    break loop
                }
                if !entry.message!.text.isEmpty {
                    captionMessage = entry.message!
                    hasGroupCaption = true
                }
            }
            if captionMessage == nil {
                captionMessage = object.message!
            }
        }
        
        if case let .MessageEntry(_message, _, _isRead, _renderType, _itemType, _fwdType, _) = object {
            message = _message
            isRead = _isRead
            itemType = _itemType
            switch _itemType {
            case .Full:
                fwdType = .FullHeader
            default:
                fwdType = _fwdType
            }
            renderType = _renderType
        }
        
        var stateOverlayTextColor: NSColor {
            if let media = message?.media.first, media.isInteractiveMedia || media is TelegramMediaMap {
                 return NSColor(0xffffff)
            } else {
                return theme.chatServiceItemTextColor
            }
        }
        
        var isStateOverlayLayout: Bool {
            if renderType == .bubble, let message = captionMessage, let media = message.media.first {
                if let file = media as? TelegramMediaFile {
                    if file.isStaticSticker || file.isAnimatedSticker {
                        return renderType == .bubble
                    }
                    
                }
                if media is TelegramMediaDice {
                    return renderType == .bubble
                }
                if let media = media as? TelegramMediaMap {
                    if let liveBroadcastingTimeout = media.liveBroadcastingTimeout {
                        var time:TimeInterval = Date().timeIntervalSince1970
                        time -= context.timeDifference
                        if Int32(time) < message.timestamp + liveBroadcastingTimeout {
                            return false
                        }
                    }
                    return media.venue == nil
                }
                return media.isInteractiveMedia && !hasGroupCaption
            } else if let message = message, bigEmojiMessage(context.sharedContext, message: message), renderType == .bubble {
                return true
            }
            return false
        }
        
        if message?.id.peerId == context.peerId {
            itemType = .Full(rank: nil)
        }
        self.renderType = renderType
        self.message = message
        
        var isForwardScam: Bool = false
        var isScam = false
        var isForwardFake: Bool = false
        var isFake = false
        if let message = message, let peer = messageMainPeer(message) {
            if peer.isGroup || peer.isSupergroup {
                if let author = message.forwardInfo?.author {
                    isForwardScam = author.isScam
                }
                if let author = message.author, case .Full = itemType {
                    isScam = author.isScam
                }
                if let author = message.forwardInfo?.author {
                    isForwardFake = author.isFake
                }
                if let author = message.author, case .Full = itemType {
                    isFake = author.isFake
                }
            }
        }
        self.isScam = isScam
        self.isForwardScam = isForwardScam
            
        self.isFake = isFake
        self.isForwardFake = isForwardFake
        
        if let message = message {
            let isBubbled = renderType == .bubble
            let hasBubble = ChatRowItem.hasBubble(captionMessage ?? message, entry: entry, type: itemType, sharedContext: context.sharedContext)
            self.hasBubble = isBubbled && hasBubble
            
            let isIncoming: Bool = message.isIncoming(context.account, renderType == .bubble)
            self.isIncoming = isIncoming

            
            if case .bubble = renderType , hasBubble{
                let isFull: Bool
                if case .Full = itemType {
                    switch entry {
                    case let .MessageEntry(message, _, _, _, _, _, _):
                        isFull = chatInteraction.mode.threadId != message.id
                    case let .groupedPhotos(entries, groupInfo: _):
                        isFull = chatInteraction.mode.threadId != entries.first?.message?.id
                    default:
                        isFull = true
                    }
                } else {
                    isFull = false
                }
                let icons = presentation.icons
                let neighbors: MessageBubbleImageNeighbors = isFull && !message.isHasInlineKeyboard ? .none : .both
                bubbleImage = isIncoming ? (neighbors == .none ? icons.chatBubble_none_incoming_withInset : icons.chatBubble_both_incoming_withInset) : (neighbors == .none ? icons.chatBubble_none_outgoing_withInset : icons.chatBubble_both_outgoing_withInset)
                bubbleBorderImage = isIncoming ? (neighbors == .none ? icons.chatBubbleBorder_none_incoming_withInset : icons.chatBubbleBorder_both_incoming_withInset) : (neighbors == .none ? icons.chatBubbleBorder_none_outgoing_withInset : icons.chatBubbleBorder_both_outgoing_withInset)
            }
            
            self.itemType = itemType
            self.isRead = isRead
            
            if let info = message.forwardInfo, message.isImported {
                if let author = info.author {
                    self.peer = author
                } else if let signature = info.authorSignature {
                    
                    self.peer = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt32Value(0)), accessHash: nil, firstName: signature, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
                } else {
                    self.peer = message.chatPeer(context.peerId)
                }
            } else if let info = message.forwardInfo, chatInteraction.peerId == context.account.peerId || (object.renderType == .list && info.psaType != nil) {
                if info.author == nil, let signature = info.authorSignature {
                    self.peer = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt32Value(0)), accessHash: nil, firstName: signature, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
                } else if (object.renderType == .list && info.psaType != nil) {
                    self.peer = info.author ?? message.chatPeer(context.peerId)
                } else {
                    self.peer = message.chatPeer(context.peerId)
                }
            } else {
                self.peer = message.chatPeer(context.peerId)
            }
            
            var isHasSource: Bool = false
            
            for attr in message.attributes {
                if let _ = attr as? SourceReferenceMessageAttribute {
                    isHasSource = true
                    break
                }
            }
            
            if let peer = peer, peer.isChannel {
                for attr in message.attributes {
                    if let attr = attr as? AuthorSignatureMessageAttribute {
                        if !message.flags.contains(.Failed) {
                            postAuthorAttributed = .initialize(string: attr.signature, color: isStateOverlayLayout ? stateOverlayTextColor : !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, object.renderType == .bubble), font: renderType == .bubble ? .italic(.small) : .normal(.short))
                        }
                        break
                    }
                }
            }
            if let peer = peer, peer.isSupergroup, message.isAnonymousMessage {
                for attr in message.attributes {
                    if let attr = attr as? AuthorSignatureMessageAttribute {
                        if !message.flags.contains(.Failed) {
                            let badge: NSAttributedString = .initialize(string: " " + attr.signature, color: !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, object.renderType == .bubble), font: .normal(.short))
                        
                            adminBadge = TextViewLayout(badge, maximumNumberOfLines: 1, truncationType: .end, alignment: .left)
                            adminBadge?.mayItems = false
                            adminBadge?.measure(width: .greatestFiniteMagnitude)
                        }
                        break
                    }
                }
            }
            if postAuthorAttributed == nil, ChatRowItem.authorIsChannel(message: message, account: context.account) {
                if let author = message.forwardInfo?.authorSignature {
                    postAuthorAttributed = .initialize(string: author, color: isStateOverlayLayout ? stateOverlayTextColor : !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, object.renderType == .bubble), font: renderType == .bubble ? .italic(.small) : .normal(.short))
                }
            }
            
            
            if let peer = messageMainPeer(message) as? TelegramUser, peer.botInfo != nil || peer.id == context.peerId {
                self.isRead = true
            }
            
            if let info = message.forwardInfo, !message.isImported {
                
                
                var accept:Bool = !isHasSource && message.id.peerId != context.peerId
                
                if let media = message.media.first as? TelegramMediaFile {
                    if media.isAnimatedSticker {
                        accept = false
                    }
                  
                    for attr in media.attributes {
                        switch attr {
                        case .Sticker:
                            accept = false
                        case let .Audio(isVoice, _, _, _, _):
                            if !isVoice, let forwardInfo = message.forwardInfo, let source = forwardInfo.source, source.isChannel {
                                accept = accept && forwardInfo.author?.id == forwardInfo.source?.id
                            } else {
                                accept = accept && isVoice
                            }
                        default:
                            break
                        }
                    }
                }
                if !hasBubble && renderType == .bubble, message.forwardInfo?.psaType != nil {
                    accept = false
                } else if (entry.renderType == .list && message.forwardInfo?.psaType != nil) {
                    accept = false
                }
                
                if accept || (ChatRowItem.authorIsChannel(message: message, account: context.account) && info.author?.id != message.chatPeer(context.peerId)?.id) {
                    forwardType = fwdType
                    
                    var attr = NSMutableAttributedString()

                    if ChatRowItem.authorIsChannel(message: message, account: context.account) {
                        if let author = info.author {
                            var range = attr.append(string: author.displayTitle, color: presentation.chat.linkColor(isIncoming, object.renderType == .bubble), font: .medium(.text))
                            
                            let appLink = inAppLink.peerInfo(link: "", peerId: author.id, action: nil, openChat: !(author is TelegramUser), postId: info.sourceMessageId?.id, callback: chatInteraction.openInfo)
                            attr.add(link: appLink, for: range, color: presentation.chat.linkColor(isIncoming, object.renderType == .bubble))
                        } else {
                            let range = attr.append(string: info.authorTitle, color: presentation.chat.linkColor(isIncoming, object.renderType == .bubble), font: .normal(.text))
                            attr.add(link: inAppLink.callback("hid", { _ in
                                hiddenFwdTooltip?()
                            }), for: range)
                        }
                    } else {
                        
                        let color: NSColor
                        if message.forwardInfo?.psaType != nil {
                            color = presentation.chat.greenUI(isIncoming, object.renderType == .bubble)
                        } else {
                            color = presentation.chat.linkColor(isIncoming, object.renderType == .bubble)
                        }
                        
                        if let source = info.source, source.isChannel {
                            var range = attr.append(string: source.displayTitle, color: color, font: .medium(.text))
                            if info.author?.id != source.id {
                                let subrange = attr.append(string: " (\(info.authorTitle))", color: color, font: .medium(.text))
                                range.length += subrange.length
                            }
                            
                            let link = source.addressName == nil ? "https://t.me/c/\(source.id.id)/\(info.sourceMessageId?.id != nil ? "\(info.sourceMessageId!.id)" : "")" : "https://t.me/\(source.addressName!)/\(info.sourceMessageId?.id != nil ? "\(info.sourceMessageId!.id)" : "")"
                            let appLink = inApp(for: link.nsstring, context: context, peerId: nil, openInfo: chatInteraction.openInfo)
                            attr.add(link: appLink, for: range, color: color)
                            
                        } else {
                            let range = attr.append(string: info.authorTitle, color: color, font: info.author == nil ? .normal(.text) : .medium(.text))
                            
                            var linkAbility: Bool = true
                            if let channel = info.author as? TelegramChannel {
                                if channel.username == nil && channel.participationStatus != .member {
                                    linkAbility = false
                                }
                            }
                            if linkAbility, let author = info.author {
                                attr.add(link: inAppLink.peerInfo(link: "", peerId: author.id, action:nil, openChat: author.isChannel, postId: info.sourceMessageId?.id, callback:chatInteraction.openInfo), for: range)
                            } else if info.author == nil {
                                attr.add(link: inAppLink.callback("hid", { _ in
                                    hiddenFwdTooltip?()
                                }), for: range)
                                
                            }
                        }
                    }
                    
                    
                    var isInstantVideo: Bool {
                        if let media = message.media.first as? TelegramMediaFile {
                            return media.isInstantVideo
                        }
                        return false
                    }
                    
                    let forwardNameColor: NSColor
                    if message.forwardInfo?.psaType != nil {
                        forwardNameColor = theme.chat.greenUI(isIncoming, object.renderType == .bubble)
                    } else if isForwardScam {
                        forwardNameColor = theme.chat.redUI(isIncoming, object.renderType == .bubble)
                    } else if !hasBubble {
                        forwardNameColor = presentation.colors.grayText
                    } else if isIncoming {
                        forwardNameColor = presentation.chat.linkColor(isIncoming, object.renderType == .bubble)
                    } else {
                        forwardNameColor = presentation.chat.grayText(isIncoming || isInstantVideo, object.renderType == .bubble)
                    }
                    
                    if renderType == .bubble {
                        
                        let text: String
                        if let psaType = message.forwardInfo?.psaType {
                            text = localizedPsa("psa.title.bubbles", type: psaType, args: [attr.string])
                        } else {
                            var fullName = attr.string
                            if let signature = message.forwardInfo?.authorSignature, message.isAnonymousMessage {
                                fullName += " (\(signature))"
                            }
                            text = L10n.chatBubblesForwardedFrom(fullName)
                        }
                        
                        let newAttr = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.short), textColor: forwardNameColor), link: MarkdownAttributeSet(font: hasBubble && info.author != nil ? .medium(.short) : .normal(.short), textColor: forwardNameColor), linkAttribute: { [weak attr] contents in
                            if let attr = attr, !attr.string.isEmpty, let link = attr.attribute(NSAttributedString.Key.link, at: 0, effectiveRange: nil) {
                                return (NSAttributedString.Key.link.rawValue, link)
                            }
                            return nil
                        }))
                        attr = newAttr.mutableCopy() as! NSMutableAttributedString
                    } else {
                        _ = attr.append(string: " ")
                        _ = attr.append(string: DateUtils.string(forLastSeen: info.date), color: renderType == .bubble ? forwardNameColor : presentation.colors.grayText, font: .normal(.short))
                    }

                    
                    forwardNameLayout = TextViewLayout(attr, maximumNumberOfLines: renderType == .bubble ? 2 : 1, truncationType: .end, alwaysStaticItems: true)
                    forwardNameLayout?.interactions = globalLinkExecutor
                }
            }
            
            if case let .Full(rank) = itemType {
                
                
                let canFillAuthorName: Bool = ChatRowItem.canFillAuthorName(message, chatInteraction: chatInteraction, renderType: renderType, isIncoming: isIncoming, hasBubble: hasBubble)

                if isForwardScam || canFillAuthorName {
                    self.isForwardScam = false
                }
                
                var titlePeer:Peer? = self.peer
                
                var title:String = peer?.displayTitle ?? ""
                if object.renderType == .list, let _ = message.forwardInfo?.psaType {
                    
                } else if let peer = messageMainPeer(message) as? TelegramChannel, case .broadcast(_) = peer.info {
                    title = peer.displayTitle
                    titlePeer = peer
                }
                
                let attr:NSMutableAttributedString = NSMutableAttributedString()
                
                if let peer = titlePeer {
                    var nameColor:NSColor = presentation.chat.linkColor(isIncoming, object.renderType == .bubble)
                    
                    if messageMainPeer(message) is TelegramChannel || messageMainPeer(message) is TelegramGroup {
                        if let peer = messageMainPeer(message) as? TelegramChannel, case .broadcast(_) = peer.info {
                            nameColor = presentation.chat.linkColor(isIncoming, object.renderType == .bubble)
                        } else if context.peerId != peer.id {
                            if object.renderType == .bubble, message.isAnonymousMessage, !isIncoming {
                                nameColor = presentation.colors.accentIconBubble_outgoing
                            } else {
                                let value = abs(Int(peer.id.id._internalGetInt32Value()) % 7)
                                nameColor = presentation.chat.peerName(value)
                            }
                        }
                    }
                    
                    if message.forwardInfo?.psaType != nil, object.renderType == .list {
                        nameColor = presentation.colors.greenUI
                    }
                    
                    if canFillAuthorName {
                        let range = attr.append(string: title, color: nameColor, font: .medium(.text))
                        if peer.id.id._internalGetInt32Value() != 0 {
                            attr.addAttribute(NSAttributedString.Key.link, value: inAppLink.peerInfo(link: "", peerId:peer.id, action:nil, openChat: peer.isChannel, postId: nil, callback: chatInteraction.openInfo), range: range)
                        } else {
                            nameHide = L10n.chatTooltipHiddenForwardName
                        }
                    }
                    
                    
                    if let bot = message.inlinePeer, message.hasInlineAttribute, let address = bot.username {
                        if message.forwardInfo?.psaType == nil {
                            if attr.length > 0 {
                                _ = attr.append(string: " ")
                            }
                            _ = attr.append(string: "\(L10n.chatMessageVia) ", color: !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, object.renderType == .bubble), font:.medium(.text))
                            let range = attr.append(string: "@" + address, color: presentation.chat.linkColor(isIncoming, hasBubble && isBubbled), font:.medium(.text))
                            attr.addAttribute(NSAttributedString.Key.link, value: inAppLink.callback("@" + address, { (parameter) in
                                chatInteraction.updateInput(with: parameter + " ")
                            }), range: range)
                        }
                    }
                    if canFillAuthorName {
                        var badge: NSAttributedString? = nil
                        if let rank = rank {
                            badge = .initialize(string: " " + rank, color: !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, object.renderType == .bubble), font: .normal(.short))
                            
                        }
                        else if ChatRowItem.authorIsChannel(message: message, account: context.account) {
                            badge = .initialize(string: " " + L10n.chatChannelBadge, color: !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, object.renderType == .bubble), font: .normal(.short))
                        }
                        if let badge = badge {
                            adminBadge = TextViewLayout(badge, maximumNumberOfLines: 1, truncationType: .end, alignment: .left)
                            adminBadge?.mayItems = false
                            adminBadge?.measure(width: .greatestFiniteMagnitude)
                        }
                    }
                    
                    if attr.length > 0 {
                        authorText = TextViewLayout(attr, maximumNumberOfLines: 1, truncationType: .end, alignment: .left)
                        authorText?.mayItems = false
                        authorText?.interactions = globalLinkExecutor
                    }
                }
                
            }
            if message.timestamp != scheduleWhenOnlineTimestamp {
                var time:TimeInterval = TimeInterval(message.timestamp)
                time -= context.timeDifference
                
                let dateFormatter = DateFormatter()
                dateFormatter.timeStyle = .short
                dateFormatter.dateStyle = .none
                dateFormatter.timeZone = NSTimeZone.local
                
                date = TextNode.layoutText(maybeNode: nil, .initialize(string: dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(time))), color: isStateOverlayLayout ? stateOverlayTextColor : (!hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, object.renderType == .bubble)), font: renderType == .bubble ? .italic(.small) : .normal(.short)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, 20), nil, false, .left)
            }

        } else {
            self.isIncoming = false
            self.hasBubble = false
        }
 
        
        
        super.init(initialSize)
        
        hiddenFwdTooltip = { [weak self] in
            guard let view = self?.view as? ChatRowView, let forwardName = view.forwardName else { return }
            tooltip(for: forwardName, text: L10n.chatTooltipHiddenForwardName, autoCorner: false)
        }
        
        let editedAttribute = messages.compactMap({
            return $0.editedAttribute
        }).sorted(by: {
            $0.date < $1.date
        }).first
        
        
        if let message = message {
            
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            formatter.timeZone = NSTimeZone.local
            //
            var fullDate: String = message.timestamp == scheduleWhenOnlineTimestamp ? "" : formatter.string(from: Date(timeIntervalSince1970: TimeInterval(message.timestamp) - context.timeDifference))
            
            let threadId: MessageId? = chatInteraction.mode.threadId
            
            if let message = effectiveCommentMessage {
                for attribute in message.attributes {
                    if let attribute = attribute as? ReplyThreadMessageAttribute, attribute.count > 0 {
                        if let peer = chatInteraction.peer, peer.isSupergroup, !chatInteraction.mode.isThreadMode {
                            replyCountAttributed = .initialize(string: Int(attribute.count).prettyNumber, color: isStateOverlayLayout ? stateOverlayTextColor : !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, object.renderType == .bubble), font: renderType == .bubble ? .italic(.small) : .normal(.short))
                        }
                        break
                    }
                }
            }
            
            if let attribute = editedAttribute {
                if isEditMarkVisible {
                    editedLabel = TextNode.layoutText(maybeNode: nil, .initialize(string: L10n.chatMessageEdited, color: isStateOverlayLayout ? stateOverlayTextColor : !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, object.renderType == .bubble), font: renderType == .bubble ? .italic(.small) : .normal(.short)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, 20), nil, false, .left)
                }
                
                let formatterEdited = DateFormatter()
                formatterEdited.dateStyle = .medium
                formatterEdited.timeStyle = .medium
                formatterEdited.timeZone = NSTimeZone.local
                fullDate = "\(fullDate) (\(formatterEdited.string(from: Date(timeIntervalSince1970: TimeInterval(attribute.date)))))"
            } else if message.isImported, let forwardInfo = message.forwardInfo  {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                formatter.timeZone = NSTimeZone.local
                formatter.doesRelativeDateFormatting = true
                let text: String
                if forwardInfo.date == message.timestamp {
                    text = L10n.chatMessageImportedShort
                } else {
                   text  = L10n.chatMessageImported(formatter.string(from: Date(timeIntervalSince1970: TimeInterval(forwardInfo.date))))
                }
                editedLabel = TextNode.layoutText(maybeNode: nil, .initialize(string: text, color: isStateOverlayLayout ? stateOverlayTextColor : !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, object.renderType == .bubble), font: renderType == .bubble ? .italic(.small) : .normal(.short)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, 20), nil, false, .left)
                
                fullDate = L10n.chatMessageImportedText + "\n\n" + fullDate
            } else if let forwardInfo = message.forwardInfo {
                let formatterEdited = DateFormatter()
                formatterEdited.dateStyle = .medium
                formatterEdited.timeStyle = .medium
                formatterEdited.timeZone = NSTimeZone.local
                fullDate = "\(fullDate) (\(formatterEdited.string(from: Date(timeIntervalSince1970: TimeInterval(forwardInfo.date)))))"
            }
            
            for attribute in message.attributes {
                if let attribute = attribute as? ReplyMessageAttribute, threadId != attribute.messageId, let replyMessage = message.associatedMessages[attribute.messageId]  {
                    let replyPresentation = ChatAccessoryPresentation(background: hasBubble ? presentation.chat.backgroundColor(isIncoming, object.renderType == .bubble) : isBubbled ?  presentation.colors.grayForeground : presentation.colors.background, title: presentation.chat.replyTitle(self), enabledText: presentation.chat.replyText(self), disabledText: presentation.chat.replyDisabledText(self), border: presentation.chat.replyTitle(self))
                    
                    self.replyModel = ReplyModel(replyMessageId: attribute.messageId, context: context, replyMessage:replyMessage, autodownload: downloadSettings.isDownloable(replyMessage), presentation: replyPresentation, makesizeCallback: { [weak self] in
                        guard let `self` = self else {return}
                        _ = self.makeSize(self.oldWidth, oldWidth: 0)
                        Queue.mainQueue().async { [weak self] in
                            self?.redraw()
                        }
                    })
                    replyModel?.isSideAccessory = isBubbled && !hasBubble
                }
                if let attribute = attribute as? ViewCountMessageAttribute {
                    channelViewsAttributed = .initialize(string: max(1, attribute.count).prettyNumber, color: isStateOverlayLayout ? stateOverlayTextColor : !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, object.renderType == .bubble), font: renderType == .bubble ? .italic(.small) : .normal(.short))
                    
                    var author: String = ""
                    loop: for attr in message.attributes {
                        if let attr = attr as? AuthorSignatureMessageAttribute {
                            author = "\(attr.signature), "
                            break loop
                        }
                    }
                    
                    
                    if attribute.count >= 1000 {
                        fullDate = "\(author)\(attribute.count.separatedNumber) \(tr(L10n.chatMessageTooltipViews)), \(fullDate)"
                    } else {
                        fullDate = "\(author)\(fullDate)"
                    }
                }
               
//                if FastSettings.isTestLiked(message.id) {
//                    likesAttributed = .initialize(string: "1", color: isStateOverlayLayout ? stateOverlayTextColor : !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, object.renderType == .bubble), font: renderType == .bubble ? .italic(.small) : .normal(.short))
//                }
                
                let paid: Bool
                if let invoice = message.media.first as? TelegramMediaInvoice {
                    paid = invoice.receiptMessageId != nil
                } else {
                    paid = false
                }
                if let attribute = attribute as? ReplyMarkupMessageAttribute, attribute.flags.contains(.inline) {
                    if message.restrictedText(context.contentSettings) == nil {
                        replyMarkupModel = ReplyMarkupNode(attribute.rows, attribute.flags, chatInteraction.processBotKeyboard(with: message), paid: paid)
                    }
                }
//                else if let attribute = attribute as? ReactionsMessageAttribute {
//                    var buttons:[ReplyMarkupButton] = []
//                    let sorted = attribute.reactions.sorted(by: { $0.count > $1.count })
//                    for reaction in sorted {
//                        buttons.append(ReplyMarkupButton(title: reaction.value + " \(reaction.count)", titleWhenForwarded: nil, action: .url(reaction.value)))
//                    }
//                    if !buttons.isEmpty {
//                        replyMarkupModel = ReplyMarkupNode([ReplyMarkupRow(buttons: buttons)], [], ReplyMarkupInteractions(proccess: { (button, _) in
//                            switch button.action {
//                            case let .url(buttonReaction):
//                                if let index = sorted.firstIndex(where: { $0.value == buttonReaction}) {
//                                    let reaction = sorted[index]
//                                    var newValues = sorted
//                                    if reaction.isSelected {
//                                        newValues.remove(at: index)
//                                    } else {
//                                        newValues[index] = MessageReaction(value: reaction.value, count: reaction.count + 1, isSelected: true)
//                                    }
//                                    chatInteraction.updateReactions(message.id, buttonReaction, { value in
//                                    })
//                                }
//
//                            default:
//                                break
//                            }
//                        }))
//                    }
//                }
                
                /*
                 let reactions = object.message?.attributes.first(where: { attr -> Bool in
                 return attr is ReactionsMessageAttribute
                 })
                 
                 if let reactions = reactions as? ReactionsMessageAttribute {
                 var bp:Int = 0
                 bp += 1
                 }
 */
              
            }

            if let attr = message.autoremoveAttribute, let begin = attr.countdownBeginTime {
                self.updateCountDownTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
                    let left = Int(begin + attr.timeout - context.timestamp)
                    if left >= 0 {
                        let leftText = "\n\n" + L10n.chatContextMenuAutoDelete(smartTimeleftText(left))
                        self?.fullDate = fullDate + leftText
                        self?.updateTooltip?(fullDate + leftText)
                    } else {
                        self?.updateCountDownTimer = nil
                    }
                }, queue: .mainQueue())
                self.updateCountDownTimer?.start()
            } else {
                updateCountDownTimer = nil
            }
            
            self.fullDate = fullDate
        }
    }
    
    init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ entry: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings, theme: TelegramPresentationTheme) {
        self.entry = entry
        self.context = chatInteraction.context
        self.message = entry.message
        self.chatInteraction = chatInteraction
        self.renderType = entry.renderType
        self.downloadSettings = downloadSettings
        self.presentation = theme
        self.isIncoming = false
        self.hasBubble = false
        self.isScam = false
        self.isForwardScam = false
        self.isFake = false
        self.isForwardFake = false
        super.init(initialSize)
    }
    
    public static func item(_ initialSize:NSSize, from entry:ChatHistoryEntry, interaction:ChatInteraction, downloadSettings: AutomaticMediaDownloadSettings = AutomaticMediaDownloadSettings.defaultSettings, theme: TelegramPresentationTheme) -> TableRowItem {
        
        switch entry {
        case .UnreadEntry:
            return ChatUnreadRowItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
        case .groupedPhotos:
            return ChatGroupedItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
        case .DateEntry:
            return ChatDateStickItem(initialSize, entry, interaction: interaction, theme: theme)
        case .bottom:
            return GeneralRowItem(initialSize, height: theme.bubbled ? 10 : 20, stableId: entry.stableId, backgroundColor: .clear)
        case .commentsHeader:
            return ChatCommentsHeaderItem(initialSize, entry, interaction: interaction, theme: theme)
        case .repliesHeader:
            return RepliesHeaderRowItem(initialSize, entry: entry)
        case let .topThreadInset(height, _, _):
            return GeneralRowItem(initialSize, height: height, stableId: entry.stableId, backgroundColor: .clear)
        default:
            break
        }
        
        if let message = entry.message {
            if message.media.count == 0 || message.media.first is TelegramMediaWebpage {
                return ChatMessageItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
            } else {
                if let action = message.media[0] as? TelegramMediaAction {
                   switch action.action {
                   case .phoneCall:
                       return ChatCallRowItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
                   default:
                       return ChatServiceItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
                   }
               } else if let file = message.media[0] as? TelegramMediaFile {
                    if file.isInstantVideo {
                        return ChatVideoMessageItem(initialSize, interaction, interaction.context,entry, downloadSettings, theme: theme)
                    } else if file.isVideo && !file.isAnimated {
                        return ChatMediaItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
                    } else if file.isStaticSticker {
                        return ChatMediaItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
                    } else if file.isVoice {
                        return ChatVoiceRowItem(initialSize,interaction, interaction.context,entry, downloadSettings, theme: theme)
                    } else if file.isVideo && file.isAnimated {
                        return ChatMediaItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
                    } else if !file.isVideo && (file.isAnimated && !file.mimeType.hasSuffix("gif")) {
                        return ChatMediaItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
                    } else if file.isMusic {
                        return ChatMusicRowItem(initialSize,interaction, interaction.context, entry, downloadSettings, theme: theme)
                    } else if file.isAnimatedSticker {
                        return ChatAnimatedStickerItem(initialSize,interaction, interaction.context, entry, downloadSettings, theme: theme)
                    }
                    return ChatFileMediaItem(initialSize,interaction, interaction.context, entry, downloadSettings, theme: theme)
                } else if message.media[0] is TelegramMediaMap {
                    return ChatMapRowItem(initialSize,interaction, interaction.context, entry, downloadSettings, theme: theme)
                } else if message.media[0] is TelegramMediaContact {
                    return ChatContactRowItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
                } else if message.media[0] is TelegramMediaInvoice {
                    return ChatInvoiceItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
                } else if message.media[0] is TelegramMediaExpiredContent {
                    return ChatServiceItem(initialSize, interaction,interaction.context, entry, downloadSettings, theme: theme)
                } else if message.media.first is TelegramMediaGame {
                    return ChatMessageItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
                } else if message.media.first is TelegramMediaPoll {
                    return ChatPollItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
                } else if message.media.first is TelegramMediaUnsupported {
                    return ChatMessageItem(initialSize, interaction, interaction.context,entry, downloadSettings, theme: theme)
                } else if message.media.first is TelegramMediaDice {
                    return ChatMediaDice(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
                }
                
                return ChatMediaItem(initialSize, interaction, interaction.context, entry, downloadSettings, theme: theme)
            }
            
        }
        
        fatalError("no item for entry")
        
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
                
        let result = super.makeSize(width, oldWidth: oldWidth)
        isForceRightLine = false
        
        commentsBubbleData?.makeSize()
        commentsBubbleDataOverlay?.makeSize()
        commentsData?.makeSize()
        
        if !(self is ChatGroupedItem) {
            for layout in captionLayouts {
                layout.layout.dropLayoutSize()
            }
        }
        
        if let channelViewsAttributed = channelViewsAttributed {
            channelViews = TextNode.layoutText(maybeNode: channelViewsNode, channelViewsAttributed, !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, renderType == .bubble), 1, .end, NSMakeSize(hasBubble ? 60 : max(150,width - contentOffset.x - 44 - 150), 20), nil, false, .left)
        }
        
        if let replyCountAttributed = replyCountAttributed {
            replyCount = TextNode.layoutText(maybeNode: replyCountNode, replyCountAttributed, !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, renderType == .bubble), 1, .end, NSMakeSize(hasBubble ? 60 : max(150,width - contentOffset.x - 44 - 150), 20), nil, false, .left)
        }
        
        if let likesAttributed = likesAttributed {
            likes = TextNode.layoutText(maybeNode: likesNode, likesAttributed, !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, renderType == .bubble), 1, .end, NSMakeSize(hasBubble ? 60 : max(150,width - contentOffset.x - 44 - 150), 20), nil, false, .left)
        }
       
        var widthForContent: CGFloat = blockWidth
        if previousBlockWidth != widthForContent {
            self.previousBlockWidth = widthForContent
            _contentSize = self.makeContentSize(widthForContent)
        }
       

        func layout() -> Bool {
            if additionalLineForDateInBubbleState == nil && !isFixedRightPosition {
                if _contentSize.width + rightSize.width + insetBetweenContentAndDate > widthForContent {
                   // widthForContent = _contentSize.width - 5
                    self.isForceRightLine = true
                    //_contentSize = self.makeContentSize(widthForContent)
                    return true
                }
            }
            return true
        }
        
        if hasBubble {
           
            while !layout() {}
        }
        
        
        
        var maxContentWidth = _contentSize.width
        if hasBubble {
            maxContentWidth -= bubbleDefaultInnerInset
        }
        
        if isBubbled && isBubbleFullFilled {
            widthForContent = maxContentWidth
        }
        if !(self is ChatGroupedItem) {
            for layout in captionLayouts {
                if layout.layout.layoutSize == .zero {
                    layout.layout.measure(width: maxContentWidth)
                }
            }
        }
        
        

        
        if let forwardNameLayout = forwardNameLayout {
            var w = widthForContent
            if isBubbled && !hasBubble {
                w = width - _contentSize.width - 85
            }
            forwardNameLayout.measure(width: min(w, 250))
        }
        
        if (forwardType == .FullHeader || forwardType == .ShortHeader) && (entry.renderType == .bubble || message?.forwardInfo?.psaType == nil) {
            
            let color: NSColor
            let text: String
            if let psaType = message?.forwardInfo?.psaType {
                color = presentation.chat.greenUI(isIncoming, isBubbled)
                text = localizedPsa("psa.title", type: psaType)
            } else {
                color = !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, renderType == .bubble)
                text = L10n.messagesForwardHeader
            }
            
            forwardHeader = TextNode.layoutText(maybeNode: forwardHeaderNode, .initialize(string: text, color: color, font: .normal(.text)), nil, 1, .end, NSMakeSize(width - self.contentOffset.x - 44, 20), nil,false, .left)
        } else {
            forwardHeader = nil
        }
        
        if !isBubbled {
            replyModel?.measureSize(widthForContent, sizeToFit: true)
        } else if let replyModel = replyModel {
            if let item = self as? ChatMessageItem, item.webpageLayout == nil && !replyModel.isSideAccessory {
                if isBubbled {
                    replyModel.measureSize(max(blockWidth, 200), sizeToFit: true)
                } else {
                    replyModel.measureSize(max(contentSize.width, 200), sizeToFit: true)
                }
            } else {
                if !hasBubble {
                    replyModel.measureSize(min(width - _contentSize.width - contentOffset.x - 80, 300), sizeToFit: true)
                } else {
                    replyModel.measureSize(_contentSize.width - bubbleDefaultInnerInset, sizeToFit: true)
                }
            }
        }
        
       
        
        if !canFillAuthorName, let replyModel = replyModel, let authorText = authorText, replyModel.isSideAccessory {
            var adminWidth: CGFloat = 0
            if let adminBadge = adminBadge {
                adminWidth = adminBadge.layoutSize.width
            }
            
            authorText.measure(width: replyModel.size.width - 10 - adminWidth)
            
            replyModel.topOffset = authorText.layoutSize.height + 6
            replyModel.measureSize(replyModel.width, sizeToFit: replyModel.sizeToFit)
        } else {
            var adminWidth: CGFloat = 0
            if let adminBadge = adminBadge {
                adminWidth = adminBadge.layoutSize.width
            }
            
            var supplyOffset: CGFloat = 0
           
//            if let channelViews = channelViews {
//                supplyOffset += channelViews.0.size.width + 16
//            }
//            if let replyCount = replyCount {
//                supplyOffset += replyCount.0.size.width + 16
//            }
//
//            if let _ = postAuthorAttributed {
//                supplyOffset += 50
//            }
//            if let commentsData = commentsData {
//                supplyOffset += commentsData.size(false).width
//            }
            if !isBubbled {
                supplyOffset += rightSize.width
            }
            
            authorText?.measure(width: widthForContent - adminWidth - supplyOffset)
            
        }
      
       
        if let postAuthorAttributed = postAuthorAttributed {
            
            postAuthor = TextNode.layoutText(maybeNode: postAuthorNode, postAuthorAttributed, !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, renderType == .bubble), 1, .end, NSMakeSize(hasBubble ? 60 : (width - (authorText != nil ? authorText!.layoutSize.width : 0) - contentOffset.x - 44) / 2, 20), nil, false, .left)
        }
        
        if hasBubble && isBubbleFullFilled {
            if let postAuthor = postAuthor, let postAuthorAttributed = postAuthorAttributed {
                let width: CGFloat = _contentSize.width - (rightSize.width - postAuthor.0.size.width - 8) - bubbleContentInset - additionBubbleInset - 10
                if width < 0 {
                    self.postAuthor = nil
                } else {
                    self.postAuthor = TextNode.layoutText(maybeNode: postAuthorNode, postAuthorAttributed, !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, renderType == .bubble), 1, .end, NSMakeSize( width, 20), nil, false, .left)
                }
            }
        }
        
         if hasBubble && !isBubbleFullFilled {
            if let postAuthorAttributed = postAuthorAttributed, let postAuthor = postAuthor {
                if bubbleFrame.width < width - 150 {
                    let size = rightSize.width - postAuthor.0.size.width - 8
                    var w = width - bubbleFrame.width - 150
                    if let _ = self as? ChatMessageItem, additionalLineForDateInBubbleState != nil {
                        w = _contentSize.width - size
                    }
                    self.postAuthor = TextNode.layoutText(maybeNode: postAuthorNode, postAuthorAttributed, !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, renderType == .bubble), 1, .end, NSMakeSize( w, 20), nil, false, .left)
                } else if bubbleFrame.width > _contentSize.width + rightSize.width + bubbleDefaultInnerInset {
                    var size = bubbleFrame.width - (_contentSize.width + rightSize.width + bubbleDefaultInnerInset)
                    if !postAuthor.0.isPerfectSized {
                        size = bubbleFrame.width - (_contentSize.width + bubbleDefaultInnerInset)
                    }
                    self.postAuthor = TextNode.layoutText(maybeNode: postAuthorNode, postAuthorAttributed, !hasBubble ? presentation.colors.grayText : presentation.chat.grayText(isIncoming, renderType == .bubble), 1, .end, NSMakeSize( size, 20), nil, false, .left)
                    while !layout() {}
                }
                
            }
            
            
            
            if _contentSize.width < rightSize.width {
                if !(self is ChatMessageItem)  {
                    _contentSize.width = rightSize.width
                } else if additionalLineForDateInBubbleState != nil {
                    _contentSize.width = rightSize.width
                }
            }
        }
        
        if isBubbled {
            replyMarkupModel?.measureSize(bubbleFrame.width - additionBubbleInset)
        } else {
            if let item = self as? ChatMessageItem {
                if item.webpageLayout != nil {
                    replyMarkupModel?.measureSize(_contentSize.width)
                } else if _contentSize.width < 200 {
                    replyMarkupModel?.measureSize(max(_contentSize.width, blockWidth))
                } else {
                    replyMarkupModel?.measureSize(_contentSize.width)
                }
            } else {
                 replyMarkupModel?.measureSize(_contentSize.width)
            }
        }
        
        
        return result
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    var bubbleContentInset: CGFloat {
        return 13
    }
    
    var additionBubbleInset: CGFloat {
        return 6
    }
    
    var insetBetweenContentAndDate: CGFloat {
        return 10
    }
    
    var bubbleCornerInset: CGFloat {
        if isIncoming {
            if let message = message, let peer = message.peers[message.id.peerId] {
                if peer.isGroup || peer.isSupergroup {
                    return additionBubbleInset + 36
                }
            }
        }
        return additionBubbleInset
    }
    
    var maxTitleWidth: CGFloat {
        let nameWidth:CGFloat
        if hasBubble {
            nameWidth = (authorText?.layoutSize.width ?? 0) + additionBad + (adminBadge?.layoutSize.width ?? 0)
        } else {
            nameWidth = 0
        }

        let forwardWidth = hasBubble ? (forwardNameLayout?.layoutSize.width ?? 0) + additionForwardBad + (isPsa ? 30 : 0) : 0
        
        let replyWidth = min(hasBubble ? (replyModel?.size.width ?? 0) : 0, 200)
        
        return min(max(max(nameWidth, forwardWidth), replyWidth), contentSize.width)
    }
    
    var additionBad: CGFloat {
        return (isScam ? theme.icons.chatScam.backingSize.width + 3 : 0) + (isFake ? theme.icons.chatFake.backingSize.width + 3 : 0)
    }
    var additionForwardBad: CGFloat {
        return (isForwardScam ? theme.icons.chatScam.backingSize.width + 3 : 0) + (isForwardFake ? theme.icons.chatFake.backingSize.width + 3 : 0)
    }
    
    var badIcon: CGImage {
        return isScam ? theme.icons.chatScam : theme.icons.chatFake
    }
    var forwardBadIcon: CGImage {
        return isForwardScam ? theme.icons.chatScam : theme.icons.chatFake
    }
    
    var bubbleFrame: NSRect {
        let nameWidth:CGFloat
        if hasBubble {
            nameWidth = (authorText?.layoutSize.width ?? 0) + additionBad + (adminBadge?.layoutSize.width ?? 0)
        } else {
            nameWidth = 0
        }
        
        let forwardWidth = hasBubble ? (forwardNameLayout?.layoutSize.width ?? 0) + additionForwardBad + (isPsa ? 30 : 0) : 0
        let replyWidth: CGFloat = hasBubble ? (replyModel?.size.width ?? 0) : 0

        var rect = NSMakeRect(defLeftInset, 2, contentSize.width, height - 4)
        
       
        if isBubbled, let replyMarkup = replyMarkupModel {
            rect.size.height -= (replyMarkup.size.height + defaultContentInnerInset)
        }
        
        //if forwardType != nil {
         //   rect.origin.x -= leftContentInset
        //}
        
        if additionalLineForDateInBubbleState == nil && !isFixedRightPosition && rightSize.width > 0 {
            rect.size.width += rightSize.width + insetBetweenContentAndDate + bubbleDefaultInnerInset
        } else {
            rect.size.width += bubbleContentInset * 2 + insetBetweenContentAndDate
        }
        
        
        
        rect.size.width = max(nameWidth + bubbleDefaultInnerInset, rect.width)
        
        rect.size.width = max(rect.size.width, replyWidth + bubbleDefaultInnerInset)
        
        rect.size.width = max(rect.size.width, forwardWidth + bubbleDefaultInnerInset)
        
        if let commentsBubbleData = commentsBubbleData {
            rect.size.width = max(rect.size.width, commentsBubbleData.size(hasBubble, false).width)
        }
        return rect
    }
    
    var isFixedRightPosition: Bool {
        return additionalLineForDateInBubbleState != nil
    }
    
    var additionalLineForDateInBubbleState: CGFloat? {
        return isForceRightLine ? rightSize.height : nil
    }
    
    func deleteMessage() {
        _ = context.account.postbox.transaction { [weak message] transaction -> Void in
            if let message = message {
                if let _ = message.groupingKey {
                    let messages = transaction.getMessageGroup(message.id)
                    if let messages = messages {
                        transaction.deleteMessages(messages.map { $0.id }, forEachMedia: { media in
                            
                        })
                    }
                } else {
                    transaction.deleteMessages([message.id], forEachMedia: { media in
                        
                    })
                }
                
            }
        }.start()
    }
    
    func openInfo() {
        switch chatInteraction.chatLocation {
        case .peer, .replyThread:
            if let peer = peer {
                let messageId: MessageId?
                if chatInteraction.isGlobalSearchMessage {
                    messageId = self.message?.id
                } else {
                    messageId = nil
                }
                if peer.id == self.message?.id.peerId, messageId == nil {
                    chatInteraction.openInfo(peer.id, false, nil, nil)
                } else {
                    chatInteraction.openInfo(peer.id, !(peer is TelegramUser), messageId, nil)
                }
            }
        }
        
    }
    
    func resendMessage(_ ids: [MessageId]) {
       _ = resendMessages(account: context.account, messageIds: ids).start()
    }
    
    func makeContentSize(_ width:CGFloat) -> NSSize {
        
        return NSZeroSize
    }
    
    override func viewClass() -> AnyClass {
        return ChatRowView.self
    }
    
    func replyAction() -> Bool {
        if chatInteraction.presentation.state == .normal, chatInteraction.mode.threadId != effectiveCommentMessage?.id {
            chatInteraction.setupReplyMessage(message?.id)
            return true
        }
        return false
    }
    func editAction() -> Bool {
         if chatInteraction.presentation.state == .normal || chatInteraction.presentation.state == .editing, chatInteraction.mode.threadId != effectiveCommentMessage?.id {
            if let message = message, canEditMessage(message, context: context) {
                chatInteraction.beginEditingMessage(message)
                return true
            }
        }
        return false
    }
    func forwardAction() -> Bool {
        if chatInteraction.presentation.state != .selecting, let message = message {
            if canForwardMessage(message, account: context.account) {
                chatInteraction.forwardMessages([message.id])
                return true
            }
        }
        return false
    }
    
    override var instantlyResize: Bool {
        return forwardType != nil
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        if chatInteraction.disableSelectAbility {
            return super.menuItems(in: location)
        }
        if let message = message {
            return chatMenuItems(for: message, chatInteraction: chatInteraction)
        }
        return super.menuItems(in: location)
    }
    
    var stateOverlayBackgroundColor: NSColor {
        guard let media = self.message?.media.first else {
            return self.presentation.chatServiceItemColor
        }
        if media is TelegramMediaImage {
            return self.presentation.colors.blackTransparent.withAlphaComponent(0.5)
        } else if let media = media as? TelegramMediaFile, media.isVideo && !media.isInstantVideo {
            return self.presentation.colors.blackTransparent.withAlphaComponent(0.5)
        } else if media is TelegramMediaMap {
            return self.presentation.colors.blackTransparent.withAlphaComponent(0.5)
        } else {
            return self.presentation.chatServiceItemColor
        }
    }
    
    var stateOverlayTextColor: NSColor {
       guard let media = self.message?.media.first else {
           return self.presentation.chatServiceItemTextColor
       }
        if let file = media as? TelegramMediaFile, file.isInstantVideo {
            return self.presentation.chatServiceItemTextColor
        } else if media is TelegramMediaMap {
            return NSColor(0xffffff)
        }
        
       if media.isInteractiveMedia {
            return NSColor(0xffffff)
       } else {
           return self.presentation.chatServiceItemTextColor
       }
    }
    var isInteractiveMedia: Bool {
        guard let media = self.message?.media.first else {
            return false
        }
        return media.isInteractiveMedia
    }
}

func chatMenuItems(for message: Message, chatInteraction: ChatInteraction) -> Signal<[ContextMenuItem], NoError> {
    
    let account = chatInteraction.context.account
    let context = chatInteraction.context
    let peerId = chatInteraction.peerId
    let peer = chatInteraction.peer
    let messageId = message.id
    if chatInteraction.isLogInteraction || chatInteraction.presentation.state == .selecting {
        return .single([])
    }
    switch chatInteraction.mode {
    case .preview:
        return .single([])
    default:
        break
    }
    
    var items:[ContextMenuItem] = []
    
    
    if message.id.peerId == repliesPeerId, let author = message.chatPeer(context.peerId), author.id != context.peerId {
        
        let text = author.isUser ? L10n.chatContextBlockUser : L10n.chatContextBlockGroup
        
        items.append(ContextMenuItem(text, handler: {

            let header = author.isUser ? L10n.chatContextBlockUserHeader : L10n.chatContextBlockGroupHeader
            let info = author.isUser ? L10n.chatContextBlockUserInfo(author.displayTitle) : L10n.chatContextBlockGroupInfo(author.displayTitle)
            let third = author.isUser ? L10n.chatContextBlockUserThird : L10n.chatContextBlockGroupThird
            let ok = author.isUser ? L10n.chatContextBlockUserOK : L10n.chatContextBlockGroupOK
            let cancel = author.isUser ? L10n.chatContextBlockUserCancel : L10n.chatContextBlockGroupCancel

            modernConfirm(for: context.window, account: account, peerId: author.id, header: header, information: info, okTitle: ok, cancelTitle: cancel, thridTitle: third, thridAutoOn: true, successHandler: { result in
                switch result {
                case .thrid:
                    let block: Signal<Never, NoError> = context.blockedPeersContext.add(peerId: author.id) |> `catch` { _ in return .complete() }
                    
                    _ = showModalProgress(signal: combineLatest(reportPeerMessages(account: account, messageIds: [message.id], reason: .spam, message: ""), block), for: context.window).start()
                case .basic:
                    _ = showModalProgress(signal: context.blockedPeersContext.add(peerId: author.id), for: context.window).start()
                }
                
            })
        }))
        items.append(ContextSeparatorItem())
    }

    
    if message.isScheduledMessage, let peer = peer {
        items.append(ContextMenuItem(L10n.chatContextScheduledSendNow, handler: {
            _ = sendScheduledMessageNowInteractively(postbox: account.postbox, messageId: message.id).start()
        }))
        items.append(ContextMenuItem(L10n.chatContextScheduledReschedule, handler: {
            showModal(with: DateSelectorModalController(context: context, defaultDate: Date(timeIntervalSince1970: TimeInterval(message.timestamp)), mode: .schedule(peer.id), selectedAt: { date in
                _ = showModalProgress(signal: requestEditMessage(account: account, messageId: message.id, text: message.text, media: .keep, entities: message.textEntities, scheduleTime: Int32(min(date.timeIntervalSince1970, Double(scheduleWhenOnlineTimestamp)))), for: context.window).start(next: { result in
                    
                }, error: { error in
                   
                })
           }), for: context.window)
        }))
        items.append(ContextSeparatorItem())
    }
    
    if canReplyMessage(message, peerId: chatInteraction.peerId, mode: chatInteraction.mode)  {
        items.append(ContextMenuItem(tr(L10n.messageContextReply1) + (FastSettings.tooltipAbility(for: .edit) ? " (\(L10n.messageContextReplyHelp))" : ""), handler: { [unowned chatInteraction] in
            chatInteraction.setupReplyMessage(message.id)
        }))
    }
    if chatInteraction.mode.threadId == nil, let peer = message.peers[message.id.peerId] as? TelegramChannel, peer.isSupergroup {
        if let attr = message.replyThread, attr.count > 0 {
            var messageId: MessageId = message.id
            var modeIsReplies = true
            if let source = message.sourceReference {
                messageId = source.messageId
                if let peer = message.peers[source.messageId.peerId] {
                    if peer.isChannel {
                        modeIsReplies = false
                    }
                }
            }
            
            items.append(ContextMenuItem(modeIsReplies ? L10n.messageContextViewRepliesCountable(Int(attr.count)) : L10n.messageContextViewCommentsCountable(Int(attr.count)), handler: { [unowned chatInteraction] in
                chatInteraction.openReplyThread(messageId, !modeIsReplies, true, modeIsReplies ? .replies(origin: messageId) : .comments(origin: messageId))
            }))
        }
//        if let attr = message.replyAttribute, let threadId = attr.threadMessageId, threadId != message.id {
//            switch chatInteraction.presentation.discussionGroupId {
//            case let .known(peerId):
//                if peerId != nil {
//                    items.append(ContextMenuItem(L10n.messageContextViewThread, handler: {
//                        chatInteraction.openReplyThread(threadId, true, true, .replies(origin: message.id))
//                    }))
//                }
//            default:
//                break
//            }
//        }
    }
    
    if let file = message.media.first as? TelegramMediaFile, file.isEmojiAnimatedSticker {
        items.append(ContextMenuItem(L10n.textCopyText, handler: {
            copyToClipboard(message.text)
        }))
    }
    
    if let peer = message.peers[message.id.peerId] as? TelegramChannel {
        if !message.flags.contains(.Failed), !message.flags.contains(.Unsent), !message.isScheduledMessage {
            items.append(ContextMenuItem(tr(L10n.messageContextCopyMessageLink1), handler: { [unowned chatInteraction] in
                _ = showModalProgress(signal: exportMessageLink(account: account, peerId: peer.id, messageId: message.id, isThread: chatInteraction.mode.threadId != nil), for: context.window).start(next: { link in
                    if let link = link {
                        copyToClipboard(link)
                    }
                })
               
            }))
        }
    }
    
    items.append(ContextSeparatorItem())
    
    if canEditMessage(message, context: context), chatInteraction.mode != .pinned {
        items.append(ContextMenuItem(tr(L10n.messageContextEdit), handler: { [unowned chatInteraction] in
            chatInteraction.beginEditingMessage(message)
        }))
    }
    
    if !message.isScheduledMessage, let peer = message.peers[message.id.peerId], !peer.isDeleted, message.id.namespace == Namespaces.Message.Cloud, peerId == message.id.peerId {
        
        let needUnpin = chatInteraction.presentation.pinnedMessageId?.others.contains(message.id) == true
        let pinAndOld: Bool
        if let pinnedMessage = chatInteraction.presentation.pinnedMessageId, let last = pinnedMessage.others.last {
            pinAndOld = last > message.id
        } else {
            pinAndOld = false
        }
        let pinText = message.tags.contains(.pinned) ? L10n.messageContextUnpin : L10n.messageContextPin

        if let peer = message.peers[message.id.peerId] as? TelegramChannel, peer.hasPermission(.pinMessages) || (peer.isChannel && peer.hasPermission(.editAllMessages)) {
            if !message.flags.contains(.Unsent) && !message.flags.contains(.Failed) {
                if !chatInteraction.mode.isThreadMode, (needUnpin || chatInteraction.mode != .pinned) {
                    items.append(ContextMenuItem(pinText, handler: {
                        if peer.isSupergroup, !needUnpin {
                            modernConfirm(for: context.window, account: account, peerId: nil, information: pinAndOld ? L10n.chatConfirmPinOld : L10n.messageContextConfirmPin1, okTitle:  L10n.messageContextPin, thridTitle: pinAndOld ? nil : L10n.messageContextConfirmNotifyPin, successHandler: { [unowned chatInteraction] result in
                                chatInteraction.updatePinned(message.id, chatInteraction.presentation.pinnedMessageId?.others.contains(message.id) == true, result != .thrid, false)
                            })
                        } else {
                            chatInteraction.updatePinned(message.id, needUnpin, true, false)
                        }
                    }))
                }
            }
        } else if message.id.peerId == account.peerId {
            items.append(ContextMenuItem(pinText, handler: { [unowned chatInteraction] in
                chatInteraction.updatePinned(message.id, needUnpin, true, false)
            }))
        } else if let peer = message.peers[message.id.peerId] as? TelegramGroup, peer.canPinMessage, (needUnpin || chatInteraction.mode != .pinned) {
            items.append(ContextMenuItem(pinText, handler: { [unowned chatInteraction] in
                if !needUnpin {
                    modernConfirm(for: context.window, account: account, peerId: nil, information: pinAndOld ? L10n.chatConfirmPinOld : L10n.messageContextConfirmPin1, okTitle: L10n.messageContextPin, thridTitle: pinAndOld ? nil : L10n.messageContextConfirmNotifyPin, successHandler: { result in
                        chatInteraction.updatePinned(message.id, needUnpin, result == .thrid, false)
                    })
                } else {
                    chatInteraction.updatePinned(message.id, needUnpin, false, false)
                }
            }))
        } else if chatInteraction.presentation.canPinMessage, let peer = chatInteraction.peer, (needUnpin || chatInteraction.mode != .pinned) {
            items.append(ContextMenuItem(pinText, handler: {
                if !needUnpin {
                    modernConfirm(for: context.window, account: account, peerId: nil, information: pinAndOld ? L10n.chatConfirmPinOld : L10n.messageContextConfirmPin1, okTitle: L10n.messageContextPin, thridTitle: L10n.chatConfirmPinFor(peer.displayTitle), thridAutoOn: false, successHandler: { result in
                        chatInteraction.updatePinned(message.id, needUnpin, false, result != .thrid)
                    })
                } else {
                    chatInteraction.updatePinned(message.id, needUnpin, false, false)
                }
            }))
        }
    }
   
    
    if canForwardMessage(message, account: account) {
        items.append(ContextMenuItem(tr(L10n.messageContextForward), handler: { [unowned chatInteraction] in
            chatInteraction.forwardMessages([message.id])
        }))
    } else if message.id.peerId.namespace == Namespaces.Peer.SecretChat, !message.containsSecretMedia {
        items.append(ContextMenuItem(L10n.messageContextShare, handler: { [unowned chatInteraction] in
            chatInteraction.forwardMessages([message.id])
        }))
    }
    
    if canDeleteMessage(message, account: account, mode: chatInteraction.mode) {
        items.append(ContextMenuItem(tr(L10n.messageContextDelete), handler: { [unowned chatInteraction] in
            chatInteraction.deleteMessages([message.id])
        }))
    }
    
    if chatInteraction.mode.threadId != message.id {
        items.append(ContextMenuItem(tr(L10n.messageContextSelect), handler: { [unowned chatInteraction] in
            chatInteraction.withToggledSelectedMessage({$0.withToggledSelectedMessage(message.id)})
        }))
    }
   
    

    
    if canForwardMessage(message, account: account), chatInteraction.peerId != account.peerId, chatInteraction.mode == .history {
        items.append(ContextMenuItem(tr(L10n.messageContextForwardToCloud), handler: { [unowned chatInteraction] in
            _ = Sender.forwardMessages(messageIds: [message.id], context: chatInteraction.context, peerId: account.peerId).start()
        }))
        items.append(ContextSeparatorItem())
    }
    
    
    
   

    
    var signal:Signal<[ContextMenuItem], NoError> = .single(items)
    
    
    if let file = message.media.first as? TelegramMediaFile, let mediaId = file.id {
        signal = signal |> mapToSignal { items -> Signal<[ContextMenuItem], NoError> in
            var items = items
            
            return account.postbox.transaction { transaction -> [ContextMenuItem] in
                if file.isAnimated && file.isVideo {
                    let gifItems = transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudRecentGifs).compactMap {$0.contents as? RecentMediaItem}
                    if let _ = gifItems.firstIndex(where: {$0.media.id == mediaId}) {
                        items.append(ContextMenuItem(L10n.messageContextRemoveGif, handler: {
                            let _ = removeSavedGif(postbox: account.postbox, mediaId: mediaId).start()
                        }))
                    } else {
                        items.append(ContextMenuItem(L10n.messageContextSaveGif, handler: {
                            let _ = addSavedGif(postbox: account.postbox, fileReference: FileMediaReference.message(message: MessageReference(message), media: file)).start()
                        }))
                    }
                }
                return items
            } |> mapToSignal { items in
                var items = items
                
                return combineLatest(queue: .mainQueue(), account.postbox.mediaBox.resourceData(file.resource), fileFinderPath(file, context.account.postbox)) |> mapToSignal { data, downloadPath in
                    if !file.isInteractiveMedia && !file.isVoice && !file.isMusic && !file.isStaticSticker && !file.isGraphicFile && !file.isAnimatedSticker {
                        let quickLook = ContextMenuItem(L10n.contextOpenInQuickLook, handler: {
                            FastSettings.toggleOpenInQuickLook(fileExtenstion(file))
                        })
                        quickLook.state = FastSettings.openInQuickLook(fileExtenstion(file)) ? .on : .off
                        items.append(quickLook)
                    }
                   
                    if data.complete, !message.containsSecretMedia {
                        items.append(ContextMenuItem(tr(L10n.contextCopyMedia), handler: {
                            saveAs(file, account: account)
                        }))
                        
                        #if BETA || ALPHA || DEBUG
                        if file.isAnimatedSticker, let data = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                            items.append(ContextMenuItem("Copy thumbnail (Dev.)", handler: {
                                _ = getAnimatedStickerThumb(data: data).start(next: { path in
                                    if let path = path {
                                        let pb = NSPasteboard.general
                                        pb.clearContents()
                                        pb.writeObjects([NSURL(fileURLWithPath: path)])
                                    }
                                })
                            }))
                        }
                        #endif
                        
                        if let downloadPath = downloadPath {
                            if !file.isVoice {
                                let path: String
                                if FileManager.default.fileExists(atPath: downloadPath) {
                                    path = downloadPath
                                } else {
                                    path = data.path + "." + fileExtenstion(file)
                                    try? FileManager.default.removeItem(atPath: path)
                                    try? FileManager.default.linkItem(atPath: data.path, toPath: path)
                                }
                                let result = ObjcUtils.apps(forFileUrl: path)
                                if let result = result, !result.isEmpty {
                                    let item = ContextMenuItem(L10n.messageContextOpenWith, handler: {})
                                    let menu = NSMenu()
                                    item.submenu = menu
                                    for item in result {
                                        menu.addItem(ContextMenuItem(item.fullname, handler: {
                                            NSWorkspace.shared.openFile(path, withApplication: item.app.path)
                                        }, image: item.icon))
                                    }
                                    items.append(item)
                                }
                            }
                        }
                        
                    }
                    
                    if file.isStaticSticker, let fileId = file.id {
                        return account.postbox.transaction { transaction -> [ContextMenuItem] in
                            let saved = getIsStickerSaved(transaction: transaction, fileId: fileId)
                            items.append(ContextMenuItem( !saved ? tr(L10n.chatContextAddFavoriteSticker) : tr(L10n.chatContextRemoveFavoriteSticker), handler: {
                                
                                if !saved {
                                    _ = addSavedSticker(postbox: account.postbox, network: account.network, file: file).start()
                                } else {
                                    _ = removeSavedSticker(postbox: account.postbox, mediaId: fileId).start()
                                }
                            }))
                            
                            return items
                        }
                    }
                    
                    return .single(items)
                }
            }
            
            
        }
    } else if let image = message.media.first as? TelegramMediaImage {
        signal = signal |> mapToSignal { items -> Signal<[ContextMenuItem], NoError> in
            var items = items
            if let resource = image.representations.last?.resource {
                return account.postbox.mediaBox.resourceData(resource) |> take(1) |> deliverOnMainQueue |> map { data in
                    if data.complete {
                        items.append(ContextMenuItem(tr(L10n.galleryContextCopyToClipboard), handler: {
                            if let path = link(path: data.path, ext: "jpg") {
                                let pb = NSPasteboard.general
                                pb.clearContents()
                                pb.writeObjects([NSURL(fileURLWithPath: path)])
                            }
                        }))
                        items.append(ContextMenuItem(tr(L10n.contextCopyMedia), handler: {
                            savePanel(file: data.path, ext: "jpg", for: mainWindow)
                        }))
                    }
                    return items
                }
            } else {
                return .single(items)
            }
        }
    }
    
    
    signal = signal |> map { [unowned chatInteraction] items in
        if let peer = chatInteraction.peer as? TelegramChannel, peer.isSupergroup, chatInteraction.mode == .history {
            if peer.hasPermission(.banMembers), let author = message.author, author.id != account.peerId, message.isIncoming(account, theme.bubbled) {
                var items = items
                items.append(ContextMenuItem(L10n.chatContextRestrict, handler: {
                    _ = showModalProgress(signal: fetchChannelParticipant(account: account, peerId: chatInteraction.peerId, participantId: author.id), for: mainWindow).start(next: { participant in
                        if let participant = participant {
                            switch participant {
                            case let .member(memberId, _, _, _, _):
                                showModal(with: RestrictedModalViewController(context, peerId: peerId, memberId: memberId, initialParticipant: participant, updated: { updatedRights in
                                    _ = context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(account: context.account, peerId: peerId, memberId: author.id, bannedRights: updatedRights).start()
                                }), for: context.window)
                            default:
                                break
                            }
                        }

                    })
                }))
                return items
            }
        }
        return items
    }
//
    signal = signal |> map { [unowned chatInteraction] items in
        var items = items
        if canReportMessage(message, account), chatInteraction.mode != .pinned {
            items.append(ContextMenuItem(L10n.messageContextReport, handler: {
                _ = reportReasonSelector(context: context).start(next: { value in
                    _ = showModalProgress(signal: reportPeerMessages(account: account, messageIds: [message.id], reason: value.reason, message: value.comment), for: context.window).start(completed: {
                        alert(for: context.window, info: L10n.messageContextReportAlertOK)
                    })
                })
            }))
        }
        return items
    }
    
    signal = signal |> map { [unowned chatInteraction] items in
        var items = items
        if let peer = peer, peer.isGroup || peer.isSupergroup, let author = message.author, chatInteraction.mode == .history {
            items.append(ContextSeparatorItem())
            items.append(ContextMenuItem(L10n.chatServiceSearchAllMessages(author.compactDisplayTitle), handler: {
                chatInteraction.searchPeerMessages(author)
            }))
        }
        return items
    }
    
    signal = signal |> mapToSignal { items in
        return account.pendingUpdateMessageManager.updatingMessageMedia |> take(1) |> deliverOnMainQueue |> map {
            $0[messageId] != nil
        } |> map { editing in
            if editing {
                var items = items
                items.append(ContextSeparatorItem())
                items.append(ContextMenuItem(L10n.chatContextCancelEditing, handler: {
                    account.pendingUpdateMessageManager.cancel(messageId: messageId)
                }))
                return items
            } else {
                return items
            }
        }
    }
    
    return signal
}
