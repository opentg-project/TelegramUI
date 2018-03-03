import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore

private enum ChatInfoTitleButton {
    case search
    case info
    case mute
    case unmute
    case call
    case report
    case grouping
    case channels
    
    func title(_ strings: PresentationStrings) -> String {
        switch self {
            case .search:
                return strings.Common_Search
            case .info:
                return strings.Conversation_Info
            case .mute:
                return strings.Conversation_Mute
            case .unmute:
                return strings.Conversation_Unmute
            case .call:
                return strings.Conversation_Call
            case .report:
                return strings.ReportPeer_Report
            case .grouping:
                return "Grouping"
            case .channels:
                return "Channels"
        }
    }
    
    func icon(_ theme: PresentationTheme) -> UIImage? {
        switch self {
            case .search:
                return PresentationResourcesChat.chatTitlePanelSearchImage(theme)
            case .info, .channels:
                return PresentationResourcesChat.chatTitlePanelInfoImage(theme)
            case .mute:
                return PresentationResourcesChat.chatTitlePanelMuteImage(theme)
            case .unmute:
                return PresentationResourcesChat.chatTitlePanelUnmuteImage(theme)
            case .call:
                return PresentationResourcesChat.chatTitlePanelCallImage(theme)
            case .report:
                return PresentationResourcesChat.chatTitlePanelReportImage(theme)
            case .grouping:
                return PresentationResourcesChat.chatTitlePanelGroupingImage(theme)
        }
    }
}

private func peerButtons(_ peer: Peer, isMuted: Bool) -> [ChatInfoTitleButton] {
    let muteAction: ChatInfoTitleButton
    if isMuted {
        muteAction = .unmute
    } else {
        muteAction = .mute
    }
    
    if let peer = peer as? TelegramUser {
        var buttons: [ChatInfoTitleButton] = [.search, muteAction]
        if peer.botInfo == nil {
            buttons.append(.call)
        }
        buttons.append(.info)
        return buttons
    } else if let channel = peer as? TelegramChannel {
        if channel.flags.contains(.isCreator) {
            return [.search, muteAction, .info]
        } else {
            return [.search, .report, muteAction, .info]
        }
    } else if let group = peer as? TelegramGroup {
        if case .creator = group.role {
            return [.search, muteAction, .info]
        } else {
            return [.search, .report, muteAction, .info]
        }
    } else {
        return [.search, muteAction, .info]
    }
}

private func groupButtons() -> [ChatInfoTitleButton] {
    return [.search, .grouping, .channels]
}

private let buttonFont = Font.regular(10.0)

private final class ChatInfoTitlePanelButtonNode: HighlightableButtonNode {
    override init() {
        super.init()
        
        self.displaysAsynchronously = false
        self.imageNode.displayWithoutProcessing = true
        self.imageNode.displaysAsynchronously = false
        
        self.titleNode.displaysAsynchronously = false
        
        self.laysOutHorizontally = false
    }
    
    func setup(text: String, color: UIColor, icon: UIImage?) {
        self.setTitle(text, with: buttonFont, with: color, for: [])
        self.setImage(icon, for: [])
        if let icon = icon {
            self.contentSpacing = max(0.0, 32.0 - icon.size.height)
        }
    }
}

final class ChatInfoTitlePanelNode: ChatTitleAccessoryPanelNode {
    private var theme: PresentationTheme?
    
    private let separatorNode: ASDisplayNode
    private var buttons: [(ChatInfoTitleButton, ChatInfoTitlePanelButtonNode)] = []
    
    override init() {
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.separatorNode)
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        let themeUpdated = self.theme !== interfaceState.theme
        self.theme = interfaceState.theme
        
        let panelHeight: CGFloat = 55.0
        
        if themeUpdated {
            self.separatorNode.backgroundColor = interfaceState.theme.rootController.navigationBar.separatorColor
            self.backgroundColor = interfaceState.theme.rootController.navigationBar.backgroundColor
        }
        
        let updatedButtons: [ChatInfoTitleButton]
        switch interfaceState.chatLocation {
            case .peer:
                if let peer = interfaceState.peer?.peer {
                    updatedButtons = peerButtons(peer, isMuted: interfaceState.peerIsMuted)
                } else {
                    updatedButtons = []
                }
            case .group:
                updatedButtons = groupButtons()
        }
        
        var buttonsUpdated = false
        if self.buttons.count != updatedButtons.count {
            buttonsUpdated = true
        } else {
            for i in 0 ..< updatedButtons.count {
                if self.buttons[i].0 != updatedButtons[i] {
                    buttonsUpdated = true
                    break
                }
            }
        }
        
        if buttonsUpdated || themeUpdated {
            for (_, buttonNode) in self.buttons {
                buttonNode.removeFromSupernode()
            }
            self.buttons.removeAll()
            for button in updatedButtons {
                let buttonNode = ChatInfoTitlePanelButtonNode()
                buttonNode.laysOutHorizontally = false
                
                buttonNode.setup(text: button.title(interfaceState.strings), color: interfaceState.theme.rootController.navigationBar.accentTextColor, icon: button.icon(interfaceState.theme))
                
                buttonNode.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: [.touchUpInside])
                self.addSubnode(buttonNode)
                self.buttons.append((button, buttonNode))
            }
        }
        
        if !self.buttons.isEmpty {
            let buttonWidth = floor((width - leftInset - rightInset) / CGFloat(self.buttons.count))
            var nextButtonOrigin: CGFloat = leftInset
            for (_, buttonNode) in self.buttons {
                buttonNode.frame = CGRect(origin: CGPoint(x: nextButtonOrigin, y: 0.0), size: CGSize(width: buttonWidth, height: panelHeight))
                nextButtonOrigin += buttonWidth
            }
        }
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelHeight - UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel)))
        
        return panelHeight
    }
    
    @objc func buttonPressed(_ node: HighlightableButtonNode) {
        for (button, buttonNode) in self.buttons {
            if buttonNode === node {
                switch button {
                    case .info, .channels:
                        self.interfaceInteraction?.openPeerInfo()
                    case .mute:
                        self.interfaceInteraction?.togglePeerNotifications()
                    case .unmute:
                        self.interfaceInteraction?.togglePeerNotifications()
                    case .search:
                        self.interfaceInteraction?.beginMessageSearch(.everything)
                    case .call:
                        self.interfaceInteraction?.beginCall()
                    case .report:
                        self.interfaceInteraction?.reportPeer()
                    case .grouping:
                        self.interfaceInteraction?.openGrouping()
                        break
                }
                break
            }
        }
    }
}