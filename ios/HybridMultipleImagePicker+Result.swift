//
//  HybridMultipleImagePicker+Result.swift
//  Pods
//
//  Created by BAO HA on 24/10/24.
//

import HXPhotoPicker
// import Photos

extension HybridMultipleImagePicker {
    func getResult(_ asset: PhotoAsset, isCropped: Bool = false) async throws -> PickerResult {
        let urlResult = try await asset.urlResult()
        let url = urlResult.url

        let creationDate = Int(asset.phAsset?.creationDate?.timeIntervalSince1970 ?? 0)

        let mime = url.getMimeType()

        let phAsset = asset.phAsset

        let type: ResultType = .init(fromString: asset.mediaType == .video ? "video" : "image")!
        let thumbnail = asset.phAsset?.getVideoAssetThumbnail(from: url.absoluteString, in: 1)

        // phAsset이 없는 경우 (임시 파일로 생성된 경우) URL을 localIdentifier로 사용
        let localIdentifier = phAsset?.localIdentifier ?? url.lastPathComponent

        return PickerResult(localIdentifier: localIdentifier,
                            width: asset.imageSize.width,
                            height: asset.imageSize.height,
                            mime: mime,
                            size: Double(asset.fileSize),
                            bucketId: nil,
                            realPath: nil,
                            parentFolderName: nil,
                            creationDate: creationDate > 0 ? Double(creationDate) : nil,
                            crop: isCropped,
                            path: "file://\(url.absoluteString)",
                            type: type,
                            duration: asset.videoDuration,
                            thumbnail: thumbnail,
                            fileName: phAsset?.fileName)
    }
}
