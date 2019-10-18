//
//  CaptureView.swift
//  IsCute
//
//  Created by Jaakko Kangasharju on 15.10.19.
//  Copyright © 2019 Jaakko Kangasharju. All rights reserved.
//

import UIKit

// This view draws a square around the capture area and, when the app is classifying the image
// or showing results, it displays the picture that is being classified.
class CaptureView: UIView {

    private let lineWidth: CGFloat = 10.0
    private var image: UIImage? = nil

    var imageFrame: CGRect {
        return self.frame.insetBy(dx: lineWidth, dy: lineWidth)
    }

    // Override the draw() function since line drawing is easier with a graphics context
    override func draw(_ rect: CGRect) {
        if let context = UIGraphicsGetCurrentContext() {
            context.setStrokeColor(UIColor.red.cgColor)
            context.setLineWidth(lineWidth)
            context.addRect(CGRect(x: lineWidth / 2, y: lineWidth / 2, width: self.bounds.width - lineWidth, height: self.bounds.height - lineWidth))
            context.strokePath()
            if let image = image {
                image.draw(in: self.bounds.insetBy(dx: lineWidth, dy: lineWidth))
            }
        }
    }

    func freezeImage(_ image: UIImage) {
        self.image = image
        setNeedsDisplay()
    }

    func releaseImage() {
        self.image = nil
        setNeedsDisplay()
    }
}
