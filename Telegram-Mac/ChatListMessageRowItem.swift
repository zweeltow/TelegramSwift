//
//  ChatListMessageRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 11/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox

class ChatListMessageRowItem: ChatListRowItem {

    init(_ initialSize:NSSize,  context: AccountContext, message: Message, query: String, renderedPeer:RenderedPeer, readState: CombinedPeerReadState?) {
        super.init(initialSize, context: context, messages: [message], readState: readState, renderedPeer: renderedPeer, highlightText: query, showBadge: false)
    }
    
    override var stableId: AnyHashable {
        return message!.id
    }
}
