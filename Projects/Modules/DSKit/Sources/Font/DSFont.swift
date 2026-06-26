import UIKit

extension UIFont {
    public enum MDS {
        case display
        case heading1
        case heading2
        case heading3
        case title
        case bodyLarge
        case body
        case caption
        
        public var font: UIFont {
            switch self {
                case .display:
                    return DSKitFontFamily.Pretendard.bold.font(size: 46)
                case .heading1:
                    return DSKitFontFamily.Pretendard.bold.font(size: 36)
                case .heading2:
                    return DSKitFontFamily.Pretendard.bold.font(size: 28)
                case .heading3:
                    return DSKitFontFamily.Pretendard.bold.font(size: 22)
                case .title:
                    return DSKitFontFamily.Pretendard.regular.font(size: 18)
                case .bodyLarge:
                    return DSKitFontFamily.Pretendard.regular.font(size: 16)
                case .body:
                    return DSKitFontFamily.Pretendard.regular.font(size: 14)
                case .caption:
                    return DSKitFontFamily.Pretendard.medium.font(size: 12)
            }
        }
        
        public var lineHeight: CGFloat {
            switch self {
                case .display:
                return 56.f
                case .heading1:
                    return 44.f
                case .heading2:
                    return 36.f
                case .heading3:
                    return 30.f
                case .title:
                    return 26.f
                case .bodyLarge:
                    return 24.f
                case .body:
                    return 22.f
                case .caption:
                    return 18.f
            }
        }
        
        public var letterSpacing: CGFloat {
            switch self {
                case .display:   return -1.0.f
                case .heading1:  return -0.5.f
                case .heading2:  return -0.3.f
                case .heading3:  return -0.2.f
                case .title:     return 0.f
                case .bodyLarge: return 0.f
                case .body:      return 0.f
                case .caption:   return 0.2.f
            }
        }
        
    }
}

