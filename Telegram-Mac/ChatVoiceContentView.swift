//
//  ChatVoiceContentView.swift
//  TelegramMac
//
//  Created by keepcoder on 21/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import TelegramCore
import SyncCore
import TGUIKit
import SwiftSignalKit


class ChatVoiceContentView: ChatAudioContentView {

    var isIncomingConsumed:Bool {
        var isConsumed:Bool = false
        if let parent = parent {
            for attr in parent.attributes {
                if let attr = attr as? ConsumableContentMessageAttribute {
                    isConsumed = attr.consumed
                    break
                }
            }
        }
        return isConsumed
    }
    
    let waveformView:AudioWaveformView
    private var acceptDragging: Bool = false
    private var playAfterDragging: Bool = false
    
    private var downloadingView: RadialProgressView?
    
    required init(frame frameRect: NSRect) {
        waveformView = AudioWaveformView(frame: NSMakeRect(0, 20, 100, 20))
        super.init(frame: frameRect)
        durationView.userInteractionEnabled = false
        addSubview(waveformView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func open() {
        if let parameters = parameters as? ChatMediaVoiceLayoutParameters, let context = context, let parent = parent  {
            if let controller = globalAudio, controller.playOrPause(parent.id) {
            } else {
                let controller:APController
                if parameters.isWebpage {
                    controller = APSingleResourceController(context: context, wrapper: APSingleWrapper(resource: parameters.resource, name: L10n.audioControllerVoiceMessage, performer: parent.author?.displayTitle, duration: Int32(parameters.duration), id: parent.chatStableId), streamable: false, volume: FastSettings.volumeRate)
                } else {
                    controller = APChatVoiceController(context: context, chatLocationInput: parameters.chatLocationInput(), mode: parameters.chatMode, index: MessageIndex(parent), volume: FastSettings.volumeRate)
                }
                parameters.showPlayer(controller)
                controller.start()
            }
        }
    }
    
    var wBackgroundColor:NSColor {
        if let parameters = parameters {
            return parameters.presentation.waveformBackground
        }
        return theme.colors.grayIcon.withAlphaComponent(0.7)
    } 
    var wForegroundColor:NSColor {
        if let parameters = parameters {
            return parameters.presentation.waveformForeground
        }
        return theme.colors.accent
    }
    
    override func checkState(animated: Bool) {
        super.checkState(animated: animated)
   
        
        if  let parameters = parameters as? ChatMediaVoiceLayoutParameters {
            if let parent = parent, let controller = globalAudio, let song = controller.currentSong {
                if song.entry.isEqual(to: parent) {
                    switch song.state {
                    case let .playing(current, _, progress):
                        waveformView.set(foregroundColor: wForegroundColor, backgroundColor: wBackgroundColor)
                        let width = floorToScreenPixels(backingScaleFactor, parameters.waveformWidth * CGFloat(progress))
                        waveformView.foregroundClipingView.change(size: NSMakeSize(width, waveformView.frame.height), animated: animated && !acceptDragging)
                        let layout = parameters.duration(for: current)
                        layout.measure(width: frame.width - 50)
                        durationView.update(layout)
                        break
                    case let .fetching(progress):
                        waveformView.set(foregroundColor: wForegroundColor, backgroundColor: wBackgroundColor)
                        let width = floorToScreenPixels(backingScaleFactor, parameters.waveformWidth * CGFloat(progress))
                        waveformView.foregroundClipingView.change(size: NSMakeSize(width, waveformView.frame.height), animated: animated && !acceptDragging)
                        durationView.update(parameters.durationLayout)
                    case .stoped, .waiting:
                        waveformView.set(foregroundColor: isIncomingConsumed ? wBackgroundColor : wForegroundColor, backgroundColor: wBackgroundColor)
                        waveformView.foregroundClipingView.change(size: NSMakeSize(parameters.waveformWidth, waveformView.frame.height), animated: false)
                        durationView.update(parameters.durationLayout)
                    case let .paused(current, _, progress):
                        waveformView.set(foregroundColor: wForegroundColor, backgroundColor: wBackgroundColor)
                        let width = floorToScreenPixels(backingScaleFactor, parameters.waveformWidth * CGFloat(progress))
                        waveformView.foregroundClipingView.change(size: NSMakeSize(width, waveformView.frame.height), animated: animated && !acceptDragging)
                        let layout = parameters.duration(for: current)
                        layout.measure(width: frame.width - 50)
                        durationView.update(layout)
                    }
                    
                } else {
                    waveformView.set(foregroundColor: isIncomingConsumed ? wBackgroundColor : wForegroundColor, backgroundColor: wBackgroundColor)
                    waveformView.foregroundClipingView.change(size: NSMakeSize(parameters.waveformWidth, waveformView.frame.height), animated: false)
                    durationView.update(parameters.durationLayout)
                }
            } else {
                waveformView.foregroundClipingView.change(size: NSMakeSize(parameters.waveformWidth, waveformView.frame.height), animated: false)
                durationView.update(parameters.durationLayout)
            }
            needsLayout = true

        }
        
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        
        if acceptDragging, let parent = parent, let controller = globalAudio, let song = controller.currentSong {
            if song.entry.isEqual(to: parent) {
                let point = waveformView.convert(event.locationInWindow, from: nil)
                let progress = Float(min(max(point.x, 0), waveformView.frame.width)/waveformView.frame.width)
                switch song.state {
                case .playing:
                    _ = controller.pause()
                    playAfterDragging = true
                default:
                    break
                }
                controller.set(trackProgress: progress)
            } else {
                super.mouseDragged(with: event)
            }
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        acceptDragging = waveformView.mouseInside()
        if !acceptDragging {
            super.mouseDown(with: event)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if acceptDragging && playAfterDragging {
            _ = globalAudio?.play()
        }
        playAfterDragging = false
        acceptDragging = false
    }
    
    override func update(with media: Media, size: NSSize, context: AccountContext, parent: Message?, table: TableView?, parameters: ChatMediaLayoutParameters?, animated: Bool = false, positionFlags: LayoutPositionFlags? = nil, approximateSynchronousValue: Bool = false) {
        super.update(with: media, size: size, context: context, parent: parent, table: table, parameters: parameters, animated: animated, positionFlags: positionFlags)
        
        
        var updatedStatusSignal: Signal<MediaResourceStatus, NoError>
        
        let file:TelegramMediaFile = media as! TelegramMediaFile
        
      //  self.progressView.state = .None
 
        if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
            updatedStatusSignal = combineLatest(chatMessageFileStatus(account: context.account, file: file), context.account.pendingMessageManager.pendingMessageStatus(parent.id))
                |> map { resourceStatus, pendingStatus -> MediaResourceStatus in
                    if let pendingStatus = pendingStatus.0 {
                        return .Fetching(isActive: true, progress: pendingStatus.progress)
                    } else {
                        return resourceStatus
                    }
                } |> deliverOnMainQueue
        } else {
            updatedStatusSignal = chatMessageFileStatus(account: context.account, file: file, approximateSynchronousValue: approximateSynchronousValue) |> deliverOnMainQueue
        }
        
        self.statusDisposable.set((updatedStatusSignal |> deliverOnMainQueue).start(next: { [weak self] status in
            if let strongSelf = self {
                strongSelf.fetchStatus = status
                
                var state: RadialProgressState? = nil
                switch status {
                case let .Fetching(_, progress):
                    state = .Fetching(progress: progress, force: false)
                    strongSelf.progressView.state = .Fetching(progress: progress, force: false)
                case .Remote:
                    state = .Remote
                    strongSelf.progressView.state = .Remote
                case .Local:
                    strongSelf.progressView.state = .Play
                }
                if let state = state {
                    let current: RadialProgressView
                    if let value = strongSelf.downloadingView {
                        current = value
                    } else {
                        current = RadialProgressView(theme: strongSelf.progressView.theme, twist: true, size: NSMakeSize(40, 40))
                        current.fetchControls = strongSelf.fetchControls
                        strongSelf.downloadingView = current
                        strongSelf.addSubview(current)
                        current.frame = strongSelf.progressView.frame
                        
                        if !approximateSynchronousValue && animated {
                            current.layer?.animateAlpha(from: 0.2, to: 1, duration: 0.3)
                        }
                    }
                    current.state = state
                } else if let download = strongSelf.downloadingView {
                    download.state = .Fetching(progress: 1.0, force: false)
                    strongSelf.downloadingView = nil
                    download.layer?.animateAlpha(from: 1, to: 0.2, duration: 0.25, removeOnCompletion: false, completion: { [weak download] _ in
                        download?.removeFromSuperview()
                    })
                }
            }
        }))
        
        if let parameters = parameters as? ChatMediaVoiceLayoutParameters {
            waveformView.waveform = parameters.waveform
            
            waveformView.set(foregroundColor: isIncomingConsumed ? wBackgroundColor : wForegroundColor, backgroundColor: wBackgroundColor)
            checkState(animated: animated)
        }
        
        
        
        needsLayout = true
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        if let parent = parent,let parameters = parameters as? ChatMediaVoiceLayoutParameters  {
            for attr in parent.attributes {
                if let attr = attr as? ConsumableContentMessageAttribute {
                    if !attr.consumed {
                        let center = floorToScreenPixels(backingScaleFactor, frame.height / 2.0)
                        ctx.setFillColor(parameters.presentation.activityBackground.cgColor)
                        ctx.fillEllipse(in: NSMakeRect(leftInset + parameters.durationLayout.layoutSize.width + 3, center + 8, 5, 5))
                    }
                    break
                }
            }
        }
    }
    

    override func layout() {
        super.layout()
        let center = floorToScreenPixels(backingScaleFactor, frame.height / 2.0)
        if let parameters = parameters as? ChatMediaVoiceLayoutParameters {
            waveformView.setFrameSize(parameters.waveformWidth, waveformView.frame.height)
        }
        waveformView.setFrameOrigin(leftInset,center - waveformView.frame.height - 2)
        durationView.setFrameOrigin(leftInset,center + 2)
    }
    
}
