# Authentication Setup Guide

This guide explains the Supabase authentication implementation in Renaissance Mobile.

## Architecture Overview

The app uses Supabase Auth for user authentication with email/password and supports social logins (Apple, Google planned).

### Key Components

1. **SupabaseClient.swift** - Singleton Supabase client instance
2. **EnvironmentConfig.swift** - Stores Supabase credentials
3. **AuthViewModel.swift** - Manages authentication state and operations
4. **SignInView.swift** - User sign-in interface
5. **SignUpView.swift** - User account creation interface
6. **ProfileView.swift** - User profile with sign-out functionality

## Configuration

### Supabase Client

The Supabase client in `SupabaseClient.swift` is configured with:
- **emitLocalSessionAsInitialSession**: Enabled to ensure consistent session behavior
- This prevents deprecation warnings and ensures expired sessions are properly handled

### Supabase Credentials

Your Supabase credentials are stored in `EnvironmentConfig.swift`:

```swift
static var supabaseURL: String {
    return "https://gqporfhogzyqgsxincbx.supabase.co"
}

static var supabaseAnonKey: String {
    return "sb_publishable_DPHSDnwQi_gXLCN6WSyd0w_u4tfurQ-"
}
```

**To update credentials:**
1. Open `EnvironmentConfig.swift`
2. Update the return values
3. You can use `#if DEBUG` to have different values for development vs production

## Features Implemented

### ✅ Email/Password Authentication
- Sign in with email and password
- Sign up with full name, email and password
- Real-time validation
- Password confirmation matching
- Error handling with user feedback
- Loading states

### ✅ Session Management
- Automatic session monitoring
- Persistent authentication state
- Auto-login on app launch
- Session expiration checking (prevents auto-login with expired sessions)

### ✅ Sign Out
- Secure sign-out functionality
- State cleanup

### ✅ Google Sign-In
- Native Google Sign-In integration
- Secure token exchange with Supabase
- Automatic user profile creation

### 🔜 Coming Soon
- Password reset
- Apple Sign-In

## Usage

### Sign Up
```swift
await authViewModel.signUp(email: "user@example.com", password: "password")
```

### Sign In
```swift
await authViewModel.signIn(email: "user@example.com", password: "password")
```

### Sign Out
```swift
await authViewModel.signOut()
```

### Google Sign-In
```swift
// From a UIViewController
await authViewModel.signInWithGoogle(presentingViewController: viewController)
```

### Check Auth State
```swift
if authViewModel.isAuthenticated {
    // User is logged in
}
```

## Security

- ✅ Credentials in dedicated config file (not scattered in code)
- ✅ Easy to manage for different environments
- ✅ Secure token storage via Supabase SDK
- ✅ Password fields use SecureField

## Setup Instructions

### 1. Supabase Package (Already Done ✅)

The following Supabase modules are installed:
- Supabase (main module)
- Auth
- Functions
- PostgREST
- Realtime
- Storage

### 2. Test the App

You can now create accounts directly in the app using the Sign Up flow!

1. **Run the app** in simulator
2. **Tap "Create Account"** from the welcome screen
3. **Fill in the form**:
   - Full Name
   - Email
   - Password
   - Confirm Password
4. **Tap "Create Account"** - should navigate to main app
5. **Sign out** from Profile view
6. **Sign back in** with your credentials

Alternatively, you can create a test user manually in your Supabase dashboard:
1. Go to **Authentication** → **Users**
2. Click **Add User**
3. Enter email and password
4. Confirm the user

## Troubleshooting

### Build Errors

**"Unable to find module dependency: 'Supabase'"**
- Verify Supabase module is added in Xcode
- Clean build folder (Cmd+Shift+K)
- Rebuild project

### Runtime Errors

**Sign in fails with network error**
- Verify Supabase URL in `EnvironmentConfig.swift`
- Check API key is correct
- Ensure user exists in Supabase dashboard

**User credentials rejected**
- Verify user is confirmed in Supabase dashboard
- Check email confirmation settings
- Try creating a new test user

## Environment-Specific Configuration

To use different credentials for Debug vs Release:

```swift
static var supabaseURL: String {
    #if DEBUG
    return "https://dev-project.supabase.co"
    #else
    return "https://prod-project.supabase.co"
    #endif
}
```

## Google Sign-In Setup

### Prerequisites

1. **Add Google Sign-In Package**
   - In Xcode: File > Add Package Dependencies
   - Enter URL: `https://github.com/google/GoogleSignIn-iOS`
   - Select version 7.0.0 or later
   - Add `GoogleSignIn` to your target

2. **Configure Google Cloud Console**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select existing
   - Enable Google+ API
   - Go to Credentials > Create OAuth 2.0 Client ID
   - For iOS application:
     - Application type: iOS
     - Bundle ID: Your app's bundle identifier (e.g., `com.yourcompany.RenaissanceMobile`)
   - Copy the **Client ID** (it ends with `.apps.googleusercontent.com`)

3. **Configure Supabase Dashboard**
   - Go to your Supabase project dashboard
   - Navigate to Authentication > Providers
   - Enable Google provider
   - Paste your **Client ID** from Google Cloud Console
   - Paste your **Client Secret** from Google Cloud Console
   - Save changes

4. **Configure iOS App**
   - Open your `Info.plist`
   - Add a new URL Type:
     - Identifier: `com.google.gid`
     - URL Schemes: Add your reversed Client ID (e.g., `com.googleusercontent.apps.123456789`)

   Or add this to your Info.plist:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleTypeRole</key>
           <string>Editor</string>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
           </array>
       </dict>
   </array>
   ```

5. **Configure Google Client ID in App**
   - In your app startup (e.g., `Renaissance_MobileApp.swift`), configure Google Sign-In:
   ```swift
   import GoogleSignIn

   @main
   struct Renaissance_MobileApp: App {
       init() {
           // Configure Google Sign-In with your Client ID
           GIDSignIn.sharedInstance.configuration = GIDConfiguration(
               clientID: "YOUR-CLIENT-ID.apps.googleusercontent.com"
           )
       }
   }
   ```

### Testing Google Sign-In

1. Build and run the app
2. Tap "Continue With Google" on Sign In or Sign Up screens
3. Complete the Google Sign-In flow
4. You should be authenticated and redirected to the main app

### Troubleshooting

**Error: "Invalid client ID"**
- Verify your Client ID is correct in both Google Cloud Console and your app
- Ensure the Client ID matches the one in Supabase Dashboard

**Error: "URL scheme not configured"**
- Check your Info.plist has the reversed Client ID as a URL scheme
- Make sure the URL scheme matches exactly (case-sensitive)

**Error: "Provider not enabled"**
- Verify Google provider is enabled in Supabase Dashboard
- Check that Client ID and Secret are saved correctly

## Next Steps

1. ✅ Test email/password authentication
2. ✅ Create sign-up view
3. ✅ Implement Google Sign-In
4. Add password reset functionality
5. Implement Apple Sign-In
6. Add user profile management
7. Store user's full name in Supabase profiles table
