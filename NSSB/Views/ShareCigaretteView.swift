//
//  ShareCigaretteView.swift
//  NSSB
//
//  Created by Anders Munck on 08/07/2024.
//

import SwiftUI

struct ShareCigaretteView: View {
    
    let cigarette:CigDesign
    
    //private let messageComposeDelegate = MessageComposerDelegate()
    
    var body: some View {
        
        if let cigURL = cigarette.encodeURL() {
            
            ZStack(alignment: .bottomTrailing) {
                
                //let preview = SharePreview(cigarette.title, icon: Image(systemName: "pencil"))
                
                ShareLink(item: cigURL, subject: Text("Try my custom non-smoke"), message: Text("Have a non-smoking smoke break with my custom non-smoking smoke\(cigarette.title.isEmpty ? "." : ": \(cigarette.title)")"), label: {
                    Text(Image(systemName: "square.and.arrow.up"))
                        .font(.title)
                })
                
                
            }
            
        } else {
            EmptyView()
        }
        
    }
}

#Preview {
    ShareCigaretteView(cigarette: CigDesign.example3)
}

/*import MessageUI

extension ShareCigaretteView {

    private class MessageComposerDelegate: NSObject, MFMessageComposeViewControllerDelegate {
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            // Customize here
            controller.dismiss(animated: true)
        }
    }
    /// Present an message compose view controller modally in UIKit environment
    private func presentMessageCompose(body: String? = nil) {
        guard MFMessageComposeViewController.canSendText() else {
            return
        }
        //let vc = UIApplication.shared.windows.filter {$0.isKeyWindow}.first?.rootViewController
        let vc = UIApplication.shared
            .connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .last?.rootViewController
        
        let composeVC = MFMessageComposeViewController()
        
        composeVC.messageComposeDelegate = messageComposeDelegate

        composeVC.body = body
        
        vc?.present(composeVC, animated: true)
    }
}
*/
