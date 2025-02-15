//
//  UIColor+Extension.swift
//  KommunicateChatUI-iOS-SDK
//
//  Created by Mukesh Thawani on 04/05/17.
//

import Foundation

import UIKit

public extension UIColor {
    convenience init(hexString: String, alpha: CGFloat = 1.0) {
        let hexString: String = hexString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let scanner = Scanner(string: hexString)
        if hexString.hasPrefix("#") {
            scanner.scanLocation = 1
        }
        var color: UInt32 = 0
        scanner.scanHexInt32(&color)
        let mask = 0x0000_00FF
        let r = Int(color >> 16) & mask
        let g = Int(color >> 8) & mask
        let b = Int(color) & mask
        let red = CGFloat(r) / 255.0
        let green = CGFloat(g) / 255.0
        let blue = CGFloat(b) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    // 0xAARRGGBB
    static func hex8(_ netHex: Int64) -> UIColor {
        let shiftedRed = netHex >> 16
        let redBits = shiftedRed & 0xFF

        let shiftedGreen = netHex >> 8
        let greenBits = shiftedGreen & 0xFF

        let shiftedBlue = netHex
        let blueBits = shiftedBlue & 0xFF

        let alpha = CGFloat((netHex >> 24) & 0xFF)
        return UIColor(red: Int(redBits), green: Int(greenBits), blue: Int(blueBits)).withAlphaComponent(alpha / 255.0)
    }

    static func mainRed() -> UIColor {
        return UIColor(netHex: 0xE00909)
    }

    static func borderGray() -> UIColor {
        return UIColor(netHex: 0xDBDFE2)
    }

    static func lineBreakerProfile() -> UIColor {
        return UIColor(netHex: 0xEAEAEA)
    }

    static func circleChartStartPointRed() -> UIColor {
        return UIColor(netHex: 0xCE0A11)
    }

    static func circleChartGray() -> UIColor {
        return UIColor(netHex: 0xCCCCCC)
    }

    static func circleChartPurple() -> UIColor {
        return UIColor(netHex: 0x350064)
    }

    static func circleChartTextColor() -> UIColor {
        return UIColor(netHex: 0x666666)
    }

    static func placeholderGray() -> UIColor {
        return UIColor(netHex: 0xCCCCCC)
    }

    static func disabledButton() -> UIColor {
        return UIColor(netHex: 0xCCCCCC)
    }

    static func onlineGreen() -> UIColor {
        return UIColor(netHex: 0x0EB04B)
    }

    static func navigationOceanBlue() -> UIColor {
        return UIColor(netHex: 0x0076FF)
    }

    static func navigationTextOceanBlue() -> UIColor {
        return UIColor(netHex: 0x19A5E4)
    }

    static func actionButtonColor() -> UIColor {
        return UIColor(red: 85, green: 83, blue: 183)
    }

    func toHexString() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb = Int(r * 255) << 16 | Int(g * 255) << 8 | Int(b * 255) << 0
        return String(format: "%06x", rgb)
    }
}
