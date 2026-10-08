import SwiftUI
import UIKit

// MARK: - Color Extension (十六进制色彩解析)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - AppTheme 视觉与自然感设计系统 (深邃森林、鼠尾草绿与空间毛玻璃)
enum AppTheme {
    // 品牌核心色系 (深林翠绿与微光薄荷)
    static let forestDeep = Color(hex: "0D2620")       // 极深林绿色基调
    static let forestPrimary = Color(hex: "1F5F4B")    // 经典墨绿
    static let sageMint = Color(hex: "52B788")         // 鼠尾草薄荷绿 (主要高光)
    static let luminousMint = Color(hex: "74D7BA")     // 荧光微亮薄荷绿 (高对比度指示)
    
    // 暖色点缀 (沙漠暖金与晚霞珊瑚红)
    static let sunsetCoral = Color(hex: "FF6B52")      // 核心打卡高光
    static let warmAmber = Color(hex: "F4A261")        // 暖黄美食/标签
    static let sandIvory = Color(hex: "F9F6F0")        // 柔和暖白
    
    // 向前兼容别名
    static let mintGreen = sageMint
    static let sunsetGold = warmAmber
    
    // 交通辅助色
    static let indigoPrimary = Color(hex: "2B4C7E")    // 地铁/枢纽深蓝
    static let skyTeal = Color(hex: "2A9D8F")          // 公交/渡口青绿
    static let royalPurple = Color(hex: "795290")      // 特色换乘紫
    
    // 背景与卡片质感
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let tertiaryBackground = Color(uiColor: .tertiarySystemGroupedBackground)
    static let canvasBackground = Color(uiColor: .systemGroupedBackground)
    
    // 渐变方案
    static let brandGradient = LinearGradient(
        colors: [Color(hex: "1B5E4B"), Color(hex: "2D7F67"), Color(hex: "52B788")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let emeraldGlowGradient = LinearGradient(
        colors: [Color(hex: "2D6A4F"), Color(hex: "74D7BA")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let sunsetGradient = LinearGradient(
        colors: [Color(hex: "FF6B52"), Color(hex: "F4A261")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let mintGradient = LinearGradient(
        colors: [Color(hex: "2D6A4F"), Color(hex: "52B788"), Color(hex: "74D7BA")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let cardGlassBorder = LinearGradient(
        colors: [Color.white.opacity(0.35), Color.white.opacity(0.06)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - 触觉反馈管理器 (Taptic Engine)
@MainActor
enum HapticFeedback {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

// MARK: - 高级毛玻璃悬浮卡片 ViewModifier
struct GlassmorphicCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 22
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.cardGlassBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 5)
    }
}

struct ElevatedCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 24
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.04), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 22) -> some View {
        modifier(GlassmorphicCardModifier(cornerRadius: cornerRadius))
    }
    
    func elevatedCard(cornerRadius: CGFloat = 24) -> some View {
        modifier(ElevatedCardModifier(cornerRadius: cornerRadius))
    }
}
