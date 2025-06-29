//
//  AppError.swift
//  PodcastDownloader
//
//  Created by Mansour Kalagar on 28.06.25.
//

import Foundation

enum AppError: LocalizedError, Identifiable {
    case networkUnavailable
    case invalidURL(String)
    case downloadFailed(String)
    case fileSystemError(String)
    case parsingError(String)
    case unsupportedProvider(String)
    case quotaExceeded
    case authenticationRequired
    case metadataExtractionFailed(String)
    
    var id: String {
        switch self {
        case .networkUnavailable:
            return "network_unavailable"
        case .invalidURL:
            return "invalid_url"
        case .downloadFailed:
            return "download_failed"
        case .fileSystemError:
            return "filesystem_error"
        case .parsingError:
            return "parsing_error"
        case .unsupportedProvider:
            return "unsupported_provider"
        case .quotaExceeded:
            return "quota_exceeded"
        case .authenticationRequired:
            return "auth_required"
        case .metadataExtractionFailed:
            return "metadata_extraction_failed"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "No internet connection available"
        case .invalidURL(_):
            return "Invalid URL: \\(url)"
        case .downloadFailed(_):
            return "Download failed: \\(reason)"
        case .fileSystemError(_):
            return "File system error: \\(reason)"
        case .parsingError(_):
            return "Parsing error: \\(reason)"
        case .unsupportedProvider(_):
            return "Unsupported provider: \\(provider)"
        case .quotaExceeded:
            return "API quota exceeded. Please try again later."
        case .authenticationRequired:
            return "Authentication required for this provider"
        case .metadataExtractionFailed(_):
            return "Metadata extraction failed: \\(reason)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .networkUnavailable:
            return "Please check your internet connection and try again."
        case .invalidURL:
            return "Please check the URL format and try again."
        case .downloadFailed:
            return "The download could not be completed."
        case .fileSystemError:
            return "There was a problem accessing the file system."
        case .parsingError:
            return "The content could not be processed."
        case .unsupportedProvider:
            return "This provider is not currently supported."
        case .quotaExceeded:
            return "The service has reached its usage limit."
        case .authenticationRequired:
            return "Please configure authentication for this provider."
        case .metadataExtractionFailed:
            return "Could not extract metadata from the content."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Connect to the internet and try again."
        case .invalidURL:
            return "Verify the URL is correct and complete."
        case .downloadFailed:
            return "Try downloading again or check the source."
        case .fileSystemError:
            return "Check disk space and permissions."
        case .parsingError:
            return "Contact support if this persists."
        case .unsupportedProvider:
            return "Use a supported provider like YouTube, Spotify, or RSS."
        case .quotaExceeded:
            return "Wait and try again, or upgrade your service plan."
        case .authenticationRequired:
            return "Go to Settings to configure authentication."
        case .metadataExtractionFailed:
            return "Try a different URL or contact support if this persists."
        }
    }
}
