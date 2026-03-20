//
//  PhotoAnglePrompt.swift
//  Renaissance Mobile
//
//  Defines guided photo angles and per-procedure weekly photo guides.
//  Used by PhotoAngleGuideService to populate WeeklyCheckInBannerView.
//

import Foundation

enum PhotoAngle: String, CaseIterable, Codable {
    case front             = "front"
    case leftProfile       = "left_profile"
    case rightProfile      = "right_profile"
    case leftThreeQuarter  = "left_three_quarter"
    case rightThreeQuarter = "right_three_quarter"
    case underChin         = "under_chin"
    case smileNeutral      = "smile_neutral"
    case smileFull         = "smile_full"
    case browRaised        = "brow_raised"
    case closeUpLips       = "close_up_lips"
    case closeUpEyes       = "close_up_eyes"
    case lateral           = "lateral"
    case decolletage       = "decolletage"

    var displayName: String {
        switch self {
        case .front:             return "Front"
        case .leftProfile:       return "Left"
        case .rightProfile:      return "Right"
        case .leftThreeQuarter:  return "Left ¾"
        case .rightThreeQuarter: return "Right ¾"
        case .underChin:         return "Under Chin"
        case .smileNeutral:      return "Neutral"
        case .smileFull:         return "Full Smile"
        case .browRaised:        return "Brow Raised"
        case .closeUpLips:       return "Lips"
        case .closeUpEyes:       return "Eyes"
        case .lateral:           return "Side"
        case .decolletage:       return "Décolletage"
        }
    }

    var systemImage: String {
        switch self {
        case .front, .leftProfile, .rightProfile,
             .leftThreeQuarter, .rightThreeQuarter: return "person.fill"
        case .underChin:                             return "arrow.up.circle"
        case .smileNeutral, .smileFull, .browRaised: return "face.smiling"
        case .closeUpLips:                           return "mouth.fill"
        case .closeUpEyes:                           return "eye.fill"
        case .lateral:                               return "arrow.left.and.right"
        case .decolletage:                           return "person.bust.fill"
        }
    }
}

struct PhotoAnglePrompt: Equatable {
    let angle: PhotoAngle
    let instruction: String
}

struct WeeklyPhotoGuide: Identifiable {
    var id: String { "\(procedureName)-wk\(weekNumber)" }
    let weekNumber: Int
    let procedureName: String
    let contextNote: String
    let angles: [PhotoAnglePrompt]
}
