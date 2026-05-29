import UIKit
import XCTest
@testable import Stepmates_Auth

@MainActor
final class ViewControllerSmokeTests: XCTestCase {
    private func exercise(_ viewController: UIViewController, file: StaticString = #filePath, line: UInt = #line) {
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()
        XCTAssertFalse(viewController.view.subviews.isEmpty, file: file, line: line)
    }

    func testAuthAndPasswordScreensBuildTheirViews() {
        let network = NetworkHandler()
        let tokenStorage = AccessTokenStorage()

        exercise(LoginViewController(viewModel: .init(networkHandler: network, tokenStorage: tokenStorage)))
        exercise(RegisterViewController(viewModel: .init(networkHandler: network)))
        exercise(ResetPasswordViewController(viewModel: .init(networkHandler: network)))
        exercise(NewPasswordViewController(viewModel: .init(email: "diana@example.com", code: "123456", networkHandler: network)))
        exercise(UsernameViewController(viewModel: .init(networkHandler: network, tokenStorage: tokenStorage)))
    }

    func testCodeVerifyScreenBuildsSixDigitFields() {
        let viewModel = CodeVerifyViewController.ViewModel(
            email: "diana@example.com",
            isRegistrationFlow: true,
            networkHandler: NetworkHandler(),
            tokenStorage: AccessTokenStorage()
        )
        let controller = CodeVerifyViewController(viewModel: viewModel)

        exercise(controller)

        let digitFields = controller.view.allSubviews().compactMap { $0 as? UITextField }
        XCTAssertEqual(digitFields.count, 6)
    }
}

private extension UIView {
    func allSubviews() -> [UIView] {
        subviews + subviews.flatMap { $0.allSubviews() }
    }
}
