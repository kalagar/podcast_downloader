//
//  ErrorView.swift
//  PodcastDownloader
//
//  Created by Mansour Kalagar on 28.06.25.
//

import SwiftUI

struct ErrorView: View {
    let error: AppError
    let retryAction: (() -> Void)?
    
    init(error: AppError, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            VStack(spacing: 8) {
                Text(error.errorDescription ?? "An error occurred")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                if let failureReason = error.failureReason {
                    Text(failureReason)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                if let recoverySuggestion = error.recoverySuggestion {
                    Text(recoverySuggestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            
            HStack {
                if let retryAction = retryAction {
                    Button("Retry") {
                        retryAction()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Button("Dismiss") {
                    // Handle dismissal
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: 300)
    }
    
    private var iconName: String {
        switch error {
        case .networkUnavailable:
            return "wifi.slash"
        case .invalidURL:
            return "link.badge.plus"
        case .downloadFailed:
            return "arrow.down.circle.fill"
        case .fileSystemError:
            return "folder.badge.minus"
        case .parsingError:
            return "doc.badge.ellipsis"
        case .unsupportedProvider:
            return "questionmark.circle"
        case .quotaExceeded:
            return "exclamationmark.triangle"
        case .authenticationRequired:
            return "person.badge.key"
        case .metadataExtractionFailed:
            return "info.circle"
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ErrorView(error: .networkUnavailable) {
            print("Retry network")
        }
        
        ErrorView(error: .invalidURL("https://invalid.example.com"))
        
        ErrorView(error: .downloadFailed("Connection timeout"))
    }
    .padding()
}
