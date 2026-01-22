//
//  Config.swift
//  Luma
//
//  Secure configuration management
//

import Foundation

struct Config {
    /// Google Cloud Vision API Key
    /// ⚠️ IMPORTANT: Never commit real API keys to git!
    /// To use Cloud Vision:
    /// 1. Get your API key from Google Cloud Console
    /// 2. Replace "YOUR_API_KEY_HERE" with your actual key
    /// 3. Make sure this file is in .gitignore
    static let googleCloudVisionAPIKey = "YOUR_API_KEY_HERE"

    /// Check if API key is configured
    static var isCloudVisionConfigured: Bool {
        return googleCloudVisionAPIKey != "YOUR_API_KEY_HERE" && !googleCloudVisionAPIKey.isEmpty
    }
}
