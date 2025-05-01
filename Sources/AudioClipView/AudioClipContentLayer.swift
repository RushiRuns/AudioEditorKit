//
//  AudioClipContentLayer.swift
//  TRApp
//
//  Created by 82Flex on 2025/1/4.
//

import CoreFoundation
import QuartzCore

public final class AudioClipContentLayer: CATiledLayer {
    override public class func fadeDuration() -> CFTimeInterval {
        0.15
    }
}
