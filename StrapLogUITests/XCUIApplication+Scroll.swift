import XCTest

extension XCUIApplication {
    /// Swipes up until `element` is on screen.
    func scroll(to element: XCUIElement, maxSwipes: Int = 6) -> Bool {
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable { return true }
            swipeUp()
        }
        return element.exists && element.isHittable
    }
}
