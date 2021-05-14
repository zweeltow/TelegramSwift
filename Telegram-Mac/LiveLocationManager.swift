//
//  LiveLocationManager.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 16/10/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import CoreLocation


public protocol LiveLocationSummaryManager {
    func broadcastingToMessages() -> Signal<[MessageId: Message], NoError>
    func peersBroadcastingTo(peerId: PeerId) -> Signal<[(Peer, Message)]?, NoError>
}

public protocol LiveLocationManager {
    var summaryManager: LiveLocationSummaryManager { get }
    var isPolling: Signal<Bool, NoError> { get }
    
    func cancelLiveLocation(peerId: PeerId)
    func pollOnce()
    func internalMessageForPeerId(_ peerId: PeerId) -> MessageId?
}



public final class LiveLocationManagerImpl: LiveLocationManager {
    private let queue = Queue.mainQueue()
    
    private let postbox: Postbox
    private let network: Network
    private let stateManager: AccountStateManager
    
    private let summaryManagerImpl: LiveLocationSummaryManagerImpl
    public var summaryManager: LiveLocationSummaryManager {
        return self.summaryManagerImpl
    }
    
    private var requiredLocationTypeDisposable: Disposable?
    private let hasActiveMessagesToBroadcast = ValuePromise<Bool>(false, ignoreRepeated: true)
    
    public var isPolling: Signal<Bool, NoError> {
        return self.pollingOnce.get()
    }
    private let pollingOnce = ValuePromise<Bool>(false, ignoreRepeated: true)
    private var pollingOnceValue = false {
        didSet {
            self.pollingOnce.set(self.pollingOnceValue)
        }
    }
    
    private let deviceLocationDisposable = MetaDisposable()
    private var messagesDisposable: Disposable?
    
    private var broadcastToMessageIds: [MessageId: Int32] = [:]
    private var stopMessageIds = Set<MessageId>()
    
    private let editMessageDisposables = DisposableDict<MessageId>()
    
    private var invalidationTimer: (SwiftSignalKit.Timer, Int32)?
    
    public init(postbox: Postbox, network: Network, accountPeerId: PeerId, viewTracker: AccountViewTracker, stateManager: AccountStateManager, inForeground: Signal<Bool, NoError>) {
        self.postbox = postbox
        self.network = network
        self.stateManager = stateManager
        
        self.summaryManagerImpl = LiveLocationSummaryManagerImpl(queue: self.queue, postbox: postbox, accountPeerId: accountPeerId, viewTracker: viewTracker)
        
        let viewKey: PostboxViewKey = .localMessageTag(.OutgoingLiveLocation)
        self.messagesDisposable = (postbox.combinedView(keys: [viewKey])
            |> deliverOn(self.queue)).start(next: { [weak self] view in
                if let strongSelf = self {
                    let timestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                    
                    var broadcastToMessageIds: [MessageId: Int32] = [:]
                    var stopMessageIds = Set<MessageId>()
                    
                    if let view = view.views[viewKey] as? LocalMessageTagsView {
                        for message in view.messages.values {
                            if !message.flags.contains(.Incoming) {
                                if message.flags.intersection([.Failed, .Unsent]).isEmpty {
                                    var activeLiveBroadcastingTimeout: Int32?
                                    for media in message.media {
                                        if let telegramMap = media as? TelegramMediaMap {
                                            if let liveBroadcastingTimeout = telegramMap.liveBroadcastingTimeout {
                                                if message.timestamp + liveBroadcastingTimeout > timestamp {
                                                    activeLiveBroadcastingTimeout = liveBroadcastingTimeout
                                                }
                                            }
                                        }
                                    }
                                    if let activeLiveBroadcastingTimeout = activeLiveBroadcastingTimeout {
                                        broadcastToMessageIds[message.id] = message.timestamp + activeLiveBroadcastingTimeout
                                    } else {
                                        stopMessageIds.insert(message.id)
                                    }
                                }
                            } else {
                                assertionFailure()
                            }
                        }
                    }
                    
                    strongSelf.update(broadcastToMessageIds: broadcastToMessageIds, stopMessageIds: stopMessageIds)
                }
            })
    }
    
    deinit {
        self.requiredLocationTypeDisposable?.dispose()
        self.deviceLocationDisposable.dispose()
        self.messagesDisposable?.dispose()
        self.editMessageDisposables.dispose()
        self.invalidationTimer?.0.invalidate()
    }
    
    private func update(broadcastToMessageIds: [MessageId: Int32], stopMessageIds: Set<MessageId>) {
        assert(self.queue.isCurrent())
        
        if self.broadcastToMessageIds == broadcastToMessageIds && self.stopMessageIds == stopMessageIds {
            return
        }
        
        let validBroadcastToMessageIds = Set(broadcastToMessageIds.keys)
        if self.broadcastToMessageIds != broadcastToMessageIds {
            self.summaryManagerImpl.update(messageIds: validBroadcastToMessageIds)
        }
        
        let wasEmpty = self.broadcastToMessageIds.isEmpty
        self.broadcastToMessageIds = broadcastToMessageIds
        
        let removedFromActions = Set(self.broadcastToMessageIds.keys).union(self.stopMessageIds).subtracting(validBroadcastToMessageIds.union(stopMessageIds))
        for id in removedFromActions {
            self.editMessageDisposables.set(nil, forKey: id)
        }
        
        if !broadcastToMessageIds.isEmpty {
            if wasEmpty {
                self.hasActiveMessagesToBroadcast.set(true)
            }
        } else if !wasEmpty {
            self.hasActiveMessagesToBroadcast.set(false)
        }
        
        let addedStopped = stopMessageIds.subtracting(self.stopMessageIds)
        self.stopMessageIds = stopMessageIds
        
        self.rescheduleTimer()
    }
    
    private func rescheduleTimer() {
        let currentTimestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
        
        var updatedBroadcastToMessageIds = self.broadcastToMessageIds
        var updatedStopMessageIds = self.stopMessageIds
        
        var earliestCancelIdAndTimestamp: (MessageId, Int32)?
        for (id, timestamp) in self.broadcastToMessageIds {
            if currentTimestamp >= timestamp {
                updatedBroadcastToMessageIds.removeValue(forKey: id)
                updatedStopMessageIds.insert(id)
            } else {
                if earliestCancelIdAndTimestamp == nil || timestamp < earliestCancelIdAndTimestamp!.1 {
                    earliestCancelIdAndTimestamp = (id, timestamp)
                }
            }
        }
        
        if let (_, timestamp) = earliestCancelIdAndTimestamp {
            if self.invalidationTimer?.1 != timestamp {
                self.invalidationTimer?.0.invalidate()
                
                let timer = SwiftSignalKit.Timer(timeout: Double(max(0, timestamp - currentTimestamp)), repeat: false, completion: { [weak self] in
                    self?.invalidationTimer?.0.invalidate()
                    self?.invalidationTimer = nil
                    self?.rescheduleTimer()
                    }, queue: self.queue)
                self.invalidationTimer = (timer, timestamp)
                timer.start()
            }
        } else if let (timer, _) = self.invalidationTimer {
            self.invalidationTimer = nil
            timer.invalidate()
        }
        
        self.update(broadcastToMessageIds: updatedBroadcastToMessageIds, stopMessageIds: updatedStopMessageIds)
    }
    
    public func cancelLiveLocation(peerId: PeerId) {
        assert(self.queue.isCurrent())
        
        let ids = self.broadcastToMessageIds.keys.filter({ $0.peerId == peerId })
        if !ids.isEmpty {
            let _ = self.postbox.transaction({ transaction -> Void in
                for id in ids {
                    transaction.updateMessage(id, update: { currentMessage in
                        var storeForwardInfo: StoreMessageForwardInfo?
                        if let forwardInfo = currentMessage.forwardInfo {
                            storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: [])
                        }
                        var updatedMedia = currentMessage.media
                        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                        for i in 0 ..< updatedMedia.count {
                            if let media = updatedMedia[i] as? TelegramMediaMap, let _ = media.liveBroadcastingTimeout {
                                updatedMedia[i] = TelegramMediaMap(latitude: media.latitude, longitude: media.longitude, heading: media.heading, accuracyRadius: media.accuracyRadius, geoPlace: media.geoPlace, venue: media.venue, liveBroadcastingTimeout: max(0, timestamp - currentMessage.timestamp - 1), liveProximityNotificationRadius: nil)
                            }
                        }
                        return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: updatedMedia))
                    })
                }
            }).start()
        }
    }
    
    public func pollOnce() {
        if !self.broadcastToMessageIds.isEmpty {
            self.pollingOnceValue = true
        }
    }
    
    public func internalMessageForPeerId(_ peerId: PeerId) -> MessageId? {
        for id in self.broadcastToMessageIds.keys {
            if id.peerId == peerId {
                return id
            }
        }
        return nil
    }
}
