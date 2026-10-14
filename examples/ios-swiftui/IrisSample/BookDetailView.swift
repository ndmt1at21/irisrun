import SwiftUI

struct BookDetailView: View {
    let book: Book

    var body: some View {
        VStack(spacing: 16) {
            Text(book.title)
                .font(.title)
            Text(book.isFavorite ? "★ Favorite" : "Not a favorite")
                .foregroundStyle(.secondary)
            Button(book.isFavorite ? "Remove from favorites" : "Add to favorites") {
                book.isFavorite.toggle()
            }
        }
        .padding()
        .navigationTitle(book.title)
    }
}
