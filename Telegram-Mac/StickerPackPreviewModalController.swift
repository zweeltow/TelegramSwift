//
//  StickerPackPreviewModalController.swift
//  Telegram
//
//  Created by keepcoder on 27/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit




final class StickerPackArguments {
    let context: AccountContext
    let send:(TelegramMediaFile, NSView)->Void
    let addpack:(StickerPackCollectionInfo, [ItemCollectionItem], Bool)->Void
    let share:(String)->Void
    let close:()->Void
    init(context: AccountContext, send:@escaping(Media, NSView)->Void, addpack:@escaping(StickerPackCollectionInfo, [ItemCollectionItem], Bool)->Void, share:@escaping(String)->Void, close:@escaping()->Void) {
        self.context = context
        self.send = send
        self.addpack = addpack
        self.share = share
        self.close = close
    }
}



private class StickersModalView : View {
    private let grid:GridNode = GridNode(frame: NSZeroRect)
    private let add:TitleButton = TitleButton()
    private let shareView:ImageButton = ImageButton()
    private let close: ImageButton = ImageButton()
    private let headerTitle:TextView = TextView()
    private let headerSeparatorView:View = View()
    private let dismiss:ImageButton = ImageButton()
    private var indicatorView:ProgressIndicator?
    private let shadowView: ShadowView = ShadowView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundColor = theme.colors.background
        addSubview(grid)
        //addSubview(interactionView)
        addSubview(headerTitle)
        addSubview(shareView)
        addSubview(close)
        addSubview(headerSeparatorView)
        addSubview(dismiss)
        
        shadowView.shadowBackground = theme.colors.background
        shadowView.setFrameSize(frame.width, 70)
        
        addSubview(shadowView)
        
        dismiss.set(image: theme.icons.stickerPackDelete, for: .Normal)
        _ = dismiss.sizeToFit()
        add.disableActions()
        add.setFrameSize(170, 40)
        add.layer?.cornerRadius = 20
        
        add.set(color: theme.colors.underSelectedColor, for: .Normal)
        add.set(font: .medium(.title), for: .Normal)
        add.set(background: theme.colors.accent, for: .Normal)
        add.set(background: theme.colors.accent, for: .Hover)
        add.set(background: theme.colors.accent, for: .Highlight)
        add.set(text: L10n.stickerPackAdd1Countable(0), for: .Normal)

        addSubview(add)
        headerTitle.backgroundColor = theme.colors.background
        headerSeparatorView.backgroundColor = theme.colors.border
        
        shareView.set(image: theme.icons.stickersShare, for: .Normal)
        close.set(image: theme.icons.stickerPackClose, for: .Normal)
        _ = shareView.sizeToFit()
        _ = close.sizeToFit()
        
        
    }
    
    
    func layout(with result: LoadedStickerPack, arguments: StickerPackArguments) -> Void {
        

        switch result {
        case .none:
            break
        case .fetching:
            dismiss.isHidden = true
            shareView.isHidden = true
            if self.indicatorView == nil {
                self.indicatorView = ProgressIndicator(frame: NSMakeRect(0, 0, 30, 30))
                addSubview(self.indicatorView!)
            }
            self.indicatorView?.center()
            add.isHidden = true
            shadowView.isHidden = true
        case let .result(info: info, items: collectionItems, installed: installed):
            if let indicatorView = self.indicatorView {
                self.indicatorView = nil
                indicatorView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak indicatorView] _ in
                    indicatorView?.removeFromSuperview()
                })
            }
            dismiss.isHidden = !installed
            shareView.isHidden = false
            add.set(text: tr(L10n.stickerPackAdd1Countable(collectionItems .count)).uppercased(), for: .Normal)
            _ = add.sizeToFit(NSMakeSize(20, 0), NSMakeSize(frame.width - 40, 40), thatFit: false)
            add.isHidden = installed
            shadowView.isHidden = installed
            let attr = NSMutableAttributedString()
            
            _ = attr.append(string: info.title, color: theme.colors.text, font: .medium(16.0))
            attr.detectLinks(type: [.Mentions], context: arguments.context, color: theme.colors.accent, openInfo: { (peerId, _, _, _) in
                _ = (arguments.context.account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue).start(next: { peer in
                    arguments.close()
                    if peer.isUser || peer.isBot {
                        arguments.context.sharedContext.bindings.rootNavigation().push(PeerInfoController(context: arguments.context, peerId: peerId))
                    } else {
                        arguments.context.sharedContext.bindings.rootNavigation().push(ChatAdditionController(context: arguments.context, chatLocation: .peer(peer.id)))
                    }
                })
            })
            let layout = TextViewLayout(attr, maximumNumberOfLines: 2, alignment: .center)
            layout.interactions = globalLinkExecutor
            
            
            layout.measure(width: frame.width - 160)
            headerTitle.update(layout)
            
            let items = collectionItems.filter({ item -> Bool in
                return item is StickerPackItem
            }).map ({ item -> StickerPackGridItem in
                return StickerPackGridItem(context: arguments.context, file: (item as! StickerPackItem).file, send: arguments.send, selected: {})
            })
            
            var insert:[GridNodeInsertItem] = []
            
            for index in 0 ..< items.count {
                insert.append(GridNodeInsertItem(index: index, item: items[index], previousIndex: nil))
            }
            
            grid.removeAllItems()
            
            grid.transaction(GridNodeTransaction(deleteItems: [], insertItems: insert, updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: CGSize(width: frame.width, height: frame.height), insets: NSEdgeInsets(left: 0, right: 0, top: 10, bottom: installed ? 0 : 60), preloadSize: self.bounds.width, type: .fixed(itemSize: CGSize(width: 70, height: 70), lineSpacing: 10)), transition: .immediate), itemTransition: .immediate, stationaryItems: .all, updateFirstIndexInSectionOffset: nil), completion: { _ in })
            
            grid.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            self.needsLayout = true
            
            
            
            shareView.set(handler: { _ in
                arguments.share("https://t.me/addstickers/\(info.shortName)")
            }, for: .SingleClick)
            
            add.removeAllHandlers()
            dismiss.removeAllHandlers()
            close.removeAllHandlers()
            
            func action(_ control:Control) {
                arguments.addpack(info, collectionItems, installed)
            }
            
            
            add.set(handler: action, for: .SingleClick)
            dismiss.set(handler: action, for: .SingleClick)

            close.set(handler: { _ in
                arguments.close()
            }, for: .Click)
            
        }
        
       
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        let headerHeight:CGFloat = 50
        
        grid.frame = NSMakeRect(0, headerHeight, frame.width, frame.height - headerHeight)
        
        headerTitle.centerX(y : floorToScreenPixels(backingScaleFactor, (headerHeight - headerTitle.frame.height)/2) + 1)
        headerSeparatorView.frame = NSMakeRect(0, headerHeight - .borderSize, frame.width, .borderSize)
        shareView.setFrameOrigin(frame.width - close.frame.width - 12, floorToScreenPixels(backingScaleFactor, (headerHeight - shareView.frame.height)/2))
        close.setFrameOrigin(12, floorToScreenPixels(backingScaleFactor, (headerHeight - shareView.frame.height)/2))
        add.centerX(y: frame.height - add.frame.height - 15)
        dismiss.setFrameOrigin(NSMakePoint(shareView.frame.minX - dismiss.frame.width - 15, floorToScreenPixels(backingScaleFactor, (headerHeight - shareView.frame.height)/2)))
        
        shadowView.setFrameOrigin(0, frame.height - shadowView.frame.height)
    }
}



class StickerPackPreviewModalController: ModalViewController {
    private let context:AccountContext
    private let peerId:PeerId?
    private let reference:StickerPackReference
    private let disposable: MetaDisposable = MetaDisposable()
    private var arguments:StickerPackArguments!
   
    init(_ context: AccountContext, peerId:PeerId?, reference:StickerPackReference) {
        self.context = context
        self.peerId = peerId
        self.reference = reference
        super.init(frame: NSMakeRect(0, 0, 350, 400))
        bar = .init(height: 0)
        arguments = StickerPackArguments(context: context, send: { [weak self] media, view in
            let interactions = (context.sharedContext.bindings.rootNavigation().controller as? ChatController)?.chatInteraction
            
            if let interactions = interactions, let media = media as? TelegramMediaFile, media.maskData == nil {
                if let slowMode = interactions.presentation.slowMode, slowMode.hasLocked {
                    showSlowModeTimeoutTooltip(slowMode, for: view)
                } else {
                    interactions.sendAppFile(media, false, nil)
                    self?.close()
                }
            }
        }, addpack: { [weak self] info, items, installed in
            self?.close()
            self?.disposable.dispose()
            if !installed {
                _ = addStickerPackInteractively(postbox: context.account.postbox, info: info, items: items).start()
            } else {
                _ = removeStickerPackInteractively(postbox: context.account.postbox, id: info.id, option: .archive).start()
            }
            
        }, share: { [weak self] link in
            self?.close()
            showModal(with: ShareModalController(ShareLinkObject(context, link: link)), for: mainWindow)
        }, close: { [weak self] in
            self?.close()
        })
    }
    
    fileprivate var genericView:StickersModalView {
        return self.view as! StickersModalView
    }
    
    override func viewClass() -> AnyClass {
        return StickersModalView.self
    }
    
    
    override var dynamicSize: Bool {
        return true
    }
    
    
    override func measure(size: NSSize) {
       // self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(size.height - 70, genericView.listHeight)), animated: false)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        disposable.set((loadedStickerPack(postbox: context.account.postbox, network: context.account.network, reference: reference, forceActualized: true) |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let `self` = self else {return}
            switch result {
            case .none:
                alert(for: mainWindow, info: L10n.stickerSetDontExist)
                self.close()
            default:
                self.genericView.layout(with: result, arguments: self.arguments)
                self.readyOnce()
            }

        }))

    }
    
    
    deinit {
        disposable.dispose()
    }
    
}
