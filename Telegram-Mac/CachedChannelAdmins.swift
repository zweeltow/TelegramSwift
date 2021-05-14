//
//  CachedChannelAdmins.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02/01/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Foundation
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit


struct CachedChannelAdminRank : PostboxCoding, Equatable {
   
    
    let peerId: PeerId
    let type: CachedChannelAdminRankType
    
    init(peerId: PeerId, type: CachedChannelAdminRankType) {
        self.peerId = peerId
        self.type = type
    }
    
    init(decoder: PostboxDecoder) {
        self.peerId = PeerId(decoder.decodeInt64ForKey("peerId", orElse: 0))
        self.type = decoder.decodeObjectForKey("type", decoder: { CachedChannelAdminRankType(decoder: $0) }) as! CachedChannelAdminRankType
    }
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.peerId.toInt64(), forKey: "peerId")
        encoder.encodeObject(self.type, forKey: "type")
    }
}

enum CachedChannelAdminRankType: PostboxCoding, Equatable {
    case owner
    case admin
    case custom(String)
    
    init(decoder: PostboxDecoder) {
        let value: Int32 = decoder.decodeInt32ForKey("v", orElse: 0)
        switch value {
        case 0:
            self = .owner
        case 1:
            self = .admin
        case 2:
            self = .custom(decoder.decodeStringForKey("s", orElse: ""))
        default:
            self = .admin
        }
    }
    
    func encode(_ encoder: PostboxEncoder) {
        switch self {
        case .owner:
            encoder.encodeInt32(0, forKey: "v")
        case .admin:
            encoder.encodeInt32(1, forKey: "v")
        case let .custom(rank):
            encoder.encodeInt32(2, forKey: "v")
            encoder.encodeString(rank, forKey: "s")
        }
    }
}

final class CachedChannelAdminRanks: PostboxCoding {
    let ranks: [CachedChannelAdminRank]
    
    init(ranks: [CachedChannelAdminRank]) {
        self.ranks = ranks
    }
    
    init(decoder: PostboxDecoder) {
        self.ranks = decoder.decodeObjectArrayForKey("ranks1").compactMap { $0 as? CachedChannelAdminRank }
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.ranks, forKey: "ranks1")
    }
    
    static func cacheKey(peerId: PeerId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: peerId.toInt64())
        return key
    }
}

private let collectionSpec = ItemCacheCollectionSpec(lowWaterItemCount: 100, highWaterItemCount: 200)

func cachedChannelAdminRanksEntryId(peerId: PeerId) -> ItemCacheEntryId {
    return ItemCacheEntryId(collectionId: 100, key: CachedChannelAdminRanks.cacheKey(peerId: peerId))
}

func updateCachedChannelAdminRanks(postbox: Postbox, peerId: PeerId, ranks: Dictionary<PeerId, CachedChannelAdminRankType>) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: 100, key: CachedChannelAdminRanks.cacheKey(peerId: peerId)), entry: CachedChannelAdminRanks(ranks: ranks.map { CachedChannelAdminRank(peerId: $0.key, type: $0.value)}), collectionSpec: collectionSpec)
    }
}
