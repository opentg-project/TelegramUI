import Foundation
import Display
import LegacyComponents

public enum LegacyControllerPresentation {
    case custom
    case modal(animateIn: Bool)
}

private func passControllerAppearanceAnimated(in: Bool, presentation: LegacyControllerPresentation) -> Bool {
    switch presentation {
        case let .modal(animateIn):
            if `in` {
                return animateIn
            } else {
                return true
            }
        default:
            return false
    }
}

private final class LegacyComponentsOverlayWindowManagerImpl: NSObject, LegacyComponentsOverlayWindowManager {
    private weak var contentController: UIViewController?
    private weak var parentController: ViewController?
    private var controller: LegacyController?
    private var boundController = false
    
    init(parentController: ViewController?, theme: PresentationTheme?) {
        self.parentController = parentController
        self.controller = LegacyController(presentation: .custom, theme: theme)
        
        super.init()
        
        if let parentController = parentController {
            if parentController.statusBar.statusBarStyle == .Hide {
                self.controller?.statusBar.statusBarStyle = parentController.statusBar.statusBarStyle
            }
            self.controller?.view.frame = parentController.view.bounds
        }
    }
    
    func managesWindow() -> Bool {
        return true
    }
    
    func bindController(_ controller: UIViewController!) {
        self.contentController = controller
        controller.state_setNeedsStatusBarAppearanceUpdate({ [weak self, weak controller] in
            if let parentController = self?.parentController, let controller = controller {
                if parentController.statusBar.statusBarStyle != .Hide {
                    self?.controller?.statusBar.statusBarStyle = StatusBarStyle(systemStyle: controller.preferredStatusBarStyle)
                }
            }
        })
        if let parentController = self.parentController {
            if parentController.statusBar.statusBarStyle != .Hide {
                self.controller?.statusBar.statusBarStyle = StatusBarStyle(systemStyle: controller.preferredStatusBarStyle)
            }
        }
    }
    
    func context() -> LegacyComponentsContext! {
        return self.controller?.context
    }
    
    func setHidden(_ hidden: Bool, window: UIWindow!) {
        if hidden {
            self.controller?.dismiss()
            self.controller = nil
        } else if let contentController = self.contentController, let parentController = self.parentController, let controller = self.controller {
            if !self.boundController {
                controller.bind(controller: contentController)
                self.boundController = true
            }
            parentController.present(controller, in: .window(.root))
        }
    }
}

final class LegacyControllerContext: NSObject, LegacyComponentsContext {
    private weak var controller: ViewController?
    private let theme: PresentationTheme?
    
    init(controller: ViewController?, theme: PresentationTheme?) {
        self.controller = controller
        self.theme = theme
        
        super.init()
    }
    
    public func fullscreenBounds() -> CGRect {
        if let controller = self.controller {
            return controller.view.bounds
        } else {
            return CGRect()
        }
    }
    
    public func keyCommandController() -> TGKeyCommandController! {
        return nil
    }
    
    public func rootCallStatusBarHidden() -> Bool {
        return true
    }
    
    public func statusBarFrame() -> CGRect {
        return legacyComponentsApplication!.statusBarFrame
    }
    
    public func isStatusBarHidden() -> Bool {
        if let controller = self.controller {
            return controller.statusBar.isHidden
        } else {
            return true
        }
    }
    
    public func setStatusBarHidden(_ hidden: Bool, with animation: UIStatusBarAnimation) {
        if let controller = self.controller {
            controller.statusBar.isHidden = hidden
            self.updateDeferScreenEdgeGestures()
        }
    }
    
    public func forceSetStatusBarHidden(_ hidden: Bool, with animation: UIStatusBarAnimation) {
        if let controller = self.controller {
            controller.statusBar.isHidden = hidden
        }
    }
    
    public func statusBarStyle() -> UIStatusBarStyle {
        if let controller = self.controller {
            switch controller.statusBar.statusBarStyle {
                case .Black:
                    return .default
                case .White:
                    return .lightContent
                default:
                    return .default
            }
        } else {
            return .default
        }
    }
    
    public func setStatusBarStyle(_ statusBarStyle: UIStatusBarStyle, animated: Bool) {
        if let controller = self.controller {
            switch statusBarStyle {
                case .default:
                    controller.statusBar.statusBarStyle = .Black
                case .lightContent:
                    controller.statusBar.statusBarStyle = .White
                default:
                    controller.statusBar.statusBarStyle = .Black
            }
        }
    }
    
    public func forceStatusBarAppearanceUpdate() {
    }
    
    public func currentlyInSplitView() -> Bool {
        return false
    }
    
    public func currentSizeClass() -> UIUserInterfaceSizeClass {
        return .compact
    }
    
    public func currentHorizontalSizeClass() -> UIUserInterfaceSizeClass {
        return .compact
    }
    
    public func currentVerticalSizeClass() -> UIUserInterfaceSizeClass {
        return .compact
    }
    
    public func sizeClassSignal() -> SSignal! {
        return SSignal.single(UIUserInterfaceSizeClass.compact.rawValue as NSNumber)
    }
    
    public func canOpen(_ url: URL!) -> Bool {
        return false
    }
    
    public func open(_ url: URL!) {
    }
    
    public func serverMediaData(forAssetUrl url: String!) -> [AnyHashable : Any]! {
        return nil
    }
    
    public func presentActionSheet(_ actions: [LegacyComponentsActionSheetAction]!, view: UIView!, completion: ((LegacyComponentsActionSheetAction?) -> Void)!) {
        
    }
    
    public func presentActionSheet(_ actions: [LegacyComponentsActionSheetAction]!, view: UIView!, sourceRect: (() -> CGRect)!, completion: ((LegacyComponentsActionSheetAction?) -> Void)!) {
        
    }
    
    func makeOverlayWindowManager() -> LegacyComponentsOverlayWindowManager! {
        return LegacyComponentsOverlayWindowManagerImpl(parentController: self.controller, theme: self.theme)
    }
    
    func applicationStatusBarAlpha() -> CGFloat {
        if let controller = self.controller {
            return controller.statusBar.alpha
        }
        return 0.0
    }
    
    func setApplicationStatusBarAlpha(_ alpha: CGFloat) {
        if let controller = self.controller {
            controller.statusBar.alpha = alpha
            self.updateDeferScreenEdgeGestures()
        }
    }
    
    private func updateDeferScreenEdgeGestures() {
        if let controller = self.controller {
            if controller.statusBar.isHidden || controller.statusBar.alpha.isZero {
                controller.deferScreenEdgeGestures = [.top]
            } else {
                controller.deferScreenEdgeGestures = []
            }
        }
    }

    func animateApplicationStatusBarAppearance(_ statusBarAnimation: Int32, delay: TimeInterval, duration: TimeInterval, completion: (() -> Void)!) {
        completion?()
    }
    
    func animateApplicationStatusBarAppearance(_ statusBarAnimation: Int32, duration: TimeInterval, completion: (() -> Void)!) {
        self.animateApplicationStatusBarAppearance(statusBarAnimation, delay: 0.0, duration: duration, completion: completion)
    }
    
    func animateApplicationStatusBarStyleTransition(withDuration duration: TimeInterval) {
    }
    
    func safeAreaInset() -> UIEdgeInsets {
        if let controller = self.controller as? LegacyController, let validLayout = controller.validLayout {
            var safeInsets = validLayout.safeInsets
            if safeInsets.top.isEqual(to: 44.0) {
                safeInsets.bottom = 34.0
            }
            return safeInsets
        }
        return UIEdgeInsets()
    }
    
    func prefersLightStatusBar() -> Bool {
        if let controller = self.controller {
            switch controller.statusBar.statusBarStyle {
                case .Black:
                    return false
                case .White:
                    return true
                default:
                    return false
            }
        } else {
            return false
        }
    }
}

public class LegacyController: ViewController {
    public private(set) var legacyController: UIViewController!
    private let presentation: LegacyControllerPresentation
    
    private var controllerNode: LegacyControllerNode {
        return self.displayNode as! LegacyControllerNode
    }
    
    private var contextImpl: LegacyControllerContext!
    public var context: LegacyComponentsContext {
        return self.contextImpl!
    }
    
    fileprivate var validLayout: ContainerViewLayout?
    
    var controllerLoaded: (() -> Void)?
    public var presentationCompleted: (() -> Void)?
    
    public init(presentation: LegacyControllerPresentation, theme: PresentationTheme?, initialLayout: ContainerViewLayout? = nil) {
        self.presentation = presentation
        self.validLayout = initialLayout
        
        super.init(navigationBarTheme: nil)
        
        if let theme = theme {
            self.statusBar.statusBarStyle = theme.rootController.statusBar.style.style
        }
        
        let contextImpl = LegacyControllerContext(controller: self, theme: theme)
        self.contextImpl = contextImpl
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func bind(controller: UIViewController) {
        self.legacyController = controller
        if let controller = controller as? TGViewController {
            controller.customRemoveFromParentViewController = { [weak self] in
                self?.dismiss()
            }
        }
    }
    
    override public func loadDisplayNode() {
        self.displayNode = LegacyControllerNode()
        self.displayNodeDidLoad()
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if self.ignoreAppearanceMethodInvocations() {
            return
        }
        
        if self.controllerNode.controllerView == nil {
            self.controllerNode.controllerView = self.legacyController.view
            if let legacyController = self.legacyController as? TGViewController {
                legacyController.ignoreAppearEvents = true
            }
            self.controllerNode.view.insertSubview(self.legacyController.view, at: 0)
            if let legacyController = self.legacyController as? TGViewController {
                legacyController.ignoreAppearEvents = false
            }
            
            if let controllerLoaded = self.controllerLoaded {
                controllerLoaded()
            }
        }
        
        self.legacyController.viewWillAppear(animated && passControllerAppearanceAnimated(in: true, presentation: self.presentation))
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if self.ignoreAppearanceMethodInvocations() {
            return
        }
        
        self.legacyController.viewWillDisappear(animated && passControllerAppearanceAnimated(in: false, presentation: self.presentation))
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if self.ignoreAppearanceMethodInvocations() {
            return
        }
        
        switch self.presentation {
            case let .modal(animateIn):
                if animateIn {
                    self.controllerNode.animateModalIn(completion: { [weak self] in
                        self?.presentationCompleted?()
                    })
                } else {
                    self.presentationCompleted?()
                }
                self.legacyController.viewDidAppear(animated && animateIn)
            case .custom:
                self.legacyController.viewDidAppear(animated)
                self.presentationCompleted?()
        }
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if self.ignoreAppearanceMethodInvocations() {
            return
        }
        
        self.legacyController.viewDidDisappear(animated && passControllerAppearanceAnimated(in: false, presentation: self.presentation))
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    override open func dismiss(completion: (() -> Void)? = nil) {
        self.view.endEditing(true)
        switch self.presentation {
            case .modal:
                self.controllerNode.animateModalOut { [weak self] in
                    if let controller = self?.legacyController as? TGViewController {
                        //controller.didDismiss()
                    } else if let controller = self?.legacyController as? TGNavigationController {
                        //controller.didDismiss()
                    }
                    self?.presentingViewController?.dismiss(animated: false, completion: completion)
                }
            case .custom:
                if let controller = self.legacyController as? TGViewController {
                    //controller.didDismiss()
                } else if let controller = self.legacyController as? TGNavigationController {
                    //controller.didDismiss()
                }
                self.presentingViewController?.dismiss(animated: false, completion: completion)
        }
    }
    
    func dismissWithAnimation() {
        self.controllerNode.animateModalOut { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
    }
}