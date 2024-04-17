import XCTest
@testable import Organic_Maps__Debug_

final class DefaultLocalDirectoryMonitorTests: XCTestCase {

  let fileManager = FileManager.default
  let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  var directoryMonitor: DefaultLocalDirectoryMonitor!
  var mockDelegate: LocalDirectoryMonitorDelegateMock!

  override func setUp() {
    super.setUp()
    // Setup with a temporary directory and a mock delegate
    directoryMonitor = DefaultLocalDirectoryMonitor(fileManager: fileManager, directory: tempDirectory, fileType: .kml)
    mockDelegate = LocalDirectoryMonitorDelegateMock()
    directoryMonitor.delegate = mockDelegate
  }

  override func tearDown() {
    directoryMonitor.stop()
    mockDelegate = nil
    try? fileManager.removeItem(at: tempDirectory)
    super.tearDown()
  }

  func testInitialization() {
    XCTAssertEqual(directoryMonitor.directory, tempDirectory, "Monitor initialized with incorrect directory.")
    XCTAssertFalse(directoryMonitor.isStarted, "Monitor should not be started initially.")
    XCTAssertTrue(directoryMonitor.isPaused, "Monitor should be paused initially.")
  }

  func testStartMonitoring() {
    let startExpectation = expectation(description: "Start monitoring")
    directoryMonitor.start { result in
      switch result {
      case .success:
        XCTAssertTrue(self.directoryMonitor.isStarted, "Monitor should be started.")
        XCTAssertFalse(self.directoryMonitor.isPaused, "Monitor should not be paused after starting.")
      case .failure(let error):
        XCTFail("Monitoring failed to start with error: \(error)")
      }
      startExpectation.fulfill()
    }
    wait(for: [startExpectation], timeout: 5.0)
  }

  func testStopMonitoring() {
    directoryMonitor.start()
    directoryMonitor.stop()
    XCTAssertFalse(directoryMonitor.isStarted, "Monitor should be stopped.")
    XCTAssertTrue(directoryMonitor.contents.isEmpty, "Contents should be cleared after stopping.")
  }

  func testPauseAndResumeMonitoring() {
    directoryMonitor.start()
    directoryMonitor.pause()
    XCTAssertTrue(directoryMonitor.isPaused, "Monitor should be paused.")

    directoryMonitor.resume()
    XCTAssertFalse(directoryMonitor.isPaused, "Monitor should be resumed.")
  }

  func testDelegateDidFinishGathering() {
    mockDelegate.didFinishGatheringExpectation = expectation(description: "didFinishGathering called")
    directoryMonitor.start()
    wait(for: [mockDelegate.didFinishGatheringExpectation!], timeout: 5.0)
  }

  func testDelegateDidReceiveError() {
    mockDelegate.didReceiveErrorExpectation = expectation(description: "didReceiveLocalMonitorError called")

    let error = NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError, userInfo: nil)
    directoryMonitor.delegate?.didReceiveLocalMonitorError(error)

    wait(for: [mockDelegate.didReceiveErrorExpectation!], timeout: 1.0)
  }

  func testContentUpdateDetection() {
    let startExpectation = expectation(description: "Start monitoring")
    let didFinishGatheringExpectation = expectation(description: "didFinishGathering called")
    let didUpdateExpectation = expectation(description: "didUpdate called")

    mockDelegate.didFinishGatheringExpectation = didFinishGatheringExpectation
    mockDelegate.didUpdateExpectation = didUpdateExpectation

    
    directoryMonitor.start { result in
      if case .success = result {
        XCTAssertTrue(self.directoryMonitor.isStarted, "Monitor should be started.")
      }
      startExpectation.fulfill()
    }

    let fileURL = tempDirectory.appendingPathComponent("test.kml")
    self.fileManager.createFile(atPath: fileURL.path, contents: Data(), attributes: nil)

    wait(for: [startExpectation, didFinishGatheringExpectation, didUpdateExpectation], timeout: 10)
    XCTAssertTrue(directoryMonitor.contents.contains { $0.fileUrl == fileURL }, "Contents should contain the newly added file.")
  }
}
