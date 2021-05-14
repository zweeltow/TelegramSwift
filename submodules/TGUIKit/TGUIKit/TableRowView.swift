//
//  TableRowView.swift
//  TGUIKit
//
//  Created by keepcoder on 07/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import AVFoundation
import Foundation

open class TableRowView: NSTableRowView, CALayerDelegate {
    
    private var animatedView: RowAnimateView?

    private let longDisposable = MetaDisposable()
    
    public internal(set) var isResorting: Bool = false {
        didSet {
            updateIsResorting()
        }
    }
    
    var dynamicContentStateForRestore:Bool? = nil
    var interactionStateForRestore:Bool? = nil
    
    public var isDynamicContentLocked:Bool = false {
        didSet {
            if isDynamicContentLocked != oldValue {
                viewDidUpdatedDynamicContent()
            }
        }
    }
    public var userInteractionEnabled:Bool = true {
        didSet {
            if userInteractionEnabled != oldValue {
                viewDidUpdatedInteractivity()
            }
        }
    }
    
    open func viewDidUpdatedInteractivity() {
        
    }
    open func viewDidUpdatedDynamicContent() {
        
    }
    
    
    open private(set) weak var item:TableRowItem?
    private let menuDisposable = MetaDisposable()
    // var selected:Bool?
    
    open var border:BorderType?
    public var animates:Bool = true
    
    public private(set) var contextMenu:ContextMenu?
    
    
    required public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // self.layer = (self.layerClass() as! CALayer.Type).init()
        self.wantsLayer = true
        backgroundColor = .clear
        self.layerContentsRedrawPolicy = .never
        autoresizingMask = []
      //  self.layer?.delegate = self
        autoresizesSubviews = false
     //   canDrawSubviewsIntoLayer = true
        pressureConfiguration = NSPressureConfiguration(pressureBehavior: .primaryDeepClick)
        appearance = presentation.appearance
        self.canDrawSubviewsIntoLayer = true
    }
    

    
    open func updateColors() {
        self.layer?.backgroundColor = backdorColor.cgColor
    }
    
    open override func smartMagnify(with event: NSEvent) {
        super.smartMagnify(with: event)
    }
    
    open func layerClass() ->AnyClass {
        return CALayer.self;
    }
    
    open var backdorColor: NSColor {
        return presentation.colors.background
    }
    
    open var isSelect: Bool {
        return item?.isSelected ?? false
    }
    
    open var isHighlighted: Bool {
         return item?.isHighlighted ?? false
    }
    
    open override func draw(_ dirtyRect: NSRect) {
        var bp:Int = 0
        bp += 1
    }
    open func updateIsResorting() {
        
    }

    
    open func draw(_ layer: CALayer, in ctx: CGContext) {
//        ctx.setFillColor(backdorColor.cgColor)
//        ctx.fill(layer.bounds)
       // layer.draw(in: ctx)
        
        if let border = border {
            
            ctx.setFillColor(presentation.colors.border.cgColor)
            
            if border.contains(.Top) {
                ctx.fill(NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize))
            }
            if border.contains(.Bottom) {
                ctx.fill(NSMakeRect(0, 0, frame.width, .borderSize))
            }
            if border.contains(.Left) {
                ctx.fill(NSMakeRect(0, 0, .borderSize, frame.height))
            }
            if border.contains(.Right) {
                ctx.fill(NSMakeRect(frame.width - .borderSize, 0, .borderSize, frame.height))
            }
            
        }
        
    }
    
    open func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        return self
    }
    open func interactionControllerDidFinishAnimation(interactive: Bool, innerId: AnyHashable) {
        
    }
    open func addAccesoryOnCopiedView(innerId: AnyHashable, view: NSView) {
        
    }
    open func videoTimebase(for innerId: AnyHashable) -> CMTimebase? {
        return nil
    }
    open func applyTimebase(for innerId: AnyHashable, timebase: CMTimebase?) {
        
    }
    
    open func hasFirstResponder() -> Bool {
        return false
    }
    
    open func nextResponder() -> NSResponder? {
        return nil
    }
    
    open var firstResponder:NSResponder? {
        return self
    }
    
    open override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateMouse()
    }
    open override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateMouse()
    }
    open override func mouseExited(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateMouse()
    }
    
    open override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) && event.clickCount == 1 {
            showContextMenu(event)
        } else {
            if event.clickCount == 2 {
                doubleClick(in: convert(event.locationInWindow, from: nil))
                return
            }
            super.mouseDown(with: event)
        }
    }
    
    private var lastPressureEventStage = 0
    
    open override func pressureChange(with event: NSEvent) {
        super.pressureChange(with: event)
        
        
        if event.stage >= 1 && event.stage != lastPressureEventStage {
            longDisposable.set(delaySignal(0.25).start(completed: { [weak self] in
                if let strongSelf = self {
                    if NSEvent.pressedMouseButtons & (1 << 0) != 0 {
                        if strongSelf.window?.mouseLocationOutsideOfEventStream == event.locationInWindow {
                            strongSelf.forceClick(in: strongSelf.convert(event.locationInWindow, from: nil))
                        }
                    }
                }
            }))
        }
        
        if event.stage < 1 {
            longDisposable.set(nil)
        }
        
        if event.stage == 2 && lastPressureEventStage < 2 {
            longDisposable.set(nil)
            forceClick(in: convert(event.locationInWindow, from: nil))
        }
        lastPressureEventStage = event.stage
    }
    
    open override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event)
        if mouseInside() {
            showContextMenu(event)
        }
    }
    
    open func doubleClick(in location:NSPoint) -> Void {
        
    }
    
    open func forceClick(in location: NSPoint) {
        
    }
    
    open func canMultiselectTextIn(_ location: NSPoint) -> Bool {
        return true
    }
    
    open func convertWindowPointToContent(_ point: NSPoint) -> NSPoint {
        return convert(point, from: nil)
    }
    
    open func showContextMenu(_ event:NSEvent) -> Void {
        
        menuDisposable.set(nil)
        contextMenu = nil
        
        if let item = item {
            menuDisposable.set((item.menuItems(in: convertWindowPointToContent(event.locationInWindow)) |> deliverOnMainQueue |> take(1)).start(next: { [weak self] items in
                if let strongSelf = self {
                    let menu = ContextMenu()

                    if let appearance = self?.rowAppearance {
                        if menu.responds(to: Selector("appearance")) {
                            menu.appearance = appearance
                        }
                    }

//                    presntContextMenu(for: event, items: items.compactMap({ item in
//                        if !(item is ContextSeparatorItem) {
//                            return SPopoverItem(item.title, item.handler)
//                        } else {
//                            return nil
//                        }
//                    }))
                    
//                    let window = Window(contentRect: NSMakeRect(event.locationInWindow.x + 100, event.locationInWindow.y, 100, 300), styleMask: [], backing: .buffered, defer: true)
//                    window.contentView?.wantsLayer = true
//                    window.contentView?.background = .random
//                    event.window?.addChildWindow(window, ordered: .above)
                    
                    menu.onShow = { [weak strongSelf] menu in
                        strongSelf?.contextMenu = menu
                        strongSelf?.onShowContextMenu()
                    }
                    menu.delegate = menu
                    menu.onClose = { [weak strongSelf] in
                        strongSelf?.contextMenu = nil
                        strongSelf?.onCloseContextMenu()
                    }
                    for item in items {
                        menu.addItem(item)
                    }
                    

                    RunLoop.current.add(Timer.scheduledTimer(timeInterval: 0, target: strongSelf, selector: #selector(strongSelf.openPanelInRunLoop), userInfo: (event, menu), repeats: false), forMode: RunLoop.Mode.modalPanel)

                    
//                    if #available(OSX 10.12, *) {
//                        RunLoop.current.perform(inModes: [.modalPanel], block: {
//                            NSMenu.popUpContextMenu(menu, with: event, for: strongSelf)
//                        })
//                    } else {
//                        // Fallback on earlier versions
//                    }
                    
                }
                
            }))
        }
        
        
    }
    
    @objc private func openPanelInRunLoop(_ timer:Foundation.Timer) {
        if let (event, menu) = timer.userInfo as? (NSEvent, NSMenu) {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }
    }
    
    open override func menu(for event: NSEvent) -> NSMenu? {
        return NSMenu()
    }
    
    
    
    
    open func onShowContextMenu() ->Void {
        self.layer?.setNeedsDisplay()
        updateColors()
    }
    
    open func onCloseContextMenu() ->Void {
        self.layer?.setNeedsDisplay()
        updateColors()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open func updateMouse() {
        
    }
    
    public var isInsertionAnimated:Bool {
        if let layer = layer?.presentation(), layer.animation(forKey: "position") != nil {
            return true
        }
        return false
    }
    
    public var rect:NSRect {
        if let layer = layer?.presentation(), layer.animation(forKey: "position") != nil {
            let rect = NSMakeRect(layer.position.x, layer.position.y, frame.width, frame.height)
            return rect
        }
        return frame
    }
    
    open override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        guard #available(OSX 10.12, *) else {
            needsLayout = true
            return
        }
    }
    
    open override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
        guard #available(OSX 10.12, *) else {
            needsLayout = true
            return
        }
    }
    
    open override func viewDidMoveToSuperview() {
        if superview != nil {
            guard #available(OSX 10.12, *) else {
                needsLayout = true
                return
            }
        }
    }
    
    open override func layout() {
        super.layout()
    }
    
    public func notifySubviewsToLayout(_ subview:NSView) -> Void {
        for sub in subview.subviews {
            sub.needsLayout = true
        }
    }
    
    
    open override var needsLayout: Bool {
        set {
            super.needsLayout = newValue
            if newValue {
                guard #available(OSX 10.12, *) else {
                    layout()
                    notifySubviewsToLayout(self)
                    return
                }
            }
        }
        get {
            return super.needsLayout
        }
    }
    
    deinit {
        longDisposable.dispose()
        menuDisposable.dispose()
    }
    
    open var mouseInsideField: Bool {
        return false
    }
    
    open override func copy() -> Any {
        let view:View = View(frame:bounds)
        view.backgroundColor = self.backdorColor
        return view
    }
    
    open func onRemove(_ animation: NSTableView.AnimationOptions) {
        
    }
    
    open func onInsert(_ animation: NSTableView.AnimationOptions) {
        
    }
    
    open func set(item:TableRowItem, animated:Bool = false) -> Void {
        self.item = item;
        updateColors()
    }
    
    open func focusAnimation(_ innerId: AnyHashable?) {
        
        if animatedView == nil {
            self.animatedView = RowAnimateView(frame: bounds)
            self.animatedView?.isEventLess = true
            self.addSubview(animatedView!)
            animatedView?.backgroundColor = presentation.colors.focusAnimationColor
            animatedView?.layer?.opacity = 0
            
        }
        animatedView?.stableId = item?.stableId
        
        
        let animation: CABasicAnimation = makeSpringAnimation("opacity")
        
        animation.fromValue = animatedView?.layer?.presentation()?.opacity ?? 0
        animation.toValue = 0.5
        animation.autoreverses = true
        animation.isRemovedOnCompletion = true
        animation.fillMode = CAMediaTimingFillMode.forwards
        
        animation.delegate = CALayerAnimationDelegate(completion: { [weak self] completed in
            if completed {
                self?.animatedView?.removeFromSuperview()
                self?.animatedView = nil
            }
        })
        animation.isAdditive = false
        
        animatedView?.layer?.add(animation, forKey: "opacity")
    }
    
    open var interactableView: NSView {
        return self
    }
    
    open func shakeView() {
        
    }
    
    open func shakeViewWithData(_ data: Any) {
        
    }
    
    open func change(pos position: NSPoint, animated: Bool, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeOut, completion:((Bool)->Void)? = nil) -> Void  {
        super._change(pos: position, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
    }
    
    open func change(size: NSSize, animated: Bool, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeOut, completion:((Bool)->Void)? = nil) {
        super._change(size: size, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
    }
    open func change(opacity to: CGFloat, animated: Bool = true, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeOut, completion:((Bool)->Void)? = nil) {
        super._change(opacity: to, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
    }
    
    open func mouseInside() -> Bool {
        return super._mouseInside()
    }
    
    open var rowAppearance: NSAppearance? {
        return self.appearance
    }
    
}
