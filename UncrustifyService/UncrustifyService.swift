//
//  UncrustifyService.swift
//  UncrustifyService
//
//  Created by B. Kevin Hardman on 9/22/17.
//  Copyright © 2017 B. Kevin Hardman. All rights reserved.
//

import Foundation

@objc class UncrustifyService: NSObject, UncrustifyServiceProtocol {

	var usersCommandURL: URL? {
		let sharedDefaults = UserDefaults(suiteName: "9K27VUYL9J.com.harddays.XcodeSEE")
		if let toolpath = sharedDefaults?.data(forKey: "toolpath") {
			var stale : Bool = false
			if let url = try? URL(resolvingBookmarkData: toolpath, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) {
				return url
			}
		}
//		return Bundle.main.url(forResource: "uncrustify", withExtension: nil)
		return URL(fileURLWithPath: "/Users/kevin/Documents/Unix/bin/uncrustify")
	}

	var userConfigURL: URL? {
		let sharedDefaults = UserDefaults(suiteName: "9K27VUYL9J.com.harddays.XcodeSEE")
		if let configpath = sharedDefaults?.data(forKey: "configpath") {
			var stale : Bool = false
			if let url = try? URL(resolvingBookmarkData: configpath, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) {
				return url
			}
		}
//		return Bundle.main.url(forResource: "source", withExtension: "cfg")
		return URL(fileURLWithPath: "/Users/kevin/.uncrustify/source.cfg")
	}

	func sourceFormat(withType: String) -> String? {
		//-l           : Language override: C, CPP, D, CS, JAVA, PAWN, OC, OC+, VALA.
		let type = withType as CFString
		if (UTTypeConformsTo(type, kUTTypeObjectiveCSource)) {
			return "OC"
		}
		if (UTTypeConformsTo(type, kUTTypeCPlusPlusSource)) {
			return "CPP"
		}
		if (UTTypeConformsTo(type, kUTTypeObjectiveCPlusPlusSource)) {
			return "OC+"
		}
		if (UTTypeConformsTo(type, kUTTypeCPlusPlusHeader)) {
			let sharedDefaults = UserDefaults(suiteName: "9K27VUYL9J.com.harddays.XcodeSEE")
			if sharedDefaults!.bool(forKey: "always_objective-cpp") {
				return "OC+"
			}
			return "CPP"
		}
		if (UTTypeConformsTo(type, kUTTypeCHeader)) {
			let sharedDefaults = UserDefaults(suiteName: "9K27VUYL9J.com.harddays.XcodeSEE")
			if sharedDefaults!.bool(forKey: "always_cpp") {
				if sharedDefaults!.bool(forKey: "always_objective-cpp") {
					return "OC+"
				}
				return "CPP"
			}
		}
		return "C"
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

	func uncrustify(withType inType: String, source inSource: String, additionalArguments inArguments: [String], withReply: (String?)->()) {
		guard let commandURL = usersCommandURL else {
			return withReply(nil)
		}
		guard let configURL = userConfigURL else {
			return withReply(nil)
		}
		guard let type = sourceFormat(withType: inType) else {
			return withReply(nil)
		}
		return withReply(UncrustifyService.run(commandURL.path,
		                                       arguments: [ "-c", configURL.path, "-L", "2", "-l", type ] + inArguments,
		                                       stdin: inSource))
	}

}
