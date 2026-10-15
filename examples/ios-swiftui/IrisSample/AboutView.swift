import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showsThanks = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("IrisSample")
                    .font(.title)
                Text("Một app SwiftUI chạy trên Iris.")
                    .foregroundStyle(.secondary)
                Button("Đánh giá") {
                    showsThanks = true
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Giới thiệu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") {
                        dismiss()
                    }
                }
            }
            .alert("Cảm ơn!", isPresented: $showsThanks) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Bạn đã đánh giá 5 sao.")
            }
        }
        .presentationDetents([.medium, .large])
    }
}
