import SwiftUI

/// 应用主 Tab 导航容器
struct MainTabView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: 行程与攻略联动
            TripListView()
                .tabItem {
                    Label("行程", systemImage: "map.fill")
                }
                .tag(0)
            
            // Tab 2: 全局足迹大地图
            FootprintMapView()
                .tabItem {
                    Label("足迹", systemImage: "location.north.circle.fill")
                }
                .tag(1)
            
            // Tab 3: 行前打包清单
            ChecklistTabView()
                .tabItem {
                    Label("行前准备", systemImage: "checklist")
                }
                .tag(2)
        }
        .tint(AppTheme.forestPrimary)
        .onChange(of: selectedTab) { _, _ in
            HapticFeedback.selection()
        }
    }
}
