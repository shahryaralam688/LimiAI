# Weather API Setup Instructions

## Quick Setup (5 minutes)

### Step 1: Get Your Free API Key

1. Go to [OpenWeatherMap Sign Up](https://home.openweathermap.org/users/sign_up)
2. Create a free account
3. Verify your email
4. Go to [API Keys](https://home.openweathermap.org/api_keys)
5. Copy your API key (it looks like: `a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6`)

### Step 2: Add API Key to Your Project

1. Open `WeatherService.swift` in Xcode
2. Find line 15:
   ```swift
   private let apiKey = "YOUR_API_KEY_HERE"
   ```
3. Replace `YOUR_API_KEY_HERE` with your actual API key:
   ```swift
   private let apiKey = "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"
   ```
4. Save the file

### Step 3: Test the Weather Widget

1. Build and run the app in the simulator
2. Grant location permission when prompted
3. The weather widget should now display:
   - ✅ Loading animation (briefly)
   - ✅ Real temperature from your location
   - ✅ Weather condition (e.g., "Clear sky", "Light rain")
   - ✅ Feels like temperature
   - ✅ Humidity percentage
   - ✅ Atmospheric pressure

## Troubleshooting

### "Please add your OpenWeatherMap API key" error
- You forgot to replace `YOUR_API_KEY_HERE` with your actual API key

### "Invalid API key" error
- Check that you copied the entire API key correctly
- Make sure there are no extra spaces
- Wait a few minutes - new API keys can take 10-15 minutes to activate

### Weather not loading
- Check that you granted location permission
- Make sure you have an internet connection
- Check the Xcode console for detailed error messages

### Location permission denied
- Go to iOS Settings → Privacy → Location Services
- Enable location for your app

## API Key Security Note

⚠️ **Important**: The API key is currently hardcoded in the source code. For production apps, you should:
- Store the API key in a secure configuration file
- Use environment variables
- Never commit API keys to public repositories

For this demo/exhibition app, the current approach is acceptable.
