    //
    //  Extractor.swift
    //  PaperlessExtractor
    //
    //  Created by Scott Gruby on 3/18/23.
    //

import Foundation
import AppKit
import PDFKit

struct ExtractorError: Error {
}

struct URLItem: Identifiable {
    let id = UUID()
    let url: URL
}

@MainActor
class Extractor: ObservableObject {
    func addUnclassified(url: URL) async {
        unclassifiedURLs.append(URLItem(url: url))
    }
    
    func setProgress(current: Int, total: Int) async {
        percentComplete = Double(current)/Double(total)
    }
    
    var itemProvider: NSItemProvider?
    @Published var percentComplete = 0.0
    @Published var extracting: Bool = false {
        didSet {
            percentComplete = 0
        }
    }
    @Published var destFolder: URL?
    @Published var libraryURL: URL? {
        didSet {
            unclassifiedURLs = []
            destFolder = nil
            percentComplete = 0
        }
    }
    @Published var unclassifiedURLs: [URLItem] = []
    let dateFormatter = DateFormatter()
    let dateFormatterAlt = DateFormatter()
    let destDateFormatter = DateFormatter()

    init() {
        dateFormatter.dateFormat = "MM/dd/yy"
        destDateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatterAlt.dateFormat = "dd/MMM/yy"
    }
    
    func processFile() {
        Task {
            extracting = true
            do {
                libraryURL = try await self.getProviderURL()
                if libraryURL != nil {
                    destFolder = showSavePanel()
                    if destFolder != nil && libraryURL != nil {
                        await readAndProcessFiles()
                    }
                }
            } catch {
                
            }
            extracting = false
        }
    }

    private func getProviderURL() async throws -> URL? {
        guard let itemProvider else {return nil}
        guard itemProvider.canLoadObject(ofClass: String.self) else {return nil}
        return try await withCheckedThrowingContinuation { continuation in
            _ = itemProvider.loadObject(ofClass: String.self) { value, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    if let fileURL = value, let url = URL(string: fileURL), url.isFileURL {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: ExtractorError())
                    }
                }
            }
        }
    }

   
    private func showSavePanel() -> URL? {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.folder]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.allowsOtherFileTypes = false
        savePanel.title = NSLocalizedString("choose_folder_title", comment: "")
        savePanel.message = NSLocalizedString("choose_folder_text", comment: "")
        savePanel.nameFieldLabel = NSLocalizedString("dest_directory_name", comment: "")
        let response = savePanel.runModal()
        return response == .OK ? savePanel.url : nil
    }

    nonisolated
    private func getPDFdata(url: URL) -> (String?, Date?) {
        let document = PDFDocument(url: url)
        let titleKeyword = "Title - "
        let merchantKeyword = "Merchant - "
        let vendorKeyword = "vendor="
        let dateKeyword = "Date - "
        let dateAltKeyword = "date="
        var title: String?
        var date: Date?
        if let keywords = document?.documentAttributes?[PDFDocumentAttribute.keywordsAttribute] as? [String] {
            keywords.forEach { item in
                if item.lowercased().hasPrefix(titleKeyword.lowercased()) {
                    title = String(item.dropFirst(titleKeyword.count))
                } else if item.lowercased().hasPrefix(merchantKeyword.lowercased()) {
                    title = String(item.dropFirst(merchantKeyword.count))
                } else if item.lowercased().hasPrefix(dateKeyword.lowercased()) {
                    let dateStr = String(item.dropFirst(dateKeyword.count))
                    date = dateFormatter.date(from: dateStr)
                    if date == nil {
                        date = dateFormatterAlt.date(from: dateStr)
                    }
                }
                else if item.lowercased().hasPrefix(vendorKeyword.lowercased()) {
                    title = String(item.dropFirst(vendorKeyword.count))
                } else if item.lowercased().hasPrefix(dateAltKeyword.lowercased()) {
                    let dateStr = String(item.dropFirst(dateAltKeyword.count))
                    date = dateFormatter.date(from: dateStr)
                    if date == nil {
                        date = dateFormatterAlt.date(from: dateStr)
                    }
                }
            }
        }
        return (title, date)
    }
    
    nonisolated
    private func createDateSubdirectories(for date: Date, destFolder: URL) -> URL? {
        var dest: URL?
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        let month = String(format: "%02d", components.month!)
        let year = String(format: "%04d", components.year!)
        dest = destFolder.appendingPathComponent(year, conformingTo: .folder)
            .appendingPathComponent(month, conformingTo: .folder)
        do {
            try FileManager.default.createDirectory(at: dest!, withIntermediateDirectories: true)
        } catch {
            print(error)
        }
        
        return dest
    }
    
    nonisolated
    func readAndProcessFiles() async {
        guard let libraryURL = await libraryURL else {return}
        var pdfURLs: [URL] = []
        FileManager.default.enumerator(at: libraryURL, includingPropertiesForKeys: nil)?.forEach { item in
            if let url = item as? URL, url.isFileURL, url.pathExtension.lowercased() == "pdf" {
                pdfURLs.append(url)
            }
        }
        
        await copyFiles(pdfURLs)
    }
    
    nonisolated
    private func copyFiles(_ pdfs: [URL]) async {
        guard let destFolder = await destFolder else {return}
        let totalCount = pdfs.count
        for (index, url) in pdfs.enumerated() {
            Task {
                await setProgress(current: index, total: totalCount - 1)
            }

            var dest: URL?
                // Get the info from the PDF
                // Set new path to be YYYY/MM/DD + Merchant name
            let (title, date) = getPDFdata(url: url)
            if let title = title?.replacingOccurrences(of: "/", with: " "), let date {
                if let subDirectory = createDateSubdirectories(for: date, destFolder: destFolder) {
                    let newTitle = "\(destDateFormatter.string(from: date)) \(title)"
                    dest = subDirectory.appendingPathComponent(newTitle, conformingTo: .pdf)
                }
            } else if let date {
                if let subDirectory = createDateSubdirectories(for: date, destFolder: destFolder) {
                    let newTitle = url.lastPathComponent.replacingOccurrences(of: "/", with: " ")
                    dest = subDirectory.appendingPathComponent(newTitle, conformingTo: .pdf)
                }
            } else {
                    // Just copy
                let newTitle = title ?? url.lastPathComponent
                dest = destFolder.appendingPathComponent("Unclassified", conformingTo: .folder)
                do {
                    try FileManager.default.createDirectory(at: dest!, withIntermediateDirectories: true)
                } catch {
                    print(error)
                }
                dest = dest!.appendingPathComponent(newTitle, conformingTo: .pdf)
                Task {
                    await addUnclassified(url: url)
                }
            }
            
            if let dest {
                    // See if item exists; append value
                let destUrl = dest.uniqueFilename()
                try? FileManager.default.copyItem(at: url, to: destUrl)
                if let date {
                        // Change the date
                    try? FileManager.default.setAttributes([FileAttributeKey.creationDate: date], ofItemAtPath: destUrl.path)
                }
            }
        }
    }
}
