import XCTest
import YandexMapsMobile
@testable import Stepmates_Auth

final class TrackProcessingTests: XCTestCase {
    private func point(_ latitude: Double, _ longitude: Double) -> YMKPoint {
        YMKPoint(latitude: latitude, longitude: longitude)
    }

    private func sample(
        _ index: Int,
        at date: Date,
        latitude: Double? = nil,
        longitude: Double? = nil,
        quality: TrackQuality = .good,
        confidence: Int? = nil,
        movementKind: MapMovementKind = .walking,
        breakReason: TrackBreakReason? = nil
    ) -> TrackSample {
        TrackSample(
            point: point(latitude ?? 55.751 + Double(index) * 0.0001, longitude ?? 37.618 + Double(index) * 0.0001),
            recordedAt: date,
            quality: quality,
            movementState: .walking,
            horizontalAccuracy: 8,
            confidenceScore: confidence,
            movementKind: movementKind,
            breakReason: breakReason
        )
    }

    func testSmoothingKeepsEndpointsAndAveragesMiddlePoint() {
        let segment = [
            point(10, 10),
            point(13, 16),
            point(16, 19)
        ]

        let result = TrackSmoothing.smoothSegment(segment)

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.first?.latitude, 10)
        XCTAssertEqual(result.first?.longitude, 10)
        XCTAssertEqual(result.last?.latitude, 16)
        XCTAssertEqual(result.last?.longitude, 19)
        XCTAssertEqual(result[1].latitude, 13, accuracy: 0.000001)
        XCTAssertEqual(result[1].longitude, 15, accuracy: 0.000001)
    }

    func testSmoothingDoesNotChangeTinySegments() {
        let segment = [point(1, 1), point(2, 2)]
        XCTAssertEqual(TrackSmoothing.smoothSegment(segment).count, 2)
    }

    func testSimplificationRemovesCloseStraightMiddlePoint() {
        let segment = [
            point(55.751000, 37.618000),
            point(55.751005, 37.618005),
            point(55.751100, 37.618100)
        ]

        let result = TrackSimplification.simplifySegment(segment, minimumDistance: 10)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.latitude, segment.first?.latitude)
        XCTAssertEqual(result.last?.latitude, segment.last?.latitude)
    }

    func testUploadQueueSkipsAlmostDuplicatePoints() {
        let first = TrackPointPayload(
            latitude: 55.751000,
            longitude: 37.618000,
            horizontalAccuracy: 8,
            speed: 1,
            course: nil,
            movementState: "walking",
            stepsDelta: 3,
            confidenceScore: 92,
            movementKind: "walking",
            breakReason: nil,
            recordedAt: "2026-05-28T10:00:00Z"
        )
        let near = TrackPointPayload(
            latitude: 55.751001,
            longitude: 37.618001,
            horizontalAccuracy: 8,
            speed: 1,
            course: nil,
            movementState: "walking",
            stepsDelta: 1,
            confidenceScore: 91,
            movementKind: "walking",
            breakReason: nil,
            recordedAt: "2026-05-28T10:00:05Z"
        )
        let far = TrackPointPayload(
            latitude: 55.752000,
            longitude: 37.619000,
            horizontalAccuracy: 8,
            speed: 1,
            course: nil,
            movementState: "walking",
            stepsDelta: 9,
            confidenceScore: 93,
            movementKind: "walking",
            breakReason: nil,
            recordedAt: "2026-05-28T10:01:00Z"
        )

        XCTAssertTrue(TrackSimplification.shouldAppendToUploadQueue(newPoint: first, lastPoint: nil))
        XCTAssertFalse(TrackSimplification.shouldAppendToUploadQueue(newPoint: near, lastPoint: first, minimumDistance: 8))
        XCTAssertTrue(TrackSimplification.shouldAppendToUploadQueue(newPoint: far, lastPoint: first, minimumDistance: 8))
    }

    func testTrackSegmentationBuildsDrawableWalkingSegment() {
        let start = Date()
        let samples = [
            sample(0, at: start, confidence: 90),
            sample(1, at: start.addingTimeInterval(8), confidence: 80),
            sample(2, at: start.addingTimeInterval(16), quality: .weak, confidence: 70)
        ]

        let segments = TrackSegmentation.buildTrackSegments(from: samples)

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].points.count, 3)
        XCTAssertEqual(segments[0].quality, .weak)
        XCTAssertEqual(segments[0].confidenceScore, 80)
        XCTAssertTrue(segments[0].isDrawableWalkSegment)
    }

    func testTrackSegmentationSplitsOnLongTimeGap() {
        let start = Date()
        let samples = [
            sample(0, at: start),
            sample(1, at: start.addingTimeInterval(10)),
            sample(2, at: start.addingTimeInterval(TrackSegmentation.maxTimeGap + 20)),
            sample(3, at: start.addingTimeInterval(TrackSegmentation.maxTimeGap + 30))
        ]

        let segments = TrackSegmentation.buildTrackSegments(from: samples)

        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].points.count, 2)
        XCTAssertEqual(segments[1].points.count, 2)
    }

    func testTransportSegmentIsNotDrawableWalk() {
        let start = Date()
        let samples = [
            sample(0, at: start, movementKind: .transport, breakReason: .vehicleJump),
            sample(1, at: start.addingTimeInterval(8), movementKind: .transport, breakReason: .vehicleJump)
        ]

        let segments = TrackSegmentation.buildTrackSegments(from: samples)

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].quality, .poor)
        XCTAssertFalse(segments[0].isDrawableWalkSegment)
        XCTAssertEqual(segments[0].breakReason, .vehicleJump)
    }
}
