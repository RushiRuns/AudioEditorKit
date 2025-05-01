//
//  View+HitTest.swift
//  TRApp
//
//  Created by 82Flex on 2024/11/17.
//

import UIKit

public class HitTestView: UIView {
    override public func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
        bounds.insetBy(dx: -20, dy: -20).contains(point)
    }
}

public class HitTestButton: UIButton {
    override public func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
        bounds.insetBy(dx: -20, dy: -20).contains(point)
    }
}

public class HitTestLabel: UILabel {
    override public func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
        bounds.insetBy(dx: -20, dy: -20).contains(point)
    }
}

public class HitTestStackView: UIStackView {
    override public func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
        bounds.insetBy(dx: -20, dy: -20).contains(point)
    }
}
