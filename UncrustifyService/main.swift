//
//  main.swift
//  UncrustifyService
//
//  Created by B. Kevin Hardman on 9/22/17.
//  Copyright © 2017 B. Kevin Hardman. All rights reserved.
//

import Foundation

class ServiceDelegate : NSObject, NSXPCListenerDelegate {
	func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
		newConnection.exportedInterface = NSXPCInterface(with: UncrustifyServiceProtocol.self)
		let exportedObject = UncrustifyService()
		newConnection.exportedObject = exportedObject
		newConnection.resume()
		return true
	}
}

// Create the listener and resume it:
let delegate = ServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate;
listener.resume()
