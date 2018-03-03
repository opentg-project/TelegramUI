import Foundation
import SwiftSignalKit
import TelegramCore
import Postbox

enum ChatContextQueryUpdate {
    case remove
    case update(ChatPresentationInputQuery, Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError>)
}

func contextQueryResultStateForChatInterfacePresentationState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account, currentQueryStates: inout [ChatPresentationInputQueryKind: (ChatPresentationInputQuery, Disposable)]) -> [ChatPresentationInputQueryKind: ChatContextQueryUpdate] {
    guard let peer = chatPresentationInterfaceState.peer?.peer else {
        return [:]
    }
    let inputQueries = inputContextQueriesForChatPresentationIntefaceState(chatPresentationInterfaceState)
    
    var updates: [ChatPresentationInputQueryKind: ChatContextQueryUpdate] = [:]
    
    for query in inputQueries {
        let previousQuery = currentQueryStates[query.kind]?.0
        if previousQuery != query {
            let signal = updatedContextQueryResultStateForQuery(account: account, peer: peer, inputQuery: query, previousQuery: previousQuery)
            updates[query.kind] = .update(query, signal)
        }
    }
    
    for currentQueryKind in currentQueryStates.keys {
        var found = false
        inner: for query in inputQueries {
            if query.kind == currentQueryKind {
                found = true
                break inner
            }
        }
        if !found {
            updates[currentQueryKind] = .remove
        }
    }
    
    return updates
}

private func updatedContextQueryResultStateForQuery(account: Account, peer: Peer, inputQuery: ChatPresentationInputQuery, previousQuery: ChatPresentationInputQuery?) -> Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> {
    switch inputQuery {
        case let .emoji(query):
            var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .complete()
            if let previousQuery = previousQuery {
                switch previousQuery {
                    case .emoji:
                        break
                    default:
                        signal = .single({ _ in return .stickers([]) })
                }
            } else {
                signal = .single({ _ in return .stickers([]) })
            }
            let stickers: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = searchStickers(postbox: account.postbox, query: query.firstEmoji)
                |> map { stickers -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                    return { _ in
                        return .stickers(stickers)
                    }
                }
            return signal |> then(stickers)
        case let .hashtag(query):
            var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .complete()
            if let previousQuery = previousQuery {
                switch previousQuery {
                    case .hashtag:
                        break
                    default:
                        signal = .single({ _ in return .hashtags([]) })
                }
            } else {
                signal = .single({ _ in return .hashtags([]) })
            }
            
            let hashtags: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = recentlyUsedHashtags(postbox: account.postbox) |> map { hashtags -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                let normalizedQuery = query.lowercased()
                var result: [String] = []
                for hashtag in hashtags {
                    if hashtag.lowercased().hasPrefix(normalizedQuery) {
                        result.append(hashtag)
                    }
                }
                return { _ in return .hashtags(result) }
            }
            
            return signal |> then(hashtags)
        case let .mention(query, types):
            let normalizedQuery = query.lowercased()
            
            var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .complete()
            if let previousQuery = previousQuery {
                switch previousQuery {
                    case .mention:
                        break
                    default:
                        signal = .single({ _ in return .mentions([]) })
                }
            } else {
                signal = .single({ _ in return .mentions([]) })
            }
            
            let inlineBots: Signal<[(Peer, Double)], NoError> = types.contains(.contextBots) ? recentlyUsedInlineBots(postbox: account.postbox) : .single([])
            let participants = combineLatest(inlineBots, searchGroupMembers(postbox: account.postbox, network: account.network, peerId: peer.id, query: query))
                |> map { inlineBots, peers -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                    let filteredInlineBots = inlineBots.sorted(by: { $0.1 > $1.1 }).filter { peer, rating in
                        if rating < 0.14 {
                            return false
                        }
                        if peer.indexName.matchesByTokens(normalizedQuery) {
                            return true
                        }
                        if let addressName = peer.addressName, addressName.lowercased().hasPrefix(normalizedQuery) {
                            return true
                        }
                        return false
                    }.map { $0.0 }
                    
                    let inlineBotPeerIds = Set(filteredInlineBots.map { $0.id })
                    
                    let filteredPeers = peers.filter { peer in
                        if inlineBotPeerIds.contains(peer.id) {
                            return false
                        }
                        if !types.contains(.accountPeer) && peer.id == account.peerId {
                            return false
                        }
                        return true
                    }
                    var sortedPeers = filteredInlineBots
                    sortedPeers.append(contentsOf: filteredPeers.sorted(by: { lhs, rhs in
                        let result = lhs.indexName.indexName(.lastNameFirst).compare(rhs.indexName.indexName(.lastNameFirst))
                        return result == .orderedAscending
                    }))
                    return { _ in return .mentions(sortedPeers) }
                }
            
            return signal |> then(participants)
        case let .command(query):
            let normalizedQuery = query.lowercased()
            
            var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .complete()
            if let previousQuery = previousQuery {
                switch previousQuery {
                    case .command:
                        break
                    default:
                        signal = .single({ _ in return .commands([]) })
                }
            } else {
                signal = .single({ _ in return .commands([]) })
            }
            
            let participants = peerCommands(account: account, id: peer.id)
                |> map { commands -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                    let filteredCommands = commands.commands.filter { command in
                        if command.command.text.hasPrefix(normalizedQuery) {
                            return true
                        }
                        return false
                    }
                    let sortedCommands = filteredCommands
                    return { _ in return .commands(sortedCommands) }
            }
            
            return signal |> then(participants)
        case let .contextRequest(addressName, query):
            var delayRequest = true
            var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .complete()
            if let previousQuery = previousQuery {
                switch previousQuery {
                    case let .contextRequest(currentAddressName, currentContextQuery) where currentAddressName == addressName:
                        if query.isEmpty && !currentContextQuery.isEmpty {
                            delayRequest = false
                        }
                    default:
                        delayRequest = false
                        signal = .single({ _ in return .contextRequestResult(nil, nil) })
                }
            } else {
                signal = .single({ _ in return .contextRequestResult(nil, nil) })
            }
            
            let chatPeer = peer
            let contextBot = resolvePeerByName(account: account, name: addressName)
                |> mapToSignal { peerId -> Signal<Peer?, NoError> in
                    if let peerId = peerId {
                        return account.postbox.loadedPeerWithId(peerId)
                            |> map { peer -> Peer? in
                                return peer
                            }
                            |> take(1)
                    } else {
                        return .single(nil)
                    }
                }
                |> mapToSignal { peer -> Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> in
                    if let user = peer as? TelegramUser, let botInfo = user.botInfo, let _ = botInfo.inlinePlaceholder {
                        let contextResults = requestChatContextResults(account: account, botId: user.id, peerId: chatPeer.id, query: query, offset: "")
                            |> map { results -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                                return { _ in
                                    return .contextRequestResult(user, results)
                                }
                            }
                        
                        let botResult: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .single({ previousResult in
                            var passthroughPreviousResult: ChatContextResultCollection?
                            if let previousResult = previousResult {
                                if case let .contextRequestResult(previousUser, previousResults) = previousResult {
                                    if previousUser?.id == user.id {
                                        passthroughPreviousResult = previousResults
                                    }
                                }
                            }
                            return .contextRequestResult(user, passthroughPreviousResult)
                        })
                        
                        let maybeDelayedContextResults: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError>
                        if delayRequest {
                            maybeDelayedContextResults = contextResults |> delay(0.4, queue: Queue.concurrentDefaultQueue())
                        } else {
                            maybeDelayedContextResults = contextResults
                        }
                        
                        return botResult |> then(maybeDelayedContextResults)
                    } else {
                        return .single({ _ in return nil })
                    }
                }
            
            return signal |> then(contextBot)
    }
}

func searchQuerySuggestionResultStateForChatInterfacePresentationState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account, currentQuery: ChatPresentationInputQuery?) -> (ChatPresentationInputQuery?, Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError>)? {
    var inputQuery: ChatPresentationInputQuery?
    if let search = chatPresentationInterfaceState.search {
        switch search.domain {
            case .members:
                inputQuery = .mention(query: search.query, types: [.members, .accountPeer])
            default:
                break
        }
    }
    
    if let inputQuery = inputQuery {
        if inputQuery == currentQuery {
            return nil
        } else {
            switch inputQuery {
                case let .mention(query, _):
                    if let peer = chatPresentationInterfaceState.peer?.peer {
                        var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .complete()
                        if let currentQuery = currentQuery {
                            switch currentQuery {
                            case .mention:
                                break
                            default:
                                signal = .single({ _ in return nil })
                            }
                        }
                        
                        let participants = searchGroupMembers(postbox: account.postbox, network: account.network, peerId: peer.id, query: query)
                            |> map { peers -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                                let filteredPeers = peers
                                var sortedPeers: [Peer] = []
                                sortedPeers.append(contentsOf: filteredPeers.sorted(by: { lhs, rhs in
                                    let result = lhs.indexName.indexName(.lastNameFirst).compare(rhs.indexName.indexName(.lastNameFirst))
                                    return result == .orderedAscending
                                }))
                                return { _ in return .mentions(sortedPeers) }
                        }
                        
                        return (inputQuery, signal |> then(participants))
                    } else {
                        return (nil, .single({ _ in return nil }))
                    }
                default:
                    return (nil, .single({ _ in return nil }))
            }
        }
    } else {
        return (nil, .single({ _ in return nil }))
    }
}

private let dataDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType([.link]).rawValue)

func urlPreviewStateForInputText(_ inputText: String?, account: Account, currentQuery: String?) -> (String?, Signal<(TelegramMediaWebpage?) -> TelegramMediaWebpage?, NoError>)? {
    guard let text = inputText else {
        if currentQuery != nil {
            return (nil, .single({ _ in return nil }))
        } else {
            return nil
        }
    }
    if let dataDetector = dataDetector {
        let utf16 = text.utf16
        
        var detectedUrl: String?
        
        let matches = dataDetector.matches(in: text, options: [], range: NSRange(location: 0, length: utf16.count))
        if let match = matches.first {
            let urlText = (text as NSString).substring(with: match.range)
            detectedUrl = urlText
        }
        
        if detectedUrl != currentQuery {
            if let detectedUrl = detectedUrl {
                return (detectedUrl, webpagePreview(account: account, url: detectedUrl) |> map { value in
                    return { _ in return value }
                })
            } else {
                return (nil, .single({ _ in return nil }))
            }
        } else {
            return nil
        }
    } else {
        return (nil, .single({ _ in return nil }))
    }
}