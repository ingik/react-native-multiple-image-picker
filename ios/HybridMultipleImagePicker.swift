//
//  HybridMultipleImagePicker.swift
//
//  Created by Marc Rousavy on 18.07.24.
//

import Foundation
import HXPhotoPicker
import NitroModules
import Photos

class HybridMultipleImagePicker: HybridMultipleImagePickerSpec {
    var selectedAssets: [PhotoAsset] = .init()

    var config: PickerConfiguration = .init()

    func openPicker(config: NitroConfig, resolved: @escaping (([PickerResult]) -> Void), rejected: @escaping ((Double) -> Void)) throws {
        setConfig(config)

        // get selected photo
        selectedAssets = selectedAssets.filter { asset in
            config.selectedAssets.contains {
                $0.localIdentifier == asset.phAsset?.localIdentifier
            }
        }

        DispatchQueue.main.async {
            Photo.picker(
                self.config,
                selectedAssets: self.selectedAssets
            ) { pickerResult, controller in

                controller.autoDismiss = false

                // 자동 크롭: 모든 이미지에 대해 isSquare 비율로 자동 크롭 적용
                let imageAssets = pickerResult.photoAssets.filter { $0.mediaType == .photo && $0.editedResult?.url == nil }
                
                if !imageAssets.isEmpty {
                    // 자동 크롭 설정 생성 (isSquare 설정에 따라 비율 결정)
                    var autoCropConfig = self.config.editor
                    
                    // isSquare 설정에 따라 비율 설정
                    if let isSquare = config.crop?.isSquare {
                        if isSquare {
                            // 1:1 비율 고정
                            autoCropConfig.cropSize.aspectRatio = .init(width: 1, height: 1)
                        } else {
                            // 4:5 비율 고정 (1:1.25)
                            autoCropConfig.cropSize.aspectRatio = .init(width: 4, height: 5)
                        }
                    } else {
                        // 기본값: 1:1 비율
                        autoCropConfig.cropSize.aspectRatio = .init(width: 1, height: 1)
                    }
                    
                    autoCropConfig.isFixedCropSizeState = true
                    autoCropConfig.cropSize.isFixedRatio = true
                    autoCropConfig.cropSize.aspectRatios = []
                    
                    // 첫 번째 이미지부터 순차적으로 크롭 처리
                    self.processAutoCrop(assets: imageAssets, config: autoCropConfig, controller: controller, resolved: resolved)
                    return
                }

                // show alert view
                let alert = UIAlertController(title: nil, message: "Loading...", preferredStyle: .alert)
                alert.showLoading()
                controller.present(alert, animated: true)

                let group = DispatchGroup()

                var data: [PickerResult] = []

                self.selectedAssets = pickerResult.photoAssets

                Task {
                    for response in pickerResult.photoAssets {
                        group.enter()

                        let resultData = try await self.getResult(response)
                        data.append(resultData)
                        
                        group.leave()
                    }

                    DispatchQueue.main.async {
                        alert.dismiss(animated: true) {
                            controller.dismiss(true)
                            resolved(data)
                        }
                    }
                }

            } cancel: { cancel in
                cancel.autoDismiss = true
            }
        }
    }
    
    // 모든 이미지를 자동으로 1:1 비율로 크롭하는 메서드
    private func processAutoCrop(assets: [PhotoAsset], config: EditorConfiguration, controller: PhotoPickerController, resolved: @escaping (([PickerResult]) -> Void)) {
        var remainingAssets = assets
        var processedAssets: [PhotoAsset] = []
        
        func processNextAsset() {
            guard let currentAsset = remainingAssets.first else {
                // 모든 에셋 처리 완료
                Task {
                    var data: [PickerResult] = []
                    for asset in processedAssets {
                        let resultData = try await self.getResult(asset)
                        data.append(resultData)
                    }
                    
                    DispatchQueue.main.async {
                        controller.dismiss(true)
                        resolved(data)
                    }
                }
                return
            }
            
            // 현재 에셋을 크롭 처리
            Photo.edit(asset: .init(type: .photoAsset(currentAsset)), config: config) { editedResult, _ in
                if let result = editedResult.result {
                    currentAsset.editedResult = .some(result)
                    processedAssets.append(currentAsset)
                } else {
                    // 크롭 실패 시 원본 에셋 그대로 추가
                    processedAssets.append(currentAsset)
                }
                
                remainingAssets.removeFirst()
                processNextAsset()
            }
        }
        
        processNextAsset()
    }
}

extension UIAlertController {
    func showLoading() {
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))

        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = UIActivityIndicatorView.Style.medium

        if #available(iOS 13.0, *) {
            loadingIndicator.color = .secondaryLabel
        } else {
            loadingIndicator.color = .black
        }

        loadingIndicator.startAnimating()

        view.addSubview(loadingIndicator)
    }
}
