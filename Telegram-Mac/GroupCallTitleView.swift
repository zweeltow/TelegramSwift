//
//  GroupCallTitleView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06.04.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private final class GroupCallRecordingView : Control {
    private let indicator: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(indicator)
        
        indicator.isEventLess = true
        
        self.set(handler: { [weak self] control in
            self?.recordClick?()
        }, for: .Click)
        

        indicator.backgroundColor = GroupCallTheme.customTheme.redColor
        indicator.setFrameSize(NSMakeSize(8, 8))
        indicator.layer?.cornerRadius = indicator.frame.height / 2
        
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.timingFunction = .init(name: .easeInEaseOut)
        animation.fromValue = 0.5
        animation.toValue = 1.0
        animation.duration = 1.0
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        animation.fillMode = CAMediaTimingFillMode.forwards
        
        indicator.layer?.add(animation, forKey: "opacity")

    }
    private var recordingStartTime: Int32 = 0
    private var account: Account?
    private var recordClick:(()->Void)? = nil
    
    var updateParentLayout:(()->Void)? = nil
    
    func update(recordingStartTime: Int32, account: Account, recordClick: (()->Void)?) {
        self.account = account
        self.recordClick = recordClick
        self.recordingStartTime = recordingStartTime
        self.backgroundColor = .clear
        self.updateParentLayout?()
        
        setFrameSize(NSMakeSize(8, 8))
    }
 
    override func layout() {
        super.layout()
        indicator.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}



final class GroupCallTitleView : Control {
    fileprivate let titleView: TextView = TextView()
    fileprivate let statusView: DynamicCounterTextView = DynamicCounterTextView()
    private var recordingView: GroupCallRecordingView?
    private let backgroundView: View = View()
    fileprivate let settings = ImageButton()
    enum Mode {
        case normal
        case transparent
    }
    
    fileprivate var mode: Mode = .normal
    
    private var settingsClick: (()->Void)? = nil
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(backgroundView)
        backgroundView.addSubview(titleView)
        backgroundView.addSubview(statusView)
        //backgroundView.addSubview(settings)
        titleView.isSelectable = false
        titleView.userInteractionEnabled = false
        statusView.userInteractionEnabled = false
        titleView.disableBackgroundDrawing = true
        
        settings.set(image: GroupCallTheme.topSettingsIcon, for: .Normal)
        settings.sizeToFit()
        settings.scaleOnClick = true
        settings.autohighlight = false
        
        
        settings.set(handler: { [weak self] _ in
            self?.settingsClick?()
        }, for: .SingleClick)
        
        
        set(handler: { [weak self] _ in
            self?.window?.performZoom(nil)
        }, for: .DoubleClick)
    }
    
    override var backgroundColor: NSColor {
        didSet {
            titleView.backgroundColor = .clear
            statusView.backgroundColor = .clear
        }
    }
    
    func updateMode(_ mode: Mode, animated: Bool) {
        self.mode = mode
        backgroundView.backgroundColor = mode == .transparent ? .clear : GroupCallTheme.windowBackground
        if animated {
            backgroundView.layer?.animateBackground()
        }
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: NSArray(array: [NSColor.black.withAlphaComponent(0.6).cgColor, NSColor.black.withAlphaComponent(0).cgColor]), locations: nil)!
        
        ctx.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: layer.bounds.height), options: CGGradientDrawingOptions())
    }
    
    
    override var mouseDownCanMoveWindow: Bool {
        return true
    }

    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        
        
        transition.updateFrame(view: backgroundView, frame: NSMakeRect(0, 0, bounds.width, 54))
        
        transition.updateFrame(view: statusView, frame:  statusView.centerFrameX(y: backgroundView.frame.midY))

        if let recordingView = recordingView {
            
            let layout = titleView.layout
            layout?.measure(width: backgroundView.frame.width - 125 - recordingView.frame.width - 10 - 30)
            titleView.update(layout)
            
            let rect = backgroundView.focus(titleView.frame.size)

            transition.updateFrame(view: titleView, frame: CGRect(origin: NSMakePoint(max(100, rect.minX), backgroundView.frame.midY - titleView.frame.height), size: titleView.frame.size))

            transition.updateFrame(view: recordingView, frame: CGRect(origin: NSMakePoint(titleView.frame.maxX + 5, titleView.frame.minY + 6), size: recordingView.frame.size))
            
        } else {
            
            let layout = titleView.layout
            layout?.measure(width: backgroundView.frame.width - 125)
            titleView.update(layout)
            
            let rect = backgroundView.focus(titleView.frame.size)
            transition.updateFrame(view: titleView, frame: CGRect(origin: NSMakePoint(max(100, rect.minX), backgroundView.frame.midY - titleView.frame.height), size: titleView.frame.size))
        }
        
        transition.updateFrame(view: settings, frame: settings.centerFrameY(x: backgroundView.frame.width - settings.frame.width - 15))
    }
    
    
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }
    
    
    private var currentState: GroupCallUIState?
    private var currentPeer: Peer?
    func update(_ peer: Peer, _ state: GroupCallUIState, _ account: Account, settingsClick: @escaping()->Void, recordClick: @escaping()->Void, animated: Bool) {
        
        let oldMode = self.mode
        let mode: Mode = state.isFullScreen && state.currentDominantSpeakerWithVideo != nil ? .transparent : .normal
        
        self.updateMode(mode, animated: animated)
        
        self.settingsClick = settingsClick
        
        let title: String = state.title
        let oldTitle: String? = currentState?.title
        
        let titleUpdated = title != oldTitle
                
        let recordingUpdated = state.state.recordingStartTimestamp != currentState?.state.recordingStartTimestamp
        let participantsUpdated = state.summaryState?.participantCount != currentState?.summaryState?.participantCount || state.state.scheduleTimestamp != currentState?.state.scheduleTimestamp
        
        let updated = titleUpdated || recordingUpdated || participantsUpdated || mode != oldMode
                
        guard updated else {
            self.currentState = state
            self.currentPeer = peer
            return
        }
        
        if titleUpdated {
            let layout = TextViewLayout(.initialize(string: title, color: GroupCallTheme.titleColor, font: .medium(.title)), maximumNumberOfLines: 1)
            layout.measure(width: frame.width - 125 - (recordingView != nil ? 80 : 0))
            titleView.update(layout)
        }

        if recordingUpdated {
            if let recordingStartTimestamp = state.state.recordingStartTimestamp {
                let view: GroupCallRecordingView
                if let current = self.recordingView {
                    view = current
                } else {
                    view = GroupCallRecordingView(frame: .zero)
                    backgroundView.addSubview(view)
                    self.recordingView = view
                    
                    if animated {
                        recordingView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                }
                view.update(recordingStartTime: recordingStartTimestamp, account: account, recordClick: recordClick)
                
                view.updateParentLayout = { [weak self] in
                    self?.needsLayout = true
                }
            } else {
                if let recordingView = recordingView {
                    self.recordingView = nil
                    if animated {
                        recordingView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false,completion: { [weak recordingView] _ in
                            recordingView?.removeFromSuperview()
                        })
                    } else {
                        recordingView.removeFromSuperview()
                    }
                }
            }

        }
        if participantsUpdated || oldMode != mode {
            let status: String
            let count: Int
            if state.state.scheduleTimestamp != nil {
                status = L10n.voiceChatTitleScheduledSoon
                count = 0
            }  else if let summaryState = state.summaryState {
                status = L10n.voiceChatStatusMembersCountable(summaryState.participantCount)
                count = summaryState.participantCount
            } else {
                status = L10n.voiceChatStatusLoading
                count = 0
            }

            let dynamicResult = DynamicCounterTextView.make(for: status, count: "\(count)", font: .normal(.text), textColor: mode == .transparent ? NSColor.white.withAlphaComponent(0.8) : GroupCallTheme.grayStatusColor, width: frame.width - 140)

            self.statusView.update(dynamicResult, animated: animated && oldMode == mode)

            self.statusView.change(size: dynamicResult.size, animated: animated)
            self.statusView.change(pos: NSMakePoint(floorToScreenPixels(backingScaleFactor, (frame.width - dynamicResult.size.width) / 2), frame.midY), animated: animated)
        }
        self.currentState = state
        self.currentPeer = peer
        if updated {
            needsLayout = true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

