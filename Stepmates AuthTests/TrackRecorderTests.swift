import CoreLocation
import XCTest
import YandexMapsMobile
@testable import Stepmates_Auth

final class TrackRecorderTests: XCTestCase {
    private func location(
        latitude: Double = 55.751000,
        longitude: Double = 37.618000,
        accuracy: CLLocationAccuracy = 8,
        speed: CLLocationSpeed = 1.2,
        timeOffset: TimeInterval = 0
    ) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 5,
            course: 90,
            speed: speed,
            timestamp: Date().addingTimeInterval(timeOffset)
        )
    }

    private func walkingMotion(steps: Int = 12) -> MotionSnapshot {
        MotionSnapshot(
            state: .walking,
            stepsDelta: steps,
            cadenceStepsPerMinute: 96,
            confidenceHigh: true
        )
    }

    func testRecorderAcceptsFirstFreshAccurateWalkingPoint() {
        let recorder = TrackRecorder()

        XCTAssertTrue(recorder.appendIfNeeded(location(), motion: walkingMotion()))
        XCTAssertEqual(recorder.points.count, 1)
        XCTAssertEqual(recorder.samples.count, 1)
        XCTAssertEqual(recorder.samples[0].quality, .good)
        XCTAssertEqual(recorder.samples[0].movementKind, .walking)
    }

    func testRecorderRejectsInvalidStaleAndTooInaccurateLocations() {
        let recorder = TrackRecorder()

        XCTAssertFalse(recorder.appendIfNeeded(location(latitude: 0, longitude: 0), motion: walkingMotion()))
        XCTAssertFalse(recorder.appendIfNeeded(location(accuracy: 20, timeOffset: -90), motion: walkingMotion()))
        XCTAssertFalse(recorder.appendIfNeeded(location(accuracy: 260), motion: walkingMotion()))
        XCTAssertTrue(recorder.points.isEmpty)
    }

    func testRecorderRejectsStandingNoiseButAcceptsRealMovement() {
        let recorder = TrackRecorder()
        let first = location(timeOffset: -4)
        let tinyMove = location(latitude: 55.751004, longitude: 37.618004, timeOffset: -2)
        let realMove = location(latitude: 55.751120, longitude: 37.618120, timeOffset: 0)

        XCTAssertTrue(recorder.appendIfNeeded(first, motion: walkingMotion()))
        XCTAssertFalse(recorder.appendIfNeeded(tinyMove, motion: walkingMotion(steps: 1)))
        XCTAssertTrue(recorder.appendIfNeeded(realMove, motion: walkingMotion(steps: 20)))
        XCTAssertEqual(recorder.samples.count, 2)
    }

    func testRecorderKeepsTransportJumpAsSeparatePoorSampleInsteadOfHardRejectingIt() {
        let recorder = TrackRecorder()
        let first = location(timeOffset: -20)
        let jump = location(latitude: 55.770000, longitude: 37.650000, speed: 18, timeOffset: 0)

        XCTAssertTrue(recorder.appendIfNeeded(first, motion: walkingMotion()))
        XCTAssertTrue(recorder.appendIfNeeded(jump, motion: MotionSnapshot(state: .automotive, stepsDelta: 0, cadenceStepsPerMinute: nil, confidenceHigh: true)))
        XCTAssertEqual(recorder.samples.last?.movementKind, .transport)
        XCTAssertEqual(recorder.samples.last?.breakReason, .vehicleJump)
    }

    func testRecorderSmoothsWeakDrawablePointButKeepsRawPoint() throws {
        let recorder = TrackRecorder()
        let first = location(timeOffset: -10)
        let weak = location(latitude: 55.751500, longitude: 37.618500, accuracy: 70, speed: 1.0, timeOffset: 0)

        XCTAssertTrue(recorder.appendIfNeeded(first, motion: walkingMotion()))
        XCTAssertTrue(recorder.appendIfNeeded(weak, motion: walkingMotion()))

        let lastSample = try XCTUnwrap(recorder.samples.last)
        XCTAssertEqual(lastSample.rawPoint.latitude, weak.coordinate.latitude, accuracy: 0.000001)
        XCTAssertLessThan(lastSample.point.latitude, weak.coordinate.latitude)
        XCTAssertGreaterThan(lastSample.point.latitude, first.coordinate.latitude)
    }

    func testReplaceAndClearKeepRecorderStateConsistent() {
        let recorder = TrackRecorder()
        let now = Date()
        let samples = [
            TrackSample(
                point: YMKPoint(latitude: 55.751, longitude: 37.618),
                recordedAt: now,
                quality: .good,
                movementState: .walking,
                horizontalAccuracy: 8
            ),
            TrackSample(
                point: YMKPoint(latitude: 55.752, longitude: 37.619),
                recordedAt: now.addingTimeInterval(10),
                quality: .weak,
                movementState: .walking,
                horizontalAccuracy: 35
            )
        ]

        recorder.replace(with: samples)
        XCTAssertEqual(recorder.points.count, 2)
        XCTAssertEqual(recorder.samples.count, 2)

        recorder.clear()
        XCTAssertTrue(recorder.points.isEmpty)
        XCTAssertTrue(recorder.samples.isEmpty)
    }
}
