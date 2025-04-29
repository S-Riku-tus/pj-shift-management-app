import SwiftUI
import UIKit
import VisionKit

struct ScannerView: View {
    @State private var showScanner = false
    @State private var scannedImage: UIImage?
    @State private var isProcessing = false
    @State private var recognizedText = ""
    @State private var extractedShifts: [ShiftEntry] = []
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("userName") private var userName: String = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if let image = scannedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                    
                    if isProcessing {
                        ProgressView("シフト解析中...")
                    } else if !extractedShifts.isEmpty {
                        VStack(alignment: .leading) {
                            Text("検出されたシフト:")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            List {
                                ForEach(extractedShifts) { shift in
                                    HStack {
                                        Text(shift.date, style: .date)
                                        Spacer()
                                        Text(shift.startTime.formatted(date: .omitted, time: .shortened))
                                        Text("-")
                                        Text(shift.endTime.formatted(date: .omitted, time: .shortened))
                                    }
                                }
                            }
                            .frame(height: 200)
                            
                            Button("カレンダーに保存") {
                                saveShiftsToCalendar()
                            }
                            .buttonStyle(.borderedProminent)
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                    } else if !recognizedText.isEmpty {
                        Text("シフトが検出できませんでした。")
                            .foregroundColor(.red)
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.viewfinder")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.blue)
                        
                        Text("シフト表を撮影またはアップロードして解析しましょう")
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Button("シフト表をスキャン") {
                            showScanner = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .navigationTitle("シフト解析")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        scannedImage = nil
                        recognizedText = ""
                        extractedShifts = []
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .disabled(scannedImage == nil)
                }
            }
            .sheet(isPresented: $showScanner) {
                DocumentScannerView(scannedImage: $scannedImage, completion: { 
                    if scannedImage != nil {
                        processImage()
                    }
                })
            }
        }
    }
    
    private func processImage() {
        guard let image = scannedImage else { return }
        
        isProcessing = true
        
        // OCRサービスを使用してテキスト認識
        OCRService.recognizeText(from: image) { result in
            switch result {
            case .success(let text):
                self.recognizedText = text
                
                // ユーザー名を基にシフト解析
                if !self.userName.isEmpty {
                    extractShifts(from: text, for: self.userName)
                } else {
                    // ユーザー名が設定されていない場合
                    extractedShifts = []
                }
            case .failure(let error):
                print("OCR Error: \(error)")
                self.recognizedText = ""
                self.extractedShifts = []
            }
            
            isProcessing = false
        }
    }
    
    private func extractShifts(from text: String, for userName: String) {
        // OCRサービスからのテキストデータを解析
        OCRService.extractShifts(from: text, for: userName) { shifts in
            self.extractedShifts = shifts
        }
    }
    
    private func saveShiftsToCalendar() {
        // Core Dataに保存
        for shift in extractedShifts {
            let newShift = ShiftModel(context: viewContext)
            newShift.id = UUID()
            newShift.date = shift.date
            newShift.startTime = shift.startTime
            newShift.endTime = shift.endTime
            newShift.notes = shift.notes
        }
        
        do {
            try viewContext.save()
            // 保存成功通知
            scannedImage = nil
            recognizedText = ""
            extractedShifts = []
        } catch {
            print("保存エラー: \(error)")
        }
    }
}

// DocumentScannerのラッパー
struct DocumentScannerView: UIViewControllerRepresentable {
    @Binding var scannedImage: UIImage?
    var completion: () -> Void
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = context.coordinator
        return scannerViewController
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var parent: DocumentScannerView
        
        init(_ parent: DocumentScannerView) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount > 0 else { return }
            
            let originalImage = scan.imageOfPage(at: 0)
            parent.scannedImage = originalImage
            controller.dismiss(animated: true) {
                self.parent.completion()
            }
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
            print("Scanner error: \(error)")
        }
    }
}