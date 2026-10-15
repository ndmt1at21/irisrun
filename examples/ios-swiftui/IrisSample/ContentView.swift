import SwiftUI

struct ContentView: View {
    @State private var count = 0
    @State private var library = Library()
    @State private var showsAbout = false

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
                    NavigationLink(value: book.id) {
                        BookRow(book: book)
                    }
                    .contextMenu {
                        Button("Nhân bản") {
                            library.duplicate(book)
                        }
                    }
                }
                .onDelete { offsets in
                    library.books.remove(atOffsets: offsets)
                }
                Button("Add book") {
                    library.addBook()
                }
                NavigationLink("Đăng nhập") {
                    LoginView()
                }
                NavigationLink("Cài đặt") {
                    SettingsView()
                }
                NavigationLink("Bộ sưu tập") {
                    CollectionView(library: library)
                }
            }
            .navigationTitle("Library")
            .navigationDestination(for: UUID.self) { id in
                if let book = library.books.first(where: { $0.id == id }) {
                    BookDetailView(book: book)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Giới thiệu") {
                        showsAbout = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Thêm") {
                        library.addBook()
                    }
                }
            }
            .sheet(isPresented: $showsAbout) {
                AboutView()
            }
        }
    }
}

struct BookRow: View {
    let book: Book

    var body: some View {
        HStack {
            Image("BookCover")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
            Text(book.title)
            Spacer()
            if book.isFavorite {
                Text("★")
            }
        }
    }
}
