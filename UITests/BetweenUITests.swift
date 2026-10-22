import XCTest

final class BetweenUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    @MainActor func launch(_ screen: String = "find") -> XCUIApplication {
        let app = XCUIApplication();app.launchArguments = ["-ui-testing", "-screen", screen];app.launch();return app
    }
    @MainActor func requireDemo(_ app: XCUIApplication) throws {
        if !app.staticTexts["Demo data"].exists { throw XCTSkip("This deterministic report flow uses the isolated Between-Demo scheme.") }
    }
    @MainActor func capture(_ name: String, app: XCUIApplication) {
        let attachment=XCTAttachment(screenshot:app.screenshot());attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
    }
    @MainActor func testOfficialUFLargeText() throws {
        let app = launch()
        if app.staticTexts["Demo data"].exists { throw XCTSkip("Use the UF-connected scheme.") }
        for _ in 0..<3 { app.swipeUp() }
        let count = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "people in building")).firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: 30))
        capture("18-Official-UF-LargeText", app: app)
    }
    @MainActor func testOfficialUFData() throws {
        let app = launch()
        if app.staticTexts["Demo data"].exists { throw XCTSkip("Run this network smoke test with the Between scheme / Development configuration.") }
        let count = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "people in building")).firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: 40), "Real UF display count must reach the native UI")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Open until")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Sensor update time unavailable"].firstMatch.exists)
        capture("15-Official-UF-Find", app: app)
        app.buttons["place-marston"].tap()
        let heading = app.staticTexts["OFFICIAL UF OCCUPANCY"]
        if !heading.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        capture("16-Official-UF-Details", app: app)
    }
    @MainActor func testGuestFindPlanDetailsAndReport() throws {
        let app=launch()
        try requireDemo(app)
        XCTAssertTrue(app.staticTexts["Demo data"].waitForExistence(timeout:15))
        capture("01-Find",app:app)
        app.buttons["time-plan"].tap()
        app.buttons["duration-45"].tap()
        app.buttons["Find a spot"].tap()
        app.buttons["toggle-map"].tap()
        let place=app.buttons["place-marston"]
        if !place.waitForExistence(timeout:5) { app.swipeUp() }
        XCTAssertTrue(place.waitForExistence(timeout:5));place.tap()
        XCTAssertTrue(app.buttons["report-conditions"].waitForExistence(timeout:5))
        capture("02-Details",app:app)
        app.buttons["report-conditions"].tap()
        XCTAssertTrue(app.buttons["seat-1"].waitForExistence(timeout:5));app.buttons["seat-1"].tap()
        capture("03-Report",app:app)
        app.swipeUp()
        let demo=app.buttons["demo-sign-in"];if demo.waitForExistence(timeout:3){demo.tap()}
        let submit = app.buttons["submit-report"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: submit)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        submit.tap()
        let accepted = app.staticTexts["Demo report saved"].waitForExistence(timeout:8)
        if !accepted {
            capture("Submission-failure", app: app)
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Submission failure hierarchy"; hierarchy.lifetime = .keepAlways; add(hierarchy)
        }
        XCTAssertTrue(accepted)
        capture("04-Accepted",app:app)
    }
    @MainActor func testManualOriginAndWalkingDirections() throws {
        let app = launch()
        try requireDemo(app)
        app.buttons["origin"].tap()
        app.buttons["Library West"].tap()
        app.buttons["toggle-map"].tap()
        let place=app.buttons["place-marston"]
        if !place.waitForExistence(timeout:3) { app.swipeUp() }
        XCTAssertTrue(place.waitForExistence(timeout:5));place.tap()
        app.buttons["Directions"].tap()
        XCTAssertTrue(app.buttons["Open in Apple Maps"].waitForExistence(timeout:40))
        capture("08-Walking-directions",app:app)
    }
    @MainActor func testSavePersistsAcrossLaunch() throws {
        let app=launch("details"); try requireDemo(app)
        let save=app.buttons["detail-save"];XCTAssertTrue(save.waitForExistence(timeout:10));save.tap()
        app.terminate();app.launchArguments=["-screen","saved"];app.launch()
        XCTAssertTrue(app.staticTexts["Marston"].waitForExistence(timeout:10))
        capture("05-Saved",app:app)
    }
    @MainActor func testScreensAndEmptyStates() throws {
        let app=launch("you");try requireDemo(app);XCTAssertTrue(app.staticTexts["Your space, your pace."].waitForExistence(timeout:10));capture("06-You",app:app)
        app.terminate();app.launchArguments=["-screen","empty"];app.launch();app.buttons["toggle-map"].tap();XCTAssertTrue(app.staticTexts["No recent reports"].firstMatch.waitForExistence(timeout:10));capture("07-No-reports",app:app)
    }
}
