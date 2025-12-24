//
//  IPATool.swift
//  MuffinStoreJailed
//
//  تم الإنشاء بواسطة Mineek في 19/10/2024
//

// مستوحى بشكل كبير من ipatool-py
// https://github.com/NyaMisty/ipatool-py

import Foundation
import CommonCrypto
import Zip

// تحويل البيانات إلى تمثيل Hex
extension Data {
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}

// كلاس لحساب SHA1
class SHA1 {
    static func hash(_ data: Data) -> Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest)
    }
}

// تسهيل الوصول إلى أجزاء من النص
extension String {
    subscript (i: Int) -> String {
        return String(self[index(startIndex, offsetBy: i)])
    }

    subscript (r: Range<Int>) -> String {
        let start = index(startIndex, offsetBy: r.lowerBound)
        let end = index(startIndex, offsetBy: r.upperBound)
        return String(self[start..<end])
    }
}

// عميل متجر Apple Store
class StoreClient {
    var session: URLSession
    var appleId: String
    var password: String
    var guid: String?
    var accountName: String?
    var authHeaders: [String: String]?
    var authCookies: [HTTPCookie]?

    init(appleId: String, password: String) {
        session = URLSession.shared
        self.appleId = appleId
        self.password = password
    }

    // توليد GUID خاص بالحساب
    func generateGuid(appleId: String) -> String {
        print("جاري توليد GUID")
        let DEFAULT_GUID = "000C2941396B"
        let GUID_DEFAULT_PREFIX = 2
        let GUID_SEED = "CAFEBABE"
        let GUID_POS = 10

        let h = SHA1.hash((GUID_SEED + appleId + GUID_SEED).data(using: .utf8)!).hexString
        let defaultPart = DEFAULT_GUID.prefix(GUID_DEFAULT_PREFIX)
        let hashPart = h[GUID_POS..<GUID_POS + (DEFAULT_GUID.count - GUID_DEFAULT_PREFIX)]
        let guid = (defaultPart + hashPart).uppercased()

        print("تم إنشاء GUID: \(guid)")
        return guid
    }

    // حفظ بيانات المصادقة بشكل مشفّر
    func saveAuthInfo() {
        let cookiesData = NSKeyedArchiver.archivedData(withRootObject: authCookies!)
        let cookiesBase64 = cookiesData.base64EncodedString()

        let out: [String: Any] = [
            "appleId": appleId,
            "password": password,
            "guid": guid!,
            "accountName": accountName ?? "",
            "authHeaders": authHeaders!,
            "authCookies": cookiesBase64
        ]

        let data = try! JSONSerialization.data(withJSONObject: out)
        EncryptedKeychainWrapper.saveAuthInfo(base64: data.base64EncodedString())
    }

    // محاولة تحميل بيانات المصادقة المخزنة
    func tryLoadAuthInfo() -> Bool {
        guard let base64 = EncryptedKeychainWrapper.loadAuthInfo(),
              let data = Data(base64Encoded: base64),
              let out = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            print("لم يتم العثور على بيانات مصادقة")
            return false
        }

        appleId = out["appleId"] as! String
        password = out["password"] as! String
        guid = out["guid"] as? String
        accountName = out["accountName"] as? String
        authHeaders = out["authHeaders"] as? [String: String]

        let cookiesBase64 = out["authCookies"] as! String
        let cookiesData = Data(base64Encoded: cookiesBase64)!
        authCookies = NSKeyedUnarchiver.unarchiveObject(with: cookiesData) as? [HTTPCookie]

        print("تم تحميل بيانات المصادقة بنجاح")
        return true
    }

    // تسجيل الدخول إلى متجر iTunes
    func authenticate(requestCode: Bool = false) -> Bool {
        if guid == nil {
            guid = generateGuid(appleId: appleId)
        }

        var req: [String: String] = [
            "appleId": appleId,
            "password": password,
            "guid": guid!,
            "rmp": "0",
            "why": "signIn"
        ]

        let url = URL(string: "https://buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/authenticate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = [
            "Accept": "*/*",
            "Content-Type": "application/x-www-form-urlencoded",
            "User-Agent": "Configurator/2.17"
        ]

        var success = false

        for attempt in 1...4 {
            req["attempt"] = "\(attempt)"
            request.httpBody = try! JSONSerialization.data(withJSONObject: req)

            let task = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("خطأ أثناء المصادقة: \(error.localizedDescription)")
                    return
                }

                guard let data = data,
                      let resp = try? PropertyListSerialization.propertyList(from: data) as? [String: Any]
                else { return }

                if resp["m-allowed"] as? Bool == true {
                    print("تم تسجيل الدخول بنجاح")
                    let info = resp["download-queue-info"] as! [String: Any]
                    let dsid = info["dsid"] as! Int
                    let token = resp["passwordToken"] as! String

                    self.authHeaders = [
                        "X-Dsid": "\(dsid)",
                        "iCloud-Dsid": "\(dsid)",
                        "X-Token": token
                    ]

                    self.authCookies = self.session.configuration.httpCookieStorage?.cookies
                    self.saveAuthInfo()
                    success = true
                } else {
                    print("فشل تسجيل الدخول")
                }
            }

            task.resume()
            while task.state != .completed { sleep(1) }
            if success || requestCode { break }
        }

        return success
    }
}

// أداة التعامل مع IPA
class IPATool {
    var storeClient: StoreClient

    init(appleId: String, password: String) {
        print("تهيئة IPATool")
        storeClient = StoreClient(appleId: appleId, password: password)
    }

    // مصادقة المستخدم
    func authenticate(requestCode: Bool = false) -> Bool {
        print("جاري المصادقة مع متجر iTunes...")
        if !storeClient.tryLoadAuthInfo() {
            return storeClient.authenticate(requestCode: requestCode)
        }
        return true
    }

    // جلب قائمة معرفات الإصدارات
    func getVersionIDList(appId: String) -> [String] {
        print("جلب الإصدارات المتاحة للتطبيق \(appId)")
        let resp = storeClient.download(appId: appId, isRedownload: true)
        let songList = resp["songList"] as! [[String: Any]]
        guard let metadata = songList.first?["metadata"] as? [String: Any],
              let ids = metadata["softwareVersionExternalIdentifiers"] as? [Int]
        else {
            print("فشل جلب الإصدارات")
            return []
        }
        return ids.map { "\($0)" }
    }
}

// ==============================
// Keychain + Secure Enclave
// ==============================

class EncryptedKeychainWrapper {

    // إنشاء مفتاح تشفير داخل Secure Enclave
    static func generateAndStoreKey() {
        deleteKey()
        print("جاري إنشاء مفتاح تشفير")
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: "dev.mineek.muffinstorejailed.key",
                kSecAttrAccessControl as String:
                    SecAccessControlCreateWithFlags(
                        nil,
                        kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                        [.privateKeyUsage, .biometryAny],
                        nil
                    )!
            ]
        ]
        SecKeyCreateRandomKey(query as CFDictionary, nil)
        print("تم إنشاء المفتاح")
    }

    // حذف المفتاح
    static func deleteKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: "dev.mineek.muffinstorejailed.key"
        ]
        SecItemDelete(query as CFDictionary)
    }

    // حفظ بيانات المصادقة مشفّرة
    static func saveAuthInfo(base64: String) {
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("authinfo")
        try? base64.data(using: .utf8)?.write(to: path)
        print("تم حفظ بيانات المصادقة")
    }

    static func loadAuthInfo() -> String? {
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("authinfo")
        return try? String(contentsOf: path)
    }

    static func deleteAuthInfo() {
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("authinfo")
        try? FileManager.default.removeItem(at: path)
    }

    static func hasAuthInfo() -> Bool {
        return loadAuthInfo() != nil
    }

    static func getAuthInfo() -> [String: Any]? {
        guard let base64 = loadAuthInfo(),
              let data = Data(base64Encoded: base64),
              let out = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return out
    }

    static func nuke() {
        deleteAuthInfo()
        deleteKey()
    }
}
