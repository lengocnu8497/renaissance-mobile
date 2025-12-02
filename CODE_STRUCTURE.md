# Renaissance Mobile - Code Structure Documentation

## Overview
This document describes the refactored code structure following iOS development best practices for maintainability and scalability.

## File Structure

```
Renaissance Mobile/
├── Renaissance_MobileApp.swift          # App entry point
├── ContentView.swift                    # Main tab view controller
├── Theme.swift                          # Centralized theme/style constants
├── Extensions.swift                     # Reusable extensions
├── Models.swift                         # Data models
├── Views/
│   ├── HomeView.swift                   # Home screen
│   └── ChatView.swift                   # Chat screen
└── Components/
    ├── NavigationCardView.swift         # Reusable navigation card
    ├── MessageBubbleView.swift          # Chat message bubble
    └── TypingIndicatorView.swift        # Typing indicator animation
```

## Architecture Patterns

### 1. **Theme System** (`Theme.swift`)
Centralized theme constants for consistent styling across the app.

**Benefits:**
- Single source of truth for colors, typography, spacing
- Easy to update design system-wide
- Type-safe access to design tokens
- Supports theme switching in the future

**Usage:**
```swift
Text("Welcome")
    .font(Theme.Typography.welcomeHeader)
    .foregroundColor(Theme.Colors.textPrimary)
    .padding(Theme.Spacing.xl)
```

### 2. **Component-Based Architecture**
Reusable, self-contained UI components in the `Components/` folder.

**Benefits:**
- Promotes code reuse
- Easier to test individual components
- Cleaner, more maintainable code
- Each component has its own preview

**Components:**
- **NavigationCardView**: Reusable card for home screen navigation
- **MessageBubbleView**: Chat message display (handles both user and concierge)
- **TypingIndicatorView**: Animated typing indicator

### 3. **View Separation**
Each major screen has its own file in the `Views/` folder.

**Benefits:**
- Better organization
- Easier navigation in Xcode
- Reduces file size and complexity
- Clear separation of concerns

### 4. **Extensions** (`Extensions.swift`)
Shared utility extensions used across the app.

**Current Extensions:**
- `Color(hex:)`: Create colors from hex strings
- `View.cornerRadius(_:corners:)`: Apply corner radius to specific corners
- `RoundedCorner`: Custom shape for selective corner rounding

### 5. **Models** (`Models.swift`)
Data models representing business entities.

**Current Models:**
- `ChatMessage`: Represents a chat message with user/concierge distinction

## Best Practices Implemented

### ✅ Separation of Concerns
- UI logic separate from data models
- Theme/styling separate from views
- Reusable components isolated

### ✅ DRY Principle (Don't Repeat Yourself)
- Theme constants eliminate magic numbers
- Reusable components prevent code duplication
- Shared extensions for common functionality

### ✅ Maintainability
- Well-organized file structure
- Clear naming conventions
- MARK comments for section organization
- Each file has a single responsibility

### ✅ Scalability
- Easy to add new screens (just create new view file)
- Easy to add new components
- Theme system supports future customization
- Structure supports feature additions

### ✅ SwiftUI Best Practices
- Computed properties for subviews
- Preview providers for all views/components
- State management with `@State`
- Proper use of navigation

## Code Organization Conventions

### MARK Comments
Used to organize code sections:
```swift
// MARK: - Section Name
// MARK: Subsection Name
```

### File Headers
All files include standard header:
```swift
//
//  FileName.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/1/25.
//
```

### View Structure
Views follow this pattern:
1. State variables
2. Body property
3. Computed subviews (using `MARK:` comments)
4. Helper methods
5. Preview provider

## How to Add New Features

### Adding a New Screen
1. Create new file in `Views/` folder
2. Define view struct with `NavigationStack` if needed
3. Add computed properties for subviews
4. Use `Theme` constants for styling
5. Add preview provider
6. Update `ContentView.swift` to include in navigation

### Adding a New Component
1. Create new file in `Components/` folder
2. Define reusable component with configurable parameters
3. Use `Theme` constants
4. Add preview provider with sample data
5. Use component in relevant views

### Adding New Theme Values
1. Open `Theme.swift`
2. Add to appropriate struct (Colors, Typography, Spacing, etc.)
3. Use throughout the app for consistency

### Adding New Models
1. Add to `Models.swift`
2. Make `Identifiable` if used in lists
3. Add `Codable` if persisting data
4. Keep models simple and focused

## Testing Strategy

### Build Testing
```bash
xcodebuild -scheme "Renaissance Mobile" -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

### Preview Testing
Each view and component has a `#Preview` block for visual testing in Xcode.

### Component Isolation
Components are designed to be testable in isolation with sample data.

## Future Improvements

### Recommended Next Steps
1. **ViewModels**: Add MVVM pattern for complex business logic
2. **Networking Layer**: Create service layer for API calls
3. **Persistence**: Add data persistence (CoreData/SwiftData)
4. **Navigation**: Implement coordinator pattern for complex navigation
5. **Dependency Injection**: Add DI container for better testability
6. **Unit Tests**: Add test targets
7. **Localization**: Add string catalog for multi-language support
8. **Accessibility**: Add accessibility labels and traits

### Potential Enhancements
- Dark mode support (Theme already prepared for this)
- Custom fonts (already structured in Theme)
- Animation library for consistent transitions
- Error handling layer
- Loading states
- Analytics integration

## Key Takeaways

1. **Maintainable**: Easy to find and update code
2. **Scalable**: Structure supports growth
3. **Consistent**: Theme system ensures design consistency
4. **Reusable**: Components can be used across the app
5. **Testable**: Components isolated and preview-ready
6. **Professional**: Follows iOS development best practices

---

**Last Updated**: December 1, 2025
**Version**: 1.0
**Build Status**: ✅ BUILD SUCCEEDED
