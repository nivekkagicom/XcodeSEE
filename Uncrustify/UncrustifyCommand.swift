//
//  UncrustifyCommand.swift
//  Uncrustify
//
//  Created by B. Kevin Hardman on 9/20/17.
//  Copyright © 2017 B. Kevin Hardman. All rights reserved.
//

import Foundation
import XcodeKit

enum UncrustifyError: Swift.Error {
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

	lazy var connection: NSXPCConnection = {
		let connection = NSXPCConnection(serviceName: "com.harddays.XcodeSEE.UncrustifyService")
		connection.remoteObjectInterface = NSXPCInterface(with: UncrustifyServiceProtocol.self)
		connection.resume()
		return connection
	}()

	var usersCommandURL: URL? {
		let sharedDefaults = UserDefaults(suiteName: "9K27VUYL9J.com.harddays.XcodeSEE")
		if let toolpath = sharedDefaults?.data(forKey: "toolpath") {
			var stale : Bool = false
			if let url = try? URL(resolvingBookmarkData: toolpath, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) {
				return url
			}
		}
		return Bundle.main.url(forResource: "uncrustify", withExtension: nil)
	}

	var userConfigURL: URL? {
		let sharedDefaults = UserDefaults(suiteName: "9K27VUYL9J.com.harddays.XcodeSEE")
		if let configpath = sharedDefaults?.data(forKey: "configpath") {
			var stale : Bool = false
			if let url = try? URL(resolvingBookmarkData: configpath, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) {
				return url
			}
		}
		return Bundle.main.url(forResource: "source", withExtension: "cfg")
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

	func uncrustify(withType inType: String, source inSource: String, additionalArguments inArguments: [String] = []) -> String? {
		let downloadGroup = DispatchGroup()
		downloadGroup.enter()

		let handler: (Error) -> () = { error in
			print("remote proxy error: \(error)")
			downloadGroup.leave()
		}
		var output: String? = nil
		let service = connection.remoteObjectProxyWithErrorHandler(handler) as! UncrustifyServiceProtocol
		service.uncrustify(withType: inType, source: inSource, additionalArguments: inArguments) { (inOutput) in
			output = inOutput
			downloadGroup.leave()
		}
		downloadGroup.wait()

		return output
	}

	func uncrustifyFragment(with invocation: XCSourceEditorCommandInvocation) -> UncrustifyError? {
		for index in 0..<invocation.buffer.selections.count {
			let range = sourceRange(range: invocation.buffer.selections[index] as! XCSourceTextRange)

			guard let source = sourceText(with: invocation, range:range) as String? else {
				return UncrustifyError.invalidSelection
			}

			guard let output = uncrustify(withType: invocation.buffer.contentUTI, source: source, additionalArguments:["--frag"]) as String? else {
				return UncrustifyError.parseError
			}

			let lines = output.strings(terminatedBy: NSCharacterSet.newlines)

			invocation.buffer.lines.replaceObjects(in: NSMakeRange(range.lowerBound, range.count), withObjectsFrom: lines)

			invocation.buffer.selections.replaceObject(at: index,
			                                           with: XCSourceTextRange(start: XCSourceTextPosition(line: range.lowerBound, column: 0),
			                                                                   end: XCSourceTextPosition(line: range.lowerBound + lines.count, column: 0)))
		}
		return nil
	}

	func uncrustifyFunction(with invocation: XCSourceEditorCommandInvocation) -> UncrustifyError? {
		for index in 0..<invocation.buffer.selections.count {
			let range = sourceRange(range: invocation.buffer.selections[index] as! XCSourceTextRange)

			guard let source = "#pragma fake\n" + sourceText(with: invocation, range:range)! as String? else {
				return UncrustifyError.invalidSelection
			}

			guard let output = uncrustify(withType: invocation.buffer.contentUTI, source: source, additionalArguments: []) else {
				return UncrustifyError.parseError
			}

			let lines = Array(output.strings(terminatedBy: NSCharacterSet.newlines)[1...])

			invocation.buffer.lines.replaceObjects(in: NSMakeRange(range.lowerBound, range.count), withObjectsFrom: lines)

			invocation.buffer.selections.replaceObject(at: index,
													   with: XCSourceTextRange(start: XCSourceTextPosition(line: range.lowerBound, column: 0),
																			   end: XCSourceTextPosition(line: range.lowerBound + lines.count, column: 0)))
		}
		return nil
	}

	func uncrustifySelection(with invocation: XCSourceEditorCommandInvocation) -> UncrustifyError? {
		for index in 0..<invocation.buffer.selections.count {
			let range = sourceRange(range: invocation.buffer.selections[index] as! XCSourceTextRange)

			guard let source = sourceText(with: invocation, range:range) as String? else {
				return UncrustifyError.invalidSelection
			}

			guard let output = uncrustify(withType: invocation.buffer.contentUTI, source: source, additionalArguments: []) else {
				return UncrustifyError.parseError
			}

			let lines = output.strings(terminatedBy: NSCharacterSet.newlines)

			invocation.buffer.lines.replaceObjects(in: NSMakeRange(range.lowerBound, range.count), withObjectsFrom: lines)

			invocation.buffer.selections.replaceObject(at: index,
			                                           with: XCSourceTextRange(start: XCSourceTextPosition(line: range.lowerBound, column: 0),
			                                                                   end: XCSourceTextPosition(line: range.lowerBound + lines.count, column: 0)))
		}
		return nil
	}

	func uncrustifySource(with invocation: XCSourceEditorCommandInvocation) -> UncrustifyError? {
		guard let source = invocation.buffer.completeBuffer as String? else {
			return UncrustifyError.invalidSelection
		}

		guard let output = uncrustify(withType: invocation.buffer.contentUTI, source: source) as String? else {
			return UncrustifyError.parseError
		}

		let lines = output.strings(terminatedBy: NSCharacterSet.newlines)

		invocation.buffer.lines.removeAllObjects()
		invocation.buffer.lines.addObjects(from: lines)

		// If there is a no longer valid selection, Xcode crashes
		invocation.buffer.selections.removeAllObjects()
		// and it does the same if there aren't any selections, so we set the insertion point
		invocation.buffer.selections.add(XCSourceTextRange(start: XCSourceTextPosition(line: 0, column: 0),
		                                                   end: XCSourceTextPosition(line: 0, column: 0)))
		return nil
	}

    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        // Implement your command here, invoking the completion handler when done. Pass it nil on success, and an NSError on failure.
		switch invocation.commandIdentifier {
		case "com.harddays.XcodeSEE.Uncrustify.fragment":
			return completionHandler(uncrustifyFragment(with: invocation))
		case "com.harddays.XcodeSEE.Uncrustify.function":
			return completionHandler(uncrustifyFunction(with: invocation));
		case "com.harddays.XcodeSEE.Uncrustify.selection":
			return completionHandler(uncrustifySelection(with: invocation))
		case "com.harddays.XcodeSEE.Uncrustify.source":
			return completionHandler(uncrustifySource(with: invocation))
		default:
			completionHandler(nil)
		}
    }

}

