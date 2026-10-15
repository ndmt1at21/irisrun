import SwiftUI

struct BookDetailView: View {
    @Bindable var book: Book

    var body: some View {
        VStack(spacing: 16) {
            Text(book.title)
                .font(.title)
            Text(book.isFavorite ? "★ Favorite" : "Not a favorite")
                .foregroundStyle(.secondary)
            Button(book.isFavorite ? "Remove from favorites" : "Add to favorites") {
                book.isFavorite.toggle()
            }
            TextEditor(text: $book.notes)
                .frame(height: 120)
                .background(Color(red: 0.95, green: 0.95, blue: 0.97))
        }
        .padding()
        .navigationTitle(book.title)
    }
}
