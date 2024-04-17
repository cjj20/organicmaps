protocol DirectoryMonitor {
  var isStarted: Bool { get }
  var isPaused: Bool { get }

  func start(completion: VoidResultCompletionHandler?)
  func stop()
  func pause()
  func resume()
}

protocol LocalDirectoryMonitor: DirectoryMonitor {
  var directory: URL { get }
  var delegate: LocalDirectoryMonitorDelegate? { get set }
}

protocol LocalDirectoryMonitorDelegate : AnyObject {
  func didFinishGathering(contents: LocalContents)
  func didUpdate(contents: LocalContents)
  func didReceiveLocalMonitorError(_ error: Error)
}

final class DefaultLocalDirectoryMonitor: LocalDirectoryMonitor {

  typealias Delegate = LocalDirectoryMonitorDelegate

  fileprivate enum State {
    case stopped
    case started(dirSource: DispatchSourceFileSystemObject)
    case debounce(dirSource: DispatchSourceFileSystemObject, timer: Timer)
  }

  private let fileManager: FileManager
  private let fileType: FileType
  private let resourceKeys: [URLResourceKey] = [.nameKey, .typeIdentifierKey]
  private var source: DispatchSourceFileSystemObject?
  private var state: State = .stopped
  private var didFinishGatheringIsCalled = false
  private(set) var contents = LocalContents()

  // MARK: - Public properties
  let directory: URL
  var isStarted: Bool { if case .stopped = state { false } else { true } }
  private(set) var isPaused: Bool = true
  weak var delegate: Delegate?

  init(fileManager: FileManager, directory: URL, fileType: FileType) {
    self.fileManager = fileManager
    self.directory = directory
    self.fileType = fileType
  }

  // MARK: - Public methods
  func start(completion: VoidResultCompletionHandler? = nil) {
    guard case .stopped = state else { return }

    let nowTimer = Timer.scheduledTimer(withTimeInterval: .zero, repeats: false) { [weak self] _ in
      self?.debounceTimerDidFire()
    }

    if let source {
      state = .debounce(dirSource: source, timer: nowTimer)
      resume()
      completion?(.success)
      return
    }

    do {
      let directorySource = try fileManager.source(for: directory)
      directorySource.setEventHandler { [weak self] in
        self?.queueDidFire()
      }
      source = directorySource
      state = .debounce(dirSource: directorySource, timer: nowTimer)
      resume()
      completion?(.success)
    } catch {
      stop()
      completion?(.failure(error))
    }
  }

  func stop() {
    pause()
    state = .stopped
    contents.removeAll()
    didFinishGatheringIsCalled = false
  }

  func pause() {
    source?.suspend()
    isPaused = true
  }

  func resume() {
    source?.resume()
    isPaused = false
  }

  // MARK: - Private
  private func queueDidFire() {
    let debounceTimeInterval = 0.2
    switch state {
    case .started(let directorySource):
      let timer = Timer.scheduledTimer(withTimeInterval: debounceTimeInterval, repeats: false) { [weak self] _ in
        self?.debounceTimerDidFire()
      }
      state = .debounce(dirSource: directorySource, timer: timer)
    case .debounce(_, let timer):
      timer.fireDate = Date(timeIntervalSinceNow: debounceTimeInterval)
      // Stay in the `.debounce` state.
    case .stopped:
      // This can happen if the read source fired and enqueued a block on the
      // main queue but, before the main queue got to service that block, someone
      // called `stop()`.  The correct response is to just do nothing.
      break
    }
  }

  private func debounceTimerDidFire() {
    guard !isPaused else { return }
    guard case .debounce(let dirSource, let timer) = state else { fatalError() }
    timer.invalidate()
    state = .started(dirSource: dirSource)

    let newContents = fileManager.contents(of: directory, matching: fileType.typeIdentifier, including: resourceKeys)
    let newContentMetadataItems = LocalContents(newContents.compactMap { url in
      do {
        let metadataItem = try LocalMetadataItem(fileUrl: url)
        return metadataItem
      } catch {
        delegate?.didReceiveLocalMonitorError(error)
        return nil
      }
    })

    if contents.isEmpty && !didFinishGatheringIsCalled {
      didFinishGatheringIsCalled = true
      delegate?.didFinishGathering(contents: newContentMetadataItems)
    } else {
      delegate?.didUpdate(contents: newContentMetadataItems)
    }
    contents = newContentMetadataItems
  }
}

private extension DefaultLocalDirectoryMonitor.State {
  var isRunning: Bool {
    switch self {
    case .stopped: return false
    case .started: return true
    case .debounce: return true
    }
  }
}

private extension FileManager {
  func source(for directory: URL) throws -> DispatchSourceFileSystemObject {
    if !fileExists(atPath: directory.path) {
      do {
        try createDirectory(at: directory, withIntermediateDirectories: true)
      } catch {
        throw error
      }
    }
    let directoryFileDescriptor = open(directory.path, O_EVTONLY)
    guard directoryFileDescriptor >= 0 else {
      let errorCode = errno
      throw NSError(domain: POSIXError.errorDomain, code: Int(errorCode), userInfo: nil)
    }
    let dispatchSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: directoryFileDescriptor, eventMask: [.write], queue: DispatchQueue.main)
    dispatchSource.setCancelHandler {
      close(directoryFileDescriptor)
    }
    return dispatchSource
  }

  // TODO: Implement an errors and exceptions handling
  func contents(of directory: URL, matching typeIdentifier: String, including: [URLResourceKey]) -> Set<URL> {
    guard let rawContents = try? contentsOfDirectory(at: directory, includingPropertiesForKeys: including, options: [.skipsHiddenFiles]) else {
      return []
    }
    // Filter the contents to include only those that match the type identifier.
    // TODO: This filtering should be removed when full directory sync including nested directories will be implemented.
    let filteredContents = rawContents.filter { url in
      guard let type = try? url.resourceValues(forKeys: [.typeIdentifierKey]), let urlType = type.typeIdentifier else {
        return false
      }
      return urlType == typeIdentifier
    }
    return Set(filteredContents)
  }
}
