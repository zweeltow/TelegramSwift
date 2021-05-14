//
//  RIghtView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 22/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore



class ChatRightView: View {
    
    private var stateView:ImageView?
    private var readImageView:ImageView?
    private var sendingView:SendingClockProgress?

    private weak var item:ChatRowItem?
    
    var isReversed: Bool {
        guard let item = item else {return false}
        
        return item.isBubbled && !item.isIncoming
    }
    
    func set(item:ChatRowItem, animated:Bool) {
        self.item = item
        self.toolTip = item.fullDate
        item.updateTooltip = { [weak self] value in
            self?.toolTip = value
        }
        if !item.isIncoming || item.isUnsent || item.isFailed
            && !item.chatInteraction.isLogInteraction {
            if item.isUnsent {
                stateView?.removeFromSuperview()
                stateView = nil
                readImageView?.removeFromSuperview()
                readImageView = nil
                if sendingView == nil {
                    sendingView = SendingClockProgress()
                    addSubview(sendingView!)
                    needsLayout = true
                }
            } else {
                
                sendingView?.removeFromSuperview()
                sendingView = nil
                
                
                if let peer = item.peer as? TelegramChannel, peer.isChannel && !item.isFailed {
                    stateView?.removeFromSuperview()
                    stateView = nil
                    readImageView?.removeFromSuperview()
                    readImageView = nil
                } else {
                    let stateImage = item.presentation.chat.stateStateIcon(item)
                    
                    if stateView == nil {
                        stateView = ImageView()
                        self.addSubview(stateView!)
                    }
                    
                    if item.isRead && !item.isFailed && !item.hasSource {
                        if readImageView == nil {
                            readImageView = ImageView()
                            addSubview(readImageView!)
                        }
                        
                    } else {
                        readImageView?.removeFromSuperview()
                        readImageView = nil
                    }
                    
                    stateView?.image = stateImage
                    stateView?.setFrameSize(NSMakeSize(stateImage.backingSize.width, stateImage.backingSize.height))
                }
                
            }
        } else {
            stateView?.removeFromSuperview()
            stateView = nil
            readImageView?.removeFromSuperview()
            readImageView = nil
            sendingView?.removeFromSuperview()
            sendingView = nil
        }
        readImageView?.image = item.presentation.chat.readStateIcon(item)
        readImageView?.sizeToFit()
        sendingView?.set(item: item)
        self.needsLayout = true

    }
    

    override func layout() {
        super.layout()
        if let item = item {
            var rightInset:CGFloat = 0
            if let date = item.date {
                if !isReversed {
                    rightInset = date.0.size.width + (item.isBubbled ? 16 : 20)
                }
            }
            
            if let stateView = stateView {
                rightInset += (isReversed ? stateView.frame.width : 0)
                if isReversed {
                    rightInset += 3
                }
                if item.isFailed {
                    rightInset -= 2
                }
                stateView.setFrameOrigin(frame.width - rightInset - item.stateOverlayAdditionCorner, item.isFailed ? (item.isStateOverlayLayout ? 2 : 1) : (item.isStateOverlayLayout ? 3 : 2))
            }
            
            if let sendingView = sendingView {
                if isReversed {
                    sendingView.setFrameOrigin(frame.width - sendingView.frame.width - item.stateOverlayAdditionCorner, (item.isStateOverlayLayout ? 2 : 1))
                } else {
                    sendingView.setFrameOrigin(frame.width - rightInset - item.stateOverlayAdditionCorner, (item.isStateOverlayLayout ? 2 : 1))
                }
            }

            
            if let readImageView = readImageView {
                readImageView.setFrameOrigin((frame.width - rightInset) + 4 - item.stateOverlayAdditionCorner, (item.isStateOverlayLayout ? 3 : 2))
            }
        }
        self.setNeedsDisplay()
    }
    
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        
        if let item = item {
            
            if item.isStateOverlayLayout {
                ctx.round(frame.size, frame.height/2)
                ctx.setFillColor(item.stateOverlayBackgroundColor.cgColor)
                ctx.fill(layer.bounds)
            }
            
           // super.draw(layer, in: ctx)

            let additional: CGFloat = 0
            
            if let date = item.date {
                date.1.draw(NSMakeRect(frame.width - date.0.size.width - (isReversed ? 16 : 0) - item.stateOverlayAdditionCorner - additional, item.isBubbled ? (item.isStateOverlayLayout ? 2 : 1) : 0, date.0.size.width, date.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                
                if let editLabel = item.editedLabel {
                    editLabel.1.draw(NSMakeRect(frame.width - date.0.size.width - editLabel.0.size.width - item.stateOverlayAdditionCorner - (isReversed || (stateView != nil) ? 23 : 5), item.isBubbled ? (item.isStateOverlayLayout ? 2 : 1) : 0, editLabel.0.size.width, editLabel.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                }
            }
            
            var viewsOffset: CGFloat = 0
            
            if let likes = item.likes {
                viewsOffset += likes.0.size.width + 18
                let icon = item.presentation.chat.likedIcon(item)
                ctx.draw(icon, in: NSMakeRect(likes.0.size.width + 2 + item.stateOverlayAdditionCorner, item.isBubbled ? (item.isStateOverlayLayout ? 1 : 0) : 0, icon.backingSize.width, icon.backingSize.height))
                likes.1.draw(NSMakeRect(item.stateOverlayAdditionCorner, item.isBubbled ? (item.isStateOverlayLayout ? 2 : 1) : 0, likes.0.size.width, likes.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)

            }
            if item.isPinned {
                let icon = item.presentation.chat.messagePinnedIcon(item)
                ctx.draw(icon, in: NSMakeRect(viewsOffset + (item.isStateOverlayLayout ? 4 : 0), item.isBubbled ? (item.isStateOverlayLayout ? 3 : 2) : 2, icon.backingSize.width, icon.backingSize.height))
                viewsOffset += icon.backingSize.width + (item.isStateOverlayLayout ? 4 : 4)
            }
            
            if let channelViews = item.channelViews {
                let icon = item.presentation.chat.channelViewsIcon(item)
                ctx.draw(icon, in: NSMakeRect(channelViews.0.size.width + 2 + item.stateOverlayAdditionCorner + viewsOffset, item.isBubbled ? (item.isStateOverlayLayout ? 1 : 0) : 0, icon.backingSize.width, icon.backingSize.height))
                
                channelViews.1.draw(NSMakeRect(item.stateOverlayAdditionCorner + viewsOffset, item.isBubbled ? (item.isStateOverlayLayout ? 2 : 1) : 0, channelViews.0.size.width, channelViews.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                
                
                if let postAuthor = item.postAuthor {
                    postAuthor.1.draw(NSMakeRect(icon.backingSize.width + channelViews.0.size.width + 8 + item.stateOverlayAdditionCorner + viewsOffset, item.isBubbled ? (item.isStateOverlayLayout ? 2 : 1) : 0, postAuthor.0.size.width, postAuthor.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                    viewsOffset += postAuthor.0.size.width + 8
                }
                viewsOffset += channelViews.0.size.width + 22
            }
            if let replyCount = item.replyCount {
                let icon = item.presentation.chat.repliesCountIcon(item)
                ctx.draw(icon, in: NSMakeRect(replyCount.0.size.width + 2 + item.stateOverlayAdditionCorner + viewsOffset, item.isBubbled ? (item.isStateOverlayLayout ? 3 : 2) : 2, icon.backingSize.width, icon.backingSize.height))
                replyCount.1.draw(NSMakeRect(item.stateOverlayAdditionCorner + viewsOffset, item.isBubbled ? (item.isStateOverlayLayout ? 2 : 1) : 0, replyCount.0.size.width, replyCount.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
            }
            
        }
        
    }
    
    override func mouseUp(with event: NSEvent) {
        superview?.mouseUp(with: event)
    }
    
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
}
