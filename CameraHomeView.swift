import SwiftUI
import AVFoundation
import Photos

struct CameraHomeView: View {
    @StateObject private var camera = CameraModel()
    @State private var mode: CaptureMode = .photo
    @State private var showControls = false
    @State private var showStyles = false
    @State private var selectedStyle: NativeStyle = .standard
    @State private var selectedFilm: FilmPreset = .fuji400
    @State private var palettePoint = CGPoint(x: 0.70, y: 0.45)
    @State private var intensity: Double = 0.75
    @State private var exposure: Double = 0
    @State private var toast: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topControls
                Spacer()
                if showStyles {
                    stylePanel
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if showControls {
                    quickControls
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                captureControls
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)

            if let toast {
                VStack {
                    Text(toast)
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                    Spacer()
                }
                .padding(.top, 60)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.toast = nil
                    }
                }
            }
        }
        .statusBarHidden()
        .task { await camera.requestAndStart() }
        .onChange(of: selectedStyle) { _, _ in camera.look = currentLook }
        .onChange(of: selectedFilm) { _, _ in camera.look = currentLook }
        .onChange(of: palettePoint) { _, _ in camera.look = currentLook }
        .onChange(of: intensity) { _, _ in camera.look = currentLook }
        .onChange(of: exposure) { _, _ in camera.look = currentLook }
        .alert("Camera permission needed", isPresented: $camera.showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Allow camera and microphone access in Settings to use this camera.")
        }
    }

    private var currentLook: ImageLook {
        ImageLook(style: selectedStyle, film: mode == .film ? selectedFilm : nil,
                  point: palettePoint, intensity: intensity, exposure: exposure)
    }

    private var topControls: some View {
        // Keep the primary controls in the native Camera app's familiar positions:
        // flash at leading edge, Live Photo centered, and expanded controls at trailing edge.
        HStack {
            Button { camera.toggleFlash() } label: {
                Image(systemName: camera.flashEnabled ? "bolt.fill" : "bolt.slash")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(camera.flashEnabled ? .yellow : .white)
                    .frame(width: 40, height: 40)
                    .glassBackground()
            }
            Spacer(minLength: 0)
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    showControls.toggle()
                    if showControls { showStyles = false }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 19, weight: .bold))
                    .frame(width: 40, height: 40)
                    .glassBackground()
            }
        }
        .overlay(alignment: .center) {
            Button {
                guard camera.livePhotoSupported else {
                    toast = "此设备不支持实况照片"
                    return
                }
                camera.livePhotoEnabled.toggle()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                toast = camera.livePhotoEnabled ? "实况照片已开启" : "实况照片已关闭"
            } label: {
                Image(systemName: camera.livePhotoEnabled ? "livephoto" : "livephoto.slash")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(camera.livePhotoEnabled ? Color.yellow : Color.white)
                    .frame(width: 40, height: 40)
                    .glassBackground()
                    .opacity(camera.livePhotoSupported ? 1 : 0.45)
            }
            .disabled(!camera.livePhotoSupported)
            .accessibilityLabel(camera.livePhotoEnabled ? "关闭实况照片" : "开启实况照片")
            .accessibilityHint("实况照片控制，位于顶部中央")
        }
        .foregroundStyle(.white)
    }

    private var quickControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        showStyles = true
                        showControls = false
                    }
                } label: {
                    Label("Styles", systemImage: "circle.lefthalf.filled")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .glassBackground()
                }
                Spacer()
                Text("Exposure")
                    .font(.caption)
                Slider(value: $exposure, in: -1.5...1.5, step: 0.1)
                    .frame(maxWidth: 150)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }

    private var stylePanel: some View {
        VStack(spacing: 12) {
            HStack {
                Text(mode == .film ? "Film" : "Styles")
                    .font(.headline)
                Spacer()
                Button("Reset") {
                    palettePoint = CGPoint(x: 0.5, y: 0.5)
                    intensity = 0.75
                    exposure = 0
                }
                .font(.subheadline.weight(.medium))
            }
            if mode == .film {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(FilmPreset.allCases) { preset in
                            Button {
                                selectedFilm = preset
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                VStack(spacing: 5) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(preset.swatch)
                                        .frame(width: 54, height: 48)
                                        .overlay {
                                            if selectedFilm == preset {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(.white, lineWidth: 2)
                                            }
                                        }
                                    Text(preset.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(NativeStyle.allCases) { style in
                            Button {
                                selectedStyle = style
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text(style.rawValue)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 11).padding(.vertical, 8)
                                    .background(selectedStyle == style ? Color.white.opacity(0.24) : Color.white.opacity(0.08), in: Capsule())
                                    .overlay(Capsule().stroke(selectedStyle == style ? .white.opacity(0.8) : .clear, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                DotPalette(point: $palettePoint)
                    .frame(height: 156)
                HStack {
                    Text("Tone / Color")
                        .font(.caption)
                    Spacer()
                    Text("Intensity")
                        .font(.caption)
                    Slider(value: $intensity, in: 0...1)
                        .frame(maxWidth: 125)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private var captureControls: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center) {
                Button {
                    camera.openLatestPhoto()
                } label: {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 21))
                        .frame(width: 48, height: 48)
                        .glassBackground()
                }
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    if mode == .video || mode == .portrait || mode == .panorama {
                        toast = mode == .video ? "视频录制尚未实现" : "此相机模式尚未实现"
                    } else {
                        camera.capture(look: currentLook) { success in
                            toast = success ? (camera.livePhotoEnabled && camera.livePhotoSupported ? "实况照片已保存到照片图库" : "照片已保存到照片图库") : "保存失败，请检查照片权限和存储空间"
                        }
                    }
                } label: {
                    ZStack {
                        Circle().stroke(.white, lineWidth: 4).frame(width: 76, height: 76)
                        Circle().fill(mode == .video && camera.isRecording ? .red : .white)
                            .frame(width: mode == .video && camera.isRecording ? 30 : 62,
                                   height: mode == .video && camera.isRecording ? 30 : 62)
                            .animation(.spring(response: 0.25), value: camera.isRecording)
                    }
                }
                Spacer()
                Button {
                    camera.flipCamera()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 21))
                        .frame(width: 48, height: 48)
                        .glassBackground()
                }
            }
            modePicker
        }
        .padding(.bottom, 10)
        .foregroundStyle(.white)
    }

    private var modePicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 22) {
                    ForEach(CaptureMode.allCases) { item in
                        Button {
                            withAnimation(.snappy(duration: 0.2)) {
                                mode = item
                                showStyles = item == .film
                                showControls = false
                            }
                            proxy.scrollTo(item.id, anchor: .center)
                            camera.look = ImageLook(style: selectedStyle,
                                film: item == .film ? selectedFilm : nil,
                                point: palettePoint, intensity: intensity, exposure: exposure)
                        } label: {
                            Text(item.rawValue)
                                .font(.system(size: 14, weight: mode == item ? .bold : .medium))
                                .foregroundStyle(mode == item ? .yellow : .white.opacity(0.72))
                                .scaleEffect(mode == item ? 1.08 : 1)
                        }
                        .buttonStyle(.plain)
                        .id(item.id)
                    }
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

enum CaptureMode: String, CaseIterable, Identifiable {
    case video = "视频"
    case portrait = "人像"
    case photo = "照片"
    case film = "胶片"
    case panorama = "全景"
    var id: String { rawValue }
}

enum NativeStyle: String, CaseIterable, Identifiable {
    case standard = "标准"
    case amber = "琥珀色"
    case gold = "金色"
    case roseGold = "玫瑰金"
    case neutral = "自然"
    case vibrant = "鲜明"
    case warm = "温馨"
    case ethereal = "空灵"
    case dramatic = "戏剧"
    case luminous = "明亮"
    case monochrome = "黑白"
    var id: String { rawValue }
}

enum FilmPreset: String, CaseIterable, Identifiable {
    case fuji400 = "FUJI 400"
    case kodak800 = "KODAK 800"
    case fujiCool = "FUJI 青调"
    case kodakWarm = "KODAK 暖黄"
    var id: String { rawValue }
    var swatch: LinearGradient {
        switch self {
        case .fuji400, .fujiCool:
            return LinearGradient(colors: [Color(red: 0.15, green: 0.78, blue: 0.82), .blue, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .kodak800, .kodakWarm:
            return LinearGradient(colors: [.yellow, .orange, Color(red: 0.38, green: 0.12, blue: 0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

private extension View {
    @ViewBuilder func glassBackground() -> some View {
        if #available(iOS 26.0, *) {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.22), lineWidth: 1))
        }
    }
}
