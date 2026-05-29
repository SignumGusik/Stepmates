import XCTest

final class LaunchSmokeUITests: XCTestCase {
    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestMode", "1"]
        app.launchEnvironment["UITEST_DISABLE_ANIMATIONS"] = "1"
        return app
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesToForeground() throws {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testAppCanReturnFromBackground() throws {
        let app = makeApp()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))

        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.windows.firstMatch.exists)
    }

    @MainActor
    func testLaunchScreenshotCanBeCaptured() throws {
        let app = makeApp()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Stepmates launch smoke"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
