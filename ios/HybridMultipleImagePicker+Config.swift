//
//  HybridMultipleImagePicker+Config.swift
//  react-native-multiple-image-picker
//
//  Created by BAO HA on 15/10/2024.
//

import HXPhotoPicker
import UIKit

// Swift enum
// @objc enum MediaType: SelectBoxView.Style

extension HybridMultipleImagePicker {
    func setConfig(_ options: NitroConfig) {
        config = PickerConfiguration.default

        var photoList = config.photoList
        var previewView = config.previewView

        if let spacing = options.spacing { photoList.spacing = spacing }
        if let rowNumber = options.numberOfColumn { photoList.rowNumber = Int(rowNumber) }

        if let isHiddenPreviewButton = options.isHiddenPreviewButton {
            previewView.bottomView.isHiddenPreviewButton = isHiddenPreviewButton
            photoList.bottomView.isHiddenOriginalButton = isHiddenPreviewButton
        }

        if let isHiddenOriginalButton = options.isHiddenOriginalButton {
            previewView.bottomView.isHiddenOriginalButton = isHiddenOriginalButton
            photoList.bottomView.isHiddenOriginalButton = isHiddenOriginalButton
        }

        photoList.allowHapticTouchPreview = options.allowHapticTouchPreview ?? true

        photoList.allowSwipeToSelect = options.allowSwipeToSelect ?? true

        photoList.allowAddLimit = options.allowedLimit ?? true

        // check media type
        switch options.mediaType {
        case .image:
            config.selectOptions = [.photo, .livePhoto, .gifPhoto]
        case .video:
            config.selectOptions = .video
        default:
            config.selectOptions = [.video, .photo, .gifPhoto, .livePhoto]
        }

        config.indicatorType = .system
        config.photoList.cell.kf_indicatorColor = .black

        if let boxStyle = SelectBoxView.Style(rawValue: Int(options.selectBoxStyle.rawValue)) {
            previewView.selectBox.style = boxStyle
            photoList.cell.selectBox.style = boxStyle
        }

        photoList.isShowFilterItem = false
        photoList.sort = .desc
        photoList.isShowAssetNumber = false

        previewView.disableFinishButtonWhenNotSelected = false

        if let selectMode = PickerSelectMode(rawValue: Int(options.selectMode.rawValue)) {
            config.selectMode = selectMode
        }

        if let maxFileSize = options.maxFileSize {
            config.maximumSelectedPhotoFileSize = Int(maxFileSize)
            config.maximumSelectedVideoFileSize = Int(maxFileSize)
        }

        // Setting for video
        if options.mediaType == .all || options.mediaType == .video {
            if let maxVideo = options.maxVideo {
                config.maximumSelectedVideoCount = Int(maxVideo)
            }

            if let maxVideoDuration = options.maxVideoDuration {
                config.maximumSelectedVideoDuration = Int(maxVideoDuration)
            }

            if let minVideoDuration = options.minVideoDuration {
                config.minimumSelectedVideoDuration = Int(minVideoDuration)
            }
        }

        if let maxSelect = options.maxSelect {
            config.maximumSelectedCount = Int(maxSelect)
        }

        config.allowSyncICloudWhenSelectPhoto = true

        config.allowCustomTransitionAnimation = true

        config.isSelectedOriginal = false

        let isPreview = options.isPreview ?? true

        previewView.bottomView.isShowPreviewList = isPreview
        photoList.bottomView.isHiddenPreviewButton = !isPreview
        photoList.allowHapticTouchPreview = isPreview
        photoList.bottomView.previewListTickColor = .clear
        photoList.bottomView.isShowSelectedView = isPreview

        if isPreview {
            config.videoSelectionTapAction = .preview
            config.photoSelectionTapAction = .preview
        } else {
            config.videoSelectionTapAction = .quickSelect
            config.photoSelectionTapAction = .quickSelect
        }

        config.editorOptions = [.photo, .gifPhoto, .livePhoto]

        if let crop = options.crop {
            config.editor = setCropConfig(crop)
        } else {
            // 기본 크롭 설정으로 편집 버튼 활성화
            let defaultCrop = PickerCropConfig(circle: false, ratio: [], defaultRatio: nil, freeStyle: false, isSquare: false)
            config.editor = setCropConfig(defaultCrop)
            previewView.bottomView.isHiddenEditButton = false
        }

        photoList.finishSelectionAfterTakingPhoto = true

        if let cameraOption = options.camera {
            photoList.allowAddCamera = true

            photoList.cameraType = .system(setCameraConfig(cameraOption))
        } else {
            photoList.allowAddCamera = false
        }

        config.photoList = photoList
        config.previewView = previewView

        setLanguage(options)
        setTheme(options)

        config.modalPresentationStyle = setPresentation(options.presentation)
    }

    private func setTheme(_ options: NitroConfig) {
        let isDark = options.theme == Theme.dark

        // custom background dark
        if let background = options.backgroundDark, let backgroundDark = getReactColor(Int(background)), isDark {
            config.photoList.backgroundDarkColor = backgroundDark
            config.photoList.backgroundColor = backgroundDark
        }

        // LIGHT THEME
        if !isDark {
            let background = UIColor.white
            let barStyle = UIBarStyle.default

            config.statusBarStyle = .darkContent
            config.appearanceStyle = .normal
            config.photoList.bottomView.barStyle = barStyle
            config.navigationBarStyle = barStyle
            config.previewView.bottomView.barStyle = barStyle
            config.previewView.backgroundColor = background
            config.previewView.bottomView.backgroundColor = background

            config.photoList.leftNavigationItems = [PhotoCancelItem.self]

            config.photoList.backgroundColor = .white
            config.photoList.emptyView.titleColor = .black
            config.photoList.emptyView.subTitleColor = .darkGray
            config.photoList.titleView.backgroundColor = UIColor.black.withAlphaComponent(0.5)

            config.albumList.backgroundColor = .white
            config.albumList.cellBackgroundColor = .white
            config.albumList.albumNameColor = .black
            config.albumList.photoCountColor = .black
            config.albumList.cellSelectedColor = "#e1e1e1".hx.color
            config.albumList.separatorLineColor = "#e1e1e1".hx.color
        }

        if let primaryColor = options.primaryColor, let color = getReactColor(Int(primaryColor)) {
            config.setThemeColor(color)
        }

        config.navigationTitleColor = .white
        config.photoList.titleView.arrow.arrowColor = .white
        config.photoList.cell.customSelectableCellClass = nil
    }

    func setPresentation(_ presentation: Presentation?) -> UIModalPresentationStyle {
        if let presentation {
            switch Int(presentation.rawValue) {
            case 1:
                return .formSheet
            default:
                return .fullScreen
            }
        }

        return .fullScreen
    }

    private func setLanguage(_ options: NitroConfig) {
        // 한국어인 경우 자연스러운 텍스트 설정
        if options.language == .ko {
            // 기본 버튼 텍스트
            config.textManager.picker.photoList.bottomView.finishTitle = .custom("완료")
            config.textManager.picker.preview.bottomView.finishTitle = .custom("완료")
            config.textManager.picker.photoList.bottomView.originalTitle = .custom("원본")
            config.textManager.picker.preview.bottomView.originalTitle = .custom("원본")
            config.textManager.picker.photoList.bottomView.previewTitle = .custom("미리보기")
            config.textManager.picker.preview.bottomView.editTitle = .custom("편집")
            
            // 편집기 텍스트
            config.textManager.editor.crop.maskListFinishTitle = .custom("완료")
            
            // 빈 화면 텍스트
            config.textManager.picker.photoList.emptyTitle = .custom("사진이 없습니다")
            config.textManager.picker.photoList.emptySubTitle = .custom("사진을 찍거나 다운로드해보세요")
            
            // 추가 텍스트 (존재하는 속성만 사용)
            // config.textManager.picker.notAuthorized.titleText = .custom("사진 접근 권한이 필요합니다")
            // config.textManager.picker.notAuthorized.subTitleText = .custom("설정에서 사진 접근 권한을 허용해주세요")
        }
        
        if let text = options.text {
            if let finish = text.finish {
                config.textManager.picker.photoList.bottomView.finishTitle = .custom(finish)
                config.textManager.picker.preview.bottomView.finishTitle = .custom(finish)
                config.textManager.editor.crop.maskListFinishTitle = .custom(finish)
            }

            if let original = text.original {
                config.textManager.picker.photoList.bottomView.originalTitle = .custom(original)
                config.textManager.picker.preview.bottomView.originalTitle = .custom(original)
            }

            if let preview = text.preview {
                config.textManager.picker.photoList.bottomView.previewTitle = .custom(preview)
            }

            if let edit = text.edit {
                config.textManager.picker.preview.bottomView.editTitle = .custom(edit)
            }
        }

        config.languageType = setLocale(language: options.language)
    }

    func setLocale(language: Language) -> LanguageType {
        switch language {
        case .vi:
            return .vietnamese // -> 🇻🇳 My country. Yeahhh
        case .zhHans:
            return .simplifiedChinese
        case .zhHant:
            return .traditionalChinese
        case .ja:
            return .japanese
        case .ko:
            return .korean
        case .en:
            return .english
        case .th:
            return .thai
        case .id:
            return .indonesia
        case .ru:
            return .russian
        case .de:
            return .german
        case .fr:
            return .french
        case .ar:
            return .arabic
        default:
            return .system
        }
    }
}
