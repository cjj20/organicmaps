class FileManagerMock: FileManager {
  var mockUbiquityIdentityToken: UbiquityIdentityToken?
  var shouldReturnContainerURL: Bool = true

  override var ubiquityIdentityToken: (any UbiquityIdentityToken)? {
    return mockUbiquityIdentityToken
  }

  override func url(forUbiquityContainerIdentifier identifier: String?) -> URL? {
    return shouldReturnContainerURL ? URL(fileURLWithPath: NSTemporaryDirectory()) : nil
  }
}
