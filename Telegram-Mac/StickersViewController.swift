//
//  StickersViewController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 08/07/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import SyncCore
import Postbox

final class StickerPanelArguments {
    let context: AccountContext
    let sendMedia:(Media, NSView, Bool)->Void
    let showPack:(StickerPackReference)->Void
    let navigate:(ItemCollectionViewEntryIndex)->Void
    let addPack: (StickerPackReference)->Void
    let clearRecent:()->Void
    let removePack:(StickerPackCollectionId)->Void
    init(context: AccountContext, sendMedia: @escaping(Media, NSView, Bool)->Void, showPack: @escaping(StickerPackReference)->Void, addPack: @escaping(StickerPackReference)->Void, navigate: @escaping(ItemCollectionViewEntryIndex)->Void, clearRecent:@escaping()->Void, removePack:@escaping(StickerPackCollectionId)->Void) {
        self.context = context
        self.sendMedia = sendMedia
        self.showPack = showPack
        self.addPack = addPack
        self.navigate = navigate
        self.clearRecent = clearRecent
        self.removePack = removePack
    }
}

extension FoundStickerSets {
    func updateInfos(_ f:([(ItemCollectionId, ItemCollectionInfo, ItemCollectionItem?, Bool)])->[(ItemCollectionId, ItemCollectionInfo, ItemCollectionItem?, Bool)]) -> FoundStickerSets {
        return FoundStickerSets.init(infos: f(self.infos), entries: self.entries)
    }
}

struct SpecificPackData : Equatable {
    let info: StickerPackCollectionInfo
    let peer: Peer
    
    static func ==(lhs: SpecificPackData, rhs: SpecificPackData) -> Bool {
        if lhs.info != rhs.info {
            return false
        } else if !lhs.peer.isEqual(rhs.peer) {
            return false
        } else {
            return true
        }
    }
}

enum PackEntry: Comparable, Identifiable {
    case stickerPack(index:Int, stableId: StickerPackCollectionId, info: StickerPackCollectionInfo, topItem: StickerPackItem?)
    case recent
    case saved
    case featured(hasUnread: Bool)
    case specificPack(data: SpecificPackData)
    
    var stableId: StickerPackCollectionId {
        switch self {
        case let .stickerPack(data):
            return data.stableId
        case .recent:
            return .recent
        case .saved:
            return .saved
        case let .featured(hasUnread):
            return .featured(hasUnred: hasUnread)
        case let .specificPack(data):
            return .specificPack(data.info.id)
            
        }
    }
    
    var index: Int {
        switch self {
        case .featured:
            return -1
        case .saved:
            return 0
        case .recent:
            return 1
        case .specificPack:
            return 2
        case let .stickerPack(index, _, _, _):
            return 3 + index
        }
    }
    
    static func <(lhs: PackEntry, rhs: PackEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    
}


private enum StickerPacksUpdate {
    case generic(animated: Bool, scrollToTop: Bool?)
    case scroll(animated: Bool)
    case navigate(StickerPacksIndex, animated: Bool)
}


private enum StickerPacksIndex : Hashable, Comparable {
    case sticker(ItemCollectionViewEntryIndex)
    case speficicPack(ItemCollectionId)
    case recent(Int)
    case saved(Int)
    case featured(Int, Bool)
    case emojiRelated(Int)
    var packIndex:ItemCollectionViewEntryIndex {
        switch self {
        case let .sticker(index):
            return index
        case let .saved(index), let .recent(index), let .featured(index, _), let .emojiRelated(index):
            return ItemCollectionViewEntryIndex.lowerBound(collectionIndex: Int32(index), collectionId: ItemCollectionId(namespace: 0, id: 0))
        case let .speficicPack(id):
            return ItemCollectionViewEntryIndex.lowerBound(collectionIndex: 2, collectionId: id)
        }
    }
    
    var collectionId: StickerPackCollectionId {
        switch self {
        case let .sticker(index):
            return .pack(index.collectionId)
        case .recent:
            return .recent
        case .saved:
            return .saved
        case let .speficicPack(id):
            return .specificPack(id)
        case let .featured(_, hasUnread):
            return .featured(hasUnred: hasUnread)
        case .emojiRelated:
            return .emojiRelated
        }
    }
    
    func hash(into hasher: inout Hasher) {
        
    }
    
    var index: Int {
        switch self {
        case .emojiRelated:
            return -2
        case .featured:
            return -1
        case .saved:
            return 0
        case .recent:
            return 1
        case .speficicPack:
            return 2
        case .sticker:
            return 3
        }
    }
    
    static func <(lhs: StickerPacksIndex, rhs: StickerPacksIndex) -> Bool {
        switch lhs {
        case let .sticker(lhsIndex):
            if case let .sticker(rhsIndex) = rhs {
                return lhsIndex < rhsIndex
            } else {
                return lhs.index < rhs.index
            }
        default:
            return lhs.index < rhs.index
        }
    }
}

private enum StickerPacksScrollState: Equatable {
    static func == (lhs: StickerPacksScrollState, rhs: StickerPacksScrollState) -> Bool {
        switch lhs {
        case .initial:
            if case .initial = rhs {
                return true
            } else {
                return false
            }
        case let .loadFeaturedMore(lhsFound):
            if case .loadFeaturedMore(let rhsFound) = rhs {
                return lhsFound.sets.infos.map { $0.0 } == rhsFound.sets.infos.map { $0.0 }
            } else {
                return false
            }
        case let .scroll(aroundIndex):
            if case .scroll(aroundIndex) = rhs {
                return true
            } else {
                return false
            }
        case let .navigate(aroundIndex):
            if case .navigate(aroundIndex) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    case initial
    case loadFeaturedMore(StickerPacksSearchData)
    case scroll(aroundIndex: StickerPacksIndex)
    case navigate(index: StickerPacksIndex)
}

private struct StickerPacksSearchData {
    let sets: FoundStickerSets
    let loading: Bool
    let basicFeaturedCount: Int
    let emojiRelated: [FoundStickerItem]
}

private struct StickerPacksUpdateData {
    let view: ItemCollectionsView?
    let update: StickerPacksUpdate
    let specificPack:Tuple2<PeerSpecificStickerPackData, Peer>?
    let searchData: StickerPacksSearchData?
    let hasUnread: Bool
    init(view: ItemCollectionsView?, update: StickerPacksUpdate, specificPack: Tuple2<PeerSpecificStickerPackData, Peer>?, searchData: StickerPacksSearchData? = nil, hasUnread: Bool) {
        self.view = view
        self.update = update
        self.specificPack = specificPack
        self.searchData = searchData
        self.hasUnread = hasUnread
    }

    func withUpdatedHasUnread(_ hasUnread: Bool) -> StickerPacksUpdateData {
        return .init(view: self.view, update: self.update, specificPack: self.specificPack, searchData: self.searchData, hasUnread: hasUnread)
    }
}
enum StickerPackInfo : Equatable {
    case pack(StickerPackCollectionInfo?, installed: Bool, featured: Bool)
    case speficicPack(StickerPackCollectionInfo?)
    case recent
    case saved
    case emojiRelated
    
    var installed: Bool {
        switch self {
        case let .pack(_, installed, _):
            return installed
        default:
            return true
        }
    }
    var featured: Bool {
        switch self {
        case let .pack(_, _, featured):
            return featured
        default:
            return false
        }
    }
}

enum StickerPackCollectionId : Hashable {
    case pack(ItemCollectionId)
    case recent
    case featured(hasUnred: Bool)
    case specificPack(ItemCollectionId)
    case saved
    case emojiRelated
    var itemCollectionId:ItemCollectionId? {
        switch self {
        case let .pack(collectionId):
            return collectionId
        case let .specificPack(collectionId):
            return collectionId
        default:
            return nil
        }
    }
    
}


private enum StickerPackEntry : TableItemListNodeEntry {
    case pack(index: StickerPacksIndex, files:[TelegramMediaFile], packInfo: StickerPackInfo, collectionId: StickerPackCollectionId)
    
    
    static func < (lhs: StickerPackEntry, rhs: StickerPackEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    static func == (lhs: StickerPackEntry, rhs: StickerPackEntry) -> Bool {
        switch lhs {
        case let .pack(index, lhsFiles, packInfo, collectionId):
            if case .pack(index, let rhsFiles, packInfo, collectionId) = rhs {
                if lhsFiles.count != rhsFiles.count {
                    return false
                } else {
                    for (i, lhsFile) in lhsFiles.enumerated() {
                        if !lhsFile.isEqual(to: rhsFiles[i]) {
                            return false
                        }
                    }
                }
                return true
            } else {
                return false
            }
        }
    }
    
    var index: StickerPacksIndex {
        switch self {
        case let .pack(index, _, _, _):
            return index
        }
    }
    
    var stableId: StickerPackCollectionId {
        switch self {
        case let .pack( _, _, _, collectionId):
            return collectionId
        }
    }
    
    func item(_ arguments: StickerPanelArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .pack(_, files, packInfo, collectionId):
            return StickerPackPanelRowItem(initialSize, context: arguments.context, arguments: arguments, files: files, packInfo: packInfo, collectionId: collectionId)
        }
    }
}

private func stickersEntries(view: ItemCollectionsView?, searchData: StickerPacksSearchData?, specificPack:Tuple2<PeerSpecificStickerPackData, Peer>?) -> [StickerPackEntry] {
    var entries:[StickerPackEntry] = []
    
    if let view = view {
        var available: [ItemCollectionViewEntry] = view.entries
        var index: Int32 = 0
        
        var ids:[MediaId : MediaId] = [:]
        
        if view.lower == nil {
            if !view.orderedItemListsViews[1].items.isEmpty {
                var files:[TelegramMediaFile] = []
                for item in view.orderedItemListsViews[1].items {
                    if let entry = item.contents as? SavedStickerItem {
                        if let id = entry.file.id, ids[id] == nil, entry.file.isStaticSticker || entry.file.isAnimatedSticker {
                            ids[id] = id
                            files.append(entry.file)
                        }
                    }
                }
                if !files.isEmpty {
                    entries.append(.pack(index: .saved(0), files: files, packInfo: .saved, collectionId: .saved))
                }
            }
            
            if !view.orderedItemListsViews[0].items.isEmpty {
                var files:[TelegramMediaFile] = []
                for item in view.orderedItemListsViews[0].items {
                    if let entry = item.contents as? RecentMediaItem {
                        if let file = entry.media as? TelegramMediaFile, let id = file.id, ids[id] == nil, file.isStaticSticker || file.isAnimatedSticker {
                            ids[id] = id
                            files.append(file)
                        }
                    }
                    if files.count == 20 {
                        break
                    }
                }
                if !files.isEmpty {
                    entries.append(.pack(index: .recent(1), files: files, packInfo: .recent, collectionId: .recent))
                }
            }
            
            
            if let specificPack = specificPack, let info = specificPack._0.packInfo {
                var files:[TelegramMediaFile] = []
                for item in info.1 {
                    if let item = item as? StickerPackItem {
                        if let id = item.file.id, ids[id] == nil, item.file.isStaticSticker || item.file.isAnimatedSticker {
                            ids[id] = id
                            files.append(item.file)
                        }
                    }
                }
                if !files.isEmpty {
                    entries.append(.pack(index: .speficicPack(info.0.id), files: files, packInfo: .speficicPack(info.0), collectionId: .specificPack(info.0.id)))
                }
            }
            
        }
        
        for (id, info, item) in view.collectionInfos {
            if !available.isEmpty, let item = item {
                var files: [TelegramMediaFile] = []
                if let info = info as? StickerPackCollectionInfo {
                    let items = available.enumerated().reversed()
                    for (i, entry) in items {
                        if entry.index.collectionId == info.id {
                            if let item = available.remove(at: i).item as? StickerPackItem {
                                files.insert(item.file, at: 0)
                            }
                        }
                    }
                    if !files.isEmpty {
                        entries.append(.pack(index: .sticker(ItemCollectionViewEntryIndex(collectionIndex: index, collectionId: id, itemIndex: item.index)), files: files, packInfo: .pack(info, installed: true, featured: false), collectionId: .pack(id)))
                    }
                }
            } else {
                break
            }
            index += 1
        }
    } else if let searchData = searchData {
        if !searchData.loading {
            var available = searchData.sets.entries
            var index: Int32 = 0
            
            if !searchData.emojiRelated.isEmpty {
                
                var validIds:Set<MediaId> = Set()
                
                let files:[TelegramMediaFile] = searchData.emojiRelated.map { $0.file }.reduce([], { current, value in
                    var current = current
                    guard let id = value.id else {
                        return current
                    }
                    if !validIds.contains(id) {
                        validIds.insert(id)
                        current.append(value)
                    }
                    return current
                }).sorted(by: { lhs, rhs in
                    if lhs.isAnimatedSticker && !rhs.isAnimatedSticker {
                        return true
                    } else {
                        return false
                    }
                })
                entries.append(.pack(index: .emojiRelated(0), files: files, packInfo: .emojiRelated, collectionId: .emojiRelated))
                
              //  entries.append(.pack(index: .sticker(ItemCollectionViewEntryIndex(collectionIndex: index, collectionId: 0, itemIndex: .init(index: 0, id: 0))), files: Array(files), packInfo: .emojiRelated, collectionId: nil))
                index += 1
            }
            
            for set in searchData.sets.infos {
                if !available.isEmpty {
                    var files: [TelegramMediaFile] = []
                    if let info = set.1 as? StickerPackCollectionInfo {
                        let items = available.enumerated().reversed()
                        for (i, entry) in items {
                            if entry.index.collectionId == info.id {
                                if let item = available.remove(at: i).item as? StickerPackItem {
                                    files.insert(item.file, at: 0)
                                }
                            }
                        }
                        if !files.isEmpty {
                            entries.append(.pack(index: .sticker(ItemCollectionViewEntryIndex(collectionIndex: index, collectionId: info.id, itemIndex: .init(index: 0, id: 0))), files: Array(files.prefix(5)), packInfo: .pack(info, installed: set.3, featured: true), collectionId: .pack(info.id)))
                        }
                    }
                } else {
                    break
                }
                index += 1
            }
        }
       
    }
    
    return entries
}

private func packEntries(view: ItemCollectionsView?, specificPack:Tuple2<PeerSpecificStickerPackData, Peer>?, hasUnread: Bool) -> [PackEntry] {
    var entries:[PackEntry] = []
    var index: Int = 0
    
    if let view = view {
        entries.append(.featured(hasUnread: hasUnread))
        
        if !view.orderedItemListsViews[1].items.isEmpty {
            entries.append(.saved)
        }
        if !view.orderedItemListsViews[0].items.isEmpty {
            entries.append(.recent)
        }
        if let specificPack = specificPack, let info = specificPack._0.packInfo?.0 {
            entries.append(.specificPack(data: SpecificPackData(info: info, peer: specificPack._1)))
        }
        
        for (_, info, item) in view.collectionInfos {
            if let info = info as? StickerPackCollectionInfo {
                entries.append(.stickerPack(index: index, stableId: .pack(info.id), info: info, topItem: item as? StickerPackItem))
                index += 1
            }
        }
    }

    return entries
}


private func prepareStickersTransition(from:[AppearanceWrapperEntry<StickerPackEntry>], to: [AppearanceWrapperEntry<StickerPackEntry>], initialSize: NSSize, arguments: StickerPanelArguments, update: StickerPacksUpdate) -> TableUpdateTransition {
    let (removed,inserted,updated) = proccessEntriesWithoutReverse(from, right: to, { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    })
    let state: TableScrollState
    var anim: Bool
    switch update {
    case let .generic(animated, scrollToTop):
        anim = animated
        if let scrollToTop = scrollToTop {
            if scrollToTop {
                state = .up(animated)
            } else {
                state = .saveVisible(.lower)
            }
        } else {
            state = .none(nil)
        }
        
    case let .scroll(animated):
        state = .saveVisible(.upper)
        anim = animated
    case let .navigate(index, animated):
        state = .top(id: index.collectionId, innerId: nil, animated: true, focus: .init(focus: false), inset: 0)
        anim = animated
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: anim, state: state, grouping: !anim)
}

fileprivate func preparePackTransition(from:[AppearanceWrapperEntry<PackEntry>]?, to:[AppearanceWrapperEntry<PackEntry>], context: AccountContext, initialSize:NSSize) -> TableUpdateTransition {
    
    let (deleted,inserted,updated) = proccessEntriesWithoutReverse(from, right: to, { (entry) -> TableRowItem in
        switch entry.entry {
        case let .stickerPack(index, stableId, info, topItem):
            return StickerPackRowItem(initialSize, packIndex: index, context: context, stableId: stableId, info: info, topItem: topItem)
        case .recent:
            return RecentPackRowItem(initialSize, entry.entry.stableId)
        case .featured:
            return RecentPackRowItem(initialSize, entry.entry.stableId)
        case .saved:
            return RecentPackRowItem(initialSize, entry.entry.stableId)
        case let .specificPack(data):
            return StickerSpecificPackItem(initialSize, stableId: entry.entry.stableId, specificPack: (data.info, data.peer), account: context.account)
        }
    })
    
    return TableUpdateTransition(deleted: deleted, inserted: inserted, updated:updated, animated: true, state: .none(nil))
    
}

class NStickersView : View {
    fileprivate let tableView:TableView = TableView(frame: NSZeroRect)
    fileprivate var restrictedView:RestrictionWrappedView?
    private let emptySearchView = ImageView()
    private let emptySearchContainer: View = View()
    
    let searchView = SearchView(frame: .zero)
    private let searchContainer = View()
    fileprivate let packsView:HorizontalTableView = HorizontalTableView(frame: NSZeroRect)
    private let separator:View = View()
    fileprivate let tabsContainer: View = View()

    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(tableView)
        
        searchContainer.addSubview(searchView)
        addSubview(searchContainer)
        
        emptySearchContainer.addSubview(emptySearchView)
        tabsContainer.addSubview(packsView)
        tabsContainer.addSubview(separator)
        addSubview(tabsContainer)
        addSubview(emptySearchContainer)
        
        emptySearchContainer.isHidden = true
        emptySearchContainer.isEventLess = true
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    func updateRestricion(_ peer: Peer?) {
        if let peer = peer, let text = permissionText(from: peer, for: .banSendStickers) {
            restrictedView?.removeFromSuperview()
            restrictedView = RestrictionWrappedView(text)
            addSubview(restrictedView!)
        } else {
            restrictedView?.removeFromSuperview()
            restrictedView = nil
        }
        setFrameSize(frame.size)
        needsLayout = true
    }
    
    func updateEmpties(isEmpty: Bool, animated: Bool) {
        
        let emptySearchHidden: Bool = !isEmpty
        
        if !emptySearchHidden {
            emptySearchContainer.isHidden = false
        }
        
        emptySearchContainer.change(opacity: emptySearchHidden ? 0 : 1, animated: animated, completion: { [weak self] completed in
            if completed {
                self?.emptySearchContainer.isHidden = emptySearchHidden
            }
        })
        
        needsLayout = true
    }
    
    private var searchState: SearchState? = nil
    
    func updateSearchState(_ searchState: SearchState, animated: Bool) {
        self.searchState = searchState
        switch searchState.state {
        case .Focus:
            tabsContainer.change(pos: NSMakePoint(0, -tabsContainer.frame.height), animated: animated)
            searchContainer.change(pos: NSMakePoint(0, tabsContainer.frame.maxY), animated: animated)
        case .None:
            tabsContainer.change(pos: NSMakePoint(0, 0), animated: animated)
            searchContainer.change(pos: NSMakePoint(0, tabsContainer.frame.maxY), animated: animated)
        }
        tableView.change(size: NSMakeSize(frame.width, frame.height - searchContainer.frame.maxY), animated: animated)
        tableView.change(pos: NSMakePoint(0, searchContainer.frame.maxY), animated: animated)

    }
    
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        self.restrictedView?.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        self.separator.backgroundColor = theme.colors.border
        self.tableView.updateLocalizationAndTheme(theme: theme)
        self.tableView.backgroundColor = theme.colors.background
        self.tableView.documentView?.background = theme.colors.background
        self.emptySearchView.image = theme.icons.stickersEmptySearch
        self.emptySearchView.sizeToFit()
        self.emptySearchContainer.backgroundColor = theme.colors.background
        self.searchView.updateLocalizationAndTheme(theme: theme)
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    override func layout() {
        super.layout()

        let initial: CGFloat = searchState?.state == .Focus ? -50 : 0
        
        tabsContainer.frame = NSMakeRect(0, initial, frame.width, 50)
        separator.frame = NSMakeRect(0, tabsContainer.frame.height - .borderSize, tabsContainer.frame.width, .borderSize)
        packsView.frame = tabsContainer.focus(NSMakeSize(frame.width, 40))
        
        
        searchContainer.frame = NSMakeRect(0, tabsContainer.frame.maxY, frame.width, 50)
        searchView.setFrameSize(NSMakeSize(frame.width - 20, 30))
        searchView.center()
        
        
        tableView.frame = NSMakeRect(0, searchContainer.frame.maxY, frame.width, frame.height - searchContainer.frame.maxY)
        restrictedView?.setFrameSize(frame.size)
        
        emptySearchContainer.frame = tableView.frame
        emptySearchView.center()
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}



class NStickersViewController: TelegramGenericViewController<NStickersView>, TableViewDelegate, Notifable {

    private let searchValue = ValuePromise<SearchState>(.init(state: .None, request: nil))
    private var searchState: SearchState = .init(state: .None, request: nil) {
        didSet {
            self.searchValue.set(searchState)
        }
    }
    private let position = ValuePromise<StickerPacksScrollState>(ignoreRepeated: true)
    private let disposable = MetaDisposable()
    private let searchStateDisposable = MetaDisposable()
    private let specificPeerId = ValuePromise<PeerId>(ignoreRepeated: true)
    private var listener: TableScrollListener!
    private var interactions: EntertainmentInteractions?
    private weak var chatInteraction: ChatInteraction?
    var makeSearchCommand:((ESearchCommand)->Void)?
    override init(_ context: AccountContext) {
        super.init(context)
        bar = .init(height: 0)
    }
    
    private func updateSearchState(_ state: SearchState) {
        self.position.set(.initial)
        self.searchState = state
        if !state.request.isEmpty {
            self.makeSearchCommand?(.loading)
        }
        if self.isLoaded() == true {
            self.genericView.updateSearchState(state, animated: true)
            self.genericView.tableView.scroll(to: .up(true))

        }
    }
    
    deinit {
        disposable.dispose()
        searchStateDisposable.dispose()
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        self.genericView.packsView.updateLocalizationAndTheme(theme: theme)
    }
    
    func update(with interactions:EntertainmentInteractions, chatInteraction: ChatInteraction) {
        self.interactions = interactions
        self.chatInteraction?.remove(observer: self)
        self.chatInteraction = chatInteraction
        chatInteraction.add(observer: self)
        if isLoaded() {
            genericView.updateRestricion(chatInteraction.presentation.peer)
        }
        self.specificPeerId.set(chatInteraction.peerId)
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState {
            if let peer = value.peer, let oldPeer = oldValue.peer {
                if permissionText(from: peer, for: .banSendStickers) != permissionText(from: oldPeer, for: .banSendStickers) {
                    genericView.updateRestricion(peer)
                }
            } else if (oldValue.peer != nil) != (value.peer != nil), let peer = value.peer {
                genericView.updateRestricion(peer)
            }
        }
    }
    
    func isEqual(to other: Notifable) -> Bool {
        return other === self
    }
    
    func isSelectable(row: Int, item: TableRowItem) -> Bool {
        return true
    }
    func selectionWillChange(row: Int, item: TableRowItem, byClick: Bool) -> Bool {
        return true
    }
    func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) {
        if byClick, let collectionId = item.stableId.base as? StickerPackCollectionId {
            if let item = genericView.tableView.item(stableId: collectionId) {
                self.genericView.tableView.removeScroll(listener: self.listener)
                self.genericView.tableView.scroll(to: .top(id: item.stableId, innerId: nil, animated: true, focus: .init(focus: false), inset: 0), completion: { [weak self] _ in
                    if let `self` = self {
                        self.genericView.tableView.addScroll(listener: self.listener)
                    }
                })
            } else {
                var index: StickerPacksIndex? = nil
                switch collectionId {
                case let .pack(id):
                    if let item = item as? StickerPackRowItem {
                        index = .sticker(ItemCollectionViewEntryIndex.lowerBound(collectionIndex: Int32(item.packIndex), collectionId: id))
                    }
                case .featured:
                    self.interactions?.toggleSearch()
                case .saved:
                    index = .saved(0)
                case .recent:
                    index = .recent(1)
                case let .specificPack(id):
                    index = .speficicPack(id)
                case .emojiRelated:
                    break
                }
                if let index = index {
                    self.genericView.tableView.removeScroll(listener: self.listener)
                    self.position.set(.navigate(index: index))
                }
            }
            
        }
    }
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let context = self.context
        let initialSize = self.atomicSize
        
       
        let searchInteractions = SearchInteractions({ [weak self] state, _ in
            self?.updateSearchState(state)
        }, { [weak self] state in
            self?.updateSearchState(state)
        })
        
        genericView.searchView.searchInteractions = searchInteractions
        
        listener = TableScrollListener(dispatchWhenVisibleRangeUpdated: false, { [weak self] position in
            guard let `self` = self, position.visibleRows.length > 0 else {
                return
            }
            let item = self.genericView.tableView.item(at: position.visibleRows.location)
            self.genericView.packsView.changeSelection(stableId: item.stableId)
            self.genericView.packsView.scroll(to: .center(id: item.stableId, innerId: nil, animated: true, focus: .init(focus: false), inset: 0))
        })

        self.genericView.packsView.delegate = self
        
        let previous:Atomic<[AppearanceWrapperEntry<StickerPackEntry>]> = Atomic(value: [])
        
        let foundPacks: Atomic<StickerPacksSearchData?> = Atomic(value: nil)
        
        let previousPacks:Atomic<[AppearanceWrapperEntry<PackEntry>]> = Atomic(value: [])

        
        let arguments = StickerPanelArguments(context: context, sendMedia: { [weak self] media, view, silent in
            guard let `self` = self, let chatInteraction = self.chatInteraction else { return }
            if let slowMode = chatInteraction.presentation.slowMode, slowMode.hasLocked {
                showSlowModeTimeoutTooltip(slowMode, for: view)
            } else if let file = media as? TelegramMediaFile {
                self.interactions?.sendSticker(file, silent)
            }
        }, showPack: { [weak self] reference in
            if let peerId = self?.chatInteraction?.peerId {
                showModal(with: StickerPackPreviewModalController(context, peerId: peerId, reference: reference), for: context.window)
            }
        }, addPack: { [weak self] reference in
            _ = showModalProgress(signal: loadedStickerPack(postbox: context.account.postbox, network: context.account.network, reference: reference, forceActualized: false)
                |> filter { result in
                    switch result {
                    case .result:
                        return true
                    default:
                        return false
                    }
                }
                |> take(1)
                |> mapToSignal { result -> Signal<ItemCollectionId, NoError> in
                    switch result {
                    case let .result(info, items, _):
                        return addStickerPackInteractively(postbox: context.account.postbox, info: info, items: items) |> map { info.id }
                    default:
                        return .complete()
                    }
                }
                |> deliverOnMainQueue, for: context.window).start(next: { [weak self] result in
                    if let `self` = self {
                        if !self.searchState.request.isEmpty {
                            self.makeSearchCommand?(.close)
                            self.position.set(.navigate(index: StickerPacksIndex.sticker(ItemCollectionViewEntryIndex.lowerBound(collectionIndex: 0, collectionId: result))))
                        }
                    }
                })
        }, navigate: { [weak self] index in
            self?.position.set(.navigate(index: .sticker(index)))
        }, clearRecent: {
            confirm(for: context.window, header: L10n.stickersConfirmClearRecentHeader, information: L10n.stickersConfirmClearRecentText, okTitle: L10n.stickersConfirmClearRecentOK, successHandler: { _ in
                _ = context.account.postbox.transaction({ transaction in
                    clearRecentlyUsedStickers(transaction: transaction)
                }).start()
            })
        }, removePack: { collectionId in
            if let id = collectionId.itemCollectionId {
                _ = showModalProgress(signal: removeStickerPackInteractively(postbox: context.account.postbox, id: id, option: .delete), for: context.window).start()
            }
        })
        
        let specificPackData: Signal<Tuple2<PeerSpecificStickerPackData, Peer>?, NoError> = self.specificPeerId.get() |> mapToSignal { peerId -> Signal<Peer, NoError> in
            return context.account.postbox.loadedPeerWithId(peerId)
        } |> mapToSignal { peer -> Signal<Tuple2<PeerSpecificStickerPackData, Peer>?, NoError> in
            if peer.isSupergroup {
                return peerSpecificStickerPack(postbox: context.account.postbox, network: context.account.network, peerId: peer.id) |> map { data in
                    return Tuple2(data, peer)
                }
            } else {
                return .single(nil)
            }
        }
        
        let signal = combineLatest(queue: prepareQueue, self.searchValue.get(), self.position.get()) |> mapToSignal { values -> Signal<StickerPacksUpdateData, NoError> in
            
            let count = initialSize.with { size -> Int in
                return Int(round((size.height * (values.1 == .initial ? 2 : 20)) / 60 * 5))
            }
            if values.0.state == .None {
                var firstTime: Bool = true
                switch values.1 {
                case .initial:
                    return context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudRecentStickers, Namespaces.OrderedItemList.CloudSavedStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: nil, count: count)
                        |> mapToSignal { view  in
                            return specificPackData |> map { specificPack in
                                let scrollToTop = firstTime
                                firstTime = false
                                return StickerPacksUpdateData(view: view, update: .generic(animated: scrollToTop, scrollToTop: scrollToTop), specificPack: specificPack, hasUnread: false)
                            }
                    }
                case let .scroll(aroundIndex):
                    var firstTime = true
                    return context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudRecentStickers, Namespaces.OrderedItemList.CloudSavedStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: aroundIndex.packIndex, count: count)
                        |> mapToSignal { view in
                            return specificPackData |> map { specificPack in
                                let update: StickerPacksUpdate
                                if firstTime {
                                    firstTime = false
                                    update = .scroll(animated: false)
                                } else {
                                    update = .generic(animated: false, scrollToTop: false)
                                }
                                return StickerPacksUpdateData(view: view, update: update, specificPack: specificPack, hasUnread: false)
                            }
                    }
                case let .navigate(index):
                    var firstTime = true
                    return context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudRecentStickers, Namespaces.OrderedItemList.CloudSavedStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: index.packIndex, count: count)
                        |> mapToSignal { view in
                            return specificPackData |> map { specificPack in
                                let update: StickerPacksUpdate
                                if firstTime {
                                    firstTime = false
                                    update = .navigate(index, animated: true)
                                } else {
                                    update = .generic(animated: false, scrollToTop: false)
                                }
                                return StickerPacksUpdateData(view: view, update: update, specificPack: specificPack, hasUnread: false)
                            }
                    } 
                case .loadFeaturedMore:
                    fatalError("load featured for basic packs is not possible")
                }
            } else {
                let searchText = values.0.request.lowercased()
                if values.0.request.isEmpty {
                    switch values.1 {
                    case .initial:
                        return combineLatest(context.account.viewTracker.featuredStickerPacks(), context.account.postbox.combinedView(keys: [.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])])) |> map { value, view in
                            var found = FoundStickerSets()
                            
                            var installedPacks = Set<ItemCollectionId>()
                            if let stickerPacksView = view.views[.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])] as? ItemCollectionInfosView {
                                if let packsEntries = stickerPacksView.entriesByNamespace[Namespaces.ItemCollection.CloudStickerPacks] {
                                    for entry in packsEntries {
                                        installedPacks.insert(entry.id)
                                    }
                                }
                            }
                            
                            for (collectionIndex, set) in value.enumerated() {
                                var entries:[ItemCollectionViewEntry] = []
                                
                                for item in set.topItems {
                                    entries.append(ItemCollectionViewEntry(index: ItemCollectionViewEntryIndex(collectionIndex: Int32(collectionIndex), collectionId: set.info.id, itemIndex: item.index), item: item))
                                }
                                if !entries.isEmpty {
                                    found = found.merge(with: FoundStickerSets(infos: [(set.info.id, set.info, nil, installedPacks.contains(set.info.id))], entries: entries))
                                }
                            }
                            let searchData = StickerPacksSearchData(sets: found, loading: false, basicFeaturedCount: found.infos.count, emojiRelated: [])
                            return StickerPacksUpdateData(view: nil, update: .generic(animated: true, scrollToTop: true), specificPack: nil, searchData: searchData, hasUnread: false)
                        }
                    case let .loadFeaturedMore(current):
                        return combineLatest(requestOldFeaturedStickerPacks(network: context.account.network, postbox: context.account.postbox, offset: current.sets.infos.count - current.basicFeaturedCount, limit: 50), context.account.postbox.combinedView(keys: [.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])])) |> map { values, view in
                            var found = current.sets
                            
                            
                            var installedPacks = Set<ItemCollectionId>()
                            if let stickerPacksView = view.views[.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])] as? ItemCollectionInfosView {
                                if let packsEntries = stickerPacksView.entriesByNamespace[Namespaces.ItemCollection.CloudStickerPacks] {
                                    for entry in packsEntries {
                                        installedPacks.insert(entry.id)
                                    }
                                }
                            }
                            
                            found = found.updateInfos( { infos in
                                var infos = infos
                                for (i, info) in infos.enumerated() {
                                    infos[i] = (info.0, info.1, info.2, installedPacks.contains(info.0))
                                }
                                return infos
                            })
                            
                            for (collectionIndex, set) in values.enumerated() {
                                var entries:[ItemCollectionViewEntry] = []
                                
                                for item in set.topItems {
                                    entries.append(ItemCollectionViewEntry(index: ItemCollectionViewEntryIndex(collectionIndex: Int32(collectionIndex), collectionId: set.info.id, itemIndex: item.index), item: item))
                                }
                                if !entries.isEmpty {
                                    found = found.merge(with: FoundStickerSets(infos: [(set.info.id, set.info, nil, installedPacks.contains(set.info.id))], entries: entries))
                                }
                            }
                            let searchData = StickerPacksSearchData(sets: found, loading: false, basicFeaturedCount: current.basicFeaturedCount, emojiRelated: [])
                            return StickerPacksUpdateData(view: nil, update: .generic(animated: false, scrollToTop: nil), specificPack: nil, searchData: searchData, hasUnread: false)
                        }
                    default:
                        fatalError()
                    }
                    
                } else {
                    let searchLocal = searchStickerSets(postbox: context.account.postbox, query: searchText) |> delay(0.2, queue: prepareQueue) |> map(Optional.init)
                    let searchRemote = searchStickerSetsRemotely(network: context.account.network, query: searchText) |> delay(0.2, queue: prepareQueue) |> map(Optional.init)
                    
                    let emojiRelated: Signal<[FoundStickerItem], NoError> = context.sharedContext.inputSource.searchEmoji(postbox: context.account.postbox, sharedContext: context.sharedContext, query: searchText, completeMatch: true, checkPrediction: false) |> mapToSignal { emojis in
                        
                        let signals = emojis.map {
                            searchStickers(account: context.account, query: $0, scope: [.installed])
                        }
                        return combineLatest(signals) |> map {
                            $0.reduce([], { current, value in
                                return current + value.filter { $0.file.stickerText != nil && emojis.contains($0.file.stickerText!) }
                            })
                        }
                    } |> delay(0.2, queue: prepareQueue)

                    return combineLatest(searchLocal, searchRemote, emojiRelated) |> map { local, remote, emojiRelated in
                        var value = FoundStickerSets()
                        if let local = local {
                            value = value.merge(with: local)
                        }
                        if let remote = remote {
                            value = value.merge(with: remote)
                        }
                        
                        let searchData = StickerPacksSearchData(sets: value, loading: remote == nil && value.entries.isEmpty, basicFeaturedCount: 0, emojiRelated: emojiRelated)
                        return StickerPacksUpdateData(view: nil, update: .generic(animated: true, scrollToTop: nil), specificPack: nil, searchData: searchData, hasUnread: false)
                    }
                }
                
            }
            
        } |> deliverOnPrepareQueue
        |> mapToSignal { data -> Signal<StickerPacksUpdateData, NoError> in
            let hasUnread = context.account.viewTracker.featuredStickerPacks() |> map { featured in
                return featured.contains(where: { $0.unread })
            }
            return hasUnread |> map {
                return data.withUpdatedHasUnread($0)
            }
        }
        
        let transition = combineLatest(queue: prepareQueue, appearanceSignal, signal)
             |> map { appearance, data -> (TableUpdateTransition, TableUpdateTransition, [AppearanceWrapperEntry<PackEntry>]) in
                
                _ = foundPacks.swap(data.searchData)
                
                let entries = stickersEntries(view: data.view, searchData: data.searchData, specificPack: data.specificPack).map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
                let from = previous.swap(entries)
                
                let entriesPack = packEntries(view: data.view, specificPack: data.specificPack, hasUnread: data.hasUnread).map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
                let fromPacks = previousPacks.swap(entriesPack)
                
                let transition = prepareStickersTransition(from: from, to: entries, initialSize: initialSize.with { $0 }, arguments: arguments, update: data.update)
                let packTransition = preparePackTransition(from: fromPacks, to: entriesPack, context: context, initialSize: initialSize.with { $0 })
                
                return (transition, packTransition, entriesPack)
        } |> deliverOnMainQueue
        
        var first: Bool = true
        
        disposable.set(transition.start(next: { [weak self] (transition, packTransition, entriesPack) in
            guard let `self` = self else { return }
            
            self.genericView.tableView.removeScroll(listener: self.listener)
            self.genericView.tableView.merge(with: transition)
            self.genericView.packsView.merge(with: packTransition)
            self.genericView.updateEmpties(isEmpty: self.genericView.tableView.isEmpty, animated: !first)
            
            self.genericView.tableView.addScroll(listener: self.listener)
            first = false
            
            var visibleRows = self.genericView.tableView.visibleRows()
            if visibleRows.length == 0, !self.genericView.tableView.isEmpty {
                visibleRows.location = 0
                visibleRows.length = 1
            }
            if visibleRows.length > 0 {
                let item = self.genericView.tableView.item(at: visibleRows.location)
                self.genericView.packsView.changeSelection(stableId: item.stableId)
            }
            
            self.makeSearchCommand?(.normal)
            
           
            if !packTransition.isEmpty {
                var resortRange: NSRange = NSMakeRange(0, 0)
                let entries = entriesPack.map( {$0.entry })
                
                for entry in entries {
                    switch entry {
                    case .saved, .recent, .specificPack, .featured:
                        resortRange.location += 1
                    default:
                        break
                    }
                }
                if entries.count > resortRange.location {
                    resortRange.length = entries.count - resortRange.location
                }
                self.genericView.packsView.resortController = TableResortController(resortRange: resortRange, start: { _ in }, resort: { _ in }, complete: { fromIndex, toIndex in
                    
                    
                    if fromIndex == toIndex {
                        return
                    }
                    
                    let entries = entriesPack.map( {$0.entry })
                    
                    
                    let fromEntry = entries[fromIndex]
                    
                    guard case let .stickerPack(_, _, fromPackInfo, _) = fromEntry else {
                        return
                    }
                    
                    var referenceId: ItemCollectionId?
                    var beforeAll = false
                    var afterAll = false
                    if toIndex < entries.count {
                        switch entries[toIndex] {
                        case let .stickerPack(_, _, toPackInfo, _):
                            referenceId = toPackInfo.id
                        default:
                            if entries[toIndex] < fromEntry {
                                beforeAll = true
                            } else {
                                afterAll = true
                            }
                        }
                    } else {
                        afterAll = true
                    }
                    
                    
                    let _ = (context.account.postbox.transaction { transaction -> Void in
                        var infos = transaction.getItemCollectionsInfos(namespace: Namespaces.ItemCollection.CloudStickerPacks)
                        var reorderInfo: ItemCollectionInfo?
                        for i in 0 ..< infos.count {
                            if infos[i].0 == fromPackInfo.id {
                                reorderInfo = infos[i].1
                                infos.remove(at: i)
                                break
                            }
                        }
                        if let reorderInfo = reorderInfo {
                            if let referenceId = referenceId {
                                var inserted = false
                                for i in 0 ..< infos.count {
                                    if infos[i].0 == referenceId {
                                        if fromIndex < toIndex {
                                            infos.insert((fromPackInfo.id, reorderInfo), at: i + 1)
                                        } else {
                                            infos.insert((fromPackInfo.id, reorderInfo), at: i)
                                        }
                                        inserted = true
                                        break
                                    }
                                }
                                if !inserted {
                                    infos.append((fromPackInfo.id, reorderInfo))
                                }
                            } else if beforeAll {
                                infos.insert((fromPackInfo.id, reorderInfo), at: 0)
                            } else if afterAll {
                                infos.append((fromPackInfo.id, reorderInfo))
                            }
                            addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: Namespaces.ItemCollection.CloudStickerPacks, content: .sync, noDelay: false)
                            transaction.replaceItemCollectionInfos(namespace: Namespaces.ItemCollection.CloudStickerPacks, itemCollectionInfos: infos)
                        }
                    } |> deliverOnMainQueue).start(completed: { [weak self] in
                        if let `self` = self {
                            self.genericView.tableView.removeScroll(listener: self.listener)
                        }
                    })
                })
            }
            
            self.readyOnce()
        }))
        
        self.genericView.tableView.setScrollHandler { [weak self] position in
            if let `self` = self {
                let entries = previous.with ({ $0 })
                let index:StickerPacksIndex?
                
                if let foundPacks = foundPacks.with ({ $0 }), self.searchState.state == .Focus {
                    self.position.set(.loadFeaturedMore(foundPacks))
                } else {
                    switch position.direction {
                    case .bottom:
                        index = entries.last?.entry.index
                    case .top:
                        index = entries.first?.entry.index
                    case .none:
                        index = nil
                    }
                    if let index = index, self.searchState.state == .None {
                        self.position.set(.scroll(aroundIndex: index))
                    }
                }
            }
        }
        
        self.position.set(.initial)
        
    }
    override func scrollup(force: Bool = false) {
        self.position.set(.initial)
        self.genericView.packsView.scroll(to: .up(true))
      //  self.genericView.tableView.scroll(to: .up(true))
    }
    
    override var supportSwipes: Bool {
        return !self.genericView.packsView._mouseInside()
    }
    
}
