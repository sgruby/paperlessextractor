//
//  URL+Extensions.swift
//  PaperlessExtractor
//
//  Created by Scott Gruby on 3/19/23.
//

import Foundation

extension URL {
    func uniqueFilename() -> URL {
        var exists = false
        var url = self
        var count = 1
        repeat {
            exists = (try? url.checkResourceIsReachable()) ?? false
            if exists {
                    // Try a new name
                    // Drop the extension
                let name = self.deletingPathExtension().lastPathComponent
                let newName = "\(name) - \(count).\(self.pathExtension)"
                url = url.deletingLastPathComponent().appendingPathComponent(newName, conformingTo: .pdf)
                count = count + 1
            }
        } while exists == true
        
        return url
    }
}
