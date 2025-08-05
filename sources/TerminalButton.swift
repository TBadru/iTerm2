//
//  TerminalButton.swift
//  iTerm2SharedARC
//
//  Created by George Nachman on 9/26/23.
//

import Foundation

@available(macOS 11, *)
@objc(iTermTerminalButton)
class TerminalButton: NSObject {
    @objc var wantsFrame: Bool { true }
    @objc var action: ((NSPoint) -> ())?
    private let tintedForegroundImage: TintedImage
    private let tintedBackgroundImage: TintedImage
    private let aspectRatio: CGFloat
    @objc let tooltip: String
    @objc weak var mark: iTermMarkProtocol?
    // Returns -1 if unset
    @objc var transientAbsY: Int {
        return -1
    }
    // Clients can use this as they like
    @objc var desiredFrame = NSRect.zero
    // Clients can use this as they like
    @objc var lastTooltipRect = NSRect.zero
    @objc var absCoordForDesiredFrame = VT100GridAbsCoordMake(-1, -1)
    @objc var pressed: Bool {
        switch state {
        case .normal: return false
        case .pressedInside, .pressedOutside: return true
        }
    }
    enum State: Int {
        case normal
        case pressedOutside
        case pressedInside
    }
    var floating: Bool { false }
    private(set) var state = State.normal
    @objc let id: Int
    @objc var enclosingSessionWidth: Int32 = 0
    @objc var shift = CGFloat(0)
    var selected: Bool { false }

    // If the icon depends on internal state of a subclass, this should expose a key that can be
    // used to cache the icon.
    @objc var extraIdentifyingInfoForIcon: AnyHashable? { nil }

    init(id: Int, backgroundImage: NSImage, foregroundImage: NSImage, mark: iTermMarkProtocol?, tooltip: String) {
        self.id = id
        tintedForegroundImage = TintedImage(original: foregroundImage)
        tintedBackgroundImage = TintedImage(original: backgroundImage)
        self.mark = mark
        aspectRatio = foregroundImage.size.height / foregroundImage.size.width;
        self.tooltip = tooltip
    }

    required init?(_ original: TerminalButton) {
        self.id = original.id
        tintedForegroundImage = original.tintedForegroundImage.clone()
        tintedBackgroundImage = original.tintedBackgroundImage.clone()
        self.mark = original.mark
        aspectRatio = original.tintedForegroundImage.original.size.height / original.tintedForegroundImage.original.size.width;
        desiredFrame = original.desiredFrame
        absCoordForDesiredFrame = original.absCoordForDesiredFrame
        state = original.state
        enclosingSessionWidth = original.enclosingSessionWidth
        shift = original.shift
        self.tooltip = original.tooltip
    }

    @objc func clone() -> Self {
        return Self(self)!
    }

    var useRoundedRectForBackground: Bool { true }

    private func images(backgroundColor: NSColor,
                        foregroundColor: NSColor,
                        size: NSSize) -> (NSImage, NSImage) {
        let bg = if useRoundedRectForBackground {
            NSImage.roundedRect(size: size,
                                radius: 2,
                                color: backgroundColor)
        } else {
            tintedBackgroundImage.tintedImage(color: backgroundColor,
                                              size: size)
        }
        return (tintedForegroundImage.tintedImage(color: foregroundColor,
                                                  size: size),
                bg)
    }

    @objc func size(cellSize: NSSize) -> NSSize {
        let width = cellSize.width * 2
        var result = NSSize(width: width, height: aspectRatio * width);
        let scale = cellSize.height / result.height
        if scale < 1 {
            result.width *= scale
            result.height *= scale
        }
        return result.retinaRound(2.0)
    }

    @objc(frameWithX:absY:minAbsLine:cumulativeOffset:cellSize:)
    func frame(x: CGFloat,
               absY: Int,
               minAbsLine: Int64,
               cumulativeOffset: Int64,
               cellSize: NSSize) -> NSRect {
        let size = size(cellSize: cellSize)
        let height = cellSize.height
        let yoff = max(0, (cellSize.height - height))
        return NSRect(x: x,
                      y: CGFloat(max(minAbsLine, Int64(absY)) - cumulativeOffset) * cellSize.height + yoff,
                      width: size.width,
                      height: height)
    }

    @objc(drawWithBackgroundColor:foregroundColor:selectedColor:frame:virtualOffset:)
    func draw(backgroundColor: NSColor,
              foregroundColor: NSColor,
              selectedColor: NSColor,
              frame rect: NSRect,
              virtualOffset: CGFloat) {
        
        let (foregroundImage, backgroundImage) = switch state {
        case .normal, .pressedOutside:
            images(backgroundColor: selected ? selectedColor : backgroundColor,
                   foregroundColor: selected ? backgroundColor : foregroundColor,
                   size: rect.size)
        case .pressedInside:
            images(backgroundColor: foregroundColor, 
                   foregroundColor: backgroundColor,
                   size: rect.size)
        }
        backgroundImage.it_draw(in: rect, virtualOffset: virtualOffset)
        foregroundImage.it_draw(in: rect, virtualOffset: virtualOffset)
    }

    func image(backgroundColor: NSColor,
               foregroundColor: NSColor,
               selectedColor: NSColor,
               size: CGSize) -> NSImage {
        return NSImage(size: size,
                       flipped: false) { [weak self] _ in
            self?.draw(backgroundColor: backgroundColor,
                       foregroundColor: foregroundColor,
                       selectedColor: selectedColor,
                       frame: NSRect(x: 0, y: 0, width: size.width, height: size.height),
                       virtualOffset: 0)
            return true
        }
    }
    var highlighted: Bool {
        switch state {
        case .normal, .pressedOutside:
            return false
        case .pressedInside:
            return true
        }
    }

    @objc
    func mouseDownInside() -> Bool {
        DLog("Mouse down inside on \(description)")
        let wasHighlighted = highlighted
        state = .pressedInside
        return highlighted != wasHighlighted
    }

    @objc
    func mouseDownOutside() -> Bool {
        DLog("Mouse down outside on \(description)")
        let wasHighlighted = highlighted
        state = .pressedOutside
        return highlighted != wasHighlighted
    }

    @objc
    @discardableResult
    func mouseUp(locationInWindow: NSPoint) -> Bool {
        DLog("mouseUp: TerminalButton.mouseUp initial state is \(state)");
        let wasHighlighted = highlighted
        switch state {
        case .pressedInside:
            DLog("mouseUp: TerminalButton.mouseUp DO ACTION");
            action?(locationInWindow)
            state = .normal
        case .pressedOutside:
            state = .normal
        case .normal:
            break
        }
        return highlighted != wasHighlighted
    }

    @objc
    func mouseExited() {
        switch state {
        case .pressedInside:
            state = .pressedOutside
        case .pressedOutside, .normal:
            state = .normal
        }
    }
}

@available(macOS 11, *)
extension TerminalButton: NSViewToolTipOwner {
    func view(_ view: NSView,
              stringForToolTip tag: NSView.ToolTipTag,
              point: NSPoint,
              userData data: UnsafeMutableRawPointer?) -> String {
        DLog("Returning \(tooltip) for \(self)")
        return tooltip
    }
}

@available(macOS 11, *)
@objc
class GenericBlockButton: TerminalButton {
    @objc let blockID: String
    @objc var absY: NSNumber?
    override var transientAbsY: Int {
        if let absY {
            return absY.intValue
        }
        return -1
    }
    @objc var isFloating = false
    override var floating: Bool { isFloating }
    init?(id: Int, blockID: String, mark: iTermMarkProtocol?, absY: NSNumber?, fgName: String, bgName: String, tooltip: String) {
        self.blockID = blockID
        guard let bg = NSImage(systemSymbolName: bgName, accessibilityDescription: nil),
              let fg = NSImage(systemSymbolName: fgName, accessibilityDescription: nil) else {
            return nil
        }
        self.absY = absY
        super.init(id: id,
                   backgroundImage: bg,
                   foregroundImage: fg,
                   mark: mark,
                   tooltip: tooltip)
    }

    required init?(_ original: TerminalButton) {
        let downcast = original as! GenericBlockButton
        self.blockID = downcast.blockID
        self.absY = downcast.absY
        isFloating = downcast.isFloating
        super.init(original)
    }

    override func clone() -> Self {
        return Self(self)!
    }
}

@available(macOS 11, *)
@objc(iTermTerminalCopyButton)
class TerminalCopyButton: GenericBlockButton {
    @objc(initWithID:blockID:mark:absY:tooltip:)
    init?(id: Int, blockID: String, mark: iTermMarkProtocol?, absY: NSNumber?, tooltip: String) {
        super.init(id: id,
                   blockID: blockID,
                   mark: mark,
                   absY: absY,
                   fgName: SFSymbol.docOnDoc.rawValue,
                   bgName: SFSymbol.docOnDocFill.rawValue,
                   tooltip: tooltip)
    }

    required init?(_ original: TerminalButton) {
        super.init(original)
    }
}

@available(macOS 11, *)
@objc(iTermTerminalRevealChannelButton)
class TerminalRevealChannelButton: TerminalButton {
    override var wantsFrame: Bool { false }
    override var useRoundedRectForBackground: Bool { false }
    @objc let buttonMark: ButtonMarkReading

    @objc
    init?(place: TerminalButtonPlace) {
        guard let bg = NSImage(systemSymbolName: SFSymbol.rectangleStackFill.rawValue, accessibilityDescription: nil),
              let fg = NSImage(systemSymbolName: SFSymbol.rectangleStack.rawValue, accessibilityDescription: nil) else {
            return nil
        }
        self.buttonMark = place.mark as ButtonMarkReading
        super.init(id: place.id,
                   backgroundImage: bg,
                   foregroundImage: fg,
                   mark: place.mark,
                   tooltip: "Reveal embedded command")
    }

    required init?(_ original: TerminalButton) {
        let downcast = original as! TerminalRevealChannelButton
        self.buttonMark = downcast.buttonMark
        super.init(original)
    }

    override func clone() -> Self {
        return Self(self)!
    }
}

@available(macOS 11, *)
@objc(iTermTerminalFoldBlockButton)
class TerminalFoldBlockButton: GenericBlockButton {
    @objc let absLineRange: NSRange
    @objc let folded: Bool
    override var extraIdentifyingInfoForIcon: AnyHashable? {
        folded
    }
    @objc(initWithID:blockID:mark:absY:currentlyFolded:absLineRange:)
    init?(id: Int,
          blockID: String,
          mark: iTermMarkProtocol?,
          absY: NSNumber?,
          currentlyFolded: Bool,
          absLineRange: NSRange) {
        self.absLineRange = absLineRange
        self.folded = currentlyFolded
        let symbolName = currentlyFolded ? SFSymbol.rectangleExpandVertical.rawValue : SFSymbol.rectangleCompressVertical.rawValue
        super.init(id: id,
                   blockID: blockID,
                   mark: mark,
                   absY: absY,
                   fgName: symbolName,
                   bgName: symbolName,
                   tooltip: currentlyFolded ? "Unfold block" : "Fold block")
    }

    required init?(_ original: TerminalButton) {
        absLineRange = (original as! TerminalFoldBlockButton).absLineRange
        folded = (original as! TerminalFoldBlockButton).folded
        super.init(original)
    }
}


@available(macOS 11, *)
@objc(iTermTerminalMarkButton)
class TerminalMarkButton: TerminalButton {
    @objc let screenMark: VT100ScreenMarkReading
    @objc let dx: Int32
    @objc var shouldFloat = false

    init?(identifier: Int,
          mark: VT100ScreenMarkReading,
          fgName: String,
          bgName: String,
          dx: Int32,
          tooltip: String) {
        self.screenMark = mark
        guard let bg = NSImage(systemSymbolName: bgName, accessibilityDescription: nil),
              let fg = NSImage(systemSymbolName: fgName, accessibilityDescription: nil) else {
            return nil
        }
        self.dx = dx
        super.init(id: -2,
                   backgroundImage: bg,
                   foregroundImage: fg,
                   mark: mark,
                   tooltip: tooltip)
    }

    required init?(_ original: TerminalButton) {
        let downcast = original as! TerminalMarkButton
        self.screenMark = downcast.screenMark
        self.dx = downcast.dx
        super.init(original)
    }

    override func clone() -> Self {
        return Self(self)!
    }
}

@available(macOS 11, *)
@objc(iTermTerminalCopyCommandButton)
class TerminalCopyCommandButton: TerminalMarkButton {

    @objc(initWithMark:dx:)
    init?(mark: VT100ScreenMarkReading, dx: Int32) {
        super.init(identifier: -2, mark: mark, fgName: SFSymbol.docOnDoc.rawValue, bgName: SFSymbol.docOnDocFill.rawValue, dx: dx, tooltip: "Copy command to clipboard")
    }

    required init?(_ original: TerminalButton) {
        super.init(original)
    }
}


@available(macOS 11, *)
@objc(iTermTerminalBookmarkButton)
class TerminalBookmarkButton: TerminalMarkButton {
    override var selected: Bool {
        return screenMark.name != nil
    }
    @objc(initWithMark:dx:)
    init?(mark: VT100ScreenMarkReading, dx: Int32) {
        super.init(identifier: -3, mark: mark, fgName: SFSymbol.bookmark.rawValue, bgName: SFSymbol.bookmarkFill.rawValue, dx: dx, tooltip: "Toggle named mark")
    }
    required init?(_ original: TerminalButton) {
        super.init(original)
    }
}

@available(macOS 11, *)
@objc(iTermTerminalShareButton)
class TerminalShareButton: TerminalMarkButton {
    @objc(initWithMark:dx:)
    init?(mark: VT100ScreenMarkReading, dx: Int32) {
        super.init(identifier: -4, mark: mark, fgName: SFSymbol.squareAndArrowUp.rawValue, bgName: SFSymbol.squareAndArrowUpFill.rawValue, dx: dx, tooltip: "Share command…")
    }
    required init?(_ original: TerminalButton) {
        super.init(original)
    }
}

@available(macOS 11, *)
@objc(iTermCommandInfoButton)
class TerminalCommandInfoButton: TerminalMarkButton {
    @objc(initWithMark:dx:)
    init?(mark: VT100ScreenMarkReading, dx: Int32) {
        super.init(identifier: -5, mark: mark, fgName: SFSymbol.infoCircle.rawValue, bgName: SFSymbol.infoCircleFill.rawValue, dx: dx, tooltip: "Open Command Info…")
    }
    required init?(_ original: TerminalButton) {
        super.init(original)
    }
}

@available(macOS 11, *)
@objc(iTermTerminalFoldButton)
class TerminalFoldButton: TerminalMarkButton {
    @objc(initWithMark:dx:)
    init?(mark: VT100ScreenMarkReading, dx: Int32) {
        super.init(identifier: -6, mark: mark, fgName: SFSymbol.rectangleCompressVertical.rawValue, bgName: SFSymbol.rectangleCompressVertical.rawValue, dx: dx, tooltip: "Fold command")
    }
    required init?(_ original: TerminalButton) {
        super.init(original)
    }
}

@available(macOS 11, *)
@objc(iTermTerminalUnfoldButton)
class TerminalUnfoldButton: TerminalMarkButton {
    @objc(initWithMark:dx:)
    init?(mark: VT100ScreenMarkReading, dx: Int32) {
        super.init(identifier: -7, mark: mark, fgName: SFSymbol.rectangleExpandVertical.rawValue, bgName: SFSymbol.rectangleExpandVertical.rawValue, dx: dx, tooltip: "Unfold command")
    }
    required init?(_ original: TerminalButton) {
        super.init(original)
    }
}

@available(macOS 11, *)
@objc(iTermTerminalSettingsButton)
class TerminalSettingsButton: TerminalMarkButton {
    @objc(initWithMark:dx:)
    init?(mark: VT100ScreenMarkReading, dx: Int32) {
        super.init(identifier: -2, mark: mark, fgName: SFSymbol.switch2.rawValue, bgName: SFSymbol.switch2.rawValue, dx: dx, tooltip: "Command Settings…")
    }

    required init?(_ original: TerminalButton) {
        super.init(original)
    }
}

extension NSImage {
    static func roundedRect(size: NSSize, radius: CGFloat, color: NSColor) -> NSImage {
        return NSImage(size: size, flipped: false) { rect in
            color.setFill()
            let path = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size.width, height: size.height), xRadius: radius, yRadius: radius)
            path.fill()
            return true
        }
    }
}
