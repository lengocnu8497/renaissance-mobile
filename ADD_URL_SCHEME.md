# How to Add Google Sign-In URL Scheme in Xcode

Since you're getting a build error about Info.plist, we need to add the URL scheme directly in Xcode's project settings instead of using a separate Info.plist file.

## Step-by-Step Instructions

### Method 1: Using Xcode GUI (Recommended)

1. **Open your project in Xcode**

2. **Select your project** in the Project Navigator (the blue "Renaissance Mobile" icon at the top)

3. **Select the "Renaissance Mobile" target** (under TARGETS, not PROJECTS)

4. **Click on the "Info" tab** (at the top of the main editor area)

5. **Scroll down to find "URL Types"** section
   - If you don't see it, you may need to expand it by clicking the disclosure triangle

6. **Click the "+" button** to add a new URL Type

7. **Fill in the following:**
   - **Identifier**: `com.google.gid`
   - **URL Schemes**: `com.googleusercontent.apps.636103668184-sflddmlbj90salbiit9ted0m0lhrdmag`
   - **Role**: Editor (should be default)

8. **Click outside the field** or press Enter to save

9. **Clean and rebuild** your project:
   - Press `Cmd + Shift + K` to clean
   - Press `Cmd + B` to build

### Method 2: Edit project.pbxproj directly (Advanced)

If you prefer to edit the project file directly, I can help you add the URL scheme to the `project.pbxproj` file. However, Method 1 is safer and easier.

## What This Does

The URL scheme `com.googleusercontent.apps.636103668184-sflddmlbj90salbiit9ted0m0lhrdmag` is your **reversed iOS Client ID**. This allows:

1. Google Sign-In to redirect back to your app after authentication
2. iOS to recognize that URLs with this scheme should open your app
3. The Google SDK to complete the OAuth flow

## Verify It Worked

After adding the URL scheme:

1. Build your app (Cmd + B)
2. The build should complete without the Info.plist error
3. You can verify the URL scheme was added by:
   - Going to your target's Info tab
   - Checking that "URL Types" shows your scheme

## Next Steps

Once the URL scheme is added and your app builds successfully:

1. ✅ **iOS app is configured** - You're done on the iOS side!
2. **Configure Supabase** - Add Web OAuth credentials to Supabase Dashboard
3. **Test** - Run your app and try Google Sign-In

Need help with the Supabase configuration? See [GOOGLE_CONFIG_REFERENCE.md](GOOGLE_CONFIG_REFERENCE.md) for details.
