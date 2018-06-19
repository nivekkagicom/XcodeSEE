//
//  UncrustifyServiceProtocol.swift
//  UncrustifyService
//
//  Created by B. Kevin Hardman on 9/22/17.
//  Copyright © 2017 B. Kevin Hardman. All rights reserved.
//

import Foundation

@objc protocol UncrustifyServiceProtocol {
	func uncrustify(withType inType: String, source inSource: String, additionalArguments inArguments: [String], withReply: @escaping (String?)->())
}
