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

                    Task {
                        do {
                            for response in pickerResult.photoAssets {
                                group.enter()

                                // HEIC/HEIF 파일이거나 크롭 설정이 있으면 자동 크롭 처리
                                if self.shouldAutoCrop(response, config: config) {
                                    do {
                                        let croppedAsset = try await self.autoCropAsset(response, config: config)
                                        let resultData = try await self.getResult(croppedAsset)
                                        data.append(resultData)
                                    } catch {
                                        // 자동 크롭 실패 시 원본 사용
                                        let resultData = try await self.getResult(response)
                                        data.append(resultData)
                                    }
                                } else {
                                    let resultData = try await self.getResult(response)
                                    data.append(resultData)
                                }
                                
                                group.leave()
                            }

                            DispatchQueue.main.async {
                                alert.dismiss(animated: true) {
                                    controller.dismiss(true)
                                    resolved(data)
                                }
                            }
                        } catch {
                            // 전체 작업 실패 시
                            DispatchQueue.main.async {
                                alert.dismiss(animated: true) {
                                    controller.dismiss(true)
                                    rejected(Double(ErrorCode.UNKNOWN.rawValue))
                                }
                            }
                        }
                    }

            } cancel: { cancel in
                cancel.autoDismiss = true
            }
        }
    }
    
    // HEIC/HEIF 파일이거나 크롭 설정이 있는지 확인
    private func shouldAutoCrop(_ asset: PhotoAsset, config: NitroConfig) -> Bool {
        // 사진이 아니면 크롭하지 않음
        guard asset.mediaType == .photo else { return false }
        
        // 이미 편집된 결과가 있으면 크롭하지 않음
        guard asset.editedResult?.url == nil else { return false }
        
        // HEIC/HEIF 파일인지 확인 (더 안전한 방법)
        var isHEIC = false
        if let phAsset = asset.phAsset {
            let resource = PHAssetResource.assetResources(for: phAsset).first
            let uti = resource?.uniformTypeIdentifier ?? ""
            isHEIC = uti.contains("heic") || uti.contains("heif") || uti == "public.heic" || uti == "public.heif"
        }
        
        // 크롭 설정이 있거나 HEIC/HEIF 파일이면 자동 크롭
        return config.crop != nil || isHEIC
    }
    
    // 자동 크롭 처리 - 안전한 버전
    private func autoCropAsset(_ asset: PhotoAsset, config: NitroConfig) async throws -> PhotoAsset {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                // 기본 에디터 설정 생성 (안전한 설정)
                var editorConfig = EditorConfiguration()
                
                // 크롭 설정이 있으면 적용, 없으면 원본 비율 유지
                if let cropConfig = config.crop {
                    if let isSquare = cropConfig.isSquare {
                        if isSquare {
                            // 1:1 비율
                            editorConfig.cropSize.aspectRatio = .init(width: 1, height: 1)
                        } else {
                            // 1:1.25 비율 (4:5)
                            editorConfig.cropSize.aspectRatio = .init(width: 4, height: 5)
                        }
                        editorConfig.isFixedCropSizeState = true
                        editorConfig.cropSize.isFixedRatio = true
                    } else {
                        // 자유 크롭 또는 원본 비율 유지
                        editorConfig.isFixedCropSizeState = false
                        editorConfig.cropSize.isFixedRatio = false
                    }
                } else {
                    // HEIC/HEIF의 경우 원본 비율 유지
                    editorConfig.isFixedCropSizeState = false
                    editorConfig.cropSize.isFixedRatio = false
                }
                
                // 기본 설정
                editorConfig.photo.defaultSelectedToolOption = .cropSize
                editorConfig.cropSize.isRoundCrop = false
                editorConfig.cropSize.isResetToOriginal = true
                
                // 자동 크롭 실행
                Photo.edit(asset: .init(type: .photoAsset(asset)), config: editorConfig) { editedResult, _ in
                    if let result = editedResult.result {
                        asset.editedResult = .some(result)
                        continuation.resume(returning: asset)
                    } else {
                        // 크롭 실패 시 원본 반환
                        continuation.resume(returning: asset)
                    }
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
