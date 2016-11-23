#!/usr/bin/env swift

import Foundation

extension NSURL {
    var isDirectory : Bool {
        var isDir : ObjCBool = ObjCBool(false)
        NSFileManager.defaultManager().fileExistsAtPath(path!, isDirectory: &isDir)
        return Bool(isDir)
    }
}

class FileManagerWrapper {
    
    //returns an array of NSURLs representing the contents of the directory and its sub-directories
    class func discoverContentsInDirectoryAndSubDirectoriesWithURL(url: NSURL) -> [NSURL] {
        let fileManager = NSFileManager.defaultManager()
        var contents = [NSURL]()
        
        var subdirectories = [url]
        
        while subdirectories.count > 0 {
            
            let nextLevelDirectories : [[NSURL]] = subdirectories.map {
                let additions = try? fileManager.contentsOfDirectoryAtURL($0, includingPropertiesForKeys: [NSURLNameKey], options: .SkipsHiddenFiles).filter { !$0.isDirectory }
                contents = contents + (additions ?? [])
                do {
                    return try fileManager.contentsOfDirectoryAtURL($0, includingPropertiesForKeys: [NSURLNameKey], options: .SkipsHiddenFiles).filter { $0.isDirectory }
                } catch let error as NSError {
                    print("Error reading contents of directory. \(error.localizedDescription)")
                    return [NSURL]()
                }
            }
            subdirectories = nextLevelDirectories.flatMap { $0 }
        }
        return contents
    }
    //
    //    class func createFileInDirectory(directory: String, _ filename: String, _ contents: String) {
    //        let outputURL = directory.stringByAppendingPathComponent(filename)
    //        if  !NSFileManager.defaultManager().fileExistsAtPath(outputURL) {
    //            NSFileManager.defaultManager().createFileAtPath(outputURL, contents: contents.dataUsingEncoding(NSUTF8StringEncoding), attributes: nil)
    //        }
    //    }
}

struct RegexWrapper {
    private let regularExpression: NSRegularExpression!
    
    private init(_ pattern: String, options: NSRegularExpressionOptions = NSRegularExpressionOptions(rawValue: 0)) {
        var error: NSError?
        let re: NSRegularExpression?
        do {
            re = try NSRegularExpression(pattern: pattern, options: options)
        } catch let error1 as NSError {
            error = error1
            re = nil
        }
        
        if re == nil {
            if let error = error {
                print("Regular expression error: \(error.userInfo)")
            }
            assert(re != nil)
        }
        
        self.regularExpression = re
    }
    
    private func replace(input: String, _ replacement: String) -> String {
        let s = input as NSString
        let result = regularExpression.stringByReplacingMatchesInString(s as String, options: NSMatchingOptions(rawValue: 0), range: NSMakeRange(0, s.length), withTemplate: replacement)
        return result
    }
    
    private static func replace(input: String, pattern: String, replacement: String) -> String {
        let regex = RegexWrapper(pattern)
        return regex.replace(input, replacement)
    }
    
    private func replace(input: String, evaluator: (RegexMatch) -> String) -> String {
        // Get list of all replacements to be made
        var replacements = Array<(NSRange, String)>()
        let s = input as NSString
        let options = NSMatchingOptions(rawValue: 0)
        let range = NSMakeRange(0, s.length)
        self.regularExpression.enumerateMatchesInString(s as String,
                                                        options: options,
                                                        range: range,
                                                        usingBlock: { (result, flags, stop) -> Void in
                                                            if result!.range.location == NSNotFound {
                                                                return
                                                            }
                                                            let match = RegexMatch(textCheckingResult: result!, string: s)
                                                            let range = result!.range
                                                            let replacementText = evaluator(match)
                                                            let replacement = (range, replacementText)
                                                            replacements.append(replacement)
        })
        
        // Make the replacements from back to front
        var result = s
        for (range, replacementText) in Array(replacements.reverse()) {
            result = result.stringByReplacingCharactersInRange(range, withString: replacementText)
        }
        return result as String
    }
    
    private static func replace(input: String, pattern: String, evaluator: (RegexMatch) -> String) -> String {
        let regex = RegexWrapper(pattern)
        return regex.replace(input, evaluator: evaluator)
    }
    
    private static func replace(input: String, pattern: String, evaluator: (RegexMatch) -> String, options: NSRegularExpressionOptions) -> String {
        let regex = RegexWrapper(pattern, options: options)
        return regex.replace(input, evaluator: evaluator)
    }
    
    private static func replace(input: String, pattern: String, replacement: String, options: NSRegularExpressionOptions) -> String {
        let regex = RegexWrapper(pattern, options: options)
        return regex.replace(input, replacement)
    }
    
    private func matches(input: String) -> [RegexMatch] {
        var matchArray = Array<RegexMatch>()
        
        let s = input as NSString
        let options = NSMatchingOptions(rawValue: 0)
        let range = NSMakeRange(0, s.length)
        self.regularExpression.enumerateMatchesInString(s as String,
                                                        options: options,
                                                        range: range,
                                                        usingBlock: { (result, flags, stop) -> Void in
                                                            let match = RegexMatch(textCheckingResult: result!, string: s)
                                                            matchArray.append(match)
        })
        
        return matchArray
    }
    
    private static func matches(input: String, pattern: String) -> [RegexMatch] {
        let regex = RegexWrapper(input)
        return regex.matches(pattern)
    }
    
    private func isMatch(input: String) -> Bool {
        let s = input as NSString
        let firstMatchRange = regularExpression.rangeOfFirstMatchInString(s as String,
                                                                          options: NSMatchingOptions(rawValue: 0),
                                                                          range: NSMakeRange(0, s.length))
        return !(NSNotFound == firstMatchRange.location)
    }
    
    private static func isMatch(input: String, pattern: String) -> Bool {
        let regex = RegexWrapper(pattern)
        return regex.isMatch(input)
    }
    
    private func split(input: String) -> [String] {
        var stringArray: [String] = Array<String>()
        
        var nextStartIndex = 0
        
        let s = input as NSString
        let options = NSMatchingOptions(rawValue: 0)
        let range = NSMakeRange(0, s.length)
        self.regularExpression.enumerateMatchesInString(input,
                                                        options: options,
                                                        range: range,
                                                        usingBlock: { (result, flags, stop) -> Void in
                                                            let range = result!.range
                                                            if range.location > nextStartIndex {
                                                                let runRange = NSMakeRange(nextStartIndex, range.location - nextStartIndex)
                                                                let run = s.substringWithRange(runRange) as String
                                                                stringArray.append(run)
                                                                nextStartIndex = range.location + range.length
                                                            }
        })
        
        if nextStartIndex < s.length {
            let lastRunRange = NSMakeRange(nextStartIndex, s.length - nextStartIndex)
            let lastRun = s.substringWithRange(lastRunRange) as String
            stringArray.append(lastRun)
        }
        
        return stringArray
    }
    
    private static func escape(input: String) -> String {
        return NSRegularExpression.escapedPatternForString(input)
    }
}

extension String {
    
    func rangeFromNSRange(nsRange : NSRange) -> Range<String.Index>? {
        let from16 = utf16.startIndex.advancedBy(nsRange.location, limit: utf16.endIndex)
        let to16 = from16.advancedBy(nsRange.length, limit: utf16.endIndex)
        if let from = String.Index(from16, within: self),
            let to = String.Index(to16, within: self) {
            return from ..< to
        }
        return nil
    }
    
    func sliceAfter(after: String, to: String) -> String {
        return rangeOfString(after).flatMap {
            rangeOfString(to, range: $0.endIndex..<endIndex).map {
                substringToIndex($0.endIndex)
            }
            } ?? self
    }
    
    func sliceBefore(range: NSRange, to: String) -> String {
        if let swiftRange = rangeFromNSRange(range) {
            return rangeOfString(to, options: .BackwardsSearch, range: startIndex...swiftRange.startIndex).map {
                substringWithRange($0.startIndex..<swiftRange.startIndex)
                } ?? self
        }
        return self
    }
}

public struct RegexMatch {
    let textCheckingResult: NSTextCheckingResult
    let string: NSString
    
    init(textCheckingResult: NSTextCheckingResult, string: NSString) {
        self.textCheckingResult = textCheckingResult
        self.string = string
    }
    
    var context : String {
        return (string as String).sliceBefore(textCheckingResult.range, to: "\n")
    }
    
    var value : String {
        return string.substringWithRange(textCheckingResult.range) as String
    }
    
    var index: Int {
        return textCheckingResult.range.location
    }
    
    var length: Int {
        return textCheckingResult.range.length
    }
    
    ///Searches the context of the match for prefixes, returns a boolean indicating if the context matches one of the prefixes
    func containsPrefix(prefixes: [String]) -> Bool {
        return (prefixes.map {
            return (context as String).stringByReplacingOccurrencesOfString(" ", withString: "").lowercaseString.hasSuffix($0.stringByReplacingOccurrencesOfString(" ", withString: "").lowercaseString) }).reduce(false) { $0 || $1 }
    }
    
    func valueOfGroupAtIndex(index: Int) -> NSString {
        if 0 <= index && index < textCheckingResult.numberOfRanges {
            let groupRange = textCheckingResult.rangeAtIndex(index)
            if groupRange.location == NSNotFound {
                return ""
            }
            assert(groupRange.location + groupRange.length <= string.length, "range must be contained within string")
            return string.substringWithRange(groupRange)
        }
        return ""
    }
}

private struct RegexOptions {
    /// Allow ^ and $ to match the start and end of lines
    static let MultiLine = NSRegularExpressionOptions.AnchorsMatchLines
    
    /// Ignore whitespace and #-prefixed comments in the pattern
    static let IgnorePatternWhitespace = NSRegularExpressionOptions.AllowCommentsAndWhitespace
    
    ///Allow . to match any character, including line separators
    static let Singleline = NSRegularExpressionOptions.DotMatchesLineSeparators
    
    ///Match letters in the pattern independent of case
    static let IgnoreCase = NSRegularExpressionOptions.CaseInsensitive
    
    //Default options
    static let None = NSRegularExpressionOptions(rawValue: 0)
}

public struct Finder {
    
    public static func findString(string: String?, inText text: String, ignorePrefixes prefixes: [String]? = nil) -> [RegexMatch] {
        var matches = [RegexMatch]()
        if text.isEmpty || string == nil { return matches }
        
        let regex = RegexWrapper(string!)
        matches = regex.matches(text)
        if prefixes != nil {
            return matches.filter { !$0.containsPrefix(prefixes!) }
        }
        return matches
    }
}

class CountDown {
    
    var count : Int
    
    init(_ count: Int) {
        self.count = count
    }
    
    func countDown() {
        print("\nReviewing \(count) strings...\n")
        count = count - 1
    }
}

class OutputManager {
    var string = ""
    let file : String
    let directory : String
    
    init(file: String, directory: String) {
        self.file = file
        self.directory = directory
    }
    
    func log(output: String) {
        print(output)
        string = string + output + "\n"
    }
    
    func write() {
        write(string, toFile: file, inDirectory: directory)
    }
    
    func write(output: String, toFile filename: String, inDirectory directory: String) {
        let path = NSString(string: directory).stringByExpandingTildeInPath
        let url = NSURL(fileURLWithPath: path).URLByAppendingPathComponent(filename)
        do {
            try output.writeToURL(url, atomically: true, encoding: NSUTF8StringEncoding)
        } catch {
            //failed tow rite file - bad permissions, bad filename, missing permissions, or more likely it cannot be converted to the encoding
            print(error)
        }
    }
}

//
// main.swift
//
// StringFinder
//
// Created by Katie Jones on 11/11/2016
//
//

//Define prefixes

let regex_objc = "@\"[^\"]*\""
let regex_swift = "\"[^\"]*\""

//let regex_ignorePrefixes_objc = "(identifier)*(imageNamed)*(key)*(storyboardWithName)*(loadNibNamed)*(NibName)*(applyClassWithName)*(usingClassWithName)*(NSLog)*(isEqualToString)*(#import)*(constraintsWithVisualFormat)*(selectedSwatchSequence)*\\s*[:\\(]*\\s*"

//let regex_ignorePrefixes_swift = "(identifier)*(key)*(UIStoryboard\\(name)*(loadNibNamed)*(nibName)*(NSLog)*(print)*\\s*[:\\(]*\\s*"

let ignorePrefixes_objc = ["identifier:", "imageNamed:", "key:", "storyboardWithName:", "loadNibNamed:", "NibName:", "applyClassWithName:", "usingClassWithName:", "NSLog(", "isEqualToString:", "#import", "constraintsWithVisualFormat:", "deepLink =", "deepLink:", "selectedSwatchSequence:", "themeColorForConstant:", "applyClassWithName:[NSString stringWithFormat:", "usingClassWithName:[NSString stringWithFormat:", "URLWithString:", "errorWithDomain:", "NSLocalizedStringWithDefaultValue(", "NSLocalizedString(", "shortSku:", "predicateWithFormat:", "themePrefix=", "identifier=", "NibName=", "key=", "price:", "salePrice:", "longSku:", "initWithItemId:", "identifierName=", "themeClass=", "NSURL URLWithString:", "imageWithPDFNamed:"]

let ignorePrefixes_swift = ["identifier(", "key(", "UIStoryboard(name:", "loadNibNamed(", "nibName:", "NSLog(", "print(", "applyClassWithName(", "textAttributesFromThemeClassWithName(", "themePrefix=", "identifier=", "NibName=", "key=", "price:", "salePrice:", "longSku:", "initWithItemId:", "identifierName=", "themeClass=", "NSLocalizedString(", "usingClassWithName:", "blockName=", "modallyPresentDeepLink(", "NSURL(string:"]

//let findPrefixes_objc = ["initWithString:", "actionWithTitle:", "stringWithFormat:"]
//let findPrefixes_swift = ["styleText(", "NSAttributedString(string:", "UIAlertAction(title:", "String(format:"]

var skippedFiles = [String]()

//Main
func main() {
    let cwd = NSFileManager.defaultManager().currentDirectoryPath
    let cwdURL = NSURL(fileURLWithPath: cwd)
    let output = OutputManager(file: "stringfinder_\(cwdURL.URLByDeletingPathExtension!.lastPathComponent!)_log.txt", directory: "~/Documents")
    output.log("Running stringfinder in:\n" + cwd)
    
    let fileURLs = FileManagerWrapper.discoverContentsInDirectoryAndSubDirectoriesWithURL(cwdURL)
    output.log("searching \(fileURLs.count) files...")
    
    var fileURLs_objc = fileURLs.filter { $0.pathExtension == "h" || $0.pathExtension == "m" }
    var fileURLs_swift = fileURLs.filter { $0.pathExtension == "swift" }
    output.log("\(fileURLs_objc.count) ObjC files found...")
    output.log("\(fileURLs_swift.count) Swift files found...")
    
    for file in Array(Set(fileURLs).subtract(Set(fileURLs_objc)).subtract(Set(fileURLs_swift))) {
        print("Skipping file: \(file.lastPathComponent!)")
        skippedFiles.append(file.lastPathComponent!)
    }
    
    func regex(fileExtension: String) -> String? {
        if fileExtension == "m" || fileExtension == "h" { return regex_objc }
        else if fileExtension == "swift" { return regex_swift }
        else { return nil }
    }
    
    func ignorePrefixes(fileExtension: String) -> [String]? {
        if fileExtension == "m" || fileExtension == "h" { return ignorePrefixes_objc }
        else if fileExtension == "swift" { return ignorePrefixes_swift }
        else { return nil }
    }
    
    var validURLs = fileURLs_objc + fileURLs_swift
    validURLs = validURLs.filter {
        if $0.lastPathComponent!.uppercaseString.containsString("spec".uppercaseString) || $0.lastPathComponent!.uppercaseString.containsString("test".uppercaseString) || $0.lastPathComponent!.uppercaseString.containsString("mock".uppercaseString) {
            print("Skipping file: \($0.lastPathComponent!)")
            skippedFiles.append($0.lastPathComponent!)
            return false
        }
        return true
    }
    let rawContent = transformFiles(validURLs)
    
    let matches = rawContent.enumerate().map { Finder.findString(regex(validURLs[$0].pathExtension!), inText: $1, ignorePrefixes: ignorePrefixes(validURLs[$0].pathExtension!)) }
    
    let count = CountDown((matches.flatMap {$0}).count)
    
    for (index, matchSet) in matches.enumerate() {
        let url = validURLs[index]
        reviewMatches(matchSet, inFile: url, countDown: count.countDown) { (updated: Bool, contents: String, replacements: Int) in
            if updated { write(contents, url.path!) }
            output.log("\(replacements) string replacements made in \(url.lastPathComponent!)")
        }
    }
    
    //Create output Log
    var skippedFileString = "Skipped Files:\n"
    for path in skippedFiles {
        skippedFileString = skippedFileString + "\(path)\n"
    }
    
    output.write()
    exit(EXIT_SUCCESS)
}

func reviewMatches(matches: [RegexMatch], inFile file: NSURL, countDown: () -> Void, completion: (Bool, String, Int) -> Void) {
    var result: NSString = ""
    do {
        result = try String(contentsOfURL: file) as NSString
    } catch {
        print(error)
        completion(false, "", 0)
        return
    }
    
    func replacementTextForFileType(fileExtension: String) -> String {
        if fileExtension == "m" || fileExtension == "h" { return "NSLocalizedStringWithDefaultValue(@\"\", nil, [NSBundle mainBundle], " }
        else if fileExtension == "swift" { return "NSLocalizedString(\"\", tableName: nil, bundle: NSBundle.mainBundle(), value: " }
        else { return "" }
    }
    
    var replacements = Array<(NSRange, String)>()
    let _ = matches.map {
        countDown()
        print("Found occurrence of string in \(file)")
        print($0.context + $0.value)
        print("Add Flag? (y/n)")
        if ok() {
            let range = $0.textCheckingResult.range
            let replacementText = replacementTextForFileType(file.pathExtension!) + ($0.value as String)
            let replacement = (range, replacementText)
            replacements.append(replacement)
        }
        $0.context
    }
    for (range, replacementText) in Array(replacements.reverse()) {
        result = result.stringByReplacingCharactersInRange(range, withString: replacementText)
    }
    completion(true, result as String, replacements.count)
}

func ok() -> Bool {
    let response = readLine(stripNewline: true)
    if response == "exit" || response == ":q" {
        exit(EXIT_FAILURE)
    }
    if response == "y" { return true }
    else if response == "n" { return false }
    else { return ok() }
}

func transformFiles(URLs: [NSURL]) -> [String] {
    let rawContent = URLs.map { try? String(contentsOfURL: $0) }.map {$0 ?? ""}
    return rawContent
}

func write(output: String, _ path: String) {
    do {
        try output.writeToFile(path, atomically: true, encoding: NSUTF8StringEncoding)
    } catch {
        //failed to write file - bad permissions, bad filename, missing permissions, or more likely it cannot be converted to the encoding
        print(error)
    }
}

if Process.arguments.count > 1 {
    exit(EXIT_FAILURE)
} else {
    main()
    exit(EXIT_SUCCESS)
}
