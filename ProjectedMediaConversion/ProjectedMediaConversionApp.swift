/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
SwiftUI App structure for the Projected Media Conversion application.
*/

import SwiftUI

@main
struct ProjectedMediaConversionApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, idealWidth: 1000, maxWidth: 1400, 
                       minHeight: 600, idealHeight: 700, maxHeight: 1000)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1000, height: 700)
    }
}