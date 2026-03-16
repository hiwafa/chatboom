# chatboom

A new Flutter project.

## Getting Started

lib/
 ├── main.dart
 ├── core/           # Shared utilities, constants, and themes
 ├── models/         # Data models (User, Message, Note)
 ├── screens/        # UI Views (Login, Chat, Notes, Profile)
 ├── services/       # Firebase and Backend API wrappers
 └── widgets/        # Reusable UI components


# When run backend, before that, do this:
export GOOGLE_GENAI_USE_VERTEXAI=true
export GOOGLE_CLOUD_PROJECT="chatboom-f9a38"
export GOOGLE_CLOUD_LOCATION="us-central1"
export GOOGLE_APPLICATION_CREDENTIALS="key.json"



# Create New firebase Account And after Connecting:
Platform  Firebase App Id
web       1:349851174448:web:01aaf39e7d494db88f0ff5
android   1:349851174448:android:45269e724c5da8b28f0ff5
ios       1:349851174448:ios:f1e3a9f1ca1f492c8f0ff5

Learn more about using this file and next steps from the documentation:


> Task :app:signingReport
Variant: debug
Config: debug
Store: /Users/einaki/.android/debug.keystore
Alias: AndroidDebugKey
MD5: F0:5F:3C:3F:92:E5:99:BA:C9:F4:4F:08:06:25:3E:19
SHA1: 7B:33:2E:88:46:01:93:B3:94:6E:CD:EE:63:FD:4C:37:30:C3:44:CD
SHA-256: 50:66:DE:85:D7:DF:C1:E4:48:BF:46:53:F4:8C:77:A9:0B:1F:E9:D5:0C:FC:5A:E3:B5:D2:2C:83:5C:68:0F:CB
Valid until: Thursday, November 14, 2052
----------
Variant: release
Config: debug
Store: /Users/einaki/.android/debug.keystore
Alias: AndroidDebugKey
MD5: F0:5F:3C:3F:92:E5:99:BA:C9:F4:4F:08:06:25:3E:19
SHA1: 7B:33:2E:88:46:01:93:B3:94:6E:CD:EE:63:FD:4C:37:30:C3:44:CD
SHA-256: 50:66:DE:85:D7:DF:C1:E4:48:BF:46:53:F4:8C:77:A9:0B:1F:E9:D5:0C:FC:5A:E3:B5:D2:2C:83:5C:68:0F:CB
Valid until: Thursday, November 14, 2052
----------
Variant: profile
Config: debug
Store: /Users/einaki/.android/debug.keystore
Alias: AndroidDebugKey
MD5: F0:5F:3C:3F:92:E5:99:BA:C9:F4:4F:08:06:25:3E:19
SHA1: 7B:33:2E:88:46:01:93:B3:94:6E:CD:EE:63:FD:4C:37:30:C3:44:CD
SHA-256: 50:66:DE:85:D7:DF:C1:E4:48:BF:46:53:F4:8C:77:A9:0B:1F:E9:D5:0C:FC:5A:E3:B5:D2:2C:83:5C:68:0F:CB
Valid until: Thursday, November 14, 2052
----------
Variant: debugAndroidTest
Config: debug
Store: /Users/einaki/.android/debug.keystore
Alias: AndroidDebugKey
MD5: F0:5F:3C:3F:92:E5:99:BA:C9:F4:4F:08:06:25:3E:19
SHA1: 7B:33:2E:88:46:01:93:B3:94:6E:CD:EE:63:FD:4C:37:30:C3:44:CD
SHA-256: 50:66:DE:85:D7:DF:C1:E4:48:BF:46:53:F4:8C:77:A9:0B:1F:E9:D5:0C:FC:5A:E3:B5:D2:2C:83:5C:68:0F:CB
Valid until: Thursday, November 14, 2052



<!DOCTYPE html>
<html>
<head>
  <!--
    If you are serving your web app in a path other than the root, change the
    href value below to reflect the base path you are serving from.

    The path provided below has to start and end with a slash "/" in order for
    it to work correctly.

    For more details:
    * https://developer.mozilla.org/en-US/docs/Web/HTML/Element/base

    This is a placeholder for base href that will be replaced by the value of
    the `--base-href` argument provided to `flutter build`.
  -->
  <base href="/">

  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="description" content="A new Flutter project.">

  <!-- iOS meta tags & icons -->
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="chatboom">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">

  <!-- Favicon -->
  <link rel="icon" type="image/png" href="favicon.png"/>

  <title>chatboom</title>
  <link rel="manifest" href="manifest.json">
  <style>
    /* Match your app's deep dark background */
    body {
      background-color: #121212;
      margin: 0;
      padding: 0;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      overflow: hidden;
    }

    /* A sleek blue loading ring to match your theme */
    .chatboom-loader {
      width: 48px;
      height: 48px;
      border: 4px solid #1E1E1E;
      border-top: 4px solid #448AFF; /* Colors.blueAccent */
      border-radius: 50%;
      animation: spin 1s linear infinite;
    }

    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
  </style>
</head>
<body style="background-color: #121212;">
  <div class="chatboom-loader"></div>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
