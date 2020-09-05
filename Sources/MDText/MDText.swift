//
//  MDText.swift
//  MDText
//
//  Created by Andre Carrera on 10/9/19.
//  Copyright © 2019 Lambdo. All rights reserved.
//

import SwiftUI
import Combine
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

protocol MarkdownRule {
    var id: String { get }
    var regex: RegexMarkdown { get }
}

struct MDTextGroup {
    var string: String
    var rules: [MarkdownRule]
    var applicableRules: [MarkdownRule] {
        rules.filter { $0.regex != BaseMarkdownRules.none.regex }
    }

    var text: Text {
        guard let firstRule = applicableRules.first else { return rules[0].regex.output(for: string) }
        //print("Rule: \(firstRule)")
        return applicableRules.dropFirst().reduce(firstRule.regex.output(for: string)) { $1.regex.strategy($0) }
    }
    
    var viewType: MDViewType {
        if applicableRules.contains(where: { $0.id == BaseMarkdownRules.link.id || $0.id == BaseMarkdownRules.hyperlink.id }) {
            return .link(self)
        } else if applicableRules.contains(where: { $0.id == BaseMarkdownRules.inLineCode.id }) {
            return .inLineCode(self) 
        } else {
            return .text(self.text)
        }
    }
    
    var urlStr: String {
        RegexMarkdown.url(for: string)
    }

}

enum MDViewType {
    case text(Text)
    case inLineCode(MDTextGroup)
    case link(MDTextGroup)
}

struct MDViewGroup: Identifiable {
    let id = UUID()
    var type: MDViewType
    var view: some View {
        switch type {
        case .link(let group): return AnyView(Button(action: { self.onLinkTap(urlStr: group.urlStr) }, label: { group.text }))
        case .text(let text): return AnyView(text)
        case .inLineCode(let group): return AnyView(group.text.background(Color.gray))
        }
    }
    
    func onLinkTap(urlStr: String) {
        //print(urlStr)
        guard let url = URL(string: urlStr) else { return }
        #if os(iOS)
		UIApplication.shared.open(url, options: [:])
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
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
        let result = string.replacingOccurrences(of: self.matchIn, with: self.matchOut, options: .regularExpression)
        //print("RegexMarkdown : outputString : [\(string)][\(self.matchOut)] -> [\(result)]\n")
        return result
    }
    
    static func url(for string: String) -> String {
        let matcher = try! NSRegularExpression(pattern: #"((http(s)?:\/\/.)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*))"#)
        guard let match = matcher.firstMatch(in: string, range: NSRange(location: 0, length: string.utf16.count)) else { return ""}
        let result = string[Range(match.range, in: string)!]
        //print(result)
        return String(result)
    }
}

fileprivate extension RegexMarkdown {
    var matcher: NSRegularExpression {
        return try! NSRegularExpression(pattern: self.matchIn)
    }
    func match(string: String, options: NSRegularExpression.MatchingOptions = .init()) -> Bool {
        return self.matcher.numberOfMatches(in: string, options: options, range: NSMakeRange(0, string.utf16.count)) != 0
    }
}

enum BaseMarkdownRules: String, CaseIterable, MarkdownRule {

    case none
    case subSubHeader
    case subHeader
    case header
    case link
    case bold
    case inLineCode
    case hyperlink
    case italic
    var id: String { self.rawValue }
    //
    //    , , del, quote, inline, ul, ol, blockquotes

    /*
     https://javascript.info/regexp-groups
     https://regex101.com/
     Without parentheses, the pattern go+ means g character, followed by o repeated one or more times. For instance, goooo or gooooooooo.
     Parentheses group characters together, so (go)+ means go, gogo, gogogo and so on.
     */
    var regex: RegexMarkdown {
        switch self {
        case .subSubHeader:
            return RegexMarkdown(matchIn: #"( ### )(.*)"#, matchOut: "$2", strategy: self.subSubHeader)
        case .subHeader:
            return RegexMarkdown(matchIn: #"( ## )(.*)"#, matchOut: "$2", strategy: self.subHeader)
        case .header:
            return RegexMarkdown(matchIn: #"( # )(.*)"#, matchOut: "$2", strategy: self.header(_:))
        case .inLineCode:
            return RegexMarkdown(matchIn: #"(\s)(\`)(.+?)\2"#, matchOut: "$3", strategy: self.inLineCode(_:))
        case .link:
            return RegexMarkdown(matchIn: #"\[([^\[]+)\]\(([^\)]+)\)"#, matchOut: "$1", strategy: self.link(_:))
        case .hyperlink:
            return RegexMarkdown(matchIn: "<((?i)https?://(?:www\\.)?\\S+(?:/|\\b))>", matchOut: "$1", strategy: self.link(_:))
        case .italic:
            return RegexMarkdown(matchIn: #"(\s)(\*|_)(.+?)\2"#, matchOut: "$1$3", strategy: self.emphasis(_:))
        case .bold:
            return RegexMarkdown(matchIn: #"(\*\*|__)(.*?)\1"#, matchOut: "$2", strategy: self.bold(_:))
        case .none:
            return RegexMarkdown(matchIn: "", matchOut: "", strategy: {$0})
        }
    }
    
    func header(_ text: Text) -> Text {
        return text.font(.largeTitle).bold()//.foregroundColor(Color.red)
    }

    func subHeader(_ text: Text) -> Text {
        return text.font(.title).bold()//.foregroundColor(Color.blue)
    }

    func subSubHeader(_ text: Text) -> Text {
        return text.font(.headline).bold()//.foregroundColor(Color.green)
    }

    func link(_ text: Text) -> Text {
        return text.foregroundColor(.blue)
    }

    func inLineCode(_ text: Text) -> Text {
        return text
    }

    func bold(_ text: Text) -> Text {
        return text.font(.body).bold()
    }
    
    func emphasis(_ text: Text) -> Text {
        return text.font(.body).italic()
    }
}
//    var rules: [String : ((String) -> AnyView))] {
//        [
//        #"/(#+)(.*)/"# -> self.header,                              // headers
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
    
    var cancellable: Cancellable? = nil { didSet { oldValue?.cancel() } }
    
    func parse(string: String, for markdownRules: [MarkdownRule]) {
        let firstGroup = MDTextGroup(string: string, rules: [BaseMarkdownRules.none])
        cancellable = Just(markdownRules)
            .map { rules -> [MDTextGroup] in
                rules.reduce([firstGroup]) { (result, rule) -> [MDTextGroup] in
                    return result.flatMap { self.replace(group: $0, for: rule)}
                }
        }
        .map { textGroups in
            textGroups.map { $0.text}.reduce(Text(""), +)
        }
        .receive(on: RunLoop.main)
        .assign(to: \.finalText, on: self)
    }
    
    func parseText(string: String, for markdownRules: [MarkdownRule]) -> Text {
        let firstGroup = MDTextGroup(string: string, rules: [BaseMarkdownRules.none])
        let textGroups = markdownRules.reduce([firstGroup]) { (result, rule) -> [MDTextGroup] in
            return result.flatMap { self.replace(group: $0, for: rule) }
        }
        return textGroups.map { $0.text}.reduce(Text(""), +)
    }
    
    func parseViews(string: String, for markdownRules: [MarkdownRule]) -> [MDViewGroup] {
        let firstGroup = MDTextGroup(string: string, rules: [BaseMarkdownRules.none])
        let textGroups = markdownRules.reduce([firstGroup]) { (result, rule) -> [MDTextGroup] in
            return result.flatMap { self.replace(group: $0, for: rule)}
        }
        
        guard let firstViewGroup = textGroups.first?.viewType else { return [] }
        
        let allViewGroups = textGroups.dropFirst().reduce([MDViewGroup(type: firstViewGroup)]) { (viewGroups, textGroup) -> [MDViewGroup] in
            let previous = viewGroups.last!
            if case .text(let previousText) = previous.type,
                case .text(let currentText) = textGroup.viewType {
                let updatedText = previousText + currentText
                return viewGroups.dropLast() + [MDViewGroup(type: .text(updatedText))]
            } else {
                return viewGroups + [MDViewGroup(type: textGroup.viewType)]
            }
            // if previous is just text
        }
        return allViewGroups
    }

    func replace(group: MDTextGroup, for rule: MarkdownRule) -> [MDTextGroup] {
        let string = group.string
        guard let regex = try? NSRegularExpression(pattern: rule.regex.matchIn)
            else {
                return [group]
        }
        let matches = regex.matches(in: string, range: NSRange(0..<string.utf16.count))
        let ranges = matches.map { $0.range}
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
        
        let resultGroups: [MDTextGroup] =  zippedRanges.flatMap { (next, current) -> [MDTextGroup] in
            guard let range = Range(current, in: string) else { return [] }
            let matchStr = String(string[range])

            let lowerBound = String.Index(utf16Offset: current.upperBound, in: string)
            let upperBound = String.Index(utf16Offset: next.lowerBound, in: string)
            
            let nonMatchStr = String(string[lowerBound..<upperBound])
            let groups = [MDTextGroup(string: matchStr, rules: group.rules + [rule]), MDTextGroup(string: nonMatchStr, rules: group.rules)]
            return groups
        }
        
        let lastMatch = ranges.last.flatMap { range -> [MDTextGroup] in
            guard let index = Range(range, in: string) else { return [] }
            let matchStr = String(string[index])
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
        var escaped = markdown.replacingOccurrences(of: "\n#", with: "\n #") // Hack to deal with header, subHeader and subSubHeader
        if escaped.hasPrefix("# ") {
            escaped = " \(escaped)"
        }
        self.markdown = escaped
        self.alignment = alignment
    }
    
    var views: [MDViewGroup] {
        let result = vm.parseViews(string: markdown, for: rules)
        result.forEach { (some) in
            print("TYPE: \(some.type)")
        }
        return result
    }
    
    public var body: some View {
        VStack(alignment: alignment) {
            HStack { Spacer() }
            ForEach(self.views, id: \.id) { viewGroup in
                viewGroup.view
            }
        }
    }
}

extension View {
    func ereaseToAnyView() -> AnyView {
        AnyView(self)
    }
}

struct MDTextSampleView: View {
    var markdown =
    """
    ** Hello MDText **
    """

    var body: some View {
        ScrollView {
            MDText(markdown: sampleMD).padding()
        }
    }
}

struct MDTextSampleView_Previews: PreviewProvider {
    static var previews: some View {
        MDTextSampleView()
    }
}

private let sampleMD = """
 # Title

 ## Subtitle

 ### SubSubtitle

this is `in line code`, weeeee

__Bold__: With imperative programming

_Italic_: With declarative programming

__Combine = Publishers + _Subscribers_ + Operators__

----

 # Title

 ## Subtitle

 ### SubSubtitle

this is `in line code`, weeeee

__Bold__: With imperative programming

_Italic_: With declarative programming

__Combine = Publishers + _Subscribers_ + Operators__

----

 # Title

 ## Subtitle

 ### SubSubtitle

this is `in line code`, weeeee

__Bold__: With imperative programming

_Italic_: With declarative programming

__Combine = Publishers + _Subscribers_ + Operators__

----
"""
