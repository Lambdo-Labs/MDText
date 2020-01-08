//
//  MDText.swift
//  MDText
//
//  Created by Andre Carrera on 10/9/19.
//  Copyright © 2019 Lambdo. All rights reserved.
//

import SwiftUI
import Combine
import UIKit

protocol MarkdownRule {
    var id: String { get }
    var regex: RegexMarkdown { get }
    //    func replace(_ text: String) -> Text
}

struct MDTextGroup {
    var string: String
    var rules: [MarkdownRule]
    var applicableRules: [MarkdownRule] {
        rules.filter{$0.regex != BaseMarkdownRules.none.regex}
    }
    var text: Text {
        guard let firstRule = applicableRules.first else { return rules[0].regex.output(for: string) }
        return applicableRules.dropFirst().reduce(firstRule.regex.output(for: string)) { $1.regex.strategy($0) }
    }
    
    var viewType: MDViewType {
        applicableRules.contains(where: { $0.id == BaseMarkdownRules.link.id || $0.id == BaseMarkdownRules.hyperlink.id }) ?
            .link(self) : .text(self.text)
    }
    
    var urlStr: String {
        RegexMarkdown.url(for: string)
    }
    
}

enum MDViewType {
    case text(Text), link(MDTextGroup)
}

struct MDViewGroup: Identifiable {
    let id = UUID()
    var type: MDViewType
    var view: some View {
        switch type {
        case .link(let group):
            return Button(action: {self.onLinkTap(urlStr: group.urlStr)}, label: {group.text})
                .ereaseToAnyView()
        case .text(let text):
            return text.ereaseToAnyView()
        }
    }
    
    func onLinkTap(urlStr: String) {
        print(urlStr)
        guard let url = URL(string: urlStr) else { return }
        UIApplication.shared.open(url, options: [:])
    }
}


struct RegexMarkdown: Equatable {
    static func == (lhs: RegexMarkdown, rhs: RegexMarkdown) -> Bool {
        lhs.matchIn == rhs.matchIn && lhs.matchOut == rhs.matchOut
    }
    
    var matchIn: String
    var matchOut: String
    var strategy: (Text) -> Text
    func output(for string: String) -> Text {
        let result = outputString(for: string)
        let text = Text(result)
        return strategy(text)
    }
    
    func outputString(for string: String) -> String {
        guard !matchIn.isEmpty else {
            return string
        }
        return string.replacingOccurrences(of: self.matchIn, with: self.matchOut, options: .regularExpression)
    }
    
    static func url(for string: String) -> String {
        let matcher = try! NSRegularExpression(pattern: #"((http(s)?:\/\/.)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*))"#)
        guard let match = matcher.firstMatch(in: string, range: NSRange(location: 0, length: string.utf16.count)) else { return ""}
        let result = string[Range(match.range, in: string)!]
        print(result)
        return String(result)
    }
}

extension RegexMarkdown {
    private var matcher: NSRegularExpression {
        return try! NSRegularExpression(pattern: self.matchIn)
        
    }
    func match(string: String, options: NSRegularExpression.MatchingOptions = .init()) -> Bool {
        return self.matcher.numberOfMatches(in: string, options: options, range: NSMakeRange(0, string.utf16.count)) != 0
    }
}

enum BaseMarkdownRules: String, CaseIterable, MarkdownRule {
    
    
    case none, header, link, bold, hyperlink, emphasis
    var id: String { self.rawValue }
    //
    //    , , del, quote, inline, ul, ol, blockquotes
    
    var regex: RegexMarkdown {
        switch self {
        case .header:
            return .init(matchIn: #"(#+)(.*)"#, matchOut: "$2", strategy: self.header(_:))
        case .link:
            return .init(matchIn: #"\[([^\[]+)\]\(([^\)]+)\)"#, matchOut: "$1", strategy: self.link(_:))
        case .bold:
            return .init(matchIn: #"(\*\*|__)(.*?)\1"#, matchOut: "$2", strategy: self.bold(_:))
        case .hyperlink:
            return .init(matchIn: "<((?i)https?://(?:www\\.)?\\S+(?:/|\\b))>", matchOut: "$1", strategy: self.link(_:))
        case .emphasis:
            return .init(matchIn: #"(\s)(\*|_)(.+?)\2"#, matchOut: "$1$3", strategy: self.emphasis(_:))
        case .none:
            return .init(matchIn: "", matchOut: "", strategy: {$0})
        }
    }
    
    func header(_ text: Text) -> Text {
        return text.font(.headline)
    }
    
    func link(_ text: Text) -> Text {
        return text.foregroundColor(.blue)
    }
    
    func bold(_ text: Text) -> Text {
        return text.bold()
    }
    
    func emphasis(_ text: Text) -> Text {
        return text.italic()
    }
}

func onTapLink(url: String) {
    
}


//    var rules: [String : ((String) -> AnyView))] {
//        [
//            #"/(#+)(.*)/"# -> self.header,                           // headers
//        #"/\[([^\[]+)\]\(([^\)]+)\)/"# -> '<a href=\'\2\'>\1</a>',  // links
//        #"/(\*\*|__)(.*?)\1/"# -> '<strong>\2</strong>',            // bold
//        #"/(\*|_)(.*?)\1/"# -> '<em>\2</em>',                       // emphasis
//        #"/\~\~(.*?)\~\~/"# -> '<del>\1</del>',                     // del
//        #"/\:\"(.*?)\"\:/"# -> '<q>\1</q>',                         // quote
//        #"/`(.*?)`/"# -> '<code>\1</code>',                         // inline code
//        #"/\n\*(.*)/"# -> 'self::ul_list',                          // ul lists
//        #"/\n[0-9]+\.(.*)/"# -> 'self::ol_list',                    // ol lists
//        #"/\n(&gt;|\>)(.*)/"# -> 'self::blockquote ',               // blockquotes
//        #"/\n-{5,}/"# -> "\n<hr />",                                // horizontal rule
//        #"/\n([^\n]+)\n/"# -> 'self::para',                         // add paragraphs
//        #"/<\/ul>\s?<ul>/"# -> '',                                  // fix extra ul
//        #"/<\/ol>\s?<ol>/"# -> '',                                  // fix extra ol
//        #"/<\/blockquote><blockquote>/"# -> "\n"                    // fix extra blockquote
//        ]
//    }

final class MDTextVM: ObservableObject {
    
    @Published var finalText = Text("")
    
    var cancellable: Cancellable? = nil { didSet{ oldValue?.cancel() } }
    
    func parse(string: String, for markdownRules: [MarkdownRule]) {
        let firstGroup = MDTextGroup(string: string, rules: [BaseMarkdownRules.none])
        cancellable = Just(markdownRules)
            .map{ rules -> [MDTextGroup] in
                rules.reduce([firstGroup]) { (result, rule) -> [MDTextGroup] in
                    return result.flatMap{ self.replace(group: $0, for: rule)}
                }
        }
        .map { textGroups in
            textGroups.map{ $0.text}.reduce(Text(""), +)
        }
        .receive(on: RunLoop.main)
        .assign(to: \.finalText, on: self)
    }
    
    func parseText(string: String, for markdownRules: [MarkdownRule]) -> Text {
        let firstGroup = MDTextGroup(string: string, rules: [BaseMarkdownRules.none])
        let textGroups = markdownRules.reduce([firstGroup]) { (result, rule) -> [MDTextGroup] in
            return result.flatMap{ self.replace(group: $0, for: rule)}
        }
        return textGroups.map{ $0.text}.reduce(Text(""), +)
    }
    
    func parseViews(string: String, for markdownRules: [MarkdownRule]) -> [MDViewGroup] {
        let firstGroup = MDTextGroup(string: string, rules: [BaseMarkdownRules.none])
        let textGroups = markdownRules.reduce([firstGroup]) { (result, rule) -> [MDTextGroup] in
            return result.flatMap{ self.replace(group: $0, for: rule)}
        }
        
        guard let firstViewGroup = textGroups.first?.viewType else { return [] }
        
        let allViewGroups = textGroups.dropFirst().reduce([MDViewGroup(type: firstViewGroup)]) { (viewGroups, textGroup) -> [MDViewGroup] in
            let previous = viewGroups.last!
            if case .text(let previousText) = previous.type, case .text(let currentText) = textGroup.viewType {
                let updatedText = previousText + currentText
                return viewGroups.dropLast() + [MDViewGroup(type: .text(updatedText))]
            } else {
                return viewGroups + [MDViewGroup(type: textGroup.viewType)]
            }
            // if previous is just text
        }
        return allViewGroups
    }
    
    func replaceLInk(for textGroup: MDTextGroup) -> AnyView {
        return Button(action: {
            guard let url = URL(string: textGroup.string) else { return }
            UIApplication.shared.open(url, options: [:])
        }, label: {textGroup.text})
            .ereaseToAnyView()
        //
        //        return textGroup.text.onTapGesture {
        //                        guard let url = URL(string: textGroup.string) else { return }
        //                        UIApplication.shared.open(url, options: [:])
        //        }.ereaseToAnyView()
    }
    
    func replace(group: MDTextGroup, for rule: MarkdownRule) -> [MDTextGroup] {
        let string = group.string
        guard let regex = try? NSRegularExpression(pattern: rule.regex.matchIn)
            else {
                return [group]
        }
        let matches = regex.matches(in: string, range: NSRange(0..<string.utf16.count))
        let ranges = matches.map{ $0.range}
        guard !ranges.isEmpty else {
            return [group]
        }
        let zippedRanges = zip(ranges.dropFirst(), ranges)
        // TODO: pass parent modifiers to children, just create a func in mdtextgroup
        let beforeMatchesGroup = ranges.first.flatMap { range -> [MDTextGroup] in
            let lowerBound = String.Index(utf16Offset: 0, in: string)
            let upperBound = String.Index(utf16Offset: range.lowerBound, in: string)
            
            let nonMatchStr = String(string[lowerBound..<upperBound])
            return [MDTextGroup(string: nonMatchStr, rules: group.rules)]
            } ?? []
        
        let resultGroups: [MDTextGroup] =  zippedRanges.flatMap{ (next, current) -> [MDTextGroup] in
            let matchStr = String(string[Range(current, in: string)!])
            
            let lowerBound = String.Index(utf16Offset: current.upperBound, in: string)
            let upperBound = String.Index(utf16Offset: next.lowerBound, in: string)
            
            let nonMatchStr = String(string[lowerBound..<upperBound])
            let groups = [MDTextGroup(string: matchStr, rules: group.rules + [rule]), MDTextGroup(string: nonMatchStr, rules: group.rules)]
            return groups
        }
        
        let lastMatch = ranges.last.flatMap{ range -> [MDTextGroup] in
            let matchStr = String(string[Range(range, in: string)!])
            return [MDTextGroup(string: matchStr, rules: group.rules + [rule])]
            } ?? []
        
        let afterMatchesGroup = ranges.last.flatMap { range -> [MDTextGroup] in
            let lowerBound = String.Index(utf16Offset: range.upperBound, in: string)
            let upperBound = string.endIndex
            
            if upperBound <= lowerBound { // basically if it ends with a match.
                return []
            }
            
            let nonMatchStr = String(string[lowerBound..<upperBound])
            return [MDTextGroup(string: nonMatchStr, rules: group.rules)]
            } ?? []
        
        
        let completeGroups = beforeMatchesGroup + resultGroups + lastMatch + afterMatchesGroup
        return completeGroups
    }
    
}





public struct MDText: View, Equatable {
    public static func == (lhs: MDText, rhs: MDText) -> Bool {
        lhs.markdown == rhs.markdown
    }
    
    var markdown: String
    var alignment: HorizontalAlignment
    
    var rules: [MarkdownRule] = BaseMarkdownRules.allCases
    
    @ObservedObject var vm = MDTextVM()
    
    public init(markdown: String, alignment: HorizontalAlignment = .leading) {
        self.markdown = markdown
        self.alignment = alignment
    }
    
    var views: [MDViewGroup] {
        vm.parseViews(string: markdown, for: rules)
    }
    
    public var body: some View {
        VStack(alignment: alignment) {
            HStack { Spacer() }
            //            vm.parseText(string: markdown, for: rules)
            ForEach(self.views, id: \.id) { viewGroup in
                viewGroup.view
            }
        }
        .drawingGroup()
        //        .onAppear(perform: parse)
    }
    
    //    func parse() {
    //        vm.parse(string: markdown, for: rules)
    //    }
}

extension View {
    func ereaseToAnyView() -> AnyView {
        AnyView(self)
    }
}
