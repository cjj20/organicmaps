@objc enum SynchronizationError: Int, Error {
  case fileUnavailable
  case fileNotUploadedDueToQuota
  case ubiquityServerNotAvailable
  case iCloudIsNotAvailable
  case containerNotFound
}

extension SynchronizationError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .fileUnavailable, .ubiquityServerNotAvailable:
      return L("icloud_synchronization_error_connection_error")
    case .fileNotUploadedDueToQuota:
      return L("icloud_synchronization_error_quota_exceeded")
    case .iCloudIsNotAvailable, .containerNotFound:
      return L("icloud_synchronization_error_cloud_is_unavailable")
    }
  }
}

extension SynchronizationError {
  static func fromError(_ error: Error) -> SynchronizationError? {
    let nsError = error as NSError
    switch nsError.code {
      // NSURLUbiquitousItemDownloadingErrorKey contains an error with this code when the item has not been uploaded to iCloud by the other devices yet
    case NSUbiquitousFileUnavailableError:
      return .fileUnavailable
      // NSURLUbiquitousItemUploadingErrorKey contains an error with this code when the item has not been uploaded to iCloud because it would make the account go over-quota
    case NSUbiquitousFileNotUploadedDueToQuotaError:
      return .fileNotUploadedDueToQuota
      // NSURLUbiquitousItemDownloadingErrorKey and NSURLUbiquitousItemUploadingErrorKey contain an error with this code when connecting to the iCloud servers failed
    case NSUbiquitousFileUbiquityServerNotAvailable:
      return .ubiquityServerNotAvailable
    default:
      return nil
    }
  }
}
