import Foundation
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox

final class ListMessageItem: ListViewItem {
    let account: Account
    let peerId: PeerId
    let controllerInteraction: ChatControllerInteraction
    let message: Message
    
    let selectable: Bool = true
    
    public init(account: Account, peerId: PeerId, controllerInteraction: ChatControllerInteraction, message: Message) {
        self.account = account
        self.peerId = peerId
        self.controllerInteraction = controllerInteraction
        self.message = message
    }
    
    public func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> Void) -> Void) {
        var viewClassName: AnyClass = ListMessageFileItemNode.self
        
        for media in message.media {
            if let _ = media as? TelegramMediaWebpage {
                viewClassName = ListMessageSnippetItemNode.self
                break
            }
        }
        
        let configure = { () -> Void in
            let node = (viewClassName as! ListMessageNode.Type).init()
            node.controllerInteraction = self.controllerInteraction
            node.setupItem(self)
            
            let nodeLayout = node.asyncLayout()
            let (top, bottom) = (false, false) //self.mergedWithItems(top: previousItem, bottom: nextItem)
            let (layout, apply) = nodeLayout(self, width, top, bottom)
            
            node.updateSelectionState(animated: false)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                apply(.None)
            })
        }
        if Thread.isMainThread {
            async {
                configure()
            }
        } else {
            configure()
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? ListMessageFileItemNode {
            Queue.mainQueue().async {
                node.setupItem(self)
                
                node.updateSelectionState(animated: false)
                
                let nodeLayout = node.asyncLayout()
                
                async {
                    let (top, bottom) = (false, false) //self.mergedWithItems(top: previousItem, bottom: nextItem)
                    
                    let (layout, apply) = nodeLayout(self, width, top, bottom)
                    Queue.mainQueue().async {
                        completion(layout, {
                            apply(animation)
                        })
                    }
                }
            }
        }
    }
    
    func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        
        listView.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ListMessageFileItemNode {
                if let messageId = itemNode.item?.message.id, messageId == self.message.id {
                    itemNode.activateMedia()
                }
            }
        }
    }
    
    public var description: String {
        return "(ListMessageItem id: \(self.message.id), text: \"\(self.message.text)\")"
    }
}