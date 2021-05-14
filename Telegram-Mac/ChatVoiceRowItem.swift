//
//  ChatVoiceRowItem.swift
//  TelegramMac
//
//  Created by keepcoder on 25/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

import TGUIKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
class ChatMediaVoiceLayoutParameters : ChatMediaLayoutParameters {
    let showPlayer:(APController) -> Void
    let waveform:AudioWaveform?
    let durationLayout:TextViewLayout
    let isMarked:Bool
    let isWebpage:Bool
    let resource: TelegramMediaResource
    fileprivate(set) var waveformWidth:CGFloat = 120
    let duration:Int
    init(showPlayer:@escaping(APController) -> Void, waveform:AudioWaveform?, duration:Int, isMarked:Bool, isWebpage: Bool, resource: TelegramMediaResource, presentation: ChatMediaPresentation, media: Media, automaticDownload: Bool) {
        self.showPlayer = showPlayer
        self.waveform = waveform
        self.duration = duration
        self.isMarked = isMarked
        self.isWebpage = isWebpage
        self.resource = resource
        durationLayout = TextViewLayout(NSAttributedString.initialize(string: String.durationTransformed(elapsed: duration), color: presentation.grayText, font: .normal(.text)), maximumNumberOfLines: 1, truncationType:.end, alignment: .left)
        super.init(presentation: presentation, media: media, automaticDownload: automaticDownload, autoplayMedia: AutoplayMediaPreferences.defaultSettings)
    }
    
    func duration(for duration:TimeInterval) -> TextViewLayout {
        return TextViewLayout(NSAttributedString.initialize(string: String.durationTransformed(elapsed: Int(round(duration))), color: presentation.grayText, font: .normal(.text)), maximumNumberOfLines: 1, truncationType:.end, alignment: .left)
    }
}

class ChatVoiceRowItem: ChatMediaItem {
    
    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings, theme: TelegramPresentationTheme) {
        super.init(initialSize, chatInteraction, context, object, downloadSettings, theme: theme)
        
        self.parameters = ChatMediaLayoutParameters.layout(for: media as! TelegramMediaFile, isWebpage: false, chatInteraction: chatInteraction, presentation: .make(for: object.message!, account: context.account, renderType: object.renderType), automaticDownload: downloadSettings.isDownloable(object.message!), isIncoming: object.message!.isIncoming(context.account, object.renderType == .bubble), autoplayMedia: object.autoplayMedia)
    }
    
    override func canMultiselectTextIn(_ location: NSPoint) -> Bool {
        return super.canMultiselectTextIn(location)
    }
    
    override var additionalLineForDateInBubbleState: CGFloat? {
        if isForceRightLine {
            return rightSize.height
        }
        if let parameters = parameters as? ChatMediaVoiceLayoutParameters {
            if parameters.durationLayout.layoutSize.width + 50 + rightSize.width + insetBetweenContentAndDate > contentSize.width {
                return rightSize.height
            }
        }
        
        return super.additionalLineForDateInBubbleState
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        if let parameters = parameters as? ChatMediaVoiceLayoutParameters {
            parameters.durationLayout.measure(width: width - 50)
            
            let minVoiceWidth: CGFloat = 100
            let maxVoiceWidth:CGFloat = width - 50
            let maxVoiceLength: CGFloat = 30.0
            
            let b = log(maxVoiceWidth / minVoiceWidth) / (maxVoiceLength - 0.0)
            let a = minVoiceWidth / exp(CGFloat(0.0))
            
            let w = a * exp(b * CGFloat(parameters.duration))
            
            parameters.waveformWidth = floor(min(w, 200))
            
            return NSMakeSize(parameters.waveformWidth + 50, 40)
        }
        return NSZeroSize
    }
    
    override var instantlyResize: Bool {
        return true
    }
}
