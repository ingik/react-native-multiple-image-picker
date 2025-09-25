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

                // check crop for single
                if let asset = pickerResult.photoAssets.first, config.selectMode == .single, config.crop != nil, asset.mediaType == .photo, asset.editedResult?.url == nil {
                    // open crop
                    Photo.edit(asset: .init(type: .photoAsset(asset)), config: self.config.editor, sender: controller) { editedResult, _ in

                        if let photoAsset = pickerResult.photoAssets.first, let result = editedResult.result {
                            photoAsset.editedResult = .some(result)

                            Task {
                                let resultData = try await self.getResult(photoAsset)

                                DispatchQueue.main.async {
                                    resolved([resultData])
                                    controller.dismiss(true)
                                }
                            }
                        }
                    }

                    return
                }

                // show alert view
                let alert = UIAlertController(title: nil, message: "Loading...", preferredStyle: .alert)
                alert.showLoading()
                controller.present(alert, animated: true)

                let group = DispatchGroup()

                var data: [PickerResult] = []

                self.selectedAssets = pickerResult.photoAssets

                // HEIC/HEIF 파일이 있는지 체크
                let heicAssets = pickerResult.photoAssets.filter { asset in
                    if let phAsset = asset.phAsset {
                        let resource = PHAssetResource.assetResources(for: phAsset).first
                        let uti = resource?.uniformTypeIdentifier ?? ""
                        return uti.contains("heic") || uti.contains("heif") || uti == "public.heic" || uti == "public.heif"
                    }
                    return false
                }

                // 백그라운드에서 HEIC/HEIF 자동 변환 처리
                Task {
                    for response in pickerResult.photoAssets {
                        group.enter()

                        // HEIC/HEIF 파일이면 자동으로 크롭 처리 (JPEG 변환)
                        if heicAssets.contains(response) {
                            await self.autoConvertHEIC(response)
                        }

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
    
    // HEIC/HEIF를 JPEG로 자동 변환 (백그라운드 처리)
    private func autoConvertHEIC(_ asset: PhotoAsset) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                // 원본 비율 유지하는 크롭 설정
                var editConfig = EditorConfiguration()
                editConfig.isFixedCropSizeState = false
                editConfig.cropSize.isFixedRatio = false
                editConfig.photo.defaultSelectedToolOption = .cropSize
                editConfig.cropSize.isRoundCrop = false
                editConfig.cropSize.isResetToOriginal = true
                
                // 백그라운드에서 자동 크롭 실행 (사용자에게 UI 안보임)
                Photo.edit(asset: .init(type: .photoAsset(asset)), config: editConfig) { result, _ in
                    if let editedResult = result.result {
                        // 편집된 결과를 asset에 저장 (JPEG로 변환됨)
                        asset.editedResult = .some(editedResult)
                    }
                    continuation.resume()
                }
            }
        }
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
