//
// CodeEditor.swift
//
//Rudimentary code editor with JavaScript syntax highlighting, line numbers and auto-indent/auto-brackets.
//
// The reason we're trying to implement our own code editoris that other Swift packages
// use Highlightr.js and WebViews for code syntax highlighting:
// --> When GPT starts streaming in the code, Highlightr.js cannot keep up with the highlighting
// and we get ugly flickering of unstyled text.
//
// The editor is frankenstein'd using GPT-4 and snippets from Naoto Kaneko, https://github.com/naoty/NTYSmartTextView/tree/master (2013).
//

import SwiftUI

/* Regex */
let jsCommentPattern = "//.*|/\\*.*?\\*/"

// capture js reserved keywords
let jsReservedWords = [
    "break", "do", "instanceof", "typeof", "case", "else", "new", "var", "catch",
    "finally", "return", "void", "continue", "for", "switch", "while", "debugger",
    "function", "this", "with", "default", "if", "throw", "delete", "in", "try",
    "class", "enum", "extends", "super", "const", "export", "import", "await", "null",
    "let", "async", "yield"
]
let keywordPattern = "\\b(" + jsReservedWords.joined(separator: "|") + ")\\b"

// capture function names
let functionNamePattern = "\\b[a-zA-Z_][a-zA-Z0-9_]*(?=\\()"

// capture strings, numbers and bools
let valuePattern = "(\"[^\"]*\"|'[^']*'|\\b\\d*\\.?\\d+\\b|\\btrue\\b|\\bfalse\\b)"

let typesPattern = "(?<=types\\.)(NUMBER|PROGRESS|POSITION|SIZE|ANCHOR|POINT3D|POINT4D|COLOR|BOOLEAN|PULSE|INTEGER|ENUM|STRING|JSON|IMAGE)"

// used for 'smart' auto-matching of parentheses, curly brackets etc.
let smartIndentPattern = "^(\\t|\\s)+"
let smartPairCharacters: [String: String] = [
    "(": ")",
    "[": "]",
    "{": "}",
    "\"": "\"",
    "'": "'",
    "`": "`"
]

struct CustomJavascriptEditor: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool = true
    
    @State private var firstViewUpdate: Bool = true
    
    var textViewAttributes: [NSAttributedString.Key:Any] {
        return [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .paragraphStyle: {
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineSpacing = 3
                return paragraph
            }()
        ]
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let textView = TextViewWithCustomContextMenu()
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: textView.bounds.width, height: CGFloat.infinity)
        textView.textContainer?.widthTracksTextView = true
        
        textView.backgroundColor = .clear
        
        textView.allowsUndo = true
        
        textView.isEditable = self.isEditable
        
        // padding
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.textContainer?.lineFragmentPadding = 8
        
        // TODO: Double-space still inserts a period (.) Have to fix...
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.enabledTextCheckingTypes = 0;
        textView.isRichText = false
        
        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        textView.delegate = context.coordinator
        
        textView.typingAttributes = textViewAttributes
        textView.setUpLineNumberView(gutterWidth: 40)
        
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let isScrolledToBottom = scrollView.verticalScroller?.floatValue == 1.0
        
        if textView.string != text {
            textView.string = text
            
            textView.enclosingScrollView?.verticalRulerView?.needsDisplay = true
            
            // Update cursor position as text streams in
            let newPosition = textView.string.utf16.count
            textView.setSelectedRange(NSRange(location: newPosition, length: 0))
            
            if !isScrolledToBottom && !firstViewUpdate {
                let range = NSRange(location: textView.string.utf16.count, length: 0)
                textView.scrollRangeToVisible(range)
            }
            
            if(firstViewUpdate) {
                DispatchQueue.main.async {
                    firstViewUpdate = false
                }
            }
        }
        
        textView.isEditable = self.isEditable
        
        let selectedRanges = textView.selectedRanges
        textView.typingAttributes = textViewAttributes
        
        // handle default color and syntax highlighting
        textView.textStorage?.addAttribute(.foregroundColor, value: NSColor(named: "CodeDefaultColor")!, range: NSRange(location: 0, length: textView.string.utf16.count))
        
        highlightSyntax(withPattern: keywordPattern, color: NSColor(named: "CodeKeywordColor")!, inTextView: textView)
        highlightSyntax(withPattern: valuePattern, color: NSColor(named: "CodeValueColor")!, inTextView: textView)
        highlightSyntax(withPattern: functionNamePattern, color: NSColor(named: "CodeFnColor")!, inTextView: textView)
        highlightSyntax(withPattern: typesPattern, color: NSColor(named: "CodeTypesColor")!, inTextView: textView)
        highlightSyntax(withPattern: jsCommentPattern, color: NSColor(named: "CodeCommentColor")!, inTextView: textView)
        
        // restore the cursor position after changes to text have been made
        textView.setSelectedRanges(selectedRanges, affinity: .downstream, stillSelecting: false)
        
        
    }
    
    func highlightSyntax(withPattern pattern: String, color: NSColor, inTextView nsView: NSTextView, captureGroup: Int? = nil) {
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: nsView.string, options: [], range: NSRange(location: 0, length: nsView.string.utf16.count))
        
        for match in matches {
            let range: NSRange
            
            // If a capture group is provided, use it, otherwise use the entire match.
            if let captureGroup = captureGroup {
                range = match.range(at: captureGroup)
            } else {
                range = match.range
            }
            
            nsView.textStorage?.addAttribute(.foregroundColor, value: color, range: range)
        }
    }
    
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CustomJavascriptEditor
        
        init(_ textView: CustomJavascriptEditor) {
            self.parent = textView
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            textView.enclosingScrollView?.verticalRulerView?.needsDisplay = true
            parent.text = textView.string
        }
        
        /* Smart Indent and Auto-Pairing of "'({[, courtesy of https://github.com/naoty/NTYSmartTextView/tree/master and GPT-4 */
        
        // Preserve indentation on new line
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSTextView.insertNewline(_:)) {
                insertSmartNewline(on: textView)
                return true
            }
            return false
        }
        
        /* Auto-pair "'({[ */
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard let replacementString = replacementString else { return true }
            
            if let closingCharacter = smartPairCharacters[replacementString] {
                // Check for selected text
                let selectedText = (textView.string as NSString).substring(with: affectedCharRange)
                
                textView.insertText(replacementString + selectedText + closingCharacter, replacementRange: affectedCharRange)
                // If there's a selection, adjust cursor to end of the enclosed text
                if affectedCharRange.length > 0 {
                    textView.setSelectedRange(NSRange(location: affectedCharRange.location + selectedText.utf16.count + 2, length: 0))
                } else {
                    textView.moveBackward(self)
                }
                return false
            }
            
            // delete paired characters
            if affectedCharRange.length == 0 {  // Only for simple backspace, not selections
                let nextCharacterIndex = affectedCharRange.location
                if nextCharacterIndex < textView.string.utf16.count {
                    let followingCharacter = (textView.string as NSString).substring(with: NSRange(location: nextCharacterIndex, length: 1))
                    
                    if smartPairCharacters.values.contains(followingCharacter), smartPairCharacters[replacementString] == followingCharacter {
                        textView.insertText("", replacementRange: NSRange(location: affectedCharRange.location, length: 2))
                        return false
                    }
                }
            }
            return true
        }
        
        private func insertSmartNewline(on textView: NSTextView) {
            // get the current line
            let currentLineRange = (textView.string as NSString).lineRange(for: textView.selectedRange())
            let currentLine = (textView.string as NSString).substring(with: currentLineRange)
            
            // match indentation
            if let regex = try? NSRegularExpression(pattern: smartIndentPattern),
               let match = regex.firstMatch(in: currentLine, options: [], range: NSRange(location: 0, length: currentLine.utf16.count)),
               match.range.length > 0 {
                
                let indent = (currentLine as NSString).substring(with: match.range)
                textView.insertText("\n" + indent, replacementRange: textView.selectedRange())
            } else {
                textView.insertText("\n", replacementRange: textView.selectedRange())
            }
        }
    }
}

// Add .modifiers
extension CustomJavascriptEditor {
    func isEditable(_ bool: Bool) -> CustomJavascriptEditor {
        var view = self
        view.isEditable = bool
        return view
    }
}

// Custom TextView that...
// • adds a custom context menu (to remove spellcheck etc.)
class TextViewWithCustomContextMenu: NSTextView {
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
               menu.addItem(withTitle: "Cut", action: #selector(cut(_:)), keyEquivalent: "x")
               menu.addItem(withTitle: "Copy", action: #selector(copy(_:)), keyEquivalent: "c")
               menu.addItem(withTitle: "Paste", action: #selector(paste(_:)), keyEquivalent: "v")
               return menu
    }
}


