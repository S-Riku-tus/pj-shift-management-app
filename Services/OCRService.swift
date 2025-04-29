import Foundation
import Vision
import UIKit

enum OCRServiceError: Error {
    case imageProcessingFailed
    case recognitionFailed
    case noTextFound
}

class OCRService {
    // 画像からテキストを認識する
    static func recognizeText(from image: UIImage, completion: @escaping (Result<String, OCRServiceError>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(.imageProcessingFailed))
            return
        }
        
        // リクエスト作成
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("OCR Error: \(error)")
                completion(.failure(.recognitionFailed))
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(.noTextFound))
                return
            }
            
            // 認識されたテキストを全て連結
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            if recognizedText.isEmpty {
                completion(.failure(.noTextFound))
            } else {
                completion(.success(recognizedText))
            }
        }
        
        // 日本語を含むテキスト認識設定
        request.recognitionLanguages = ["ja-JP", "en-US"]
        request.recognitionLevel = .accurate
        
        // リクエスト実行
        do {
            try requestHandler.perform([request])
        } catch {
            print("OCR Handler Error: \(error)")
            completion(.failure(.recognitionFailed))
        }
    }
    
    // 認識したテキストからシフト情報を抽出
    static func extractShifts(from text: String, for userName: String, completion: @escaping ([ShiftEntry]) -> Void) {
        // バックグラウンドスレッドで実行
        DispatchQueue.global(qos: .userInitiated).async {
            var extractedShifts: [ShiftEntry] = []
            
            // テキストを行ごとに分割
            let lines = text.components(separatedBy: .newlines)
            
            // 名前が出現する行を探索
            var userNameLines: [Int] = []
            for (index, line) in lines.enumerated() {
                if line.contains(userName) {
                    userNameLines.append(index)
                }
            }
            
            // 日付を含む行を探す（一般的なフォーマット）
            var dateLines: [(Int, Date)] = []
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "ja_JP")
            
            // 複数の日付フォーマットに対応
            let dateFormats = [
                "yyyy/MM/dd",
                "yyyy-MM-dd",
                "yyyy年MM月dd日",
                "MM/dd",
                "M月d日"
            ]
            
            for (index, line) in lines.enumerated() {
                for format in dateFormats {
                    dateFormatter.dateFormat = format
                    if let date = extractDate(from: line, with: dateFormatter) {
                        dateLines.append((index, date))
                        break
                    }
                }
            }
            
            // ユーザー名の行から近い日付行を関連付けてシフト抽出
            for userNameLine in userNameLines {
                // 最も近い日付行を見つける
                var closestDateLine: (line: Int, date: Date)? = nil
                var minDistance = Int.max
                
                for dateLine in dateLines {
                    let distance = abs(dateLine.0 - userNameLine)
                    if distance < minDistance {
                        minDistance = distance
                        closestDateLine = (dateLine.0, dateLine.1)
                    }
                }
                
                if let closestDate = closestDateLine?.date {
                    // 時間情報を抽出
                    if let (startTime, endTime) = extractTimeRange(from: lines[userNameLine]) {
                        // 日付と時間を組み合わせる
                        let calendar = Calendar.current
                        
                        var startComponents = calendar.dateComponents([.year, .month, .day], from: closestDate)
                        let startTimeComponents = calendar.dateComponents([.hour, .minute], from: startTime)
                        startComponents.hour = startTimeComponents.hour
                        startComponents.minute = startTimeComponents.minute
                        
                        var endComponents = calendar.dateComponents([.year, .month, .day], from: closestDate)
                        let endTimeComponents = calendar.dateComponents([.hour, .minute], from: endTime)
                        endComponents.hour = endTimeComponents.hour
                        endComponents.minute = endTimeComponents.minute
                        
                        // 終了時間が開始時間より早い場合は翌日と判断
                        if let startHour = startTimeComponents.hour, let endHour = endTimeComponents.hour, endHour < startHour {
                            endComponents.day! += 1
                        }
                        
                        if let startDateTime = calendar.date(from: startComponents),
                           let endDateTime = calendar.date(from: endComponents) {
                            
                            // メモ情報があれば抽出
                            var notes: String? = nil
                            let lineText = lines[userNameLine]
                            
                            // 時間情報以外の部分をメモとして抽出
                            if let timeRangeRange = lineText.range(of: "\\d{1,2}[:：]\\d{2}\\s*[-~～]\\s*\\d{1,2}[:：]\\d{2}", options: .regularExpression) {
                                let beforeTime = lineText[..<timeRangeRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                                let afterTime = lineText[timeRangeRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                                
                                // ユーザー名を除いた部分をメモとする
                                let noteText = (beforeTime + " " + afterTime).replacingOccurrences(of: userName, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                                
                                if !noteText.isEmpty {
                                    notes = noteText
                                }
                            }
                            
                            // シフトエントリ作成
                            let shift = ShiftEntry(
                                date: closestDate,
                                startTime: startDateTime,
                                endTime: endDateTime,
                                notes: notes
                            )
                            
                            extractedShifts.append(shift)
                        }
                    }
                }
            }
            
            // メインスレッドで結果を返す
            DispatchQueue.main.async {
                completion(extractedShifts)
            }
        }
    }
    
    // 文字列から日付を抽出
    private static func extractDate(from string: String, with formatter: DateFormatter) -> Date? {
        // 一般的な日付パターン
        let datePatterns = [
            "\\d{4}[/\\-年]\\d{1,2}[/\\-月]\\d{1,2}日?",  // yyyy/MM/dd, yyyy-MM-dd, yyyy年MM月dd日
            "\\d{1,2}[/\\-月]\\d{1,2}日?"                // MM/dd, M月d日
        ]
        
        for pattern in datePatterns {
            if let range = string.range(of: pattern, options: .regularExpression) {
                let dateString = String(string[range])
                
                // 年が省略されている場合は現在の年を使用
                var processedDateString = dateString
                if !dateString.contains("年") && !dateString.contains("/") && !dateString.contains("-") {
                    let currentYear = Calendar.current.component(.year, from: Date())
                    processedDateString = "\(currentYear)年" + processedDateString
                }
                
                if let date = formatter.date(from: processedDateString) {
                    return date
                }
            }
        }
        
        return nil
    }
    
    // 文字列から時間範囲を抽出
    private static func extractTimeRange(from string: String) -> (startTime: Date, endTime: Date)? {
        // HH:MM-HH:MM または H:MM-H:MM 形式のパターン
        let timePattern = "\\d{1,2}[:：]\\d{2}\\s*[-~～]\\s*\\d{1,2}[:：]\\d{2}"
        
        if let range = string.range(of: timePattern, options: .regularExpression) {
            let timeString = String(string[range])
            let components = timeString.components(separatedBy: CharacterSet(charactersIn: "-~～"))
            
            if components.count >= 2 {
                let startTimeString = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let endTimeString = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "ja_JP")
                dateFormatter.dateFormat = "HH:mm"
                
                // コロンが全角の場合は半角に変換
                let normalizedStartTime = startTimeString.replacingOccurrences(of: "：", with: ":")
                let normalizedEndTime = endTimeString.replacingOccurrences(of: "：", with: ":")
                
                if let startTime = dateFormatter.date(from: normalizedStartTime),
                   let endTime = dateFormatter.date(from: normalizedEndTime) {
                    return (startTime, endTime)
                }
            }
        }
        
        return nil
    }
    
    // テキストからシフト表の構造を解析（表形式の対応）
    static func parseShiftTable(from text: String, completion: @escaping ([String: [ShiftEntry]]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var userShifts: [String: [ShiftEntry]] = [:]
            
            // 表構造を検出するアルゴリズム
            // 1. 行を分割
            let lines = text.components(separatedBy: .newlines)
            
            // 2. 日付行を検出（最初の行に日付が並んでいることが多い）
            var dateRow: [Date] = []
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "ja_JP")
            
            for line in lines {
                // 日付が複数含まれる行を検索
                let potentialDates = extractAllDates(from: line)
                if potentialDates.count > 1 {
                    dateRow = potentialDates
                    break
                }
            }
            
            if !dateRow.isEmpty {
                // 日付行が見つかった場合、以降の行を名前とシフト時間のパターンとして処理
                for line in lines {
                    if let (name, shifts) = extractNameAndShifts(from: line, dates: dateRow) {
                        userShifts[name] = shifts
                    }
                }
            }
            
            DispatchQueue.main.async {
                completion(userShifts)
            }
        }
    }
    
    // 文字列から全ての日付を抽出
    private static func extractAllDates(from string: String) -> [Date] {
        var dates: [Date] = []
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")
        
        // 様々な日付フォーマットを試す
        let dateFormats = [
            "M/d", "MM/dd", "M月d日", "MM月dd日",
            "yyyy/M/d", "yyyy/MM/dd", "yyyy年M月d日", "yyyy年MM月dd日"
        ]
        
        // 日付っぽい部分を抽出
        let datePatterns = [
            "\\d{1,2}/\\d{1,2}",             // M/d, MM/dd
            "\\d{1,2}月\\d{1,2}日",          // M月d日, MM月dd日
            "\\d{4}/\\d{1,2}/\\d{1,2}",      // yyyy/M/d, yyyy/MM/dd
            "\\d{4}年\\d{1,2}月\\d{1,2}日"   // yyyy年M月d日, yyyy年MM月dd日
        ]
        
        // 文字列全体から日付パターンを検索
        for pattern in datePatterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            let nsString = string as NSString
            let matches = regex?.matches(in: string, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
            
            for match in matches {
                let dateString = nsString.substring(with: match.range)
                
                // 様々なフォーマットを試す
                for format in dateFormats {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: dateString) {
                        // 年が省略されている場合は現在の年を使用
                        var finalDate = date
                        if !dateString.contains("年") && !dateString.contains("/20") {
                            let calendar = Calendar.current
                            let currentYear = calendar.component(.year, from: Date())
                            let dateComponents = calendar.dateComponents([.month, .day], from: date)
                            var newComponents = DateComponents()
                            newComponents.year = currentYear
                            newComponents.month = dateComponents.month
                            newComponents.day = dateComponents.day
                            if let adjustedDate = calendar.date(from: newComponents) {
                                finalDate = adjustedDate
                            }
                        }
                        dates.append(finalDate)
                        break
                    }
                }
            }
        }
        
        return dates
    }
    
    // 行から名前とシフト情報を抽出
    private static func extractNameAndShifts(from line: String, dates: [Date]) -> (name: String, shifts: [ShiftEntry])? {
        // 名前とシフト情報を含む行のパターンを検出
        // 例: "山田太郎  9:00-17:00  休み  13:00-22:00 ..."
        
        // 時間パターン（例: 9:00-17:00）
        let timePattern = "\\d{1,2}[:：]\\d{2}\\s*[-~～]\\s*\\d{1,2}[:：]\\d{2}"
        let offPattern = "休|休み|off|OFF|Off"
        
        let regex = try? NSRegularExpression(pattern:
            "(.+?)\\s+((\(timePattern)|(\(offPattern)))\\s+((\(timePattern)|(\(offPattern)))\\s*)+", 
            options: [])
        
        let nsString = line as NSString
        if let match = regex?.firstMatch(in: line, options: [], range: NSRange(location: 0, length: nsString.length)) {
            // 最初のグループが名前
            let nameRange = match.range(at: 1)
            let name = nsString.substring(with: nameRange).trimmingCharacters(in: .whitespacesAndNewlines)
            
            var shifts: [ShiftEntry] = []
            
            // 残りの部分からシフトパターンを抽出
            let shiftPart = nsString.substring(from: nameRange.location + nameRange.length)
            let shiftTokens = shiftPart.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            
            // 日付数とシフトトークン数が一致する場合
            if shiftTokens.count >= dates.count {
                for i in 0..<dates.count {
                    let date = dates[i]
                    let shiftToken = shiftTokens[i]
                    
                    if shiftToken.lowercased() == "休み" || shiftToken.lowercased() == "off" {
                        // 休みの日はスキップ
                        continue
                    }
                    
                    if let (startTime, endTime) = extractTimeRange(from: shiftToken) {
                        // 日付と時間を組み合わせる
                        let calendar = Calendar.current
                        
                        var startComponents = calendar.dateComponents([.year, .month, .day], from: date)
                        let startTimeComponents = calendar.dateComponents([.hour, .minute], from: startTime)
                        startComponents.hour = startTimeComponents.hour
                        startComponents.minute = startTimeComponents.minute
                        
                        var endComponents = calendar.dateComponents([.year, .month, .day], from: date)
                        let endTimeComponents = calendar.dateComponents([.hour, .minute], from: endTime)
                        endComponents.hour = endTimeComponents.hour
                        endComponents.minute = endTimeComponents.minute
                        
                        // 終了時間が開始時間より早い場合は翌日と判断
                        if let startHour = startTimeComponents.hour, let endHour = endTimeComponents.hour, endHour < startHour {
                            endComponents.day! += 1
                        }
                        
                        if let startDateTime = calendar.date(from: startComponents),
                           let endDateTime = calendar.date(from: endComponents) {
                            
                            let shift = ShiftEntry(
                                date: date,
                                startTime: startDateTime,
                                endTime: endDateTime,
                                notes: nil
                            )
                            
                            shifts.append(shift)
                        }
                    }
                }
            }
            
            if !shifts.isEmpty {
                return (name, shifts)
            }
        }
        
        return nil
    }
}