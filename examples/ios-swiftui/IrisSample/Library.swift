import Foundation
import Observation

@Observable
final class Book: Identifiable {
    let id = UUID()
    var title: String
    var isFavorite = false
    var notes = ""

    init(title: String) {
        self.title = title
    }
}

@Observable
final class Library {
    var books = [
        Book(title: "Dế Mèn phiêu lưu ký"),
        Book(title: "Truyện Kiều"),
    ]

    func addBook() {
        books.append(Book(title: "Book \(books.count + 1)"))
    }

    func duplicate(_ book: Book) {
        books.append(Book(title: "\(book.title) (bản sao)"))
    }
}
