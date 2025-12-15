import SwiftUI
import Combine

final class HarvestView: ObservableObject, HarvestViewInterface {
    @Published var currentPhase: HarvestPhaseEntity = .initPhase
    @Published var showPermissions: Bool = false
    @Published var harvestConfigURL: URL?
    
    private let presenter: HarvestPresenterInterface
    
    init(presenter: HarvestPresenterInterface = HarvestPresenter(interactor: HarvestInteractor())) {
        self.presenter = presenter
        presenter.attachView(self)
    }
    
    func setPhase(_ phase: HarvestPhaseEntity) {
        currentPhase = phase
    }
    
    func showPermDialog() {
        showPermissions = true
    }
    
    func setConfigURL(_ url: URL?) {
        harvestConfigURL = url
    }
    
    func evaluateState() {
        presenter.evaluateCurrentState()
    }
    
    func handleSkip() {
        presenter.onSkipPerm()
        showPermissions = false
    }
    
    func handleGrant() {
        presenter.onGrantPerm()
    }
    
    func disapearPermissionsScreen() {
        showPermissions = false
    }
}

struct SplashHarvestView: View {
    
    @StateObject private var harvestView = HarvestView()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if harvestView.currentPhase == .initPhase || harvestView.showPermissions {
                HarvestInitScreen()
            }
            
            ActiveHarvestContent(harvestView: harvestView)
                .opacity(harvestView.showPermissions ? 0 : 1)
            
            if harvestView.showPermissions {
                HarvestPermView(
                    onAllow: harvestView.handleGrant,
                    onSkip: harvestView.handleSkip
                )
            }
        }
        .preferredColorScheme(.dark)
    }
    
}

private struct ActiveHarvestContent: View {
    @ObservedObject var harvestView: HarvestView
    
    var body: some View {
        Group {
            switch harvestView.currentPhase {
            case .initPhase:
                EmptyView()
                
            case .runningPhase:
                if harvestView.harvestConfigURL != nil {
                    HarvestMainView()
                } else {
                    ContentView()
                }
                
            case .legacyPhase:
                ContentView()
                
            case .noConnectionPhase:
                HarvestNoConnectionScreen()
            }
        }
    }
}

