import Foundation
import UIKit
import TelegramCore
import SwiftSignalKit
import MtProtoKitDynamic
import Display

import LegacyComponents

var legacyComponentsApplication: UIApplication!
private var legacyComponentsAccount: Account?

private var legacyLocalization = TGLocalization(version: 0, code: "en", dict: [:], isActive: true)

func updateLegacyLocalization(strings: PresentationStrings) {
    legacyLocalization = TGLocalization(version: 0, code: strings.languageCode, dict: strings.dict, isActive: true)
}

func updateLegacyTheme() {
    TGCheckButtonView.resetCache()
}

public func updateLegacyComponentsAccount(_ account: Account?) {
    legacyComponentsAccount = account
}

private var legacyDocumentsStorePath: String?
private var legacyCanOpenUrl: (URL) -> Bool = { _ in return false }
private var legacyOpenUrl: (URL) -> Void = { _ in }
private weak var legacyAccount: Account?

func legacyAccountGet() -> Account? {
    return legacyAccount
}

private final class LegacyComponentsAccessCheckerImpl: NSObject, LegacyComponentsAccessChecker {
    public func checkAddressBookAuthorizationStatus(alertDismissComlpetion alertDismissCompletion: (() -> Void)!) -> Bool {
        return true
    }
    
    public func checkPhotoAuthorizationStatus(for intent: TGPhotoAccessIntent, alertDismissCompletion: (() -> Void)!) -> Bool {
        return true
    }
    
    public func checkMicrophoneAuthorizationStatus(for intent: TGMicrophoneAccessIntent, alertDismissCompletion: (() -> Void)!) -> Bool {
        return true
    }
    
    public func checkCameraAuthorizationStatus(for intent: TGCameraAccessIntent, alertDismissCompletion: (() -> Void)!) -> Bool {
        return true
    }
    
    public func checkLocationAuthorizationStatus(for intent: TGLocationAccessIntent, alertDismissComlpetion alertDismissCompletion: (() -> Void)!) -> Bool {
        return true
    }
}

private func encodeText(_ string: String, _ key: Int) -> String {
    var result = ""
    for c in string.unicodeScalars {
        result.append(Character(UnicodeScalar(UInt32(Int(c.value) + key))!))
    }
    return result
}

private let keyboardWindowClass: AnyClass? = {
    if #available(iOS 9.0, *) {
        return NSClassFromString(encodeText("VJSfnpufLfzcpbseXjoepx", -1))
    } else {
        return NSClassFromString(encodeText("VJUfyuFggfdutXjoepx", -1))
    }
}()

private final class LegacyComponentsGlobalsProviderImpl: NSObject, LegacyComponentsGlobalsProvider {
    func log(_ string: String!) {
        print(string)
    }

    public func effectiveLocalization() -> TGLocalization! {
        return legacyLocalization
    }
    
    public func applicationWindows() -> [UIWindow]! {
        return legacyComponentsApplication.windows
    }
    
    public func applicationStatusBarWindow() -> UIWindow! {
        return nil
    }
    
    public func applicationKeyboardWindow() -> UIWindow! {
        guard let keyboardWindowClass = keyboardWindowClass else {
            return nil
        }
        
        for window in legacyComponentsApplication.windows {
            if window.isKind(of: keyboardWindowClass) {
                return window
            }
        }
        return nil
    }
    
    public func applicationInstance() -> UIApplication! {
        return legacyComponentsApplication
    }
    
    public func applicationStatusBarOrientation() -> UIInterfaceOrientation {
        return legacyComponentsApplication.statusBarOrientation
    }
    
    public func statusBarFrame() -> CGRect {
        return legacyComponentsApplication.statusBarFrame
    }
    
    public func isStatusBarHidden() -> Bool {
        return false
    }
    
    public func setStatusBarHidden(_ hidden: Bool, with animation: UIStatusBarAnimation) {
    }
    
    public func statusBarStyle() -> UIStatusBarStyle {
        return .default
    }
    
    public func setStatusBarStyle(_ statusBarStyle: UIStatusBarStyle, animated: Bool) {
        
    }
    
    public func forceStatusBarAppearanceUpdate() {
        
    }
    
    public func canOpen(_ url: URL!) -> Bool {
        return legacyCanOpenUrl(url)
    }
    
    public func open(_ url: URL!) {
        legacyOpenUrl(url)
    }
    
    public func openURLNative(_ url: URL!) {
        legacyOpenUrl(url)
    }
    
    public func disableUserInteraction(for timeInterval: TimeInterval) {
    }
    
    public func setIdleTimerDisabled(_ value: Bool) {
        legacyComponentsApplication.isIdleTimerDisabled = value
    }
    
    public func pauseMusicPlayback() {
    }
    
    public func dataStoragePath() -> String! {
        return legacyDocumentsStorePath!
    }
    
    public func dataCachePath() -> String! {
        return legacyDocumentsStorePath! + "/Cache"
    }
    
    public func accessChecker() -> LegacyComponentsAccessChecker! {
        return LegacyComponentsAccessCheckerImpl()
    }
    
    public func stickerPacksSignal() -> SSignal! {
        if let legacyAccount = legacyAccount {
            return legacyComponentsStickers(postbox: legacyAccount.postbox, namespace: Namespaces.ItemCollection.CloudStickerPacks)
        } else {
            var dict: [AnyHashable: Any] = [:]
            dict["packs"] = NSArray()
            return SSignal.single(dict)
        }
    }
    
    public func maskStickerPacksSignal() -> SSignal! {
        if let legacyAccount = legacyAccount {
            return legacyComponentsStickers(postbox: legacyAccount.postbox, namespace: Namespaces.ItemCollection.CloudMaskPacks)
        } else {
            var dict: [AnyHashable: Any] = [:]
            dict["packs"] = NSArray()
            return SSignal.single(dict)
        }
    }
    
    public func recentStickerMasksSignal() -> SSignal! {
        return SSignal.single(NSArray())
    }
    
    public func request(_ type: TGAudioSessionType, interrupted: (() -> Void)!) -> SDisposable! {
        if let legacyAccount = legacyAccount {
            let convertedType: ManagedAudioSessionType
            switch type {
                case TGAudioSessionTypePlayAndRecord, TGAudioSessionTypePlayAndRecordHeadphones:
                    convertedType = .playAndRecord
                default:
                    convertedType = .play
            }
            let disposable = legacyAccount.telegramApplicationContext.mediaManager.audioSession.push(audioSessionType: convertedType, once: true, activate: { _ in
            }, deactivate: {
                interrupted?()
                return .complete()
            })
            
            return SBlockDisposable(block: {
                disposable.dispose()
            })
        }
        return nil
    }
    
    public func currentWallpaperInfo() -> TGWallpaperInfo! {
        if let account = legacyComponentsAccount {
            let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
            switch presentationData.chatWallpaper {
                case .builtin:
                    return TGBuiltinWallpaperInfo()
                case let .color(color):
                    return TGColorWallpaperInfo(color: UInt32(bitPattern: color))
                case let .image(representations):
                    if let resource = largestImageRepresentation(representations)?.resource, let path = account.postbox.mediaBox.completedResourcePath(resource), let image = UIImage(contentsOfFile: path) {
                        return TGCustomImageWallpaperInfo(image: image)
                    } else {
                        return TGBuiltinWallpaperInfo()
                    }
            }
        } else {
            return TGBuiltinWallpaperInfo()
        }
    }
    
    public func currentWallpaperImage() -> UIImage! {
        if let account = legacyComponentsAccount {
            let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
            switch presentationData.chatWallpaper {
                case .builtin:
                    return nil
                case let .color(color):
                    return generateImage(CGSize(width: 1.0, height: 1.0), rotatedContext: { size, context in
                        if color == 0 {
                            context.setFillColor(UIColor(rgb: 0x222222).cgColor)
                        } else {
                            context.setFillColor(UIColor(rgb: UInt32(bitPattern: color)).cgColor)
                        }
                        context.fill(CGRect(origin: CGPoint(), size: size))
                    })
                case let .image(representations):
                    if let resource = largestImageRepresentation(representations)?.resource, let path = account.postbox.mediaBox.completedResourcePath(resource), let image = UIImage(contentsOfFile: path) {
                        return image
                    } else {
                        return nil
                    }
            }
        } else {
            return nil
        }
    }
    
    public func sharedMediaImageProcessingThreadPool() -> SThreadPool! {
        return nil
    }
    
    public func sharedMediaMemoryImageCache() -> TGMemoryImageCache! {
        return nil
    }
    
    public func squarePhotoThumbnail(_ imageAttachment: TGImageMediaAttachment!, of size: CGSize, threadPool: SThreadPool!, memoryCache: TGMemoryImageCache!, pixelProcessingBlock: ((UnsafeMutableRawPointer?, Int32, Int32, Int32) -> Void)!, downloadLargeImage: Bool, placeholder: SSignal!) -> SSignal! {
        return SSignal.never()
    }
    
    public func localDocumentDirectory(forLocalDocumentId localDocumentId: Int64, version: Int32) -> String! {
        return ""
    }
    
    public func localDocumentDirectory(forDocumentId documentId: Int64, version: Int32) -> String! {
        return ""
    }
    
    public func json(forHttpLocation httpLocation: String!) -> SSignal! {
        return self.data(forHttpLocation: httpLocation).map(toSignal: { next in
            if let next = next as? Data {
                if let object = try? JSONSerialization.jsonObject(with: next, options: []) {
                    return SSignal.single(object)
                }
            }
            return SSignal.fail(nil)
        })
    }
    
    public func data(forHttpLocation httpLocation: String!) -> SSignal! {
        return SSignal { subscriber in
            if let httpLocation = httpLocation, let url = URL(string: httpLocation) {
                let disposable = MTHttpRequestOperation.data(forHttpUrl: url).start(next: { next in
                    subscriber?.putNext(next)
                }, error: { error in
                    subscriber?.putError(error)
                }, completed: {
                    subscriber?.putCompletion()
                })
                return SBlockDisposable(block: {
                    disposable?.dispose()
                })
            } else {
                return nil
            }
        }
    }
    
    public func makeHTTPRequestOperation(with request: URLRequest!) -> (Operation & LegacyHTTPRequestOperation)! {
        return LegacyHTTPOperationImpl(request: request)
    }
    
    public func pausePictureInPicturePlayback() {
        
    }
    
    public func resumePictureInPicturePlayback() {
        
    }
    
    public func maybeReleaseVolumeOverlay() {
        
    }
    
    func navigationBarPallete() -> TGNavigationBarPallete! {
        if let account = legacyComponentsAccount {
            let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
            let theme = presentationData.theme.rootController.navigationBar
            return TGNavigationBarPallete(backgroundColor: theme.backgroundColor, separatorColor: theme.separatorColor, titleColor: theme.primaryTextColor, tintColor: theme.accentTextColor)
        } else {
            return nil
        }
    }
    
    func menuSheetPallete() -> TGMenuSheetPallete! {
        if let account = legacyComponentsAccount {
            let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
            let theme = presentationData.theme.actionSheet
            return TGMenuSheetPallete(dark: presentationData.theme.overallDarkAppearance, backgroundColor: theme.opaqueItemBackgroundColor, selectionColor: theme.opaqueItemHighlightedBackgroundColor, separatorColor: theme.opaqueItemSeparatorColor, accentColor: theme.controlAccentColor, destructiveColor: theme.destructiveActionTextColor, textColor: theme.primaryTextColor, secondaryTextColor: theme.secondaryTextColor, spinnerColor: theme.secondaryTextColor, badgeTextColor: theme.controlAccentColor, badgeImage: nil, cornersImage: generateStretchableFilledCircleImage(diameter: 11.0, color: nil, strokeColor: nil, strokeWidth: nil, backgroundColor: theme.opaqueItemBackgroundColor))
        } else {
            return nil
        }
    }
    
    func mediaAssetsPallete() -> TGMediaAssetsPallete! {
        if let account = legacyComponentsAccount {
            let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
            let theme = presentationData.theme.list
            let navigationBar = presentationData.theme.rootController.navigationBar
            return TGMediaAssetsPallete(dark: presentationData.theme.overallDarkAppearance, backgroundColor: theme.plainBackgroundColor, selectionColor: theme.itemHighlightedBackgroundColor, separatorColor: theme.itemPlainSeparatorColor, textColor: theme.itemPrimaryTextColor, secondaryTextColor: theme.controlSecondaryColor, accentColor: theme.itemAccentColor, barBackgroundColor: navigationBar.backgroundColor, barSeparatorColor: navigationBar.separatorColor, navigationTitleColor: navigationBar.primaryTextColor, badge: generateStretchableFilledCircleImage(diameter: 22.0, color: navigationBar.accentTextColor), badgeTextColor: navigationBar.backgroundColor, sendIconImage: PresentationResourcesChat.chatInputPanelSendButtonImage(presentationData.theme), maybeAccentColor: navigationBar.accentTextColor)
        } else {
            return nil
        }
    }
    
    func checkButtonPallete() -> TGCheckButtonPallete! {
        if let account = legacyComponentsAccount {
            let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
            let theme = presentationData.theme
            return TGCheckButtonPallete(defaultBackgroundColor: theme.chat.bubble.selectionControlFillColor, accentBackgroundColor: theme.chat.bubble.selectionControlFillColor, defaultBorderColor: theme.chat.bubble.selectionControlBorderColor, mediaBorderColor: theme.chat.bubble.selectionControlBorderColor, chatBorderColor: theme.chat.bubble.selectionControlBorderColor, check: theme.chat.bubble.selectionControlForegroundColor, blueColor: theme.chat.bubble.selectionControlFillColor, barBackgroundColor: theme.chat.bubble.selectionControlFillColor)
        } else {
            return nil
        }
    }
}

public func setupLegacyComponents(account: Account) {
    legacyAccount = account
}

public func initializeLegacyComponents(application: UIApplication, currentSizeClassGetter: @escaping () -> UIUserInterfaceSizeClass, currentHorizontalClassGetter: @escaping () -> UIUserInterfaceSizeClass, documentsPath: String, currentApplicationBounds: @escaping () -> CGRect, canOpenUrl: @escaping (URL) -> Bool, openUrl: @escaping (URL) -> Void) {
    legacyComponentsApplication = application
    legacyCanOpenUrl = canOpenUrl
    legacyOpenUrl = openUrl
    legacyDocumentsStorePath = documentsPath
    
    freedomInit()
    
    TGRemoteImageView.setSharedCache(TGCache())
    
    TGImageDataSource.register(LegacyStickerImageDataSource(account: {
        return legacyAccount
    }))
    TGImageDataSource.register(LegacyPeerAvatarPlaceholderDataSource(account: {
        return legacyAccount
    }))
    TGImageDataSource.register(LegacyLocationVenueIconDataSource(account: {
        return legacyAccount
    }))
    ASActor.registerClass(LegacyImageDownloadActor.self)
    
    LegacyComponentsGlobals.setProvider(LegacyComponentsGlobalsProviderImpl())
    //freedomUIKitInit();
    
    /*TGHacks.setApplication(application)
    TGLegacyComponentsSetAccessChecker(AccessCheckerImpl())
    TGHacks.setPauseMusicPlayer {
        
    }
    TGViewController.setSizeClassSignal {
        return SSignal.single(UIUserInterfaceSizeClass.compact.rawValue as NSNumber)
    }
    TGLegacyComponentsSetDocumentsPath(documentsPath)
    
    TGLegacyComponentsSetCanOpenURL({ url in
        if let url = url {
            return canOpenUrl(url)
        }
        return false
    })
    TGLegacyComponentsSetOpenURL({ url in
        if let url = url {
            return openUrl(url)
        }
    })*/
}