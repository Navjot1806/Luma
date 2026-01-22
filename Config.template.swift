//
//  Config.template.swift
//  Luma
//
//  Configuration template - Copy this to Luma/Config.swift and add your API keys
//

import Foundation

struct Config {
    /// Google Cloud Vision API Key
    /// Get your key from: https://console.cloud.google.com/apis/credentials
    ///
    /// To use:
    /// 1. Copy this file to Luma/Config.swift
    /// 2. Replace "YOUR_API_KEY_HERE" with your actual API key
    /// 3. Never commit Config.swift with real keys to git
    static let googleCloudVisionAPIKey = "YOUR_API_KEY_HERE"

    /// Check if API key is configured
    static var isCloudVisionConfigured: Bool {
        return googleCloudVisionAPIKey != "YOUR_API_KEY_HERE" && !googleCloudVisionAPIKey.isEmpty
    }
}
