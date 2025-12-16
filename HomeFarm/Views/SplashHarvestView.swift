import SwiftUI
import Combine

struct HarvestBoxSplashView: View {
    @StateObject private var presenter = HarvestBoxPresenter()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if presenter.currentHarvestPhase == .setup || presenter.displayPermView {
                HarvestInitScreen()
            }
            
            ActiveHarvestContent(presenter: presenter)
                .opacity(presenter.displayPermView ? 0 : 1)
            
            if presenter.displayPermView {
                HarvestPermView(
                    onAllow: presenter.processGrantPerm,
                    onSkip: presenter.processSkipPerm
                )
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct ActiveHarvestContent: View {
    @ObservedObject var presenter: HarvestBoxPresenter
    
    var body: some View {
        Group {
            switch presenter.currentHarvestPhase {
            case .setup:
                EmptyView()
                
            case .operational:
                if presenter.harvestURL != nil {
                    HarvestMainView()
                } else {
                    ContentView()
                }
                
            case .legacy:
                ContentView()
                
            case .disconnected:
                HarvestNoConnectionScreen()
            }
        }
    }
}
