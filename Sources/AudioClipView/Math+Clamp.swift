//
//  Math+Clamp.swift
//  TRApp
//
//  Created by Rachel on 26/12/2024.
//

import Foundation

public func clamp<T>(_ value: T, to range: ClosedRange<T>) -> T {
    min(max(value, range.lowerBound), range.upperBound)
}
