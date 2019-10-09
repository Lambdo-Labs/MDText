//
//  ContentView.swift
//  MDText
//
//  Created by Andre Carrera on 10/9/19.
//  Copyright © 2019 Lambdo. All rights reserved.
//
import SwiftUI
import Combine

protocol MarkdownRule {
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
    
}


struct RegexMarkdown: Equatable {
    static func == (lhs: RegexMarkdown, rhs: RegexMarkdown) -> Bool {
        lhs.matchIn == rhs.matchIn && lhs.matchOut == rhs.matchOut
    }
    
    var matchIn: String
    var matchOut: String
    var strategy: (Text) -> Text
    func output(for string: String) -> Text {
        guard !matchIn.isEmpty else {
            return Text(string)
        }
        let result = string.replacingOccurrences(of: self.matchIn, with: self.matchOut, options: .regularExpression)
        let text = Text(result)
        return strategy(text)
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
            return .init(matchIn: #"\s(\*|_)(.+?)\1"#, matchOut: "$2", strategy: self.emphasis(_:))
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
        let firstGroup = ranges.first.flatMap { range -> [MDTextGroup] in
            let lowerBound = String.Index(utf16Offset: 0, in: string)
            let upperBound = String.Index(utf16Offset: range.lowerBound, in: string)
            
            let nonMatchStr = String(string[lowerBound..<upperBound])
            return [MDTextGroup(string: nonMatchStr, rules: group.rules)]
            } ?? []
        let lastGroup = ranges.last.flatMap { range -> [MDTextGroup] in
            let lowerBound = String.Index(utf16Offset: range.upperBound, in: string)
            let upperBound = String.Index(utf16Offset: string.count, in: string)
            
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
        
        let completeGroups = firstGroup + resultGroups + lastMatch + lastGroup
        return completeGroups
    }
    
}





struct MDText: View {
    var markdown: String
    
    var rules: [MarkdownRule] = BaseMarkdownRules.allCases
    
    @ObservedObject var vm = MDTextVM()
    
    
    var down: some View {
        vm.finalText.onAppear(perform: parse)
    }
    
    
    var body: some View {
        VStack {
            HStack { Spacer() }
            down
        }
    }
    
    func parse() {
        vm.parse(string: markdown, for: rules)
    }
}






struct ContentView_Previews: PreviewProvider {
    
    static let string =
    #"""
# hello, This is Markdown Live Preview

----
## what is Markdown?
see [Wikipedia](https://en.wikipedia.org/wiki/Markdown)

> Markdown is a lightweight markup language, originally created by John Gruber and Aaron Swartz allowing people "to write using an easy-to-read, easy-to-write plain text format, then convert it to structurally valid XHTML (or HTML)".

----
## usage
1. Write markdown text in this textarea.
2. Click 'HTML Preview' button.

----
## markdown quick reference
# headers

*emphasis*

**strong**

* list

>block quote

    code (4 spaces indent)
[links](https://wikipedia.org)

----
## changelog
* 17-Feb-2013 re-design

----
## thanks
* [markdown-js](https://github.com/evilstreak/markdown-js)
"""#
    static var previews: some View {
        //        Group {
        ScrollView {
            VStack {
                MDText(markdown: ContentView_Previews.string)
                
            }
            .padding(.horizontal)
        }
        
        //            MDText(markdown: ContentView_Previews.string)
        //        }
    }
}
//extension View {
//    func eraseToAnyView() -> AnyView {
//        return AnyView(self)
//    }
//}
