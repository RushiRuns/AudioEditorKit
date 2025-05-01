//
//  AudioClipContext+Error.swift
//  AudioClipUtility
//
//  Created by 82Flex on 2024/12/20.
//

import Foundation

public extension AudioClipContext {
    enum Error: LocalizedError {
        case diskSpaceExhausted(requiredSpaceInBytes: Int64, availableSpaceInBytes: Int64)
        case invalidRange(start: TimeInterval, end: TimeInterval)

        public var errorDescription: String? {
            switch self {
            case let .diskSpaceExhausted(requiredSpaceInBytes, availableSpaceInBytes):
                let arg1 = AudioClipContext.fileSizeFormatter.string(fromByteCount: requiredSpaceInBytes - availableSpaceInBytes)
                let arg2 = AudioClipContext.fileSizeFormatter.string(fromByteCount: availableSpaceInBytes)
                return String(localized: "Another \(arg1) is required to continue editing. Available capacity is \(arg2).", bundle: .module)
            case let .invalidRange(start, end):
                return String(localized: "Specified range from \(start) to \(end) is invalid.", bundle: .module)
            }
        }
    }

    func checkDiskSpace(requiredSpaceInBytes: Int64) throws {
        let availableSpaceInBytes = Self.availableCapacityForOpportunisticUsage
        guard availableSpaceInBytes >= requiredSpaceInBytes else {
            throw Error.diskSpaceExhausted(
                requiredSpaceInBytes: requiredSpaceInBytes,
                availableSpaceInBytes: availableSpaceInBytes
            )
        }
    }

    private static let fileSizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    private static var availableCapacityForOpportunisticUsage: Int64 {
        guard let values = try? libraryDirectory.resourceValues(
            forKeys: [.volumeAvailableCapacityForOpportunisticUsageKey]
        ) else { return 0 }
        return values.volumeAvailableCapacityForOpportunisticUsage ?? 0
    }
}
