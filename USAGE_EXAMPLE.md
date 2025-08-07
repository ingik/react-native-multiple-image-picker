# React Native Multiple Image Picker - isSquare 옵션 사용 예시

## 개요

`isSquare` 옵션을 사용하여 크롭 비율을 제어할 수 있습니다:

- `isSquare: true` → 1:1 비율 (정사각형)
- `isSquare: false` → 1:1.25 비율 (기본값)

## 사용 예시

### 1. 정사각형 크롭 (1:1 비율)

```typescript
import { MultipleImagePicker } from '@baronha/react-native-multiple-image-picker'

const config: Config = {
  maxSelect: 5,
  primaryColor: '#FB9300',
  backgroundDark: '#2f2f2f',
  numberOfColumn: 4,
  mediaType: 'image',
  selectBoxStyle: 'number',
  selectMode: 'multiple',
  language: 'ko',
  theme: 'dark',
  isHiddenOriginalButton: false,
  crop: {
    isSquare: true, // 1:1 비율로 강제 설정
    freeStyle: false,
  },
}

// 이미지 선택 후 크롭
MultipleImagePicker.openPicker(
  config,
  (result) => {
    // 선택된 이미지들을 크롭
    result.forEach((item) => {
      MultipleImagePicker.openCrop(
        item.path,
        {
          language: 'ko',
          presentation: 'fullScreenModal',
          isSquare: true, // 1:1 비율
        },
        (cropResult) => {
          console.log('크롭된 이미지:', cropResult.path)
        },
        (error) => {
          console.error('크롭 에러:', error)
        }
      )
    })
  },
  (error) => {
    console.error('선택 에러:', error)
  }
)
```

### 2. 1:1.25 비율 크롭 (기본값)

```typescript
const config: Config = {
  maxSelect: 5,
  primaryColor: '#FB9300',
  backgroundDark: '#2f2f2f',
  numberOfColumn: 4,
  mediaType: 'image',
  selectBoxStyle: 'number',
  selectMode: 'multiple',
  language: 'ko',
  theme: 'dark',
  isHiddenOriginalButton: false,
  crop: {
    isSquare: false, // 1:1.25 비율 (기본값)
    freeStyle: false,
  },
}
```

### 3. 개별 크롭에서 isSquare 옵션 사용

```typescript
// 이미지 크롭만 실행
MultipleImagePicker.openCrop(
  imagePath,
  {
    language: 'ko',
    presentation: 'fullScreenModal',
    isSquare: true, // 1:1 비율
    circle: false,
    freeStyle: false,
  },
  (cropResult) => {
    console.log('크롭 완료:', cropResult.path)
    console.log('크롭된 이미지 크기:', cropResult.width, 'x', cropResult.height)
  },
  (error) => {
    console.error('크롭 실패:', error)
  }
)
```

## 타입 정의

```typescript
export type PickerCropConfig = {
  /** Enable circular crop mask */
  circle?: boolean

  ratio: CropRatio[]

  /**
   * Default ratio to be selected when opening the crop interface.
   */
  defaultRatio?: CropRatio

  /** Enable free style cropping */
  freeStyle?: boolean

  /**
   * Force square aspect ratio (1:1) when true, or use 1:1.25 ratio when false
   * @platform ios, android
   */
  isSquare?: boolean
}
```

## 주의사항

1. `isSquare` 옵션은 `freeStyle: false`일 때만 적용됩니다.
2. `isSquare: true`일 때는 1:1 비율이 강제됩니다.
3. `isSquare: false`일 때는 1:1.25 비율이 강제됩니다.
4. 비율 선택 UI는 숨겨지고 설정된 비율만 사용할 수 있습니다.
