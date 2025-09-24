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

        let cropOption = PickerCropConfig(circle: config.circle, ratio: config.ratio, defaultRatio: config.defaultRatio, freeStyle: config.freeStyle, isSquare: config.isSquare)

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

        // isSquare 옵션에 따라 비율 설정
        if let isSquare = cropConfig.isSquare {
            if isSquare {
                // 1:1 비율로 강제 설정
                config.cropSize.aspectRatio = .init(width: 1, height: 1)
                config.isFixedCropSizeState = true
                config.cropSize.isFixedRatio = true
            } else {
                // 1:1.25 비율로 강제 설정
                config.cropSize.aspectRatio = .init(width: 4, height: 5)
                config.isFixedCropSizeState = true
                config.cropSize.isFixedRatio = true
            }
            // 고정 비율일 때는 비율 선택 UI 숨김
            config.cropSize.aspectRatios = []
        } else {
            // isSquare가 nil인 경우 - 모든 비율 선택 가능
            config.isFixedCropSizeState = false
            config.cropSize.isFixedRatio = false
            // 기본 비율들 제공
            config.cropSize.aspectRatios = [
                .init(title: "원본", width: 0, height: 0),
                .init(title: "1:1", width: 1, height: 1),
                .init(title: "3:4", width: 3, height: 4),
                .init(title: "4:3", width: 4, height: 3),
                .init(title: "9:16", width: 9, height: 16),
                .init(title: "16:9", width: 16, height: 9)
            ]
        }

        // 기본 편집 설정
        config.photo.defaultSelectedToolOption = .cropSize
        config.cropSize.defaultSeletedIndex = 0
        config.isWhetherFinishButtonDisabledInUneditedState = false
        config.cropSize.isRoundCrop = cropConfig.circle ?? false
        config.cropSize.isResetToOriginal = true
        
        // 크롭 도구만 활성화
        config.toolsView = .init(toolOptions: [
            .init(imageType: PickerConfiguration.default.editor.imageResource.editor.tools.cropSize, type: .cropSize)
        ])

        return config
    }
}
