//
//  QoSClass+TaskPriority.swift
//  DSWaveformImage
//
//  Created by 82Flex on 2025/1/1.
//

import Foundation

public extension DispatchQoS.QoSClass {
    var taskPriority: TaskPriority {
        switch self {
        case .background: return .background
        case .utility: return .utility
        case .default: return .medium
        case .userInitiated: return .userInitiated
        case .userInteractive: return .high
        case .unspecified: return .medium
        @unknown default: return .medium
        }
    }
}
