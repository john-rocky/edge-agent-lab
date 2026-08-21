import CoreGraphics
import Foundation
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as! [[String: Any]]
for window in list {
  guard let owner = window[kCGWindowOwnerName as String] as? String, owner.contains("LFMTools"),
    let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
    let number = window[kCGWindowNumber as String] as? Int,
    bounds["Height"]! > 100
  else { continue }
  print("\(Int(bounds["X"]!)) \(Int(bounds["Y"]!)) \(Int(bounds["Width"]!)) \(Int(bounds["Height"]!)) \(number)")
}
