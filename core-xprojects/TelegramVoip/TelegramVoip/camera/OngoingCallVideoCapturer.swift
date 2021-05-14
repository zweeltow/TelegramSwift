//
//  OngoingCallVideoCapturer.swift
//  TelegramVoip
//
//  Created by Mikhail Filimonov on 07.01.2021.
//

import Foundation
import Cocoa
import TgVoipWebrtc



public enum OngoingCallVideoOrientation {
    case rotation0
    case rotation90
    case rotation180
    case rotation270
}

public extension OngoingCallVideoOrientation {
    init(_ orientation: OngoingCallVideoOrientationWebrtc) {
        switch orientation {
        case .orientation0:
            self = .rotation0
        case .orientation90:
            self = .rotation90
        case .orientation180:
            self = .rotation180
        case .orientation270:
            self = .rotation270
        @unknown default:
            self = .rotation0
        }
    }
}



public final class OngoingCallContextPresentationCallVideoView {
    public let view: NSView
    public let setOnFirstFrameReceived: (((Float) -> Void)?) -> Void
    public let getOrientation: () -> OngoingCallVideoOrientation
    public let getAspect: () -> CGFloat
    public let setOnOrientationUpdated: (((OngoingCallVideoOrientation, CGFloat) -> Void)?) -> Void
    public let setVideoContentMode: (CALayerContentsGravity) -> Void
    public let setOnIsMirroredUpdated: (((Bool) -> Void)?) -> Void

    public init(
        view: NSView,
        setOnFirstFrameReceived: @escaping (((Float) -> Void)?) -> Void,
        getOrientation: @escaping () -> OngoingCallVideoOrientation,
        getAspect: @escaping () -> CGFloat,
        setOnOrientationUpdated: @escaping (((OngoingCallVideoOrientation, CGFloat) -> Void)?) -> Void,
        setVideoContentMode: @escaping(CALayerContentsGravity) -> Void,
        setOnIsMirroredUpdated: @escaping (((Bool) -> Void)?) -> Void
        ) {
        self.view = view
        self.setOnFirstFrameReceived = setOnFirstFrameReceived
        self.getOrientation = getOrientation
        self.getAspect = getAspect
        self.setOnOrientationUpdated = setOnOrientationUpdated
        self.setVideoContentMode = setVideoContentMode
        self.setOnIsMirroredUpdated = setOnIsMirroredUpdated
    }
}



public final class OngoingCallVideoCapturer {
    public let impl: OngoingCallThreadLocalContextVideoCapturer
    
    public init(_ deviceId: String = "", keepLandscape: Bool = true) {
        self.impl = OngoingCallThreadLocalContextVideoCapturer(deviceId: deviceId, keepLandscape: keepLandscape)
    }
    
    public func makeOutgoingVideoView(completion: @escaping (OngoingCallContextPresentationCallVideoView?) -> Void) {
        self.impl.makeOutgoingVideoView { view in
            if let view = view {
                completion(OngoingCallContextPresentationCallVideoView(
                    view: view, setOnFirstFrameReceived: { [weak view] f in
                        view?.setOnFirstFrameReceived(f)
                    }, getOrientation: {
                        return .rotation90
                    },
                    getAspect: { [weak view] in
                        if let view = view {
                            return view.aspect
                        } else {
                            return 0.0
                        }
                    },
                    setOnOrientationUpdated: { [weak view] f in
                        
                    },
                    setVideoContentMode: { [weak view] mode in
                        view?.setVideoContentMode(mode)
                    }, setOnIsMirroredUpdated: { [weak view] f in
                        view?.setOnIsMirroredUpdated { value in
                            f?(value)
                        }
                    }
                ))
            } else {
                completion(nil)
            }
        }
    }
    
    public func setIsVideoEnabled(_ value: Bool) {
        self.impl.setIsVideoEnabled(value)
    }

    public func switchVideoInput(_ deviceId: String) {
        self.impl.switchVideoInput(deviceId)
    }
}
