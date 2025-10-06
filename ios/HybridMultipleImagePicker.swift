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
    
    // 모든 이미지를 자동으로 프로그래매틱하게 크롭하는 메서드 (UI 없이)
    private func processAutoCrop(assets: [PhotoAsset], config: EditorConfiguration, controller: PhotoPickerController, resolved: @escaping (([PickerResult]) -> Void)) {
        Task {
            var processedAssets: [PhotoAsset] = []
            
            for asset in assets {
                do {
                    // 프로그래매틱하게 크롭 처리 (UI 없이)
                    if let croppedAsset = try await self.programmaticCrop(asset: asset, config: config) {
                        processedAssets.append(croppedAsset)
                    } else {
                        // 크롭 실패 시 원본 에셋 그대로 추가
                        processedAssets.append(asset)
                    }
                } catch {
                    // 에러 발생 시 원본 에셋 그대로 추가
                    processedAssets.append(asset)
                }
            }
            
            // 결과 처리
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
    }
    
    // 프로그래매틱하게 이미지를 크롭하는 메서드 (Core Image 사용)
    private func programmaticCrop(asset: PhotoAsset, config: EditorConfiguration) async throws -> PhotoAsset? {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    // 원본 이미지 URL 가져오기
                    let urlResult = try await asset.urlResult()
                    let imageURL = urlResult.url
                    
                    // URL에서 UIImage 생성
                    guard let imageData = try? Data(contentsOf: imageURL),
                          let image = UIImage(data: imageData) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    // 크롭 비율 가져오기
                    let aspectRatio = config.cropSize.aspectRatio
                    
                    // 프로그래매틱하게 크롭
                    guard let croppedImage = self.cropImage(image, to: aspectRatio) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    // 크롭된 이미지를 임시 파일로 저장
                    let tempURL = self.saveImageToTempFile(croppedImage)
                    
                    // 새로운 PhotoAsset 생성 (크롭된 이미지) - 기존 패턴 사용
                    let croppedAsset = PhotoAsset(.init(imageURL: tempURL))
                    
                    continuation.resume(returning: croppedAsset)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // UIImage를 지정된 비율로 크롭
    private func cropImage(_ image: UIImage, to aspectRatio: CGSize) -> UIImage? {
        let imageSize = image.size
        
        // 비율 계산
        let targetRatio = aspectRatio.width / aspectRatio.height
        let imageRatio = imageSize.width / imageSize.height
        
        var cropRect: CGRect
        
        if targetRatio > imageRatio {
            // 이미지가 더 세로로 긴 경우
            let scaledWidth = imageSize.height * targetRatio
            let x = (imageSize.width - scaledWidth) / 2
            cropRect = CGRect(x: x, y: 0, width: scaledWidth, height: imageSize.height)
        } else {
            // 이미지가 더 가로로 긴 경우
            let scaledHeight = imageSize.width / targetRatio
            let y = (imageSize.height - scaledHeight) / 2
            cropRect = CGRect(x: 0, y: y, width: imageSize.width, height: scaledHeight)
        }
        
        // 이미지 크롭
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    // UIImage를 임시 파일로 저장
    private func saveImageToTempFile(_ image: UIImage) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "cropped_\(UUID().uuidString).jpg"
        let tempURL = tempDir.appendingPathComponent(fileName)
        
        if let imageData = image.jpegData(compressionQuality: 0.9) {
            try? imageData.write(to: tempURL)
        }
        
        return tempURL
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
