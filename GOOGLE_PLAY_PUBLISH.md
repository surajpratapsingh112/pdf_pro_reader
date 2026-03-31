# Google Play Par Publish Kaise Karein

## Step 1: Google Play Console Account Banao
1. https://play.google.com/console kholein
2. "Get Started" click karein
3. Google account se login karein
4. $25 one-time fee pay karein (debit/credit card)
5. Developer name: "PDF Pro Apps" ya apna naam

## Step 2: App Listing Banao
1. "Create app" click karein
2. App name: **PDF Pro Reader**
3. Language: Hindi / English
4. Type: App (not game)
5. Free ya Paid: **Free** (AdMob se kamaoge)

## Step 3: AdMob Setup (Paise kamane ke liye)
1. https://admob.google.com par jayen
2. Free account banao (usi Google account se)
3. "Add App" > Android > App name: PDF Pro Reader
4. **App ID milega**: ca-app-pub-XXXXX~YYYYY
5. Yeh ID AndroidManifest.xml mein daalein:
   ```xml
   android:value="ca-app-pub-XXXXX~YYYYY"
   ```
6. 2 Ad Units banao:
   - Banner Ad → ID: ca-app-pub-XXXXX/AAAAAAA
   - Interstitial Ad → ID: ca-app-pub-XXXXX/BBBBBBB
7. Yeh IDs admob_service.dart mein daalein

## Step 4: Release APK Build Karo
```bat
flutter build apk --release
```
APK milegi: build\app\outputs\flutter-apk\app-release.apk

## Step 5: App Upload Karein
1. Play Console > Your App > Production
2. "Create new release"
3. APK upload karein
4. Release notes likhein (Hindi + English)

## Step 6: Store Listing Bharo
- **Title**: PDF Pro Reader - Video PDF Viewer
- **Short description** (80 chars):
  PDF files kholein aur embedded videos seedha PDF mein play karein!
- **Full description**:
  ```
  PDF Pro Reader - Video-Enabled PDF Viewer

  Khas features:
  ✅ PDF files ke andar embedded videos play karein
  ✅ Cyan box dikhega jahan video hai - sirf tap karo
  ✅ Smooth page navigation
  ✅ Pinch to zoom
  ✅ Android aur Windows support
  ✅ Fast aur lightweight

  Yeh app PDF Pro Creator ke saath kaam karta hai jo
  aapko videos PDF mein embed karne deta hai.

  Koi bhi apni presentation, tutorial ya portfolio
  mein videos embed karke share kar sakta hai!
  ```

## Step 7: Screenshots Lein
- 2-8 screenshots minimum
- Size: 1080x1920 (portrait) ya 1920x1080 (landscape)
- Apne mobile par app chalayein, screenshots lein

## Step 8: Review Submit Karein
- Sab form fill karein
- "Send for review" click karein
- 1-3 din mein approve ho jaata hai

## Monetization Timeline
| Month | Expected |
|-------|----------|
| 1-2   | ₹200-500 (shuruat) |
| 3-6   | ₹2,000-10,000 |
| 6-12  | ₹10,000-50,000 |
| 1 yr+ | ₹50,000+ |

$25 investment 2-3 mahine mein recover ho jayegi!
