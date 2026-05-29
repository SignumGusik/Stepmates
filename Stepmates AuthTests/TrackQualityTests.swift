import XCTest
import CoreLocation
@testable import Stepmates_Auth

final class TrackQualityTests: XCTestCase {
    private func makeLocation(
        latitude: Double = 55.751244,
        longitude: Double = 37.618423,
        accuracy: CLLocationAccuracy,
        speed: CLLocationSpeed = 1.2,
        timestamp: Date = Date()
    ) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 5,
            course: 0,
            speed: speed,
            timestamp: timestamp
        )
    }

    func testScoreBucketsMapToExpectedQuality() {
        XCTAssertEqual(TrackQuality.from(score: 100), .good)
        XCTAssertEqual(TrackQuality.from(score: 78), .good)
        XCTAssertEqual(TrackQuality.from(score: 77), .weak)
        XCTAssertEqual(TrackQuality.from(score: 42), .weak)
        XCTAssertEqual(TrackQuality.from(score: 41), .poor)
        XCTAssertEqual(TrackQuality.from(score: 0), .poor)
    }

    func testWorstQualityReturnsLeastReliableValue() {
        XCTAssertEqual(TrackQuality.worst(.good, .weak), .weak)
        XCTAssertEqual(TrackQuality.worst(.poor, .good), .poor)
        XCTAssertEqual(TrackQuality.worst(.weak, .weak), .weak)
    }

    func testFreshWalkingLocationGetsHighConfidence() {
        let location = makeLocation(accuracy: 8, speed: 1.4)
        let motion = MotionSnapshot(
            state: .walking,
            stepsDelta: 12,
            cadenceStepsPerMinute: 96,
            confidenceHigh: true
        )

        let confidence = LocationConfidence.evaluate(
            location: location,
            previousLocation: nil,
            motion: motion
        )

        XCTAssertGreaterThanOrEqual(confidence.score, 90)
        XCTAssertEqual(confidence.quality, .good)
        XCTAssertEqual(confidence.movementKind, .walking)
        XCTAssertNil(confidence.breakReason)
    }

    func testPoorAccuracyMarksPointAsUnreliable() {
        let location = makeLocation(accuracy: 160, speed: 0.3)

        let confidence = LocationConfidence.evaluate(
            location: location,
            previousLocation: nil,
            motion: nil
        )

        XCTAssertLessThan(confidence.score, 42)
        XCTAssertEqual(confidence.quality, .poor)
        XCTAssertEqual(confidence.breakReason, .poorAccuracy)
    }

    func testLargeFastJumpIsDetectedAsTransport() {
        let previous = makeLocation(
            latitude: 55.751244,
            longitude: 37.618423,
            accuracy: 8,
            speed: 1,
            timestamp: Date().addingTimeInterval(-10)
        )
        let current = makeLocation(
            latitude: 55.761244,
            longitude: 37.648423,
            accuracy: 8,
            speed: 18,
            timestamp: Date()
        )

        let confidence = LocationConfidence.evaluate(
            location: current,
            previousLocation: previous,
            motion: nil
        )

        XCTAssertEqual(confidence.movementKind, .transport)
        XCTAssertEqual(confidence.breakReason, .vehicleJump)
        XCTAssertLessThan(confidence.score, 80)
    }

    func testMotionSnapshotFlagsMovementKinds() {
        XCTAssertTrue(MotionSnapshot(state: .walking, stepsDelta: 1, cadenceStepsPerMinute: nil, confidenceHigh: true).isMovingOnFoot)
        XCTAssertTrue(MotionSnapshot(state: .running, stepsDelta: 4, cadenceStepsPerMinute: nil, confidenceHigh: true).isMovingOnFoot)
        XCTAssertTrue(MotionSnapshot(state: .stationary, stepsDelta: 0, cadenceStepsPerMinute: nil, confidenceHigh: false).isStationaryLike)
        XCTAssertTrue(MotionSnapshot(state: .automotive, stepsDelta: 0, cadenceStepsPerMinute: nil, confidenceHigh: true).isVehicleLike)
        XCTAssertTrue(MotionSnapshot(state: .cycling, stepsDelta: 0, cadenceStepsPerMinute: nil, confidenceHigh: true).isVehicleLike)
    }
}
