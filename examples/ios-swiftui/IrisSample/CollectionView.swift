import SwiftUI

struct CollectionView: View {
    let library: Library
    @State private var tab = Tab.covers

    @State private var picked: String?

    enum Tab {
        case covers, stats, titles
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
                Divider()
                Link("Đọc thêm", destination: URL(string: "https://vi.wikipedia.org/wiki/Truyện_Kiều")!)
            }
            .padding()
            .tabItem {
                Label("Thống kê", systemImage: "chart.bar")
            }
            .tag(Tab.stats)

            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    HStack {
                        Text("Đã chọn: \(picked ?? "chưa có")")
                        Spacer()
                        Button("Về cuối") {
                            withAnimation {
                                proxy.scrollTo(library.books.last?.id, anchor: .bottom)
                            }
                        }
                    }
                    .padding()
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(library.books) { book in
                                Button(book.title) {
                                    picked = book.title
                                }
                                .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .tabItem {
                Label("Tên sách", systemImage: "list.bullet")
            }
            .tag(Tab.titles)
        }
        .navigationTitle("Bộ sưu tập")
    }
}
