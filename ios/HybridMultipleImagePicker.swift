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

                // 모든 사진 파일을 크롭 처리 (crop 설정이 있을 때만)
                let photoAssets = pickerResult.photoAssets.filter { $0.mediaType == .photo }

                // crop 설정이 있으면 모든 사진을 크롭으로 처리
                if !photoAssets.isEmpty && config.crop != nil {
                    Task {
                        for response in pickerResult.photoAssets {
                            group.enter()

                            // 사진 파일이면 자동으로 크롭 처리
                            if photoAssets.contains(response) {
                                await self.autoCropImage(response, config: config)
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
                } else {
                    // crop 설정이 없으면 일반 처리
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
                }

            } cancel: { cancel in
                cancel.autoDismiss = true
            }
        }
    }
    
    // 모든 이미지를 isSquare 설정에 맞춰 크롭 처리 (백그라운드 처리)
    private func autoCropImage(_ asset: PhotoAsset, config: NitroConfig) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                // isSquare 설정에 맞춘 크롭 설정
                var editConfig = EditorConfiguration()
                
                if let cropConfig = config.crop, let isSquare = cropConfig.isSquare {
                    if isSquare {
                        // 1:1 비율 고정
                        editConfig.cropSize.aspectRatio = .init(width: 1, height: 1)
                    } else {
                        // 1:1.25 비율 고정 (4:5)
                        editConfig.cropSize.aspectRatio = .init(width: 4, height: 5)
                    }
                    // 비율 완전 고정 설정 - Android와 동일하게 UI 숨김
                    editConfig.isFixedCropSizeState = true
                    editConfig.cropSize.isFixedRatio = true
                    editConfig.cropSize.aspectRatios = []  // 비율 선택 UI 완전 숨김
                } else {
                    // isSquare 설정이 없으면 원본 비율 유지
                    editConfig.isFixedCropSizeState = false
                    editConfig.cropSize.isFixedRatio = false
                }
                
                // 기본 설정
                editConfig.photo.defaultSelectedToolOption = .cropSize
                editConfig.cropSize.isRoundCrop = false
                editConfig.cropSize.isResetToOriginal = true
                
                // 크롭 도구 활성화
                editConfig.toolsView = .init(toolOptions: [
                    .init(imageType: PickerConfiguration.default.editor.imageResource.editor.tools.cropSize, type: .cropSize)
                ])
                
                // 백그라운드에서 자동 크롭 실행 (사용자에게 UI 안보임)
                Photo.edit(asset: .init(type: .photoAsset(asset)), config: editConfig) { result, editedAsset in
                    // 성공/실패 관계없이 항상 continuation resume
                    if let editedResult = result.result {
                        // 편집된 결과를 asset에 저장
                        asset.editedResult = .some(editedResult)
                    }
                    // 취소하거나 실패해도 계속 진행
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
