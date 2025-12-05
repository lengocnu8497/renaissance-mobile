# Google Sign-In Setup Instructions

Follow these steps to complete the Google Sign-In integration for your iOS app.

## Step 1: Add Google Sign-In Package to Xcode

1. Open your project in Xcode
2. Go to **File > Add Package Dependencies...**
3. In the search field, enter: `https://github.com/google/GoogleSignIn-iOS`
4. Select version **7.0.0** or later
5. Click **Add Package**
6. Ensure **GoogleSignIn** is checked for your **Renaissance Mobile** target
7. Click **Add Package** again

## Step 2: Get Google OAuth Credentials

### Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Name it something like "Renaissance Mobile"

### Enable Google Sign-In API

1. In the Google Cloud Console, go to **APIs & Services > Library**
2. Search for "Google+ API" or "Google Sign-In"
3. Click and **Enable** it

### Create iOS OAuth Client

1. Go to **APIs & Services > Credentials**
2. Click **Create Credentials > OAuth client ID**
3. Select **iOS** as the application type
4. Enter your app details:
   - **Name**: Renaissance Mobile iOS
   - **Bundle ID**: Check your Xcode project > General > Bundle Identifier
   - **App Store ID**: (leave blank if not published yet)
5. Click **Create**
6. **Copy the Client ID** - it will look like `123456789-abcdefg.apps.googleusercontent.com`

### Get Client Secret (for Supabase)

1. In **Credentials**, also create an **OAuth 2.0 Client ID** for **Web application**
2. Name it "Renaissance Mobile Web" (this is for Supabase backend)
3. Click **Create**
4. **Copy both the Client ID and Client Secret**

## Step 3: Configure Supabase

1. Go to your [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Navigate to **Authentication > Providers**
4. Find **Google** and click to enable it
5. Enter the **Client ID** from the Web OAuth client (Step 2)
6. Enter the **Client Secret** from the Web OAuth client
7. The **Redirect URL** should be auto-filled (looks like `https://your-project.supabase.co/auth/v1/callback`)
8. Click **Save**

## Step 4: Configure Your iOS App

### Add URL Scheme to Info.plist

1. In Xcode, find your **Info.plist** file
2. Right-click on it and select **Open As > Source Code**
3. Add this before the closing `</dict>` tag:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR-IOS-CLIENT-ID-HERE</string>
        </array>
    </dict>
</array>
```

**Replace `YOUR-IOS-CLIENT-ID-HERE` with just the numeric part of your iOS Client ID.**

Example: If your Client ID is `123456789-abcdef.apps.googleusercontent.com`, use `123456789-abcdef`

### Configure Google Sign-In in Your App

Open `Renaissance_MobileApp.swift` and update it:

```swift
import SwiftUI
import GoogleSignIn

@main
struct Renaissance_MobileApp: App {
    @State private var authViewModel = AuthViewModel()

    init() {
        // Configure Google Sign-In with your iOS Client ID
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: "YOUR-FULL-IOS-CLIENT-ID.apps.googleusercontent.com"
        )
    }

    var body: some Scene {
        WindowGroup {
            if authViewModel.isAuthenticated {
                ContentView()
                    .environment(authViewModel)
            } else {
                WelcomeView(
                    onStartConsultation: {
                        // Navigate to consultation
                    },
                    onSignIn: {
                        // Auth handled by AuthViewModel
                    }
                )
                .environment(authViewModel)
            }
        }
    }
}
```

**Replace `YOUR-FULL-IOS-CLIENT-ID.apps.googleusercontent.com` with your complete iOS Client ID from Step 2.**

## Step 5: Test the Integration

1. **Build and run** your app in Xcode
2. Navigate to the **Sign In** screen
3. Tap **Continue With Google**
4. Complete the Google Sign-In flow
5. You should be authenticated and see the main app

## Troubleshooting

### Build Error: "No such module 'GoogleSignIn'"

- Clean build folder: **Product > Clean Build Folder** (Cmd+Shift+K)
- Rebuild the project
- Verify the package was added correctly in **Project > Package Dependencies**

### Runtime Error: "Invalid client ID"

- Double-check your Client ID in `Renaissance_MobileApp.swift`
- Ensure you're using the **iOS Client ID**, not the Web Client ID
- Verify the Client ID format includes `.apps.googleusercontent.com`

### Runtime Error: "URL scheme not configured"

- Check your Info.plist has the URL scheme
- Ensure the reversed Client ID is correct
- The format should be `com.googleusercontent.apps.XXXXX`

### Sign-In Fails at Supabase

- Verify the **Web Client ID and Secret** are correctly entered in Supabase Dashboard
- Ensure Google provider is **enabled** in Supabase
- Check that you're not using the iOS Client ID in Supabase (it needs the Web credentials)

## Summary

You now have three OAuth clients:

1. **iOS OAuth Client** - Used in your app code and Info.plist
2. **Web OAuth Client** - Client ID and Secret used in Supabase Dashboard
3. Both point to the same Google project and allow the same users to sign in

## Resources

- [Supabase Google Auth Docs](https://supabase.com/docs/guides/auth/social-login/auth-google)
- [Google Sign-In iOS Setup](https://developers.google.com/identity/sign-in/ios/start)
- [Supabase Swift Auth Reference](https://supabase.com/docs/reference/swift/auth-signinwithidtoken)
