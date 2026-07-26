import SwiftUI
import UIKit

struct PlaybackSharePayload: Identifiable {
    let id = UUID()
    let title: String
    let url: String

    var activityItems: [Any] {
        guard let value = URL(string: url) else { return [title, url] }
        return [title, value]
    }
}

struct PlaybackInformationPayload: Identifiable {
    let id = UUID()
    let title: String
    let request: PlaybackRequest
    let engineName: String
}

struct SystemShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct PlaybackInformationSheet: View {
    @Environment(\.presentationMode) private var presentationMode
    let payload: PlaybackInformationPayload

    var body: some View {
        NavigationView {
            List {
                Section("播放") {
                    informationRow(title: "名称", value: payload.title)
                    informationRow(title: "内核", value: payload.engineName)
                    if !payload.request.format.isEmpty {
                        informationRow(title: "格式", value: payload.request.format.uppercased())
                    }
                }

                Section("地址") {
                    Text(payload.request.url)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                    Button {
                        UIPasteboard.general.string = payload.request.url
                    } label: {
                        Label("复制地址", systemImage: "doc.on.doc")
                    }
                }

                if !payload.request.headers.isEmpty {
                    Section("请求头") {
                        ForEach(payload.request.headers.keys.sorted(), id: \.self) { key in
                            informationRow(
                                title: key,
                                value: PlaybackInformationPrivacy.headerValue(
                                    key: key,
                                    value: payload.request.headers[key] ?? ""
                                )
                            )
                        }
                    }
                }

                if !payload.request.cookies.isEmpty {
                    Section("Cookie") {
                        ForEach(payload.request.cookies.keys.sorted(), id: \.self) { key in
                            informationRow(title: key, value: "已附加")
                        }
                    }
                }
            }
            .navigationTitle("播放信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func informationRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(XingGuangTheme.secondaryText)
            Text(value)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }
}

enum PlaybackInformationPrivacy {
    static func headerValue(key: String, value: String) -> String {
        switch key.lowercased() {
        case "authorization", "proxy-authorization", "cookie", "set-cookie": return "已隐藏"
        default: return value
        }
    }
}

extension PlayerEngineKind {
    var displayName: String {
        switch self {
        case .mpv: return "MPV"
        case .mdk: return "MDK"
        case .avPlayer: return "AVPlayer"
        }
    }
}
