//
//  ViewController.swift
//  XcodeSEE
//
//  Created by B. Kevin Hardman on 9/20/17.
//  Copyright © 2017 B. Kevin Hardman. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

	lazy var connection: NSXPCConnection = {
		let connection = NSXPCConnection(serviceName: "com.harddays.XcodeSEE.UncrustifyService")
		connection.remoteObjectInterface = NSXPCInterface(with: UncrustifyServiceProtocol.self)
		connection.resume()
		return connection
	}()

	@objc dynamic var code : String?

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
				guard let data = try? url?.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess ], includingResourceValuesForKeys: [], relativeTo: nil) else {
					return url;
				}
				sharedDefaults?.set(data, forKey: "configpath")
			}
			return url
		}
		set {
			guard let data = try? newValue?.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess ], includingResourceValuesForKeys: [], relativeTo: nil) else {
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
				guard let data = try? url?.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess ], includingResourceValuesForKeys: [], relativeTo: nil) else {
					return url;
				}
				sharedDefaults?.set(data, forKey: "toolpath")
			}
			return url
		}
		set {
			guard let data = try? newValue?.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess ], includingResourceValuesForKeys: [], relativeTo: nil) else {
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
		let service = connection.remoteObjectProxyWithErrorHandler(handler) as! UncrustifyServiceProtocol
		service.uncrustify(withType: kUTTypeObjectiveCSource as String, source: source, additionalArguments: []) { [weak self] (output) in
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

