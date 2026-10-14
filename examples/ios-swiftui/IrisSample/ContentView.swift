import SwiftUI

struct ContentView: View {
    @State private var count = 0
    @State private var library = Library()

    var body: some View {
        NavigationStack {
            List {
                HStack {
                    Text("Count: \(count)")
                    Spacer()
                    Button("Increment") {
                        count += 1
                    }
                }
                ForEach(library.books) { book in
                    NavigationLink {
                        BookDetailView(book: book)
                    } label: {
                        BookRow(book: book)
                    }
                }
                Button("Add book") {
                    library.addBook()
                }
            }
            .navigationTitle("Library")
        }
    }
}

struct BookRow: View {
    let book: Book

    var body: some View {
        HStack {
            Text(book.title)
            Spacer()
            if book.isFavorite {
                Text("★")
            }
        }
    }
}
