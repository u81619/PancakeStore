//
//  ContentView.swift
//  MuffinStoreJailed
//
//  تم الإنشاء بواسطة Mineek في 26/12/2024
//

import SwiftUI

struct ContentView: View {
    // أداة التعامل مع ملفات IPA
    @State var ipaTool: IPATool?
    
    // بيانات تسجيل الدخول
    @State var appleId: String = ""
    @State var password: String = ""
    @State var code: String = ""
    
    // حالات التطبيق
    @State var isAuthenticated: Bool = false
    @State var isDowngrading: Bool = false
    
    // رابط التطبيق من App Store
    @State var appLink: String = ""
    
    // حالات الواجهة
    @State var hasSent2FACode: Bool = false
    @State var showLogs: Bool = false
    @State var showPassword: Bool = false
    
    // بيانات مشتركة
    @ObservedObject var sharedData = SharedData.shared
    
    var body: some View {
        NavigationStack {
            List {
                // عرض السجلات
                if showLogs {
                    Section(header: LabelStyle(text: "السجلات", icon: "terminal")) {
                        GlassyTerminal {
                            LogView()
                        }
                    }
                }
                
                // واجهة تسجيل الدخول
                if !isAuthenticated {
                    Section(
                        header: HeaderStyle(text: "Apple ID", icon: "icloud"),
                        footer: Text("تم الإنشاء بواسطة mineek، تعديلات الواجهة بواسطة lunginspector لصالح jailbreak.party. استخدم هذه الأداة على مسؤوليتك الخاصة! قد يتم فقدان بيانات التطبيقات أو حدوث أضرار أخرى.")
                    ) {
                        VStack {
                            TextField("البريد الإلكتروني", text: $appleId)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .textFieldStyle(GlassyTextFieldStyle(isDisabled: hasSent2FACode))
                            
                            HStack {
                                if showPassword {
                                    TextField("كلمة المرور", text: $password)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .textFieldStyle(GlassyTextFieldStyle(isDisabled: hasSent2FACode))
                                } else {
                                    SecureField("كلمة المرور", text: $password)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .textFieldStyle(GlassyTextFieldStyle(isDisabled: hasSent2FACode))
                                }
                                
                                Button(action: {
                                    showPassword.toggle()
                                }) {
                                    Image(systemName: showPassword ? "eye" : "eye.slash")
                                        .frame(width: 20, height: 22)
                                }
                                .buttonStyle(GlassyButtonStyle())
                                .frame(width: 50)
                            }
                        }
                    }
                    
                    // إدخال رمز التحقق الثنائي
                    if hasSent2FACode {
                        Section(
                            header: HeaderStyle(text: "رمز التحقق (2FA)", icon: "key"),
                            footer: Text("إذا لم يصلك إشعار على أي جهاز موثوق، أدخل أي ستة أرقام عشوائية. صدقني 😄")
                        ) {
                            TextField("رمز التحقق", text: $code)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .textFieldStyle(GlassyTextFieldStyle())
                        }
                    }
                } else {
                    // واجهة تنزيل النسخة الأقدم
                    if isDowngrading {
                        Section {
                            HStack(spacing: 12) {
                                ProgressView()
                                VStack(alignment: .leading) {
                                    Text("جاري تنزيل نسخة أقدم من التطبيق...")
                                        .fontWeight(.medium)
                                    Text("قد تستغرق العملية بعض الوقت، وقد يتجمد PancakeStore مؤقتًا.")
                                        .font(.footnote)
                                }
                            }
                        }
                    } else {
                        // إدخال رابط التطبيق
                        Section(
                            header: HeaderStyle(text: "تنزيل إصدار أقدم", icon: "arrow.down.app"),
                            footer: Text("تم الإنشاء بواسطة mineek، تعديلات الواجهة بواسطة lunginspector. استخدم الأداة على مسؤوليتك.")
                        ) {
                            HStack {
                                TextField("رابط التطبيق من App Store", text: $appLink)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .textFieldStyle(GlassyTextFieldStyle())
                                
                                Button(action: {
                                    Haptic.shared.play(.soft)
                                    appLink = UIPasteboard.general.string ?? ""
                                }) {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(GlassyButtonStyle())
                                .frame(width: 50)
                            }
                        }
                    }
                }
            }
            .navigationTitle("PancakeStore")
            .safeAreaInset(edge: .bottom) {
                VStack {
                    // أزرار التحكم السفلية
                    if !isAuthenticated {
                        Button(action: {
                            Haptic.shared.play(.soft)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                if appleId.isEmpty || password.isEmpty {
                                    Alertinator.shared.alert(
                                        title: "بيانات Apple ID ناقصة",
                                        body: "يرجى إدخال البريد الإلكتروني وكلمة المرور ثم المحاولة مرة أخرى."
                                    )
                                }
                                if code.isEmpty {
                                    ipaTool = IPATool(appleId: appleId, password: password)
                                    ipaTool?.authenticate(requestCode: true)
                                    hasSent2FACode = true
                                    return
                                }
                                let finalPassword = password + code
                                ipaTool = IPATool(appleId: appleId, password: finalPassword)
                                let ret = ipaTool?.authenticate()
                                isAuthenticated = ret ?? false
                            }
                        }) {
                            if hasSent2FACode {
                                LabelStyle(text: "تسجيل الدخول", icon: "arrow.right")
                            } else {
                                LabelStyle(text: "إرسال رمز التحقق", icon: "key")
                            }
                        }
                        .buttonStyle(GlassyButtonStyle(
                            isDisabled: hasSent2FACode ? code.isEmpty : false,
                            isMaterialButton: true
                        ))
                    } else {
                        if isDowngrading {
                            Button(action: {
                                Haptic.shared.play(.heavy)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    exitinator()
                                }
                            }) {
                                LabelStyle(text: "الذهاب إلى الشاشة الرئيسية", icon: "house")
                            }
                            .buttonStyle(GlassyButtonStyle(
                                isDisabled: !sharedData.hasAppBeenServed,
                                isMaterialButton: true
                            ))
                        } else {
                            Button(action: {
                                Haptic.shared.play(.soft)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    if appLink.isEmpty { return }
                                    
                                    var appLinkParsed = appLink
                                    appLinkParsed = appLinkParsed.components(separatedBy: "id").last ?? ""
                                    
                                    for char in appLinkParsed {
                                        if !char.isNumber {
                                            appLinkParsed = String(
                                                appLinkParsed.prefix(
                                                    upTo: appLinkParsed.firstIndex(of: char)!
                                                )
                                            )
                                            break
                                        }
                                    }
                                    
                                    print("معرّف التطبيق: \(appLinkParsed)")
                                    isDowngrading = true
                                    downgradeApp(appId: appLinkParsed, ipaTool: ipaTool!)
                                }
                            }) {
                                LabelStyle(text: "تنزيل إصدار أقدم", icon: "arrow.down")
                            }
                            .buttonStyle(GlassyButtonStyle(isMaterialButton: true))
                            
                            Button(action: {
                                Haptic.shared.play(.heavy)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    isAuthenticated = false
                                    EncryptedKeychainWrapper.nuke()
                                    EncryptedKeychainWrapper.generateAndStoreKey()
                                    sleep(3)
                                    exitinator()
                                }
                            }) {
                                LabelStyle(text: "تسجيل الخروج والخروج من التطبيق", icon: "xmark")
                            }
                            .buttonStyle(GlassyButtonStyle(color: .red, isMaterialButton: true))
                        }
                    }
                }
                .padding(.horizontal, 25)
                .padding(.top, 30)
                .background(
                    VariableBlurView(
                        maxBlurRadius: 5,
                        direction: .blurredBottomClearTop
                    ).ignoresSafeArea()
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        Haptic.shared.play(.soft)
                        showLogs.toggle()
                    }) {
                        Image(systemName: "terminal")
                    }
                }
            }
            .onAppear {
                isAuthenticated = EncryptedKeychainWrapper.hasAuthInfo()
                print("تم العثور على \(isAuthenticated ? "بيانات مصادقة" : "لا توجد بيانات مصادقة") في Keychain")
                
                if isAuthenticated {
                    guard let authInfo = EncryptedKeychainWrapper.getAuthInfo() else {
                        print("فشل جلب بيانات المصادقة، سيتم تسجيل الخروج")
                        isAuthenticated = false
                        EncryptedKeychainWrapper.nuke()
                        EncryptedKeychainWrapper.generateAndStoreKey()
                        return
                    }
                    
                    appleId = authInfo["appleId"] as! String
                    password = authInfo["password"] as! String
                    ipaTool = IPATool(appleId: appleId, password: password)
                    let ret = ipaTool?.authenticate()
                    print("إعادة المصادقة \(ret! ? "نجحت" : "فشلت")")
                } else {
                    print("لا توجد بيانات مصادقة، يتم إنشاء مفتاح جديد في SEP")
                    EncryptedKeychainWrapper.generateAndStoreKey()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
