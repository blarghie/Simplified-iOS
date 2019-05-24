import Foundation

let currentAccountIdentifierKey  = "NYPLCurrentAccountIdentifier"
let userAboveAgeKey              = "NYPLSettingsUserAboveAgeKey"
let userAcceptedEULAKey          = "NYPLSettingsUserAcceptedEULA"
let accountSyncEnabledKey        = "NYPLAccountSyncEnabledKey"


/// Manage the library accounts for the app.
/// Initialized with JSON.
@objcMembers final class AccountsManager: NSObject
{
  static let shared = AccountsManager()
  static let NYPLAccountUUIDs = [
    "urn:uuid:065c0c11-0d0f-42a3-82e4-277b18786949",
    "urn:uuid:edef2358-9f6a-4ce6-b64f-9b351ec68ac4",
    "urn:uuid:56906f26-2c9a-4ae9-bd02-552557720b99"
  ]
  
  // For Objective-C classes
  class func sharedInstance() -> AccountsManager
  {
    return AccountsManager.shared
  }
  
  let defaults: UserDefaults
  var accounts = [Account]()
  var currentAccount: Account {
    get {
      if account(defaults.string(forKey: currentAccountIdentifierKey) ?? "") == nil
      {
        defaults.set(AccountsManager.NYPLAccountUUIDs[0], forKey: currentAccountIdentifierKey)
      }
      return account(defaults.string(forKey: currentAccountIdentifierKey) ?? "")!
    }
    set {
      defaults.set(newValue.uuid, forKey: currentAccountIdentifierKey)
      NotificationCenter.default.post(name: NSNotification.Name(rawValue: NYPLCurrentAccountDidChangeNotification), object: nil)
    }
  }

  fileprivate override init()
  {
    self.defaults = UserDefaults.standard
    let url = Bundle.main.url(forResource: "Accounts", withExtension: "json")
    let data = try? Data(contentsOf: url!)
    do {
      let object = try JSONSerialization.jsonObject(with: data!, options: .allowFragments)
      if let array = object as? [[String: AnyObject]]
      {
        for jsonDict in array
        {
          let account = Account(json: jsonDict)
          if (account.inProduction ||
            (NYPLConfiguration.releaseStageIsBeta() && !UserDefaults.standard.bool(forKey: "prod_only"))) {
            self.accounts.append(account)
          }
        }
      }
    } catch {
      Log.error(#file, "Accounts.json was invalid. Error: \(error.localizedDescription)")
    }
  }
  
  func account(_ uuid:String) -> Account?
  {
    return self.accounts.filter{ $0.uuid == uuid }.first
  }
  
  func changeCurrentAccount(identifier uuid: String)
  {
    if let account = account(uuid) {
      self.currentAccount = account
    }
  }
}

/// Object representing one library account in the app. Patrons may
/// choose to sign up for multiple Accounts.
@objcMembers final class Account:NSObject
{
  let defaults: UserDefaults
  let logo: UIImage
  let uuid:String
  let name:String
  let subtitle:String?
  let needsAuth:Bool
  let authPasscodeLength:UInt
  let patronIDKeyboard:LoginKeyboard
  let pinKeyboard:LoginKeyboard
  let supportsSimplyESync:Bool
  let supportsBarcodeScanner:Bool
  let supportsBarcodeDisplay:Bool
  let supportsCardCreator:Bool
  let supportsReservations:Bool
  let catalogUrl:String?
  let cardCreatorUrl:String?
  let supportEmail:String?
  let mainColor:String?
  let inProduction:Bool
  
  fileprivate var urlAnnotations:URL?
  fileprivate var urlAcknowledgements:URL?
  fileprivate var urlContentLicenses:URL?
  fileprivate var urlEULA:URL?
  fileprivate var urlPrivacyPolicy:URL?
  
  var eulaIsAccepted:Bool {
    get {
      guard let result = getAccountDictionaryKey(userAcceptedEULAKey) else { return false }
      return result as! Bool
    }
    set {
      setAccountDictionaryKey(userAcceptedEULAKey, toValue: newValue as AnyObject)
    }
  }
  var syncPermissionGranted:Bool {
    get {
      guard let result = getAccountDictionaryKey(accountSyncEnabledKey) else { return false }
      return result as! Bool
    }
    set {
      setAccountDictionaryKey(accountSyncEnabledKey, toValue: newValue as AnyObject)
    }
  }
  var userAboveAgeLimit:Bool {
    get {
      guard let result = getAccountDictionaryKey(userAboveAgeKey) else { return false }
      return result as! Bool
    }
    set {
      setAccountDictionaryKey(userAboveAgeKey, toValue: newValue as AnyObject)
    }
  }
  
  init(json: [String: AnyObject])
  {
    defaults = UserDefaults.standard
    
    name = json["name"] as! String
    subtitle = json["subtitle"] as? String
    uuid = json["id_uuid"] as! String
    needsAuth = json["needsAuth"] as! Bool
    supportsReservations = json["supportsReservations"] as! Bool
    supportsSimplyESync = json["supportsSimplyESync"] as! Bool
    supportsBarcodeScanner = json["supportsBarcodeScanner"] as! Bool
    supportsBarcodeDisplay = json["supportsBarcodeDisplay"] as! Bool
    supportsCardCreator = json["supportsCardCreator"] as! Bool
    catalogUrl = json["catalogUrl"] as? String
    cardCreatorUrl = json["cardCreatorUrl"] as? String
    supportEmail = json["supportEmail"] as? String
    mainColor = json["mainColor"] as? String
    patronIDKeyboard = LoginKeyboard(json["loginKeyboard"] as? String) ?? .standard
    pinKeyboard = LoginKeyboard(json["pinKeyboard"] as? String) ?? .standard
    inProduction = json["inProduction"] as! Bool

    let logoString = json["logo"] as? String
    if let modString = logoString?.replacingOccurrences(of: "data:image/png;base64,", with: ""),
      let logoData = Data.init(base64Encoded: modString),
      let logoImage = UIImage(data: logoData) {
      logo = logoImage
    } else {
      logo = UIImage.init(named: "LibraryLogoMagic")!
    }

    if let length = json["authPasscodeLength"] as? UInt {
      authPasscodeLength = length
    } else {
      authPasscodeLength = 0
    }
  }

  func setURL(_ URL: URL, forLicense urlType: URLType) -> Void {
    switch urlType {
    case .acknowledgements:
      urlAcknowledgements = URL
      setAccountDictionaryKey("urlAcknowledgements", toValue: URL.absoluteString as AnyObject)
    case .contentLicenses:
      urlContentLicenses = URL
      setAccountDictionaryKey("urlContentLicenses", toValue: URL.absoluteString as AnyObject)
    case .eula:
      urlEULA = URL
      setAccountDictionaryKey("urlEULA", toValue: URL.absoluteString as AnyObject)
    case .privacyPolicy:
      urlPrivacyPolicy = URL
      setAccountDictionaryKey("urlPrivacyPolicy", toValue: URL.absoluteString as AnyObject)
    case .annotations:
      urlAnnotations = URL
      setAccountDictionaryKey("urlAnnotations", toValue: URL.absoluteString as AnyObject)
    }
  }
  
  func getLicenseURL(_ type: URLType) -> URL? {
    switch type {
    case .acknowledgements:
      if let url = urlAcknowledgements {
        return url
      } else {
        guard let urlString = getAccountDictionaryKey("urlAcknowledgements") as? String else { return nil }
        guard let result = URL(string: urlString) else { return nil }
        return result
      }
    case .contentLicenses:
      if let url = urlContentLicenses {
        return url
      } else {
        guard let urlString = getAccountDictionaryKey("urlContentLicenses") as? String else { return nil }
        guard let result = URL(string: urlString) else { return nil }
        return result
      }
    case .eula:
      if let url = urlEULA {
        return url
      } else {
        guard let urlString = getAccountDictionaryKey("urlEULA") as? String else { return nil }
        guard let result = URL(string: urlString) else { return nil }
        return result
      }
    case .privacyPolicy:
      if let url = urlPrivacyPolicy {
        return url
      } else {
        guard let urlString = getAccountDictionaryKey("urlPrivacyPolicy") as? String else { return nil }
        guard let result = URL(string: urlString) else { return nil }
        return result
      }
    case .annotations:
      if let url = urlAnnotations {
        return url
      } else {
        guard let urlString = getAccountDictionaryKey("urlAnnotations") as? String else { return nil }
        guard let result = URL(string: urlString) else { return nil }
        return result
      }
    }
  }
  
  fileprivate func setAccountDictionaryKey(_ key: String, toValue value: AnyObject) {
    if var savedDict = defaults.value(forKey: self.uuid) as? [String: AnyObject] {
      savedDict[key] = value
      defaults.set(savedDict, forKey: self.uuid)
    } else {
      defaults.set([key:value], forKey: self.uuid)
    }
  }
  
  fileprivate func getAccountDictionaryKey(_ key: String) -> AnyObject? {
    let savedDict = defaults.value(forKey: self.uuid) as? [String: AnyObject]
    guard let result = savedDict?[key] else { return nil }
    return result
  }
}

@objc enum URLType: Int {
  case acknowledgements
  case contentLicenses
  case eula
  case privacyPolicy
  case annotations
}

@objc enum LoginKeyboard: Int {
  case standard
  case email
  case numeric
  case none

  init?(_ stringValue: String?) {
    if stringValue == "Default" {
      self = .standard
    } else if stringValue == "Email address" {
      self = .email
    } else if stringValue == "Number pad" {
      self = .numeric
    } else if stringValue == "No input" {
      self = .none
    } else {
      Log.error(#file, "Invalid init parameter for PatronPINKeyboard: \(stringValue ?? "nil")")
      return nil
    }
  }
}
