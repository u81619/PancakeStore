//
//  Downgrader.swift
//  MuffinStoreJailed
//
//  تم الإنشاء بواسطة Mineek في 19/10/2024
//

import Foundation
import UIKit
import Telegraph
import Zip
import SwiftUI
import SafariServices

// WebView لعرض Safari داخل SwiftUI
struct SafariWebView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // لا يوجد تحديث مطلوب
    }
}

// تنزيل إصدار محدد من التطبيق
func downgradeAppToVersion(appId: String, versionId: String, ipaTool: IPATool) {
    @ObservedObject var sharedData = SharedData.shared
    
    let path = ipaTool.downloadIPAForVersion(appId: appId, appVerId: versionId)
    print("تم تنزيل ملف IPA إلى \(path)")
    
    let tempDir = FileManager.default.temporaryDirectory
    let contents = try! FileManager.default.contentsOfDirectory(atPath: path)
    print("المحتويات: \(contents)")
    
    let destinationUrl = tempDir.appendingPathComponent("app.ipa")
    try! Zip.zipFiles(
        paths: contents.map { URL(fileURLWithPath: path).appendingPathComponent($0) },
        zipFilePath: destinationUrl,
        password: nil,
        progress: nil
    )
    print("تم ضغط IPA إلى \(destinationUrl)")
    
    let path2 = URL(fileURLWithPath: path)
    var appDir = path2.appendingPathComponent("Payload")
    
    // البحث عن مجلد التطبيق
    for file in try! FileManager.default.contentsOfDirectory(atPath: appDir.path) {
        if file.hasSuffix(".app") {
            print("تم العثور على التطبيق: \(file)")
            appDir = appDir.appendingPathComponent(file)
            break
        }
    }
    
    let infoPlistPath = appDir.appendingPathComponent("Info.plist")
    let infoPlist = NSDictionary(contentsOf: infoPlistPath)!
    let appBundleId = infoPlist["CFBundleIdentifier"] as! String
    let appVersion = infoPlist["CFBundleShortVersionString"] as! String
    
    print("معرّف الحزمة: \(appBundleId)")
    print("إصدار التطبيق: \(appVersion)")

    let finalURL =
        "https://api.palera.in/genPlist?bundleid=\(appBundleId)&name=\(appBundleId)&version=\(appVersion)&fetchurl=http://127.0.0.1:9090/signed.ipa"
    
    let installURL =
        "itms-services://?action=download-manifest&url=" +
        finalURL.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
    
    DispatchQueue.global(qos: .background).async {
        let server = Server()

        // تقديم ملف IPA الموقّع
        server.route(.GET, "signed.ipa", { _ in
            print("يتم تقديم signed.ipa")
            let signedIPAData = try Data(contentsOf: destinationUrl)
            return HTTPResponse(body: signedIPAData)
        })

        // صفحة التثبيت
        server.route(.GET, "install", { _ in
            print("يتم تقديم صفحة التثبيت")
            sharedData.hasAppBeenServed = true
            let installPage = """
            <script type="text/javascript">
                window.location = "\(installURL)"
            </script>
            """
            return HTTPResponse(
                .ok,
                headers: ["Content-Type": "text/html"],
                content: installPage
            )
        })
        
        try! server.start(port: 9090)
        print("بدأ الخادم بالاستماع")
        
        DispatchQueue.main.async {
            print("طلب تثبيت التطبيق")
            let majoriOSVersion =
                Int(UIDevice.current.systemVersion.components(separatedBy: ".").first!)!
            
            if majoriOSVersion >= 18 {
                // iOS 18+ (حل لمشكلة تظهر لدى بعض المستخدمين)
                let safariView =
                    SafariWebView(url: URL(string: "http://127.0.0.1:9090/install")!)
                UIApplication.shared.windows.first?.rootViewController?
                    .present(
                        UIHostingController(rootView: safariView),
                        animated: true,
                        completion: nil
                    )
            } else {
                // iOS 17 وأقل
                UIApplication.shared.open(URL(string: installURL)!)
            }
        }
        
        while server.isRunning {
            sleep(1)
        }
        print("تم إيقاف الخادم")
    }
}

// طلب إدخال معرّف الإصدار يدويًا
func promptForVersionId(appId: String, versionIds: [String], ipaTool: IPATool) {
    let isiPad = UIDevice.current.userInterfaceIdiom == .pad
    let alert = UIAlertController(
        title: "إدخال معرّف الإصدار",
        message: "اختر الإصدار الذي تريد الرجوع إليه",
        preferredStyle: isiPad ? .alert : .actionSheet
    )
    
    for versionId in versionIds {
        alert.addAction(UIAlertAction(title: versionId, style: .default) { _ in
            downgradeAppToVersion(
                appId: appId,
                versionId: versionId,
                ipaTool: ipaTool
            )
        })
    }
    
    alert.addAction(UIAlertAction(title: "إلغاء", style: .cancel))
    UIApplication.shared.windows.first?.rootViewController?
        .present(alert, animated: true)
}

// عرض تنبيه عام
func showAlert(title: String, message: String) {
    let alert = UIAlertController(
        title: title,
        message: message,
        preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "موافق", style: .default))
    UIApplication.shared.windows.first?.rootViewController?
        .present(alert, animated: true)
}

// جلب جميع إصدارات التطبيق من الخادم
func getAllAppVersionIdsFromServer(appId: String, ipaTool: IPATool) {
    let serverURL = "https://apis.bilin.eu.org/history/"
    let url = URL(string: "\(serverURL)\(appId)")!
    
    let task = URLSession.shared.dataTask(with: url) { data, _, error in
        if let error = error {
            DispatchQueue.main.async {
                showAlert(title: "خطأ", message: error.localizedDescription)
            }
            return
        }
        
        let json = try! JSONSerialization.jsonObject(with: data!) as! [String: Any]
        let versionIds = json["data"] as! [[String: Any]]
        
        if versionIds.isEmpty {
            DispatchQueue.main.async {
                showAlert(title: "خطأ", message: "لا توجد إصدارات متاحة")
            }
            return
        }
        
        DispatchQueue.main.async {
            let isiPad = UIDevice.current.userInterfaceIdiom == .pad
            let alert = UIAlertController(
                title: "اختيار إصدار",
                message: "اختر الإصدار الذي تريد الرجوع إليه",
                preferredStyle: isiPad ? .alert : .actionSheet
            )
            
            for versionId in versionIds {
                alert.addAction(UIAlertAction(
                    title: "\(versionId["bundle_version"]!)",
                    style: .default
                ) { _ in
                    downgradeAppToVersion(
                        appId: appId,
                        versionId: "\(versionId["external_identifier"]!)",
                        ipaTool: ipaTool
                    )
                })
            }
            
            alert.addAction(UIAlertAction(title: "إلغاء", style: .cancel))
            UIApplication.shared.windows.first?.rootViewController?
                .present(alert, animated: true)
        }
    }
    
    task.resume()
}

// بدء عملية الرجوع لإصدار أقدم
func downgradeApp(appId: String, ipaTool: IPATool) {
    let versionIds = ipaTool.getVersionIDList(appId: appId)
    let isiPad = UIDevice.current.userInterfaceIdiom == .pad
    
    let alert = UIAlertController(
        title: "معرّف الإصدار",
        message: "هل تريد إدخال معرّف الإصدار يدويًا أم جلب القائمة من الخادم؟",
        preferredStyle: isiPad ? .alert : .actionSheet
    )
    
    alert.addAction(UIAlertAction(title: "يدوي", style: .default) { _ in
        promptForVersionId(
            appId: appId,
            versionIds: versionIds,
            ipaTool: ipaTool
        )
    })
    
    alert.addAction(UIAlertAction(title: "من الخادم", style: .default) { _ in
        getAllAppVersionIdsFromServer(appId: appId, ipaTool: ipaTool)
    })
    
    alert.addAction(UIAlertAction(title: "إلغاء", style: .cancel))
    UIApplication.shared.windows.first?.rootViewController?
        .present(alert, animated: true)
}
