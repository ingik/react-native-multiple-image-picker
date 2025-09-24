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

        // CropRatio 객체들을 안전하게 처리
        let ratioArray: [CropRatio] = config.ratio.map { ratio in
            return CropRatio(title: ratio.title, width: ratio.width, height: ratio.height)
        }
        
        let defaultRatio: CropRatio? = config.defaultRatio != nil ? 
            CropRatio(title: config.defaultRatio!.title, width: config.defaultRatio!.width, height: config.defaultRatio!.height) : nil
        
        let cropOption = PickerCropConfig(circle: config.circle, ratio: ratioArray, defaultRatio: defaultRatio, freeStyle: config.freeStyle, isSquare: config.isSquare)

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
            // 기본 비율들 제공 - EditorRatioToolConfig 타입으로 명시적 생성
            let originalRatio = EditorRatioToolConfig()
            originalRatio.title = "원본"
            originalRatio.width = 0
            originalRatio.height = 0
            
            let ratio1x1 = EditorRatioToolConfig()
            ratio1x1.title = "1:1"
            ratio1x1.width = 1
            ratio1x1.height = 1
            
            let ratio3x4 = EditorRatioToolConfig()
            ratio3x4.title = "3:4"
            ratio3x4.width = 3
            ratio3x4.height = 4
            
            let ratio4x3 = EditorRatioToolConfig()
            ratio4x3.title = "4:3"
            ratio4x3.width = 4
            ratio4x3.height = 3
            
            let ratio9x16 = EditorRatioToolConfig()
            ratio9x16.title = "9:16"
            ratio9x16.width = 9
            ratio9x16.height = 16
            
            let ratio16x9 = EditorRatioToolConfig()
            ratio16x9.title = "16:9"
            ratio16x9.width = 16
            ratio16x9.height = 9
            
            config.cropSize.aspectRatios = [originalRatio, ratio1x1, ratio3x4, ratio4x3, ratio9x16, ratio16x9]
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
