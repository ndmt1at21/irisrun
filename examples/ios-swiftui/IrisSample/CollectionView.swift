import SwiftUI

struct CollectionView: View {
    let library: Library
    @State private var tab = Tab.covers

    enum Tab {
        case covers, stats
    }

    var body: some View {
        TabView(selection: $tab) {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                    ForEach(library.books) { book in
                        VStack {
                            Image("BookCover")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 64)
                            Text(book.title)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
                .padding()
            }
            .tabItem {
                Label("Bìa sách", systemImage: "square.grid.2x2")
            }
            .tag(Tab.covers)

            VStack(spacing: 8) {
                Text("\(library.books.count) cuốn sách")
                    .font(.title)
                Text("\(library.books.filter(\.isFavorite).count) cuốn yêu thích")
                    .foregroundStyle(.secondary)
            }
            .tabItem {
                Label("Thống kê", systemImage: "chart.bar")
            }
            .tag(Tab.stats)
        }
        .navigationTitle("Bộ sưu tập")
    }
}
