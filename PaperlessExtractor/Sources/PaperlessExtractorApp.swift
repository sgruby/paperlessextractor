//
//  PaperlessExtractorApp.swift
//  PaperlessExtractor
//
//  Created by Scott Gruby on 3/18/23.
//

import SwiftUI

@main
struct PaperlessExtractorApp: App {
    @StateObject var extractor: Extractor = Extractor()
    var body: some Scene {
        WindowGroup {
            ContentView(extractor: extractor)
                .frame(minWidth: 800, minHeight: 600)
        }
    }
}
