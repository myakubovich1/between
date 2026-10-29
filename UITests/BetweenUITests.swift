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
    @MainActor func testStudentStartingPointNextClassAndSearchRecovery() throws {
        let app = launch()
        if app.staticTexts["Demo data"].exists { throw XCTSkip("Use the live scheme.") }
        XCTAssertTrue(app.buttons["origin"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Choose your starting point"].exists)
        app.buttons["origin"].tap()
        app.buttons["Library West"].tap()
        XCTAssertTrue(app.staticTexts["From Library West"].waitForExistence(timeout: 5))
        app.buttons["time-plan"].tap()
        app.buttons["duration-45"].tap()
        let next = app.buttons["next-campus"]
        if !next.isHittable { app.swipeUp() }
        XCTAssertTrue(next.waitForExistence(timeout: 5)); next.tap()
        app.buttons["Turlington Hall"].tap()
        let result = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "campus-place-uf-")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 30), "The official UF campus building must be selectable")
        result.tap()
        app.buttons["Find a spot"].tap()
        capture("Student-01-Plan-And-Origin", app: app)
        let search = app.textFields["search"]
        search.tap(); search.typeText("no-such-UF-library\n")
        XCTAssertTrue(app.staticTexts["No matching library"].waitForExistence(timeout: 5))
        app.buttons["empty-clear-search"].tap()
        XCTAssertTrue(app.staticTexts["No matching library"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(search.value as? String, "Search UF libraries")
        app.tabBars.buttons["Saved"].tap()
        let find = app.buttons["saved-find"]
        XCTAssertTrue(find.waitForExistence(timeout: 5)); find.tap()
        XCTAssertTrue(app.buttons["time-plan"].waitForExistence(timeout: 5))
        capture("Student-02-Recovered-Discovery", app: app)
    }
    @MainActor func testLiveRoomsHoursAndMotion() throws {
        let app = launch()
        if app.staticTexts["Demo data"].exists { throw XCTSkip("This verifies the normal UF-connected app.") }
        let count = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "people in building")).firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: 40))
        XCTAssertFalse(app.staticTexts["Demo hours"].exists)
        let fresh = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "UF count · retrieved")).firstMatch
        XCTAssertTrue(fresh.waitForExistence(timeout: 40), "A successful new retrieval must be labeled current, not saved")
        capture("Live-01-Discovery", app: app)
        app.buttons["toggle-map"].tap()
        capture("Live-02-Map", app: app)
        let search = app.textFields["search"]
        search.tap(); search.typeText("Education\n")
        let educationOpen = app.buttons["place-education"]
        let educationClosed = app.buttons["closed-education"]
        XCTAssertTrue(educationClosed.waitForExistence(timeout: 2) || educationOpen.exists)
        if app.staticTexts["CLOSED RIGHT NOW"].exists {
            XCTAssertTrue(educationClosed.exists, "A closed result must use its closed-library row after schedules refresh")
            XCTAssertFalse(educationOpen.exists)
        }
        app.buttons["Clear search"].tap()
        search.tap(); search.typeText("Library West\n")
        let open = app.buttons["place-west"]
        let closed = app.buttons["closed-west"]
        if !open.waitForExistence(timeout: 2) && !closed.isHittable { app.swipeUp() }
        let place = open.exists ? open : closed
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: place)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed)
        place.tap()
        let hours = app.buttons["published-hours"]
        for _ in 0..<5 { if hours.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(hours.waitForExistence(timeout: 5)); hours.tap()
        capture("Live-03-Published-Hours", app: app)
        let result = app.descendants(matching: .any)["room-result-count"].firstMatch
        for _ in 0..<8 { if result.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(result.waitForExistence(timeout: 25), "Actual public LibCal results must reach the native view")
        let freshRooms = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND NOT (label CONTAINS %@)", "listed", "previously")).firstMatch
        XCTAssertTrue(freshRooms.waitForExistence(timeout: 10), "New room results must not be marked previously listed")
        capture("Live-04-Room-Availability", app: app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "UF LibCal · checked")).firstMatch.exists)
    }
    @MainActor func testLiveReducedMotionDiscovery() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reduce-motion", "-screen", "find"]
        app.launch()
        if app.staticTexts["Demo data"].exists { throw XCTSkip("Use the live scheme.") }
        let count = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "people in building")).firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: 40))
        app.buttons["toggle-map"].tap()
        app.buttons["toggle-map"].tap()
        XCTAssertTrue(app.buttons["time-plan"].exists)
        capture("Live-05-Reduced-Motion", app: app)
    }
    @MainActor func testLargeTextSearchRecovery() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Find your in-between"].waitForExistence(timeout: 10), "Exercise the actual accessibility-size layout")
        let search = app.textFields["search"]
        search.tap(); search.typeText("no-such-UF-library\n")
        let clear = app.buttons["empty-clear-search"]
        for _ in 0..<5 { if clear.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(clear.waitForExistence(timeout: 5)); clear.tap()
        XCTAssertTrue(app.staticTexts["No matching library"].waitForNonExistence(timeout: 5))
        capture("Live-06-Accessibility-Text", app: app)
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
