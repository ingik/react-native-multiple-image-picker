//
//  HybridMultipleImagePicker+Crop.swift
//  Pods
//
//  Created by BAO HA on 9/12/24.
//

import HXPhotoPicker

extension HybridMultipleImagePicker {
    func openCrop(image: String, config: NitroCropConfig, resolved: @escaping ((CropResult) -> Void), rejected: @escaping ((Double) -> Void)) throws {
        let asset: EditorAsset

        if image.hasPrefix("http://") || image.hasPrefix("https://") || image.hasPrefix("file://") {
            guard let url = URL(string: image),
                  let data = try? Data(contentsOf: url)

            else {
                rejected(0)
                return
            }

            asset = .init(type: .imageData(data))
        } else {
            asset = .init(type: .photoAsset(.init(localIdentifier: image)))
        }

        // 간단하게 빈 배열로 처리
        let cropOption = PickerCropConfig(circle: config.circle, ratio: [], defaultRatio: nil, freeStyle: config.freeStyle, isSquare: config.isSquare)

        var editConfig = setCropConfig(cropOption)

        editConfig.languageType = setLocale(language: config.language)

        DispatchQueue.main.async {
            Photo.edit(asset: asset, config: editConfig) { result, _ in

                if let path = result.result?.url.absoluteString, let size = result.result?.image?.size {
                    let result = CropResult(path: path, width: size.width, height: size.height)

                    resolved(result)
                }
            }
        }
    }

    func setCropConfig(_ cropConfig: PickerCropConfig) -> EditorConfiguration {
        var config = EditorConfiguration()

        // isSquare 옵션에 따라 간단하게 비율만 설정
        if let isSquare = cropConfig.isSquare {
            if isSquare {
                // 1:1 비율 고정
                config.cropSize.aspectRatio = .init(width: 1, height: 1)
            } else {
                // 1:1.25 비율 고정 (4:5)
                config.cropSize.aspectRatio = .init(width: 4, height: 5)
            }
            // 비율 고정 설정
            config.isFixedCropSizeState = true
            config.cropSize.isFixedRatio = true
        }

        // 기본 설정
        config.photo.defaultSelectedToolOption = .cropSize
        config.cropSize.isRoundCrop = cropConfig.circle ?? false
        config.toolsView = .init(toolOptions: [
            .init(imageType: PickerConfiguration.default.editor.imageResource.editor.tools.cropSize, type: .cropSize)
        ])

        return config
    }
}
