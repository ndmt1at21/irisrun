import SwiftUI

struct LoginView: View {
    private enum Field {
        case account, password
    }

    @State private var account = ""
    @State private var password = ""
    @State private var signedInAs: String?
    @FocusState private var focus: Field?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let signedInAs {
                Text("Xin chào, \(signedInAs)!")
                    .font(.title2)
                ProfileCard(name: signedInAs)
                Button("Đăng xuất") {
                    self.signedInAs = nil
                    password = ""
                }
            } else {
                TextField("Email hoặc tên", text: $account)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focus, equals: .account)
                    .onSubmit { focus = .password }
                SecureField("Mật khẩu", text: $password)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .focused($focus, equals: .password)
                    .onSubmit(signIn)
                Button("Đăng nhập", action: signIn)
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Đăng nhập")
        .onAppear { focus = .account }
    }

    private func signIn() {
        guard !account.isEmpty, !password.isEmpty else {
            focus = account.isEmpty ? .account : .password
            return
        }
        signedInAs = account
        focus = nil
    }
}

/// Shapes, strokes and styled text, which the sample draws once someone signs in.
private struct ProfileCard: View {
    let name: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(-6)
                Text(String(name.prefix(1)).uppercased())
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 6) {
                Text("Đã ") + Text("đăng nhập").bold().italic() + Text(" bằng ") + Text("Telex").underline()
                Text("iOS 18")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.gradient)
                    .clipShape(Capsule())
            }
            Spacer()
            Path { path in
                path.move(to: CGPoint(x: 2, y: 12))
                path.addLine(to: CGPoint(x: 9, y: 19))
                path.addLine(to: CGPoint(x: 22, y: 4))
            }
            .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .frame(width: 24, height: 24)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white).shadow(color: .black.opacity(0.2), radius: 6, y: 3))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
    }
}
