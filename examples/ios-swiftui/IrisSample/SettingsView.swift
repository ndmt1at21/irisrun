import SwiftUI

struct SettingsView: View {
    @State private var notifications = true
    @State private var fontSize = 17.0
    @State private var downloaded = 0.4
    @State private var copies = 1
    @State private var appearance = Appearance.system
    @State private var sort = "Tên"

    enum Appearance: String, CaseIterable {
        case light = "Sáng"
        case dark = "Tối"
        case system = "Tự động"
    }

    var body: some View {
        Form {
            Section("Thông báo") {
                Toggle("Thông báo", isOn: $notifications)
                Label("Âm thanh", systemImage: "speaker.wave.2")
            }
            Section {
                Text("Cỡ chữ: \(Int(fontSize))")
                Slider(value: $fontSize, in: 12 ... 28, step: 1)
                Stepper("Số bản: \(copies)", value: $copies, in: 1 ... 5)
            } header: {
                Text("Hiển thị")
            } footer: {
                Text("Áp dụng cho mọi sách.")
            }
            Section {
                Picker("Giao diện", selection: $appearance) {
                    ForEach(Appearance.allCases, id: \.self) { appearance in
                        Text(appearance.rawValue).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
                Picker("Sắp xếp", selection: $sort) {
                    Text("Tên").tag("Tên")
                    Text("Ngày thêm").tag("Ngày thêm")
                }
            } footer: {
                Text("Chế độ: \(appearance.rawValue)")
            }
            ProgressView("Đã tải", value: downloaded)
        }
        .navigationTitle("Cài đặt")
    }
}
