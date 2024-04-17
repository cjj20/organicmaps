import XCTest
@testable import Organic_Maps__Debug_

class LocalDirectoryMonitorDelegateMock: LocalDirectoryMonitorDelegate {
  var didFinishGatheringExpectation: XCTestExpectation?
  var didUpdateExpectation: XCTestExpectation?
  var didReceiveErrorExpectation: XCTestExpectation?

  func didFinishGathering(contents: LocalContents) {
    didFinishGatheringExpectation?.fulfill()
  }

  func didUpdate(contents: LocalContents) {
    didUpdateExpectation?.fulfill()
  }

  func didReceiveLocalMonitorError(_ error: Error) {
    didReceiveErrorExpectation?.fulfill()
  }
}
