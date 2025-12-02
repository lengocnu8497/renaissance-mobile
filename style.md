# Renaissance Mobile - Design System & Style Guide

## Color Palette

### Primary Colors
- **Primary/Accent**: `#D0BB95` - Gold/Beige tone
  - Used for: Selected tab items, primary actions, branding elements

### Background Colors
- **App Background**: `#f7f7f6` - Very light gray
  - Used for: Main screen backgrounds
- **Card Background**: `#FFFFFF` - White
  - Used for: Card components, elevated surfaces

### Icon Colors
- **Icon Circle Background**: `#DBEAFE` - Light blue
  - Used for: Icon background circles on cards
- **Icon Foreground**: `#D0BB95` - Gold/Beige
  - Used for: Icons within circular backgrounds

### Text Colors
- **Primary Text**: `#1F2937` - Dark gray/black
  - Used for: Headings, titles, primary content
- **Secondary Text**: `#6B7280` - Medium gray
  - Used for: Subtitles, descriptions, secondary content
- **Tertiary Text**: `#9CA3AF` - Light gray
  - Used for: Unselected tab bar items, disabled states

## Typography

### Font Family
- **Primary Font**: System (San Francisco on iOS)
- **Alternative**: Manrope (if implementing custom fonts)

### Font Sizes & Weights

#### Headers
- **Welcome Header**: 28pt, Semibold
  - Example: "Welcome, Nu"

#### Card Text
- **Card Title**: 18pt, Semibold
  - Example: "Concierge Chat"
- **Card Subtitle**: 14pt, Regular
  - Example: "Get expert advice"

#### Icons
- **Card Icon Size**: 36pt, Light weight
- **Icon Circle Size**: 64pt diameter

## Spacing

### Padding
- **Screen Horizontal Padding**: 24px
- **Screen Top Padding**: 60px
- **Card Internal Padding**: 24px (all sides)
- **Card Vertical Padding**: 24px

### Spacing Between Elements
- **Welcome Header Bottom Margin**: 40px
- **Card-to-Card Spacing**: 24px
- **Icon-to-Text Spacing**: 16px
- **Title-to-Subtitle Spacing**: 4px

## Components

### Navigation Cards
```swift
- Background: White (#FFFFFF)
- Border Radius: 16px
- Shadow: Black 4% opacity, 4px radius, offset (0, 1)
- Layout: Vertical stack (icon, title, subtitle)
- Icon circle: 64px diameter, light blue background
- Icon: 36pt, light weight, gold color
- Full width with 24px padding
```

### Tab Bar
```swift
- Background: Default system background
- Selected Icon Color: #D0BB95 (gold/beige)
- Selected Text Color: #D0BB95 (gold/beige)
- Unselected Icon Color: #9CA3AF (light gray)
- Unselected Text Color: #9CA3AF (light gray)
```

### Tab Bar Icons
- **Home**: `house.fill`
- **Chat**: `message.fill`
- **Procedures**: `magnifyingglass`
- **Profile**: `person.fill`

## SF Symbols (iOS Icons)

### Current Icon Usage
- **Concierge Chat**: `text.bubble.fill`
- **Explore Procedures**: `storefront.fill`

### Icon Alternatives (if needed)
For chat/messaging:
- `text.bubble.fill` (current)
- `bubble.left.and.bubble.right.fill`
- `message.circle.fill`
- `ellipsis.message.fill`
- `quote.bubble.fill`

## Layout Guidelines

### Home Screen Structure
```
ZStack
  └── Background Color (#f7f7f6)
      └── VStack
          ├── Welcome Header (HStack with left alignment)
          ├── Spacer (40px)
          ├── Cards Container (VStack with 24px spacing)
          │   ├── Concierge Chat Card
          │   └── Explore Procedures Card
          └── Spacer (flexible)
```

### Card Layout
```
VStack (16px spacing)
  ├── Icon Circle (ZStack)
  │   ├── Circle (64px, light blue background)
  │   └── SF Symbol Icon (36pt, gold color)
  └── Text Container (VStack, 4px spacing)
      ├── Title (18pt, semibold, dark gray)
      └── Subtitle (14pt, regular, medium gray)
```

## Helper Extensions

### Hex Color Support
```swift
extension Color {
    init(hex: String)
}
```
Usage: `Color(hex: "#D0BB95")`

## Design Principles

1. **Minimalism**: Clean, uncluttered interfaces with ample white space
2. **Soft Colors**: Muted, pastel tones (light blues, beiges) for a calming aesthetic
3. **Rounded Corners**: 16px border radius for cards and components
4. **Subtle Shadows**: Low-opacity shadows (4% black) for depth without harshness
5. **Consistent Spacing**: 24px as the primary spacing unit
6. **Typography Hierarchy**: Clear distinction between titles (18pt) and subtitles (14pt)

## Reference Files

- **HTML Design Source**: `/Users/nule/Downloads/stitch_welcome_screen/code.html`
- **Primary Implementation**: `ContentView.swift`

---

**Last Updated**: December 1, 2025
**Design System Version**: 1.0
