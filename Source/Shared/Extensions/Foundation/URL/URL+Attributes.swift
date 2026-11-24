//
//  URL+Attributes.swift
//
//  Created on 03.01.2025.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import AVFoundation
import CoreMedia
import Foundation
import WardAxisTelemetry

public extension URL {
    private static let logger = Log(category: .cache)
    
    /// Retrieves the attributes of the file at the URL.
    var attributes: [FileAttributeKey: Any]? {
        do {
            return try FileManager.default.attributesOfItem(atPath: path)
        } catch let error as NSError {
            Self.logger.warning("FileAttribute error: \(error)", privacy: .private)
        }
        return nil
    }
    
    /// Gets the file size of the URL in bytes.
    var fileSize: UInt64 {
        attributes?[.size] as? UInt64 ?? UInt64(0)
    }
    
    /// Retrieves the dimensions (width and height) of an image at the URL.
    var imageDimensions: CGSize {
        if let imageSource = CGImageSourceCreateWithURL(self as CFURL, nil) {
            if let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as Dictionary? {
                let pixelWidth = imageProperties[kCGImagePropertyPixelWidth] as! CGFloat
                let pixelHeight = imageProperties[kCGImagePropertyPixelHeight] as! CGFloat
                
                return .init(width: pixelWidth, height: pixelHeight)
            }
        }
        
        return .zero
    }
    
    /// Retrieves the duration of a video at the URL asynchronously.
    func videoDuration() async -> UInt64 {
        let asset = AVURLAsset(url: self)
        
        do {
            let duration = try await asset.load(.duration)
            return UInt64(CMTimeGetSeconds(duration))
        } catch {
            return 0
        }
    }
    
    /* private func videoResolution() async -> CGSize {
         guard let track = await AVURLAsset(url: self).loadTracks(withMediaType: AVMediaType.video).first else { return .zero }
        let size = track.naturalSize.applying(track.preferredTransform)
        return CGSize(width: abs(size.width), height: abs(size.height))
     } */
}
