//
//  AuthViewController.swift
//  MySpotify
//
//  Created by Saltanat Zarkhinova on 10.12.2024.
//

import UIKit
import WebKit

class AuthViewController: UIViewController, WKNavigationDelegate {
    
    private let webView: WKWebView = {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        let webView = WKWebView(frame: .zero, configuration: config)
        return webView
    }()
    
    public var completionHandler: ((Bool)-> Void)?
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sign in"
        view.backgroundColor = .systemBackground
        webView.navigationDelegate = self
        view.addSubview(webView)
        guard let url = AuthManager.shared.signInURL else {
            return
        }
        webView.load(URLRequest(url: url))
            
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        webView.frame = view.bounds
    }
    
    private func loadAuthorizationURL() {
        guard let url = AuthManager.shared.signInURL else {
            print("Failed to generate sign-in URL")
            return
        }
        print("Loading Sign-In URL: \(url.absoluteString)") 
        webView.load(URLRequest(url: url))
    }
                
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        if url.absoluteString.starts(with: AuthManager.Constraints.redirectURI) {
            decisionHandler(.cancel)
            
            let components = URLComponents(string: url.absoluteString)
            let code = components?.queryItems?.first(where: { $0.name == "code" })?.value
            let receivedState = components?.queryItems?.first(where: { $0.name == "state" })?.value
            
            let expectedState = UserDefaults.standard.string(forKey: "spotify_auth_state")
            guard receivedState == expectedState else {
                print("State mismatch. Possible CSRF attack.")
                completionHandler?(false)
                return
            }
            
            if let code = code {
                print("Authorization Code Received: \(code)") 
                webView.isHidden = true
                
                AuthManager.shared.exchangeCodeForToken(code: code) { [weak self] success in
                    DispatchQueue.main.async {
                        self?.navigationController?.popToRootViewController(animated: true)
                        self?.completionHandler?(success)
                    }
                }
            } else {
                print("Authorization code not found in URL.")
                completionHandler?(false)
            }
        } else {
            decisionHandler(.allow)
        }
    }
        
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("WebView failed to load: \(error.localizedDescription)")
        completionHandler?(false)
    }
    
    
}
