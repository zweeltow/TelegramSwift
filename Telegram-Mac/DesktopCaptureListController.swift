//
//  DesktopCaptureListController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 29.12.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TgVoipWebrtc
import SwiftSignalKit



struct DesktopCapturerObjectWrapper : Equatable {
    static func == (lhs: DesktopCapturerObjectWrapper, rhs: DesktopCapturerObjectWrapper) -> Bool {
        if !lhs.source.isEqual(rhs.source) {
            return false
        }
        if lhs.isAvailableToStream != rhs.isAvailableToStream {
            return false
        }
        return true
    }

    let source: VideoSource
    let isAvailableToStream: Bool
}


final class CameraCaptureDevice : VideoSource, Equatable {
    func isEqual(_ another: Any) -> Bool {
        if let another = another as? VideoSource {
            return another.uniqueKey() == self.uniqueKey()
        } else {
            return false
        }
    }
    
    let device: AVCaptureDevice
    init(_ device: AVCaptureDevice) {
        self.device = device
    }
    func deviceIdKey() -> String {
        return self.device.uniqueID
    }
    func title() -> String {
        return device.localizedName
    }
    func uniqueKey() -> String {
        return self.device.uniqueID
    }
    static func ==(lhs: CameraCaptureDevice, rhs: CameraCaptureDevice) -> Bool {
        return lhs.device == rhs.device
    }
}

private final class DesktopCaptureListArguments {
    let selectDesktop:(DesktopCaptureSource, DesktopCaptureSourceManager)->Void
    let selectCamera:(CameraCaptureDevice)->Void

    init(selectDesktop:@escaping(DesktopCaptureSource, DesktopCaptureSourceManager)->Void, selectCamera:@escaping(CameraCaptureDevice)->Void) {
        self.selectDesktop = selectDesktop
        self.selectCamera = selectCamera
    }
}

private struct DesktopCaptureListState : Equatable {

    struct Access : Equatable {
        let sharing: Bool
        let camera: Bool
    }

    var cameras:[CameraCaptureDevice]
    var screens: [DesktopCaptureSource]
    var windows: [DesktopCaptureSource]
    var selected: VideoSource?
    var access:Access
    init(cameras: [CameraCaptureDevice], screens: [DesktopCaptureSource], windows: [DesktopCaptureSource], selected: VideoSource?, access: Access) {
        self.cameras = cameras
        self.screens = screens
        self.windows = windows
        self.selected = selected
        self.access = access
    }
    static func ==(lhs: DesktopCaptureListState, rhs: DesktopCaptureListState) -> Bool {
        let listEquals = lhs.cameras == rhs.cameras && lhs.screens == rhs.screens && lhs.windows == rhs.windows
        
        if !listEquals {
            return false
        }
        if let lhsSelected = lhs.selected, let rhsSelected = rhs.selected {
            if !lhsSelected.isEqual(rhsSelected) {
                return false
            }
        } else if (lhs.selected != nil) != (rhs.selected != nil) {
            return false
        }
        if lhs.access != rhs.access {
            return false
        }
        return true
    }
}

private func entries(_ state: DesktopCaptureListState, screens: DesktopCaptureSourceManager?, windows: DesktopCaptureSourceManager?, excludeWindowNumber: Int = 0, arguments: DesktopCaptureListArguments) -> [InputDataEntry] {
        
    var entries:[InputDataEntry] = []
    
    struct DesktopTuple : Equatable {
        let source: DesktopCaptureSource
        let selected: Bool
        let isAvailable: Bool
    }
    struct CameraTuple : Equatable {
        let source: CameraCaptureDevice
        let selected: Bool
        let isAvailable: Bool
    }
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("\(sectionId)"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GeneralRowItem(initialSize, height: 15, stableId: stableId, backgroundColor: .clear)
    }))
    sectionId += 1
    
    
    for source in state.cameras {
        let id: String = source.uniqueKey()
        let selected = state.selected != nil ? source.isEqual(state.selected!) : false
        let tuple = CameraTuple(source: source, selected: selected, isAvailable: state.access.camera)
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier(id), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
            return DesktopCameraCapturerRowItem(initialSize, stableId: stableId, device: tuple.source, isAvailable: tuple.isAvailable, isSelected: tuple.selected, select: arguments.selectCamera)
        }))
        index += 1
    }
    
    for source in state.screens {
        let id: String = source.uniqueKey()
        let selected = state.selected != nil ? source.isEqual(state.selected!) : false
        let tuple = DesktopTuple(source: source, selected: selected, isAvailable: state.access.sharing)
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier(id), equatable: InputDataEquatable(tuple), comparable: nil, item: { [weak screens] initialSize, stableId in
            return DesktopCapturePreviewItem(initialSize, stableId: stableId, source: tuple.source, isAvailable: tuple.isAvailable, isSelected: tuple.selected, manager: screens, select: arguments.selectDesktop)
        }))
        index += 1
    }
    
    for source in state.windows {
        let id: String = source.uniqueKey()
        let selected = state.selected != nil ? source.isEqual(state.selected!) : false
        let tuple = DesktopTuple(source: source, selected: selected, isAvailable: state.access.sharing)
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier(id), equatable: InputDataEquatable(tuple), comparable: nil, item: { [weak windows] initialSize, stableId in
            return DesktopCapturePreviewItem(initialSize, stableId: stableId, source: tuple.source, isAvailable: tuple.isAvailable, isSelected: tuple.selected, manager: windows, select: arguments.selectDesktop)
        }))
        index += 1
    }

    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("\(sectionId)"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GeneralRowItem(initialSize, height: 15, stableId: stableId, backgroundColor: .clear)
    }))
    sectionId += 1
    
    return entries
}

final class DesktopCapturerListController: GenericViewController<HorizontalTableView> {
    
    private let windows = DesktopCaptureSourceManager(_w: ())
    private let screens = DesktopCaptureSourceManager(_s: ())

    private var updateDisposable: Disposable?
    private let disposable: MetaDisposable = MetaDisposable()
    private let devicesDisposable = MetaDisposable()
    var updateDesktopSelected:((DesktopCapturerObjectWrapper, DesktopCaptureSourceManager)->Void)? = nil
    var updateCameraSelected:((DesktopCapturerObjectWrapper)->Void)? = nil

    private let devices: DevicesContext
    init(size: NSSize, devices: DevicesContext) {
        self.devices = devices
        super.init(frame: .init(origin: .zero, size: size))
        self.bar = .init(height: 0)
    }
    
    var excludeWindowNumber: Int = 0
    
    private var getCurrentlySelected: (()->VideoSource?)? = nil
    var selected: VideoSource? {
        return self.getCurrentlySelected?()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let actionsDisposable = DisposableSet()

        var hasCameraAccess = false
        var requestCamera = false
        if #available(OSX 10.14, *) {
            let camera = AVCaptureDevice.authorizationStatus(for: .video)
            switch camera {
            case .authorized:
                hasCameraAccess = true
            case .notDetermined:
                requestCamera = true
            default:
                break
            }
        } else {
            hasCameraAccess = true
        }

        let initialState = DesktopCaptureListState(cameras: [], screens: screens.list(), windows: windows.list(), selected: nil, access: .init(sharing: requestScreenCaptureAccess(), camera: hasCameraAccess))



        let statePromise = ValuePromise(initialState, ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((DesktopCaptureListState) -> DesktopCaptureListState) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }
        getCurrentlySelected = {
            stateValue.with { $0.selected }
        }
        
        self.onDeinit = {
            updateState { current in
                var current = current
                current.cameras = []
                current.screens = []
                current.selected = nil
                current.windows = []
                return current
            }
            actionsDisposable.dispose()
        }

        if requestCamera {
            actionsDisposable.add(requestCameraPermission().start(next: { access in
                updateState { state in
                    var state = state
                    state.access = DesktopCaptureListState.Access(sharing: state.access.sharing, camera: access)
                    return state
                }
            }))
        }
        
        let windows = self.windows
        let screens = self.screens
        
        let checkSelected = {
            updateState { current in
                var current = current
                if let selected = current.selected {
                    let windowsContains = current.windows.contains(where: {
                        $0.isEqual(selected)
                    })
                    let screensContains = current.screens.contains(where: {
                        $0.isEqual(selected)
                    })
                    let camerasContains = current.cameras.contains(where: {
                        $0.isEqual(selected)
                    })
                    if !windowsContains && !screensContains && !camerasContains {
                        current.selected = nil
                    }
                }
                if current.selected == nil {
                    current.selected = current.cameras.first ?? current.screens.first ?? current.windows.first
                }
                return current
            }
        }
        
        let updateSignal = Signal<NoValue, NoError> { [weak windows, weak screens] subscriber in
            
            updateState { current in
                var current = current
                current.screens = screens?.list() ?? []
                current.windows = windows?.list() ?? []
                return current
            }
            checkSelected()
            subscriber.putCompletion()
            
            return EmptyDisposable
        }
        
        let updateSelected: Signal<VideoSource?, NoError> = statePromise.get() |> map { $0.selected } |> distinctUntilChanged(isEqual:  { lhs, rhs in
            if let lhs = lhs, let rhs = rhs {
                return lhs.isEqual(rhs)
            } else if (lhs != nil) != (rhs != nil) {
                return false
            }
            return true
        })
        
        actionsDisposable.add(updateSelected.start(next: { [weak self, weak screens] selected in
            if let selected = selected as? DesktopCaptureSource, let screens = screens {
                self?.updateDesktopSelected?(DesktopCapturerObjectWrapper(source: selected, isAvailableToStream: stateValue.with { $0.access.sharing }), screens)
            } else if let selected = selected as? CameraCaptureDevice {
                self?.updateCameraSelected?(DesktopCapturerObjectWrapper(source: selected, isAvailableToStream: stateValue.with { $0.access.camera }))
            }
        }))
        
        devicesDisposable.set((devices.signal |> deliverOnMainQueue).start(next: { devices in
            updateState { current in
                var current = current
                current.cameras = devices.camera.filter { !$0.isSuspended && $0.isConnected }.map { CameraCaptureDevice($0) }
                return current
            }
            checkSelected()
        }))
        
        

        
        self.updateDisposable = ((updateSignal |> then(.complete() |> suspendAwareDelay(2, queue: .mainQueue()))) |> restart).start()
        
        let arguments = DesktopCaptureListArguments(selectDesktop: { source, manager in
            updateState { current in
                var current = current
                current.selected = source
                return current
            }
        }, selectCamera: { source in
            updateState { current in
                var current = current
                current.selected = source
                return current
            }
        })
        
        let excludeWindowNumber = self.excludeWindowNumber

        
        let signal = statePromise.get() |> map { [weak windows, weak screens] state in
            return InputDataSignalValue(entries: entries(state, screens: screens, windows: windows, excludeWindowNumber: excludeWindowNumber, arguments: arguments))
        }
        
        let previous: Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])
        
        let initialSize = self.atomicSize
        
        let transaction: Signal<TableUpdateTransition, NoError> = combineLatest(signal, appearanceSignal) |> mapToQueue { state, appearance in
            
            let entries = state.entries.map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
            return prepareInputDataTransition(left: previous.swap(entries), right: entries, animated: state.animated, searchState: nil, initialSize: initialSize.with { $0 }, arguments: InputDataArguments(select: {_, _ in }, dataUpdated: {}), onMainQueue: false)
        } |> deliverOnMainQueue
        
        genericView.needUpdateVisibleAfterScroll = true
        
        genericView.getBackgroundColor = {
            .clear
        }
        
        disposable.set(transaction.start(next: { [weak self] transaction in
            self?.genericView.merge(with: transaction)
            self?.readyOnce()
            checkSelected()
        }))

    }
    
    override func initializer() -> HorizontalTableView {
        return HorizontalTableView(frame: bounds, isFlipped: true, bottomInset: 0, drawBorder: false)
    }
    
    deinit {
        disposable.dispose()
        updateDisposable?.dispose()
        devicesDisposable.dispose()
    }
    
}

