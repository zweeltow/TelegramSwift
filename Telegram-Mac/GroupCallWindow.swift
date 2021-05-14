//
//  GroupCallWindow.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 22/11/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit

private func generatePeerControl(_ icon: CGImage, background: NSColor) -> CGImage {
    return generateImage(NSMakeSize(28, 28), contextGenerator: { size, ctx in
        let rect: NSRect = .init(origin: .zero, size: size)
        ctx.clear(rect)
        
        ctx.round(size, 4)
        ctx.setFillColor(background.cgColor)
        ctx.fill(rect)
        
        ctx.draw(icon, in: rect.focus(icon.backingSize))
    })!
}

struct GroupCallTheme {
    static let membersColor = NSColor(hexString: "#333333")!
    static let windowBackground = NSColor(hexString: "#212121")!
    static let grayStatusColor = NSColor(srgbRed: 133 / 255, green: 133 / 255, blue: 133 / 255, alpha: 1)
    static let blueStatusColor = NSColor(srgbRed: 38 / 255, green: 122 / 255, blue: 255 / 255, alpha: 1)
    static let greenStatusColor = NSColor(hexString: "#34C759")!
    static let memberSeparatorColor = NSColor(srgbRed: 58 / 255, green: 58 / 255, blue: 58 / 255, alpha: 1)
    static let speakActiveColor = NSColor(hexString: "#34C759")!
    static let speakInactiveColor = NSColor(srgbRed: 38 / 255, green: 122 / 255, blue: 255 / 255, alpha: 1)
    static let speakLockedColor = NSColor(hexString: "#FF5257")!
    static let speakDisabledColor = NSColor(hexString: "#333333")!
    static let titleColor = NSColor.white
    static let declineColor = NSColor(hexString: "#FF3B30")!.withAlphaComponent(0.3)
    static let settingsColor = NSColor(hexString: "#333333")!
    
    static var accent: NSColor {
        return speakInactiveColor
    }
    static var secondary: NSColor {
        return grayStatusColor
    }
    
    static let videoBox_muted = NSImage(named: "Icon_GroupCall_VideoBox_Muted")!.precomposed(.white)
    static let videoBox_unmuted = NSImage(named: "Icon_GroupCall_VideoBox_Unmuted")!.precomposed(.white)

    static let videoBox_muted_locked = NSImage(named: "Icon_GroupCall_VideoBox_Muted")!.precomposed(GroupCallTheme.grayStatusColor)
    static let videoBox_unmuted_locked = NSImage(named: "Icon_GroupCall_VideoBox_Unmuted")!.precomposed(GroupCallTheme.grayStatusColor)

    
    static let topSettingsIcon = NSImage(named: "Icon_GroupCall_TopSettings")!.precomposed(.white)
    
    static let settingsIcon = NSImage(named: "Icon_GroupCall_Settings")!.precomposed(.white)
    static let declineIcon = NSImage(named: "Icon_GroupCall_Decline")!.precomposed(.white)
    static let inviteIcon = NSImage(named: "Icon_GroupCall_Invite")!.precomposed(.white)
    static let invitedIcon = NSImage(named: "Icon_GroupCall_Invited")!.precomposed(GroupCallTheme.grayStatusColor)
    
    static let videoZoomOut = NSImage(named: "Icon_GroupCall_Video_ZoomOut")!.precomposed(.white)
    static let videoZoomIn = NSImage(named: "Icon_GroupCall_Video_ZoomIn")!.precomposed(.white)
    
    

    static let small_speaking = generatePeerControl(NSImage(named: "Icon_GroupCall_Small_Unmuted")!.precomposed(GroupCallTheme.greenStatusColor), background: .clear)
    static let small_unmuted = generatePeerControl(NSImage(named: "Icon_GroupCall_Small_Unmuted")!.precomposed(GroupCallTheme.grayStatusColor), background: .clear)
    static let small_muted = generatePeerControl(NSImage(named: "Icon_GroupCall_Small_Muted")!.precomposed(GroupCallTheme.grayStatusColor), background: .clear)
    static let small_muted_locked = generatePeerControl(NSImage(named: "Icon_GroupCall_Small_Muted")!.precomposed(GroupCallTheme.speakLockedColor), background: .clear)
    
    static let small_speaking_active = generatePeerControl(NSImage(named: "Icon_GroupCall_Small_Unmuted")!.precomposed(GroupCallTheme.greenStatusColor), background: GroupCallTheme.windowBackground.withAlphaComponent(0.3))
    static let small_unmuted_active = generatePeerControl(NSImage(named: "Icon_GroupCall_Small_Unmuted")!.precomposed(GroupCallTheme.grayStatusColor), background: GroupCallTheme.windowBackground.withAlphaComponent(0.3))
    static let small_muted_active = generatePeerControl(NSImage(named: "Icon_GroupCall_Small_Muted")!.precomposed(GroupCallTheme.grayStatusColor), background: GroupCallTheme.windowBackground.withAlphaComponent(0.3))
    static let small_muted_locked_active = generatePeerControl(NSImage(named: "Icon_GroupCall_Small_Muted")!.precomposed(GroupCallTheme.speakLockedColor), background: GroupCallTheme.windowBackground.withAlphaComponent(0.3))

    
    static let small_raised_hand = generatePeerControl(NSImage(named: "Icon_GroupCall_RaiseHand_Small")!.precomposed(GroupCallTheme.customTheme.accentColor), background: .clear)
    static let small_raised_hand_active = generatePeerControl(NSImage(named: "Icon_GroupCall_RaiseHand_Small")!.precomposed(GroupCallTheme.customTheme.accentColor), background: GroupCallTheme.windowBackground.withAlphaComponent(0.3))

    
    static let big_raised_hand = NSImage(named: "Icon_GroupCall_RaiseHand_Big")!.precomposed(.white, flipVertical: true)

    
    
    static let big_unmuted = NSImage(named: "Icon_GroupCall_Big_Unmuted")!.precomposed(.white)
    static let big_muted = NSImage(named: "Icon_GroupCall_Big_Muted")!.precomposed(GroupCallTheme.speakLockedColor)
    
    static let status_video_gray = NSImage(named: "Icon_GroupCall_Status_Video")!.precomposed(GroupCallTheme.grayStatusColor)
    static let status_video_accent = NSImage(named: "Icon_GroupCall_Status_Video")!.precomposed(GroupCallTheme.blueStatusColor)
    static let status_video_green = NSImage(named: "Icon_GroupCall_Status_Video")!.precomposed(GroupCallTheme.greenStatusColor)
    static let status_video_red = NSImage(named: "Icon_GroupCall_Status_Video")!.precomposed(GroupCallTheme.speakLockedColor)

    static let status_muted = NSImage(named: "Icon_GroupCall_Status_Muted")!.precomposed(GroupCallTheme.grayStatusColor)
    
    static let status_unmuted_accent = NSImage(named: "Icon_GroupCall_Status_Unmuted")!.precomposed(GroupCallTheme.blueStatusColor)
    static let status_unmuted_green = NSImage(named: "Icon_GroupCall_Status_Unmuted")!.precomposed(GroupCallTheme.greenStatusColor)
    static let status_unmuted_gray = NSImage(named: "Icon_GroupCall_Status_Unmuted")!.precomposed(GroupCallTheme.grayStatusColor)


    static let video_on = NSImage(named: "Icon_GroupCall_VideoOn")!.precomposed(.white)
    static let video_off = NSImage(named: "Icon_GroupCall_VideoOff")!.precomposed(.white)
    
    static let invite_listener = NSImage(named: "Icon_VoiceChat_InviteListener")!.precomposed(GroupCallTheme.customTheme.accentColor, flipVertical: true)
    static let invite_speaker = NSImage(named: "Icon_VoiceChat_InviteSpeaker")!.precomposed(customTheme.accentColor, flipVertical: true)
    static let invite_link = NSImage(named: "Icon_InviteViaLink")!.precomposed(GroupCallTheme.customTheme.accentColor, flipVertical: true)

    
    private static let switchAppearance = SwitchViewAppearance(backgroundColor: GroupCallTheme.membersColor, stateOnColor: GroupCallTheme.blueStatusColor, stateOffColor: GroupCallTheme.grayStatusColor, disabledColor: GroupCallTheme.grayStatusColor.withAlphaComponent(0.5), borderColor: GroupCallTheme.memberSeparatorColor)
    
    static let customTheme: GeneralRowItem.Theme = GeneralRowItem.Theme(backgroundColor:                                            GroupCallTheme.membersColor,
                                    grayBackground: GroupCallTheme.windowBackground,
                                    grayForeground: GroupCallTheme.grayStatusColor,
                                    highlightColor: GroupCallTheme.membersColor.withAlphaComponent(0.7),
                                    borderColor: GroupCallTheme.memberSeparatorColor,
                                    accentColor: GroupCallTheme.blueStatusColor,
                                    secondaryColor: GroupCallTheme.grayStatusColor,
                                    textColor: NSColor(rgb: 0xffffff),
                                    grayTextColor: GroupCallTheme.grayStatusColor,
                                    underSelectedColor: NSColor(rgb: 0xffffff),
                                    accentSelectColor: GroupCallTheme.blueStatusColor.darker(),
                                    redColor: GroupCallTheme.speakLockedColor,
                                    indicatorColor: NSColor(rgb: 0xffffff),
                                    appearance: darkPalette.appearance,
                                    switchAppearance: switchAppearance,
                                    unselectedImage: generateChatGroupToggleUnselected(foregroundColor: GroupCallTheme.grayStatusColor.withAlphaComponent(0.6), backgroundColor: NSColor.black.withAlphaComponent(0.01)),
                                    selectedImage: generateChatGroupToggleSelected(foregroundColor: GroupCallTheme.blueStatusColor, backgroundColor: NSColor(rgb: 0xffffff)))
        

}

final class GroupCallWindow : Window {
    
    
    var navigation: NavigationViewController?
    
    init() {
        let size = NSMakeSize(380, 600)
        var rect: NSRect = .init(origin: .init(x: 100, y: 100), size: size)
        if let screen = NSScreen.main {
            let x = floorToScreenPixels(System.backingScale, (screen.frame.width - size.width) / 2)
            let y = floorToScreenPixels(System.backingScale, (screen.frame.height - size.height) / 2)
            rect = .init(origin: .init(x: x, y: y), size: size)
        }

        //.resizable
        super.init(contentRect: rect, styleMask: [.fullSizeContentView, .borderless, .miniaturizable, .closable, .titled], backing: .buffered, defer: true)
        self.minSize = NSMakeSize(380, 600)
        self.name = "GroupCallWindow5"
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.animationBehavior = .alertPanel
        self.isReleasedWhenClosed = false
        self.isMovableByWindowBackground = true
        self.level = .normal
        self.appearance = darkPalette.appearance
//        self.toolbar = NSToolbar(identifier: "window")
//        self.toolbar?.showsBaselineSeparator = false
        
        initSaver()
    }
    
    
    override func layoutIfNeeded() {
        super.layoutIfNeeded()
        
        if !isFullScreen {
            var point: NSPoint = NSMakePoint(20, 0)
            self.standardWindowButton(.closeButton)?.setFrameOrigin(point)
            point.x += 20
            self.standardWindowButton(.miniaturizeButton)?.setFrameOrigin(point)
            point.x += 20
            self.standardWindowButton(.zoomButton)?.setFrameOrigin(point)
        }
       
    }
        
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    override func orderOut(_ sender: Any?) {
        super.orderOut(sender)
    }
}


final class GroupCallContext {
    private let controller: GroupCallUIController
    private let navigation: MajorNavigationController

    let window: GroupCallWindow
    
    
    let call: PresentationGroupCall
    let peerMemberContextsManager: PeerChannelMemberCategoriesContextsManager
    private let presentDisposable = MetaDisposable()
    private let removeDisposable = MetaDisposable()
    init(call: PresentationGroupCall, peerMemberContextsManager: PeerChannelMemberCategoriesContextsManager) {
        self.call = call
        self.peerMemberContextsManager = peerMemberContextsManager
        self.window = GroupCallWindow()
        self.controller = GroupCallUIController(.init(call: call, peerMemberContextsManager: peerMemberContextsManager), size: window.frame.size)
        self.navigation = MajorNavigationController(GroupCallUIController.self, controller, self.window)
        self.navigation._frameRect = NSMakeRect(0, 0, window.frame.width, window.frame.height)
        self.navigation.alwaysAnimate = true
        self.navigation.cleanupAfterDeinit = true
        self.navigation.viewWillAppear(false)
        self.window.contentView = self.navigation.view
        self.window.navigation = navigation
        self.navigation.viewDidAppear(false)
        removeDisposable.set((self.call.canBeRemoved |> deliverOnMainQueue).start(next: { [weak self] value in
            if value {
                self?.readyClose(last: value)
            }
        }))

        self.window.closeInterceptor = { [weak self] in
            self?.readyClose()
            return true
        }
    }
    
    deinit {
        presentDisposable.dispose()
        removeDisposable.dispose()
    }
    
    func present() {

        presentDisposable.set((self.controller.ready.get() |> take(1)).start(completed: { [weak self] in
            guard let `self` = self else {
                return
            }
            self._readyPresent()
        }))
    }
    
    private func readyClose(last: Bool = false) {
        if window.isFullScreen {
            window.toggleFullScreen(nil)
            window._windowDidExitFullScreen = { [weak self] in
                self?.invikeClose(last: last)
            }
        } else {
            invikeClose(last: last)
        }
        
    }
    private func invikeClose(last: Bool) {
        if last {
            call.sharedContext.updateCurrentGroupCallValue(nil)
        }
        closeAllModals(window: window)
        self.navigation.viewWillDisappear(false)
        var window: GroupCallWindow? = self.window
        if self.window.isVisible {
            NSAnimationContext.runAnimationGroup({ _ in
                window?.animator().alphaValue = 0
            }, completionHandler: {
                window?.orderOut(nil)
                if last {
                    window?.contentView?.removeFromSuperview()
                    window?.contentView = nil
                    window?.navigation = nil
                }
                window = nil
            })
        } else if last {
            window?.contentView?.removeFromSuperview()
            window?.contentView = nil
            window?.navigation = nil
        }
        self.navigation.viewDidDisappear(false)
    }
    
    func close() {
        _ = call.sharedContext.endGroupCall(terminate: false).start()
        self.readyClose()
    }
    func leave() {
        _ = call.sharedContext.endGroupCall(terminate: false).start()
    }
    func leaveSignal() -> Signal<Bool, NoError> {
        self.controller.disableSounds = true
        return call.sharedContext.endGroupCall(terminate: false)
    }
    
    @objc private func _readyPresent() {
        call.sharedContext.updateCurrentGroupCallValue(self)
        window.alphaValue = 1
        self.window.makeKeyAndOrderFront(nil)
        self.window.orderFrontRegardless()
    }
    
}


func applyGroupCallResult(_ sharedContext: SharedAccountContext, _ result:GroupCallContext) {
    assertOnMainThread()
    result.call.sharedContext.showGroupCall(with: result)
    result.present()
}
