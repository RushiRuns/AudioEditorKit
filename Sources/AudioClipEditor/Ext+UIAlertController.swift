//
//  Ext+UIAlertController.swift
//  AudioEditorKit
//
//  Created by 秋星桥 on 5/1/25.
//

import UIKit

extension UIAlertController {
    func addAction(title: String, style: UIAlertAction.Style, handler: ((UIAlertAction) -> Void)? = nil) {
        let action = UIAlertAction(title: title, style: style, handler: handler)
        addAction(action)
    }
}
