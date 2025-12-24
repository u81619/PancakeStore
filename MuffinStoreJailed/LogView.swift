import SwiftUI

// واجهة عرض السجل (Logs)
struct LogView: View {
    // النص الذي يحتوي على سجل الإخراج
    @State var log: String = ""
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    // عرض محتوى السجل
                    Text(log)
                        .padding(.top)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .multilineTextAlignment(.leading)
                    
                    // عنصر وهمي للتمرير التلقائي للأسفل
                    Spacer()
                        .id(0)
                }
                .onAppear {
                    // قراءة مخرجات stdout من الـ Pipe
                    pipe.fileHandleForReading.readabilityHandler = { fileHandle in
                        let data = fileHandle.availableData
                        
                        if data.isEmpty { 
                            // حالة نهاية الملف (EOF)
                            fileHandle.readabilityHandler = nil
                            sema.signal()
                        } else {
                            // إضافة البيانات الجديدة إلى السجل
                            log.append(String(data: data, encoding: .utf8)!)
                            
                            // التمرير تلقائياً إلى آخر السجل
                            DispatchQueue.main.async {
                                proxy.scrollTo(0)
                            }
                        }
                    }
                    
                    // إعادة توجيه stdout
                    // print("إعادة توجيه stdout")
                    setvbuf(stdout, nil, _IONBF, 0)
                    dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
                }
                // قائمة السياق (عند الضغط المطوّل)
                .contextMenu {
                    Button {
                        // نسخ السجل إلى الحافظة
                        UIPasteboard.general.string = log
                    } label: {
                        Label("نسخ المخرجات", systemImage: "doc.on.doc")
                    }
                }
            }
        }
    }
}
