# Google Sign-In Configuration Reference

## Your Configuration Details

### iOS Client ID
```
636103668184-sflddmlbj90salbiit9ted0m0lhrdmag.apps.googleusercontent.com
```

### Reversed Client ID (URL Scheme)
```
com.googleusercontent.apps.636103668184-sflddmlbj90salbiit9ted0m0lhrdmag
```

## What's Been Configured

### ✅ 1. App Initialization
- **File**: `Renaissance_MobileApp.swift`
- **Status**: Configured with your iOS Client ID
- Google Sign-In SDK is initialized on app startup

### 🔜 2. Add URL Scheme in Xcode

**IMPORTANT**: Add the URL scheme directly in Xcode project settings:

1. Select your project → Target → Info tab
2. Expand **"URL Types"**
3. Click the **+** button
4. Set:
   - **Identifier**: `com.google.gid`
   - **URL Schemes**: `com.googleusercontent.apps.636103668184-sflddmlbj90salbiit9ted0m0lhrdmag`
5. Click outside to save

## What You Still Need to Do

### Configure Supabase Dashboard

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project: `gqporfhogzyqgsxincbx`
3. Navigate to **Authentication > Providers**
4. Find and enable **Google**
5. You'll need to enter:
   - **Client ID**: From your **Web OAuth client** (NOT the iOS client ID)
   - **Client Secret**: From your **Web OAuth client**

**Important**: Supabase needs the **Web OAuth credentials**, not the iOS credentials!

### Create Web OAuth Client (if you haven't already)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to **APIs & Services > Credentials**
3. Click **Create Credentials > OAuth 2.0 Client ID**
4. Select **Web application**
5. Add authorized redirect URIs:
   ```
   https://gqporfhogzyqgsxincbx.supabase.co/auth/v1/callback
   ```
6. Click **Create**
7. Copy the **Client ID** and **Client Secret**
8. Paste them into Supabase Dashboard

## Testing

Once everything is configured:

1. Build and run your app
2. Go to Sign In or Sign Up screen
3. Tap **"Continue With Google"**
4. You should see the native Google Sign-In dialog
5. Sign in with your Google account
6. You should be authenticated and redirected to the main app

## Troubleshooting

### Build succeeds but Google Sign-In button doesn't work
- Check that Info.plist was added to the project target
- Verify the URL scheme is correct in Xcode

### "Invalid client ID" error
- Verify the Client ID in `Renaissance_MobileApp.swift` matches your iOS Client ID
- Check that it includes the full `.apps.googleusercontent.com` suffix

### "Redirect URI mismatch" error
- This means Supabase credentials are missing or incorrect
- Verify you added the Web OAuth credentials to Supabase Dashboard
- Ensure the redirect URI matches your Supabase project URL

### "URL scheme not configured" error
- Verify Info.plist is added to your Xcode target
- Check URL Types in Xcode project settings

## Summary

**You Have:**
- ✅ iOS Client ID: `636103668184-sflddmlbj90salbiit9ted0m0lhrdmag.apps.googleusercontent.com`
- ✅ Code configured in `Renaissance_MobileApp.swift`
- ✅ Google Sign-In button hooked up in UI

**You Need:**
1. Add URL scheme in Xcode project settings (see [ADD_URL_SCHEME.md](ADD_URL_SCHEME.md))
2. Create Web OAuth client in Google Cloud Console
3. Configure Supabase Dashboard with Web OAuth credentials

Once these steps are complete, Google Sign-In will be fully functional!
