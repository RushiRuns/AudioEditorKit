//
//  TimeInterval+Duration.swift
//  TRApp
//
//  Created by Rachel on 12/20/24.
//

import Foundation

private let _preciseDurationTimeZone = TimeZone(secondsFromGMT: 0)
private let _preciseDurationLocale = Locale(identifier: "en_US_POSIX")
private let _preciseDurationFormatterCache: [String: DateFormatter] = [
    "HH:mm:ss": {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = _preciseDurationTimeZone
        formatter.locale = _preciseDurationLocale
        return formatter
    }(),
    "HH:mm:ss.SS": {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SS"
        formatter.timeZone = _preciseDurationTimeZone
        formatter.locale = _preciseDurationLocale
        return formatter
    }(),
    "mm:ss": {
        let formatter = DateFormatter()
        formatter.dateFormat = "mm:ss"
        formatter.timeZone = _preciseDurationTimeZone
        formatter.locale = _preciseDurationLocale
        return formatter
    }(),
    "mm:ss.SS": {
        let formatter = DateFormatter()
        formatter.dateFormat = "mm:ss.SS"
        formatter.timeZone = _preciseDurationTimeZone
        formatter.locale = _preciseDurationLocale
        return formatter
    }(),
]

public extension TimeInterval {
    func preciseDurationString(
        includingMilliseconds: Bool = false
    ) -> String {
        if #available(iOS 16.0, *) {
            return Duration.seconds(self)
                .formatted(.time(
                    pattern: self >= 3600
                        ? .hourMinuteSecond(
                            padHourToLength: 2,
                            fractionalSecondsLength: includingMilliseconds ? 2 : 0
                        ) : .minuteSecond(
                            padMinuteToLength: 2,
                            fractionalSecondsLength: includingMilliseconds ? 2 : 0
                        )
                ))
        } else {
            let dateFormat = self >= 3600
                ? "HH:mm:ss\(includingMilliseconds ? ".SS" : "")"
                : "mm:ss\(includingMilliseconds ? ".SS" : "")"
            let dateFormatter = _preciseDurationFormatterCache[dateFormat]!
            return dateFormatter.string(from: Date(timeIntervalSinceReferenceDate: self))
        }
    }
}
