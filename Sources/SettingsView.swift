import SwiftUI

struct SettingsView: View {
    @Binding var settings: DanmakuSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("弹幕样式") {
                    VStack(alignment: .leading) {
                        Text("字号 \(Int(settings.fontSize))")
                        Slider(value: $settings.fontSize, in: 10...30, step: 1)
                    }
                    VStack(alignment: .leading) {
                        Text("不透明度 \(Int(settings.opacity * 100))%")
                        Slider(value: $settings.opacity, in: 0.2...1.0)
                    }
                    VStack(alignment: .leading) {
                        Text("滚动速度 \(String(format: "%.1f", settings.speed)) 秒")
                        Slider(value: $settings.speed, in: 4...16, step: 0.5)
                    }
                    Stepper("屏上最多 \(settings.laneCount) 行", value: $settings.laneCount, in: 2...16)
                    Toggle("顶部弹幕", isOn: $settings.showTop)
                    Toggle("强制白色", isOn: $settings.unifiedWhite)
                }

                Section {
                    TextField("AppId", text: $settings.dandanplayAppId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("AppSecret", text: $settings.dandanplayAppSecret)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("弹弹play（可选）")
                } footer: {
                    Text("去 dandanplay.com 免费申请，填了才能按文件名自动匹配。不填也能用 B站 BV 号。")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        settings.save()
                        dismiss()
                    }
                }
            }
        }
    }
}
