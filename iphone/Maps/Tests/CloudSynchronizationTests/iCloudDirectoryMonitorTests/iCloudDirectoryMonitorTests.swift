import XCTest
@testable import Organic_Maps__Debug_

typealias UbiquityIdentityToken = NSCoding & NSCopying & NSObjectProtocol

class iCloudDirectoryMonitorTests: XCTestCase {

  var cloudMonitor: iCloudDocumentsDirectoryMonitor!
  var mockFileManager: FileManagerMock!
  var mockDelegate: UbiquitousDirectoryMonitorDelegateMock!
  var cloudContainerIdentifier: String = "iCloud.app.organicmaps.debug"

  override func setUp() {
    super.setUp()
    mockFileManager = FileManagerMock()
    mockDelegate = UbiquitousDirectoryMonitorDelegateMock()
    cloudMonitor = iCloudDocumentsDirectoryMonitor(fileManager: mockFileManager, cloudContainerIdentifier: cloudContainerIdentifier, fileType: .kml)
    cloudMonitor.delegate = mockDelegate
  }

  override func tearDown() {
    cloudMonitor = nil
    mockFileManager = nil
    mockDelegate = nil
    super.tearDown()
  }

  func testInitialization() {
    XCTAssertNotNil(cloudMonitor)
    XCTAssertEqual(cloudMonitor.containerIdentifier, cloudContainerIdentifier)
  }

  func testCloudAvailability() {
    mockFileManager.mockUbiquityIdentityToken = NSString(string: "mockToken")
    XCTAssertTrue(cloudMonitor.isCloudAvailable())

    mockFileManager.mockUbiquityIdentityToken = nil
    XCTAssertFalse(cloudMonitor.isCloudAvailable())
  }

  func testStartWhenCloudAvailable() {
    mockFileManager.mockUbiquityIdentityToken = NSString(string: "mockToken")
    let startExpectation = expectation(description: "startExpectation")
    cloudMonitor.start { result in
      if case .success = result {
        startExpectation.fulfill()
      }
    }
    waitForExpectations(timeout: 5)
    XCTAssertTrue(cloudMonitor.isStarted, "Monitor should be started when the cloud is available.")
    XCTAssertFalse(cloudMonitor.isPaused, "Monitor should not be paused after starting.")
  }



  func testStartWhenCloudNotAvailable() {
    mockFileManager.mockUbiquityIdentityToken = nil
    let startExpectation = expectation(description: "startExpectation")
    cloudMonitor.start { result in
      if case .failure(let error) = result, case SynchronizationError.iCloudIsNotAvailable = error {
        startExpectation.fulfill()
      }
    }
    waitForExpectations(timeout: 5)
    XCTAssertFalse(cloudMonitor.isStarted, "Monitor should not start when the cloud is not available.")
  }

  func testStopAfterStart() {
    testStartWhenCloudAvailable()
    cloudMonitor.stop()
    XCTAssertFalse(cloudMonitor.isStarted, "Monitor should not be started after stopping.")
    XCTAssertTrue(cloudMonitor.isPaused, "Monitor should be paused after stopping.")
  }

  func testPauseAndResume() {
    testStartWhenCloudAvailable()
    cloudMonitor.pause()
    XCTAssertTrue(cloudMonitor.isPaused, "Monitor should be paused.")

    cloudMonitor.resume()
    XCTAssertFalse(cloudMonitor.isPaused, "Monitor should not be paused after resuming.")
    XCTAssertTrue(cloudMonitor.isStarted, "Monitor should still be started after resuming.")
  }

  func testFetchUbiquityDirectoryUrl() {
    let expectation = self.expectation(description: "Fetch Ubiquity Directory URL")
    mockFileManager.shouldReturnContainerURL = true
    cloudMonitor.fetchUbiquityDirectoryUrl { result in
      if case .success = result {
        expectation.fulfill()
      }
    }
    wait(for: [expectation], timeout: 5.0)
  }

  func testDelegateMethods() {
    testStartWhenCloudAvailable()

    guard let metadataQuery = cloudMonitor.metadataQuery else {
      XCTFail("Metadata query should not be nil")
      return
    }

    let didFinishGatheringExpectation = expectation(description: "didFinishGathering")
    mockDelegate.didFinishGatheringExpectation = didFinishGatheringExpectation
    NotificationCenter.default.post(name: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: metadataQuery)
    wait(for: [didFinishGatheringExpectation], timeout: 5.0)

    let didUpdateExpectation = expectation(description: "didUpdate")
    mockDelegate.didUpdateExpectation = didUpdateExpectation
    NotificationCenter.default.post(name: NSNotification.Name.NSMetadataQueryDidUpdate, object: metadataQuery)
    wait(for: [didUpdateExpectation], timeout: 5.0)
  }

  // MARK: - Delegate

  func testDelegateDidFinishGathering() {
    testStartWhenCloudAvailable()

    guard let metadataQuery = cloudMonitor.metadataQuery else {
      XCTFail("Metadata query should not be nil")
      return
    }

    let didFinishGatheringExpectation = expectation(description: "didFinishGathering")
    mockDelegate.didFinishGatheringExpectation = didFinishGatheringExpectation
    NotificationCenter.default.post(name: .NSMetadataQueryDidFinishGathering, object: metadataQuery)
    wait(for: [didFinishGatheringExpectation], timeout: 5.0)
    XCTAssertTrue(mockDelegate.didFinishGatheringCalled, "Delegate's didFinishGathering should be called.")
  }

  func testDelegateDidUpdate() {
    testStartWhenCloudAvailable()

    guard let metadataQuery = cloudMonitor.metadataQuery else {
      XCTFail("Metadata query should not be nil")
      return
    }
    let didUpdateExpectation = expectation(description: "didUpdate")
    mockDelegate.didUpdateExpectation = didUpdateExpectation
    NotificationCenter.default.post(name: NSNotification.Name.NSMetadataQueryDidUpdate, object: metadataQuery)
    wait(for: [didUpdateExpectation], timeout: 5.0)
    XCTAssertTrue(mockDelegate.didUpdateCalled, "Delegate's didUpdate should be called.")
  }

  func testDelegateDidReceiveError() {
    testStartWhenCloudAvailable()
    let didReceiveErrorExpectation = expectation(description: "didReceiveError")
    mockDelegate.didReceiveErrorExpectation = didReceiveErrorExpectation
    cloudMonitor.delegate?.didReceiveCloudMonitorError(SynchronizationError.containerNotFound)
    wait(for: [didReceiveErrorExpectation], timeout: 5.0)
    XCTAssertTrue(mockDelegate.didReceiveErrorCalled, "Delegate's didReceiveError should be called.")
  }
}
