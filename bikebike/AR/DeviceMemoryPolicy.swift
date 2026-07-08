//
//  DeviceMemoryPolicy.swift
//  bikebike
//

import UIKit

enum DeviceMemoryPolicy {
    static var isConstrained: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
}
