//
//  ViewController.swift
//  XcodeSEE
//
//  Created by B. Kevin Hardman on 9/20/17.
//  Copyright © 2017 B. Kevin Hardman. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
	enum Format: UInt {
		case objective_cpp = 0, objective_c, cpp, c, hpp, h
	}

	lazy var connection: NSXPCConnection = {
		let connection = NSXPCConnection(serviceName: "com.harddays.XcodeSEE.UncrustifyService")
		connection.remoteObjectInterface = NSXPCInterface(with: UncrustifyServiceProtocol.self)
		connection.resume()
		return connection
	}()

	@objc dynamic var code : String?

	@objc dynamic var format : UInt {
		get {
			let sharedDefaults = UserDefaults(suiteName: "9K27VUYL9J.com.harddays.XcodeSEE")
			guard let format = sharedDefaults?.integer(forKey: "format") else {
				return 0
			}
			return UInt(format)
		}
		set {
			let sharedDefaults = UserDefaults(suiteName: "9K27VUYL9J.com.harddays.XcodeSEE")
			sharedDefaults?.set(newValue, forKey: "format")
		}
	}

	@objc dynamic var cpp : Bool {
		get {
			let sharedDefaults = UserDefaults(suiteName: "9K27VUYL9J.com.harddays.XcodeSEE")
			guard let alwayscpp = sharedDefaults?.bool(forKey: "always_cpp") else {
				return false
			}
			return alwayscpp
		}
		set {
			let sharedDefaults = UserDefaults(suiteName: "9K27VUYL9J.com.harddays.XcodeSEE")
			sharedDefaults?.set(newValue, forKey: "always_cpp")
		}
	}

	@objc dynamic var ocpp : Bool {
		get {
			let sharedDefaults = UserDefaults(suiteName: "9K27VUYL9J.com.harddays.XcodeSEE")
			guard let alwaysocpp = sharedDefaults?.bool(forKey: "always_objective-cpp") else {
				return false
			}
			return alwaysocpp;
		}
		set {
			let sharedDefaults = UserDefaults(suiteName: "9K27VUYL9J.com.harddays.XcodeSEE")
			sharedDefaults?.set(newValue, forKey: "always_objective-cpp")
		}
	}

	@objc dynamic var config : URL? {
		get {
			let sharedDefaults = UserDefaults(suiteName: "9K27VUYL9J.com.harddays.XcodeSEE")
			guard let toolpath = sharedDefaults?.data(forKey: "configpath") else {
				return nil
			}
			var stale : Bool = false
			guard let url = try? URL(resolvingBookmarkData: toolpath, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) else {
				return nil
			}
			if stale {
				guard let data = try? url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess ], includingResourceValuesForKeys: [], relativeTo: nil) else {
					return url;
				}
				sharedDefaults?.set(data, forKey: "configpath")
			}
			return url
		}
		set {
			guard let data = ((try? newValue?.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess ], includingResourceValuesForKeys: [], relativeTo: nil)) as Data??) else {
				return;
			}
			let sharedDefaults = UserDefaults(suiteName: "9K27VUYL9J.com.harddays.XcodeSEE")
			sharedDefaults?.set(data, forKey: "configpath")
		}
	}

	@objc dynamic var tool : URL? {
		get {
			let sharedDefaults = UserDefaults(suiteName: "9K27VUYL9J.com.harddays.XcodeSEE")
			guard let toolpath = sharedDefaults?.data(forKey: "toolpath") else {
				return nil
			}
			var stale : Bool = false
			guard let url = try? URL(resolvingBookmarkData: toolpath, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) else {
				return nil
			}
			if stale {
				guard let data = try? url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess ], includingResourceValuesForKeys: [], relativeTo: nil) else {
					return url;
				}
				sharedDefaults?.set(data, forKey: "toolpath")
			}
			return url
		}
		set {
			guard let data = ((try? newValue?.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess ], includingResourceValuesForKeys: [], relativeTo: nil)) as Data??) else {
				return;
			}
			let sharedDefaults = UserDefaults(suiteName: "9K27VUYL9J.com.harddays.XcodeSEE")
			sharedDefaults?.set(data, forKey: "toolpath")
		}
	}

	@IBAction func chooseConfigPath(sender: NSPathControl) {
		guard let window = self.view.window else {
			return
		}
		let openPanel = NSOpenPanel()
		openPanel.allowsMultipleSelection = false
		openPanel.canChooseDirectories = false
		openPanel.canChooseFiles = true
		openPanel.canCreateDirectories = false
		openPanel.directoryURL = config
		openPanel.showsHiddenFiles = true
		openPanel.title = "Choose config files:"
		openPanel.beginSheetModal(for: window) { [weak self] (inResponse) in
			guard inResponse == .OK else {
				return;
			}
			guard let url = openPanel.url else {
				return;
			}
			if url.startAccessingSecurityScopedResource() {
				self?.config = url
				url.stopAccessingSecurityScopedResource()
			}
		}
	}

	@IBAction func chooseToolPath(sender: NSPathControl) {
		guard let window = self.view.window else {
			return
		}
		let openPanel = NSOpenPanel()
		openPanel.allowsMultipleSelection = false
		openPanel.canChooseDirectories = false
		openPanel.canChooseFiles = true
		openPanel.canCreateDirectories = false
		openPanel.directoryURL = tool
		openPanel.showsHiddenFiles = true
		openPanel.title = "Choose uncrustify tool:"
		openPanel.beginSheetModal(for: window) { [weak self] (inResponse) in
			guard inResponse == .OK else {
				return;
			}
			guard let url = openPanel.url else {
				return;
			}
			if url.startAccessingSecurityScopedResource() {
				self?.tool = url
				url.stopAccessingSecurityScopedResource()
			}
		}
	}

	@IBAction func openPath(sender: NSPathControl) {
		guard let url = sender.url else {
			return
		}
		NSWorkspace().open(url)
	}

	@IBAction func sample(sender: NSButton) {
		code = "if (foo) { close(bar); } else { open(bar); }"
	}

	@IBAction func test(sender: NSButton) {
		guard let source = code else {
			return
		}
		let handler: (Error) -> () = { error in
			print("remote proxy error: \(error)")
		}
		var type = kUTTypeObjectiveCSource
		if let format = Format(rawValue: self.format) {
			switch (format) {
			case .objective_cpp:
				type = kUTTypeObjectiveCPlusPlusSource
			case .objective_c:
				type = kUTTypeObjectiveCSource
			case .cpp:
				type = kUTTypeCPlusPlusSource
			case .c:
				type = kUTTypeCSource
			case .hpp:
				type = kUTTypeCPlusPlusHeader
			case .h:
				type = kUTTypeCHeader
			}
		}
		let service = connection.remoteObjectProxyWithErrorHandler(handler) as! UncrustifyServiceProtocol
		service.uncrustify(withType: type as String, source: source, additionalArguments: []) { [weak self] (output) in
			OperationQueue.main.addOperation({
				self?.code = output
			})
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		// Do any additional setup after loading the view.
	}

	override var representedObject: Any? {
		didSet {
		// Update the view, if already loaded.
		}
	}

}

