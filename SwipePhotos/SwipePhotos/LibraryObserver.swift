//
//  LibraryObserver.swift
//  Prévient l'app quand la galerie change (photo supprimée dans l'app Photos, nouvelle photo…).
//

import Foundation
import Photos

nonisolated final class LibraryObserver: NSObject, PHPhotoLibraryChangeObserver, @unchecked Sendable {
    private let onChange: @Sendable () -> Void

    init(onChange: @escaping @Sendable () -> Void) {
        self.onChange = onChange
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        onChange()
    }
}
