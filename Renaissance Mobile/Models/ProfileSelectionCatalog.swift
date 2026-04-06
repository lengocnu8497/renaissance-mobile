import Foundation

enum ProfileSelectionCatalog {
    static let genderOptions = [
        "Woman", "Man", "Non-binary", "Prefer not to say"
    ]

    static let ageRangeOptions = [
        "Under 25", "25–34", "35–44", "45–54", "55+"
    ]

    static let raceOptions = [
        "Asian", "Black / African American", "Hispanic / Latino",
        "Middle Eastern", "White / Caucasian", "Multiracial", "Prefer not to say"
    ]

    static let goalOptions = [
        "Look more refreshed", "Look younger", "Change a specific feature",
        "Enhance my confidence", "Explore non-surgical first", "Just researching options"
    ]

    static let bodyAreaOptions = [
        "Face", "Nose", "Eyes / Brow", "Lips", "Neck / Jawline",
        "Breasts", "Abdomen / Waist", "Arms", "Thighs / Buttocks", "Full body"
    ]

    static let procedureOptions = [
        "Rhinoplasty", "Facelift / Mini facelift", "Eyelid surgery",
        "Breast augmentation", "Breast reduction / Lift",
        "Body contouring / BBL", "Tummy tuck", "Botox / Fillers / Lasers", "Not sure yet"
    ]

    static let previousProcedureOptions = [
        "None yet", "Rhinoplasty", "Facial surgery", "Breast surgery",
        "Body contouring", "Botox / Fillers", "Other surgical"
    ]

    static let healthFlagOptions = [
        "No known sensitivities", "History of keloid scarring",
        "Sensitive / eczema-prone skin", "Latex sensitivity",
        "Blood thinners or clotting concerns", "Slower healing than average",
        "Prefer not to say"
    ]
}
