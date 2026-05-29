import XCTest
import UIKit
import YandexMapsMobile
@testable import Stepmates_Auth

final class ErrorAndPresentationModelTests: XCTestCase {
    func testFormErrorsHaveUserFriendlyDescriptions() {
        XCTAssertEqual(FormError.missingFields.errorDescription, "Заполните все поля.")
        XCTAssertEqual(FormError.incorrectEntries.errorDescription, "Проверьте введённые данные.")
        XCTAssertEqual(FormError.passwordsDoNotMatch.errorDescription, "Пароли не совпадают.")
    }

    func testUsernameErrorsHaveUserFriendlyDescriptions() {
        XCTAssertEqual(UsernameError.missingFields.errorDescription, "Введите никнейм")
        XCTAssertEqual(UsernameError.tooShort.errorDescription, "Никнейм должен содержать минимум 3 символа")
        XCTAssertEqual(UsernameError.tooLong.errorDescription, "Никнейм должен содержать максимум 30 символов")
        XCTAssertEqual(UsernameError.invalidFormat.errorDescription, "Никнейм может содержать только латинские буквы, цифры и _")
        XCTAssertEqual(UsernameError.missingAccessToken.errorDescription, "Не удалось получить токен доступа")
    }

    func testNetworkErrorExposesStatusCodeAndBody() {
        let data = Data("bad request".utf8)
        let error = NetworkError.failedStatusCodeResponseData(400, data)

        XCTAssertEqual(error.statusCodeResponseData?.0, 400)
        XCTAssertEqual(error.statusCodeResponseData?.1, data)
        XCTAssertNil(NetworkError.noResponse.statusCodeResponseData)
    }

    func testFriendLeaderboardItemKnowsWhetherItIsFriend() {
        let friend = FriendLeaderboardItem(
            userId: 2,
            username: "sister",
            place: 1,
            steps: 12000,
            avatarColor: .orange,
            isCurrentUser: false,
            avatarUrl: nil
        )
        let me = FriendLeaderboardItem(
            userId: 1,
            username: "me",
            place: 2,
            steps: 9000,
            avatarColor: .blue,
            isCurrentUser: true,
            avatarUrl: nil
        )

        XCTAssertTrue(friend.isFriend)
        XCTAssertFalse(me.isFriend)
    }

    func testTrackSegmentDrawableRules() {
        let points = [
            YMKPoint(latitude: 55.751, longitude: 37.618),
            YMKPoint(latitude: 55.752, longitude: 37.619)
        ]
        let now = Date()

        let walking = TrackSegment(
            points: points,
            quality: .good,
            startedAt: now,
            endedAt: now.addingTimeInterval(10),
            movementKind: .walking
        )
        let poor = TrackSegment(
            points: points,
            quality: .poor,
            startedAt: now,
            endedAt: now.addingTimeInterval(10),
            movementKind: .walking
        )
        let transport = TrackSegment(
            points: points,
            quality: .weak,
            startedAt: now,
            endedAt: now.addingTimeInterval(10),
            movementKind: .transport,
            breakReason: .vehicleJump
        )

        XCTAssertTrue(walking.isDrawableWalkSegment)
        XCTAssertFalse(poor.isDrawableWalkSegment)
        XCTAssertFalse(transport.isDrawableWalkSegment)
    }

    func testMapMovementKindLabelsAndDrawableRules() {
        XCTAssertTrue(MapMovementKind.walking.isRouteDrawable)
        XCTAssertTrue(MapMovementKind.unknown.isRouteDrawable)
        XCTAssertFalse(MapMovementKind.transport.isRouteDrawable)
        XCTAssertFalse(MapMovementKind.signalLost.isRouteDrawable)
        XCTAssertEqual(MapMovementKind.stationary.labelText, "на месте")
        XCTAssertEqual(MapMovementKind.signalLost.labelText, "сигнал потерян")
    }
}
