//
//  UncrustifyCommand.swift
//  Uncrustify
//
//  Created by B. Kevin Hardman on 9/20/17.
//  Copyright © 2017 B. Kevin Hardman. All rights reserved.
//

import Foundation
import XcodeKit

enum SIGError: Swift.Error {
	case unsupportedLanguage
	case noSelection
	case invalidSelection
	case parseError
}

extension String {
	func strings(terminatedBy inSeparator: CharacterSet) -> [String] {
		var array : [String] = []
		var searchRange = startIndex..<endIndex
		while let range = rangeOfCharacter(from: inSeparator, options: [], range: searchRange) {
			array.append(String(self[searchRange.lowerBound..<range.upperBound]))
			searchRange = range.upperBound..<endIndex
		}
		return array
	}
}

class UncrustifyCommand: NSObject, XCSourceEditorCommand {
	var commandPath: String {
		return Bundle.main.path(forResource: "uncrustify", ofType: nil)!
	}

	var configPath: String {
		return Bundle.main.path(forResource: "source", ofType: "cfg")!
	}

	static func run(_ commandPath: String, arguments: [String], stdin: String) -> String? {
		let errorPipe = Pipe()
		let outputPipe = Pipe()

		let task = Process()
		task.standardError = errorPipe
		task.standardOutput = outputPipe
		task.launchPath = commandPath
		task.arguments = arguments

		let inputPipe = Pipe()
		task.standardInput = inputPipe
		let stdinHandle = inputPipe.fileHandleForWriting

		if let data = stdin.data(using: .utf8) {
			stdinHandle.write(data)
			stdinHandle.closeFile()
		}

		task.launch()
		task.waitUntilExit()

		errorPipe.fileHandleForReading.readDataToEndOfFile()

		let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
		return String(data: outputData, encoding: .utf8)
	}

	func sourceFormat(with invocation: XCSourceEditorCommandInvocation) -> String? {
		switch invocation.buffer.contentUTI as CFString {
		case kUTTypeCSource:
			return "C"
		case kUTTypeObjectiveCSource:
			return "OC"
		case kUTTypeCPlusPlusSource:
			return "CPP"
		case kUTTypeObjectiveCPlusPlusSource:
			return "OC+"
		default:
			return nil
		}
	}

	func sourceRange(range inRange: XCSourceTextRange) -> CountableClosedRange<NSInteger> {
		if inRange.end.column == 0 {
			return inRange.start.line...inRange.end.line - 1
		}
		return inRange.start.line...inRange.end.line
	}

	func sourceText(with invocation: XCSourceEditorCommandInvocation, range inRange: CountableClosedRange<NSInteger>) -> String? {
		var source = ""
		for index in inRange {
			source += invocation.buffer.lines[index] as! String
		}
		return source
	}

	func uncrustify(format inFormat: String, source inSource: String, additionalArguments inArguments: [String] = []) -> String? {
		return UncrustifyCommand.run(commandPath,
		                               arguments: [ "-c", configPath, "-L", "2", "-l", inFormat ] + inArguments,
		                               stdin: inSource)
	}

	func uncrustifyFragment(with invocation: XCSourceEditorCommandInvocation, format inFormat: String) -> SIGError? {
		for index in 0..<invocation.buffer.selections.count {
			let range = sourceRange(range: invocation.buffer.selections[index] as! XCSourceTextRange)

			guard let source = sourceText(with: invocation, range:range) as String? else {
				return SIGError.invalidSelection
			}

			guard let output = uncrustify(format: inFormat, source: source, additionalArguments:["--frag"]) as String? else {
				return SIGError.parseError
			}

			let lines = output.strings(terminatedBy: NSCharacterSet.newlines)

			invocation.buffer.lines.replaceObjects(in: NSMakeRange(range.lowerBound, range.count), withObjectsFrom: lines)

			invocation.buffer.selections.replaceObject(at: index,
			                                           with: XCSourceTextRange(start: XCSourceTextPosition(line: range.lowerBound, column: 0),
			                                                                   end: XCSourceTextPosition(line: range.lowerBound + lines.count, column: 0)))
		}
		return nil
	}

	func uncrustifySelection(with invocation: XCSourceEditorCommandInvocation, format inFormat: String) -> SIGError? {
		for index in 0..<invocation.buffer.selections.count {
			let range = sourceRange(range: invocation.buffer.selections[index] as! XCSourceTextRange)

			guard let source = sourceText(with: invocation, range:range) as String? else {
				return SIGError.invalidSelection
			}

			guard let output = uncrustify(format: inFormat, source: source) as String? else {
				return SIGError.parseError
			}

			let lines = output.strings(terminatedBy: NSCharacterSet.newlines)

			invocation.buffer.lines.replaceObjects(in: NSMakeRange(range.lowerBound, range.count), withObjectsFrom: lines)

			invocation.buffer.selections.replaceObject(at: index,
			                                           with: XCSourceTextRange(start: XCSourceTextPosition(line: range.lowerBound, column: 0),
			                                                                   end: XCSourceTextPosition(line: range.lowerBound + lines.count, column: 0)))
		}
		return nil
	}

	func uncrustifySource(with invocation: XCSourceEditorCommandInvocation, format inFormat: String) -> SIGError? {
		guard let source = invocation.buffer.completeBuffer as String? else {
			return SIGError.invalidSelection
		}

		guard let output = uncrustify(format: inFormat, source: source) as String? else {
			return SIGError.parseError
		}

		let lines = output.strings(terminatedBy: NSCharacterSet.newlines)

		invocation.buffer.lines.removeAllObjects()
		invocation.buffer.lines.addObjects(from: lines)

		// If there is a no longer valid selection, Xcode crashes
		invocation.buffer.selections.removeAllObjects()
		// and it does the same if there aren't any selections, so we set the insertion point
		invocation.buffer.selections.add(XCSourceTextRange(start: XCSourceTextPosition(line: 0, column: 0),
		                                                   end: XCSourceTextPosition(line: 0, column: 0)))
		return nil;
	}

    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        // Implement your command here, invoking the completion handler when done. Pass it nil on success, and an NSError on failure.
		guard let format = sourceFormat(with: invocation) as String? else {
			return completionHandler(SIGError.unsupportedLanguage)
		}

		switch invocation.commandIdentifier {
		case "com.harddays.XcodeSEE.Uncrustify.UncrustifyCommand.fragment":
			return completionHandler(uncrustifyFragment(with: invocation, format: format))
		case "com.harddays.XcodeSEE.Uncrustify.UncrustifyCommand.selection":
			return completionHandler(uncrustifySelection(with: invocation, format: format))
		case "com.harddays.XcodeSEE.Uncrustify.UncrustifyCommand.source":
			return completionHandler(uncrustifySource(with: invocation, format: format))
		default:
			completionHandler(nil)
		}
    }

}

//if let outputString = UncrustifyCommand.run(commandPath,
//                                              arguments: [ "-c", configPath, "-L", "2", "-l", "OC+" ],
//                                              stdin: invocation.buffer.completeBuffer),
//
//	invocation.buffer.contentUTI == "public.objective-c-source" {
//	invocation.buffer.lines.removeAllObjects()
//
//	let lines = outputString.characters.split(separator: "\n").map { String($0) }
//	invocation.buffer.lines.addObjects(from: lines)
//
//	// Crashes Xcode when replacing `completeBuffer`
//	//invocation.buffer.completeBuffer = outputString
//	// If there is a no longer valid selection, Xcode crashes
//	invocation.buffer.selections.removeAllObjects()
//	// and it does the same if there aren't any selections, so we set the insertion point
//	invocation.buffer.selections.add(XCSourceTextRange(start: XCSourceTextPosition(line: 0, column: 0),
//	                                                   end: XCSourceTextPosition(line: 0, column: 0)))
//}

//-l           : Language override: C, CPP, D, CS, JAVA, PAWN, OC, OC+, VALA.
//--frag       : Code fragment, assume the first line is indented correctly.

//#!/usr/bin/perl
//
//my $filetype = "OC+";
//my $config = "~/.uncrustify/source.cfg";
//my $debug = "";
//#$debug = "-p ~/x";
//my $logging = "-L 2";
//#$logging = "-L 66"; # LSPACE
//#$logging = "-L 24"; # LINDPC
//
//open(UNCRUSTIFY, "|~/Documents/Unix/bin/uncrustify -c $config $logging -l $filetype $debug");
//print UNCRUSTIFY do {local $/; <STDIN>};
//close(UNCRUSTIFY);
//print "\n";
