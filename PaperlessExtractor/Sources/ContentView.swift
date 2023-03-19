//
//  ContentView.swift
//  PaperlessExtractor
//
//  Created by Scott Gruby on 3/18/23.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var extractor: Extractor
    var body: some View {
        Group {
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundColor(.accentColor)
                if extractor.extracting {
                    ProgressView()
                        .progressViewStyle(.automatic)
                    ProgressView(value: extractor.percentComplete)
                        .frame(width: 200, alignment: .center)
                } else {
                    Text("drop_library_here_text")
                }
            }
            .padding()
            .frame(
                minWidth: 0,
                maxWidth: .infinity,
                minHeight: 0,
                maxHeight: .infinity,
                alignment: .center
            )
            .onDrop(of: [.fileURL], delegate: self)
            if let url = extractor.libraryURL?.path {
                Spacer()
                
                Text(String(format: NSLocalizedString("source_path_text", comment: ""), url))
                Spacer()
            }
            
            if let url = extractor.destFolder?.path {
                Spacer()
                Text(String(format: NSLocalizedString("dest_path_text", comment: ""), url))
                Spacer()
            }
            if !extractor.unclassifiedURLs.isEmpty {
                VStack {
                    Text("no_pdf_metadata")
                        .bold()
                    List (extractor.unclassifiedURLs) { url in
                        Text("\(url.url.path)")
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .background(.white)
    }
}


extension ContentView: DropDelegate {
    func validateDrop(info: DropInfo) -> Bool {
        guard extractor.extracting == false else {return false}
        // find provider with file URL
        guard info.hasItemsConforming(to: [.fileURL]) else { return false }
        guard let provider = info.itemProviders(for: [.fileURL]).first else { return false }
        
        var result = false
        if provider.canLoadObject(ofClass: String.self) {
            let group = DispatchGroup()
            group.enter()     // << make decoding sync
            
                // decode URL from item provider
            _ = provider.loadObject(ofClass: String.self) { value, _ in
                defer { group.leave() }
                guard let fileURL = value, let url = URL(string: fileURL), url.isFileURL else { return }
                if url.pathExtension.lowercased() == "paperless" {
                    result = true
                }
            }
            
                // wait a bit for verification result
            _ = group.wait(timeout: .now() + 0.5)
        }
        return result
    }

    func performDrop(info: DropInfo) -> Bool {
        guard info.hasItemsConforming(to: [.fileURL]) else { return false }
        guard let provider = info.itemProviders(for: [.fileURL]).first else { return false }
        extractor.itemProvider = provider
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            extractor.processFile()
        }
        return true
    }
    
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(extractor: Extractor())
    }
}
