import SwiftUI

struct BookDetailView: View {
    @Bindable var book: Book
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text(book.title)
                .font(.title)
            Text(book.isFavorite ? "★ Favorite" : "Not a favorite")
                .foregroundStyle(.secondary)
                .contextMenu {
                    Button(book.isFavorite ? "Bỏ yêu thích" : "Yêu thích") {
                        book.isFavorite.toggle()
                    }
                    Menu("Chia sẻ") {
                        Button("Sao chép tên") {}
                    }
                }
            Button(book.isFavorite ? "Remove from favorites" : "Add to favorites") {
                book.isFavorite.toggle()
            }
            // A highlight over the button that taps go through.
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.yellow.opacity(0.2))
                    .allowsHitTesting(false)
            }
            TextEditor(text: $book.notes)
                .frame(height: 120)
                .background(Color(red: 0.95, green: 0.95, blue: 0.97))
        }
        .padding()
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Xong") {
                dismiss()
            }
        }
    }
}
