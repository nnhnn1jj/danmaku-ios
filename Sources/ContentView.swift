import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var model = PlayerModel()
    @State private var settings = DanmakuSettings.load()

    @State private var showImporter = false
    @State private var showSearch = false
    @State private var showSettings = false
    @State private var toast: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if model.hasVideo {
                PlayerLayerView(player: model.player)
                    .ignoresSafeArea()
                DanmakuOverlay(items: model.danmaku,
                               settings: settings,
                               time: { model.currentTime })
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 18) {
                    Image(systemName: "play.rectangle.on.rectangle")
                        .font(.system(size: 58))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("选个视频开始")
                        .font(.title3)
                        .foregroundStyle(.white)
                    Text("视频会复制进 App，之后能直接播放")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            VStack {
                topBar
                Spacer()
                if model.hasVideo { bottomControls }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            if let toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.footnote)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .foregroundStyle(.white)
                        .padding(.bottom, 120)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toast)
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { importVideo(url) }
            case .failure(let err):
                say("导入失败：\(err.localizedDescription)")
            }
        }
        .sheet(isPresented: $showSearch) {
            SearchDanmakuView(model: model) { msg in say(msg) }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: $settings)
                .onDisappear {
                    settings.save()
                    model.player.rate = model.isPlaying ? 1 : 0
                }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                model.pause()
                model.player.replaceCurrentItem(with: nil)
                model.hasVideo = false
                model.currentTime = 0
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
            }
            .opacity(model.hasVideo ? 1 : 0)

            Spacer()

            if model.isLoadingDanmaku {
                ProgressView().tint(.white)
            }

            Button { showSearch = true } label: {
                Image(systemName: "magnifyingglass")
            }

            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
            }
        }
        .font(.body.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
    }

    private var bottomControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                Text(model.currentTimeText)
                Slider(
                    value: Binding(
                        get: { Double(min(model.currentTime, model.duration)) },
                        set: { model.seek(to: $0) }
                    ),
                    in: 0...max(model.duration, 1)
                )
                Text(PlayerModel.format(model.duration))
            }
            .font(.caption)
            .foregroundStyle(.white)

            HStack(spacing: 26) {
                Button { model.step(-10) } label: { Image(systemName: "gobackward.10") }
                Button { model.togglePlay() } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                Button { model.step(10) } label: { Image(systemName: "goforward.10") }

                Button {
                    settings.danmakuEnabled.toggle()
                    settings.save()
                } label: {
                    Image(systemName: settings.danmakuEnabled ? "text.bubble.fill" : "text.bubble")
                }

                Button {
                    if model.danmaku.isEmpty { showSearch = true } else {
                        model.danmaku = []
                        say("弹幕已清空")
                    }
                } label: {
                    Image(systemName: "xmark.bin")
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(.black.opacity(0.4), in: Capsule())
        }
        .padding(.bottom, 6)
    }

    private func importVideo(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = docs.appendingPathComponent(url.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: url, to: dest)
            model.load(url: dest)
            say("已加载 \(dest.lastPathComponent)")
        } catch {
            say("复制失败：\(error.localizedDescription)")
        }
    }

    private func say(_ text: String) {
        toast = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if toast == text { toast = nil }
        }
    }
}

/// 搜索弹幕：贴 BV 号 / 链接，或用弹弹play 按文件名匹配
struct SearchDanmakuView: View {
    @ObservedObject var model: PlayerModel
    var report: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                Section("B站 BV 号或视频链接") {
                    TextField("BV1xx411c7mD 或 https://b23.tv/xxxx", text: $input)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        loadBili()
                    } label: {
                        HStack {
                            Text("按 BV 号载入弹幕")
                            if busy { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(input.isEmpty || busy)
                }

                Section("按当前视频文件名匹配") {
                    Button {
                        loadDandanplay()
                    } label: {
                        Text("用「\(model.videoName)」去弹弹play 匹配")
                    }
                    .disabled(model.videoName.isEmpty || busy)
                }

                if !model.danmaku.isEmpty {
                    Section {
                        Text("已载入 \(model.danmaku.count) 条弹幕")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("找弹幕")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func loadBili() {
        busy = true
        Task {
            do {
                let list = try await BiliSource.load(input: input)
                await MainActor.run {
                    model.danmaku = list
                    busy = false
                    report("载入 \(list.count) 条弹幕")
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    busy = false
                    report(error.localizedDescription)
                }
            }
        }
    }

    private func loadDandanplay() {
        busy = true
        let s = DanmakuSettings.load()
        Task {
            do {
                let list = try await DandanplaySource.load(
                    fileName: model.videoName,
                    appId: s.dandanplayAppId,
                    appSecret: s.dandanplayAppSecret
                )
                await MainActor.run {
                    model.danmaku = list
                    busy = false
                    report("载入 \(list.count) 条弹幕")
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    busy = false
                    report(error.localizedDescription)
                }
            }
        }
    }
}
