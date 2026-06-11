# Login Screen Cleanup Audit

## Active flow

Current active authentication entry chain:

1. `LimiExhibition/Onboard/OnboardingView.swift`
2. `LimiExhibition/Login Screen/SignIn.swift` via `SignInView`
3. `LimiExhibition/Login Screen/LoginView.swift` via `LoginSkipView`
4. `OTPVerificationView` inside `LoginView.swift`
5. `HomeView`

`GetStart/GetStart.swift` still references `LoginView()` and `PULoginView()`, so those flows remain reachable outside onboarding.

## File classification

### Keep and continue refactoring

- `LimiExhibition/Login Screen/SignIn.swift`
  - Active onboarding sign-in gateway.
  - Distinct responsibility: pre-login shell with Google, Email, Guest, Privacy Policy.
  - Should eventually gain its own `SignInViewModel`.

- `LimiExhibition/Login Screen/LoginView.swift`
  - Active email/OTP auth screen.
  - Still contains multiple responsibilities and legacy sections in one file.
  - Keep, but continue extraction and later split into smaller files.

- `LimiExhibition/Login Screen/LoginViewModel.swift`
  - New active MVVM file for email sign-in / OTP request.
  - Keep.

- `LimiExhibition/Login Screen/OTPVerificationViewModel.swift`
  - New active MVVM file for OTP verification / resend.
  - Keep.

### Keep, but review for relocation

- `LimiExhibition/PULoginView.swift`
  - Still referenced by `GetStart/GetStart.swift`.
  - Looks like a separate production-user verification flow, not part of `Login Screen`.
  - Candidate move to `Features/Authentication/ProductionUser` or similar.

### Review manually

- `LimiExhibition/Login Screen/LoginView.swift`
  - Contains active `LoginView`, active `OTPVerificationView`, active `LoginSkipView`, plus extra legacy types farther down in the same file.
  - Should be split before any aggressive cleanup.

## In-file cleanup candidates inside `LoginView.swift`

### Active sections to keep

- `LoginView`
- `OTPVerificationView`
- `OTPDigitBox`
- `LottieLoadingView`
- `ShakeEffect`
- `LoginSkipView`

### Likely legacy / duplicate sections to extract or remove later

- `AppleSignInButtonView`
  - Appears to be alternate Apple sign-in implementation.
  - Not the active Apple button path used by the top `LoginView`.

- `AppleAuthManager`
  - Appears tied to alternate Apple sign-in implementation.
  - Needs reference verification before removal.

- Commented-out duplicate `LoginSkipView` block
  - Clear cleanup candidate after validation.

- Older duplicated login logic further down the file
  - Repeated email/OTP state and request logic exists below the active top flow.
  - Should be removed only after splitting active views into dedicated files.

## Risk assessment

### Low risk

- Remove commented-out duplicate code blocks after active flow is split.
- Move `LoginViewModel.swift` and `OTPVerificationViewModel.swift` into cleaner feature structure.

### Medium risk

- Remove `AppleSignInButtonView` and `AppleAuthManager` without first checking all references.
- Shrink `LoginView.swift` while multiple active and legacy structs still coexist in the same file.

### High risk

- Deleting `LoginSkipView` or `PULoginView` now.
  - Both are still reachable from current navigation.

## Recommended next cleanup order

1. Split `LoginView.swift` into dedicated files:
   - `LoginView.swift`
   - `OTPVerificationView.swift`
   - `LoginSkipView.swift`
   - `LoginSharedComponents.swift` for `OTPDigitBox`, `LottieLoadingView`, `ShakeEffect`
2. Re-run reference audit for:
   - `AppleSignInButtonView`
   - `AppleAuthManager`
   - lower duplicate login blocks
3. Remove verified dead legacy blocks from `LoginView.swift`
4. Rebuild and smoke-test email OTP, Google sign-in, Apple sign-in, and onboarding sign-in path
