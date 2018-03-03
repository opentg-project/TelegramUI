import Foundation
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit

final class ChatFeedNavigationInputPanelNode: ChatInputPanelNode {
    private let button: HighlightableButtonNode
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    init(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        
        self.button = HighlightableButtonNode()
        
        super.init()
        
        self.addSubnode(self.button)
        
        self.button.setAttributedTitle(NSAttributedString(string: "Show Next", font: Font.regular(17.0), textColor: theme.chat.inputPanel.panelControlAccentColor), for: [])
        self.button.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: [.touchUpInside])
    }
    
    deinit {
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        if self.theme !== theme || self.strings !== strings {
            self.theme = theme
            self.strings = strings
            
            self.button.setAttributedTitle(NSAttributedString(string: strings.Conversation_Unblock, font: Font.regular(17.0), textColor: theme.chat.inputPanel.panelControlAccentColor), for: [])
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            return self.button.view
        } else {
            return nil
        }
    }
    
    @objc func buttonPressed() {
        self.interfaceInteraction?.navigateFeed()
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, maxHeight: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        if self.presentationInterfaceState != interfaceState {
            self.presentationInterfaceState = interfaceState
        }
        
        let buttonSize = self.button.measure(CGSize(width: width - leftInset - rightInset - 80.0, height: 100.0))
        
        let panelHeight: CGFloat = 47.0
        
        self.button.frame = CGRect(origin: CGPoint(x: leftInset + floor((width - leftInset - rightInset - buttonSize.width) / 2.0), y: floor((panelHeight - buttonSize.height) / 2.0)), size: buttonSize)
        
        return 47.0
    }
    
    override func minimalHeight(interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        return 47.0
    }
}
