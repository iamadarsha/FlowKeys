import Foundation
import AppKit

func generateIcon() {
    let size = CGSize(width: 1024, height: 1024)
    
    // Colors
    let cream = NSColor(red: 0.98, green: 0.96, blue: 0.94, alpha: 1.0) // #FAF6F0
    let gold = NSColor(red: 0.97, green: 0.78, blue: 0.48, alpha: 1.0) // #F7C67A
    let orange = NSColor(red: 0.96, green: 0.60, blue: 0.35, alpha: 1.0) // #F49A5A
    let coral = NSColor(red: 0.95, green: 0.43, blue: 0.43, alpha: 1.0) // #F26E6E
    
    let nsImage = NSImage(size: size, flipped: false) { rect in
        cream.set()
        rect.fill()
        
        // Settings
        let center = CGPoint(x: 512, y: 512)
        let dashCount = 52
        let innerRadius: CGFloat = 340
        let outerRadius: CGFloat = 420
        let dashWidth: CGFloat = 12
        
        // Sunburst
        for i in 0..<dashCount {
            let angle = CGFloat(i) * (2 * .pi / CGFloat(dashCount))
            let t = CGFloat(i) / CGFloat(dashCount)
            let drawColor = t < 0.5 ? interpolate(from: gold, to: orange, t: t * 2) : interpolate(from: orange, to: coral, t: (t - 0.5) * 2)
            
            let pStart = CGPoint(x: center.x + cos(angle) * innerRadius, y: center.y + sin(angle) * innerRadius)
            let pEnd = CGPoint(x: center.x + cos(angle) * outerRadius, y: center.y + sin(angle) * outerRadius)
            
            let path = NSBezierPath()
            path.move(to: pStart)
            path.line(to: pEnd)
            path.lineWidth = dashWidth
            path.lineCapStyle = .round
            drawColor.setStroke()
            path.stroke()
        }
        
        // Draw "F" in center
        let fText = "F"
        let fFont = NSFont.systemFont(ofSize: 450, weight: .bold)
        let fAttrs: [NSAttributedString.Key: Any] = [
            .font: fFont,
            .foregroundColor: coral
        ]
        let fSize = fText.size(withAttributes: fAttrs)
        fText.draw(at: CGPoint(x: 512 - fSize.width/2, y: 512 - fSize.height/2 + 50), withAttributes: fAttrs)
        
        // Draw "FLOWKEYS" wordmark
        let wText = "FLOWKEYS"
        let wFont = NSFont.systemFont(ofSize: 80, weight: .heavy)
        let wAttrs: [NSAttributedString.Key: Any] = [
            .font: wFont,
            .foregroundColor: coral,
            .kern: 12.0
        ]
        let wSize = wText.size(withAttributes: wAttrs)
        wText.draw(at: CGPoint(x: 512 - wSize.width/2, y: 140), withAttributes: wAttrs)
        
        return true
    }
    
    guard let tiffData = nsImage.tiffRepresentation,
          let bitmapImage = NSBitmapImageRep(data: tiffData),
          let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
        print("Failed to save PNG")
        return
    }
    
    let path = "Resources/AppIcon-Source.png"
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("✅ Generated \(path)")
    } catch {
        print("❌ Failed to write file: \(error)")
    }
}

func interpolate(from: NSColor, to: NSColor, t: CGFloat) -> NSColor {
    return NSColor(
        red: from.redComponent + (to.redComponent - from.redComponent) * t,
        green: from.greenComponent + (to.greenComponent - from.greenComponent) * t,
        blue: from.blueComponent + (to.blueComponent - from.blueComponent) * t,
        alpha: 1.0
    )
}

generateIcon()
