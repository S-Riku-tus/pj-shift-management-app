import SwiftUI

struct ShiftCalendarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ShiftModel.date, ascending: true)],
        animation: .default)
    private var shifts: FetchedResults<ShiftModel>
    
    @State private var selectedDate = Date()
    @State private var showingMonthView = true
    
    // カレンダー表示用の日付関連変数
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    @State private var selectedMonth: Date = Date()
    
    var body: some View {
        NavigationView {
            VStack {
                // 月表示・週表示切り替え
                Picker("表示", selection: $showingMonthView) {
                    Text("月").tag(true)
                    Text("週").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // 年月表示と月移動ボタン
                HStack {
                    Button(action: previousMonth) {
                        Image(systemName: "chevron.left")
                    }
                    
                    Spacer()
                    
                    Text(monthYearString(from: selectedMonth))
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: nextMonth) {
                        Image(systemName: "chevron.right")
                    }
                }
                .padding(.horizontal)
                
                if showingMonthView {
                    // 月表示
                    MonthCalendarView(
                        selectedDate: $selectedDate,
                        selectedMonth: $selectedMonth,
                        shifts: shifts
                    )
                } else {
                    // 週表示
                    WeekCalendarView(
                        selectedDate: $selectedDate,
                        selectedMonth: $selectedMonth,
                        shifts: shifts
                    )
                }
                
                // 選択日のシフト詳細
                DayDetailView(selectedDate: $selectedDate, shifts: shifts)
            }
            .navigationTitle("シフトカレンダー")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("今日") {
                        selectedDate = Date()
                        selectedMonth = Date()
                    }
                }
            }
        }
    }
    
    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
            selectedMonth = newDate
        }
    }
    
    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
            selectedMonth = newDate
        }
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }
}

// 月カレンダービュー
struct MonthCalendarView: View {
    @Binding var selectedDate: Date
    @Binding var selectedMonth: Date
    let shifts: FetchedResults<ShiftModel>
    
    private let calendar = Calendar.current
    private let weekdays = ["日", "月", "火", "水", "木", "金", "土"]
    
    var body: some View {
        VStack(spacing: 1) {
            // 曜日の見出し
            HStack(spacing: 1) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundColor(day == "日" ? .red : (day == "土" ? .blue : .primary))
                }
            }
            
            // 日付グリッド
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 1) {
                ForEach(daysInMonth(), id: \.self) { date in
                    if let date = date {
                        DayCellView(
                            date: date,
                            selectedDate: $selectedDate,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            shifts: shiftsForDate(date)
                        )
                    } else {
                        // 空のセル
                        Rectangle()
                            .foregroundColor(.gray.opacity(0.1))
                            .aspectRatio(1, contentMode: .fill)
                    }
                }
            }
        }
        .padding(.vertical)
    }
    
    // 月のすべての日付を取得（先頭の空白を含む）
    private func daysInMonth() -> [Date?] {
        var days: [Date?] = []
        
        guard let monthRange = calendar.range(of: .day, in: .month, for: selectedMonth),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)) else {
            return days
        }
        
        // 月の最初の日の曜日を取得（0 = 日曜日、1 = 月曜日 ... 6 = 土曜日）
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) - 1
        
        // 先頭の空のセル
        for _ in 0..<firstWeekday {
            days.append(nil)
        }
        
        // 月の日を追加
        for day in monthRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
    
    // 特定の日のシフト情報を取得
    private func shiftsForDate(_ date: Date) -> [ShiftModel] {
        return shifts.filter { shift in
            calendar.isDate(shift.date ?? Date(), inSameDayAs: date)
        }
    }
}

// 週カレンダービュー
struct WeekCalendarView: View {
    @Binding var selectedDate: Date
    @Binding var selectedMonth: Date
    let shifts: FetchedResults<ShiftModel>
    
    private let calendar = Calendar.current
    private let weekdays = ["日", "月", "火", "水", "木", "金", "土"]
    
    var body: some View {
        VStack(spacing: 8) {
            // 週の移動ボタン
            HStack {
                Button(action: previousWeek) {
                    Image(systemName: "chevron.left")
                        .padding(8)
                }
                
                Spacer()
                
                Button(action: nextWeek) {
                    Image(systemName: "chevron.right")
                        .padding(8)
                }
            }
            .padding(.horizontal)
            
            // 日付と曜日の表示
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(daysInSelectedWeek(), id: \.self) { date in
                        VStack {
                            // 曜日
                            Text(weekdayString(from: date))
                                .font(.caption)
                                .foregroundColor(isWeekend(date) ? .blue : .primary)
                            
                            // 日付セル
                            ZStack {
                                Circle()
                                    .fill(calendar.isDate(date, inSameDayAs: selectedDate) ? Color.blue : Color.clear)
                                    .frame(width: 40, height: 40)
                                
                                Circle()
                                    .stroke(calendar.isDateInToday(date) ? Color.red : Color.clear, lineWidth: 1)
                                    .frame(width: 40, height: 40)
                                
                                Text("\(calendar.component(.day, from: date))")
                                    .foregroundColor(calendar.isDate(date, inSameDayAs: selectedDate) ? .white : .primary)
                            }
                            
                            // シフト表示
                            if !shiftsForDate(date).isEmpty {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .onTapGesture {
                            selectedDate = date
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // シフト情報の詳細表示（日別）
            List {
                ForEach(shiftsForDate(selectedDate), id: \.self) { shift in
                    HStack {
                        Text(formatTime(shift.startTime ?? Date()))
                        Text("-")
                        Text(formatTime(shift.endTime ?? Date()))
                        Spacer()
                        if let notes = shift.notes, !notes.isEmpty {
                            Text(notes)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
            }
            .listStyle(PlainListStyle())
        }
    }
    
    // 選択された日付の週の日付を取得
    private func daysInSelectedWeek() -> [Date] {
        var dates: [Date] = []
        
        // 週の初日（日曜日）を計算
        let weekdayComponents = calendar.dateComponents([.weekday], from: selectedDate)
        let weekday = weekdayComponents.weekday! - 1 // 0 = 日曜日
        
        if let sunday = calendar.date(byAdding: .day, value: -weekday, to: selectedDate) {
            // 日曜日から土曜日まで7日間
            for i in 0..<7 {
                if let date = calendar.date(byAdding: .day, value: i, to: sunday) {
                    dates.append(date)
                }
            }
        }
        
        return dates
    }
    
    // 特定の日付のシフト情報を取得
    private func shiftsForDate(_ date: Date) -> [ShiftModel] {
        return shifts.filter { shift in
            calendar.isDate(shift.date ?? Date(), inSameDayAs: date)
        }
    }
    
    // 週末かどうかを判定
    private func isWeekend(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7 // 1 = 日曜日, 7 = 土曜日
    }
    
    // 曜日の日本語表記を取得
    private func weekdayString(from date: Date) -> String {
        let weekday = calendar.component(.weekday, from: date) - 1
        return weekdays[weekday]
    }
    
    // 時間のフォーマット
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // 前の週へ移動
    private func previousWeek() {
        if let newDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) {
            selectedDate = newDate
            selectedMonth = newDate
        }
    }
    
    // 次の週へ移動
    private func nextWeek() {
        if let newDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) {
            selectedDate = newDate
            selectedMonth = newDate
        }
    }
}

// 日セル表示
struct DayCellView: View {
    let date: Date
    @Binding var selectedDate: Date
    let isSelected: Bool
    let isToday: Bool
    let shifts: [ShiftModel]
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 2) {
            // 日付表示
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .frame(width: 32, height: 32)
                
                Circle()
                    .stroke(isToday ? Color.red : Color.clear, lineWidth: 1)
                    .frame(width: 32, height: 32)
                
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .white : (isToday ? .red : .primary))
            }
            
            // シフト表示（簡易）
            if !shifts.isEmpty {
                ForEach(0..<min(shifts.count, 2), id: \.self) { index in
                    HStack(spacing: 2) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 4, height: 4)
                        
                        if let startTime = shifts[index].startTime {
                            Text(formatHourOnly(startTime))
                                .font(.system(size: 9))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
                }
                
                if shifts.count > 2 {
                    Text("...")
                        .font(.system(size: 9))
                }
            }
        }
        .frame(height: 60)
        .background(Color(UIColor.systemBackground))
        .onTapGesture {
            selectedDate = date
        }
    }
    
    private func formatHourOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "H時"
        return formatter.string(from: date)
    }
}

// 日詳細ビュー
struct DayDetailView: View {
    @Binding var selectedDate: Date
    let shifts: FetchedResults<ShiftModel>
    
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    
    init(selectedDate: Binding<Date>, shifts: FetchedResults<ShiftModel>) {
        self._selectedDate = selectedDate
        self.shifts = shifts
        
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(dateFormatter.string(from: selectedDate))
                .font(.headline)
                .padding(.horizontal)
            
            if shiftsForSelectedDate.isEmpty {
                VStack {
                    Spacer()
                    Text("シフトはありません")
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(height: 100)
            } else {
                List {
                    ForEach(shiftsForSelectedDate, id: \.self) { shift in
                        HStack {
                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: "clock")
                                    Text("\(formatTime(shift.startTime ?? Date())) - \(formatTime(shift.endTime ?? Date()))")
                                }
                                
                                if let notes = shift.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            
                            Text(formatDuration(shift.startTime ?? Date(), shift.endTime ?? Date()))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteShift)
                }
                .listStyle(PlainListStyle())
                .frame(height: 150)
            }
        }
        .padding(.bottom)
    }
    
    private var shiftsForSelectedDate: [ShiftModel] {
        shifts.filter { shift in
            guard let shiftDate = shift.date else { return false }
            return calendar.isDate(shiftDate, inSameDayAs: selectedDate)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ start: Date, _ end: Date) -> String {
        let components = calendar.dateComponents([.hour, .minute], from: start, to: end)
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        return "\(hours)時間\(minutes)分"
    }
    
    private func deleteShift(at offsets: IndexSet) {
        // Context取得とシフト削除処理はここに実装
    }
}