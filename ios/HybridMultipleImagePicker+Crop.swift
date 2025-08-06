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

        let cropOption = PickerCropConfig(circle: config.circle, ratio: config.ratio, defaultRatio: config.defaultRatio, freeStyle: config.freeStyle)

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

        // 1:1.25 비율로 강제 설정
        config.cropSize.aspectRatio = .init(width: 1, height: 1.25)

        config.photo.defaultSelectedToolOption = .cropSize

        config.isFixedCropSizeState = true

        config.cropSize.defaultSeletedIndex = 0

        // 비율만 고정
        config.cropSize.isFixedRatio = true  // 비율 고정

        config.isWhetherFinishButtonDisabledInUneditedState = true

        config.cropSize.isRoundCrop = cropConfig.circle ?? false

        config.cropSize.isResetToOriginal = true

        config.toolsView = .init(toolOptions: [.init(imageType: PickerConfiguration.default.editor.imageResource.editor.tools.cropSize, type: .cropSize)])

        config.photo.defaultSelectedToolOption = .cropSize

        // 비율 선택 UI 완전히 숨기기 (1:1.25만 사용)
        config.cropSize.aspectRatios = []

        return config
    }
}
