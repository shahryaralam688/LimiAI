//
//  NotificationView 2.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 20/11/2025.
//



import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    let onBack: () -> Void = {}
    @State private var showGooglePermissionAlert = false
    @State private var isRequestingGooglePermissions = false
    @StateObject private var googleAuthManager = GoogleAuthManager()

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }

    var body: some View {
        VStack{
            VStack{
                HStack {
                    Button(action: {
                        onBack()
                        dismiss()
                    }) {
                        Image("Solid arrow right sm")
                            .foregroundColor(.alabaster)
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 44)
                            .background(Color.appInputFill)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Text("Privacy Policy")
                        .font(AIDesignTokens.h1Font)
                        .foregroundColor(AIDesignTokens.textPrimary)
                    
                    Spacer()
                }
                .padding(.top, 24)
                .padding(.horizontal, AIDesignTokens.spacingLG)
                .frame(height: 124)
                .background(
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color.appSurfaceTertiary)
                        .clipShape(
                        .rect(
                            topLeadingRadius: 40,
                            bottomLeadingRadius: 40,
                            bottomTrailingRadius: 40,
                            topTrailingRadius: 40
                        )
                    )
                )

            }
            Spacer()
            ScrollView{
                VStack(alignment: .leading, spacing: 16) {
                    Button(action: {
                        print("[PrivacyPolicyView] Grant Google Permissions button tapped")
                        showGooglePermissionAlert = true
                    }) {
                        Text("Grant Google Permissions")
                            .font(.headline)
                            .foregroundColor(.themeWhite)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .disabled(isRequestingGooglePermissions)
                    .alert("Google Permissions", isPresented: $showGooglePermissionAlert) {
                        Button("Cancel", role: .cancel) {
                            print("[PrivacyPolicyView] Google permissions alert canceled by user")
                        }
                        Button(isRequestingGooglePermissions ? "Requesting..." : "Allow") {
                            print("[PrivacyPolicyView] Allow button tapped in Google permissions alert")
                            guard !isRequestingGooglePermissions else { return }
                            print("[PrivacyPolicyView] Starting Google permissions request...")
                            isRequestingGooglePermissions = true
                            let scopes = AppURLs.External.googleScopes
                            print("[PrivacyPolicyView] Requesting Google permissions with scopes: \(scopes)")
                            googleAuthManager.requestGooglePermissions(scopes: scopes) { success in
                                print("[PrivacyPolicyView] Google permissions request completed. Success = \(success)")
                                DispatchQueue.main.async {
                                    isRequestingGooglePermissions = false
                                    print("[PrivacyPolicyView] isRequestingGooglePermissions set to false")
                                }
                            }
                        }
                    } message: {
                        Text("This app will request access to your Google Calendar, Gmail (read/send), and Contacts to provide related features. You can change these permissions at any time in your Google Account settings.")
                    }

                    Text("""
Last Updated: \(formattedDate)
We at [Company Name] respect your privacy and are committed to protecting your personal information. This Privacy Policy explains how we collect, use, and disclose information about you when you use our Property Inspection Management App ("the App") and the associated services. By using the App, you agree to the practices described in this policy.

1. Information We Collect
We collect the following types of information to provide and improve our services:

1.1 Personal Information
When you register or use the App, we may collect personal information such as:
• Name
• Email address
• Contact number
• Business information (if applicable)

1.2 Property Information
To facilitate property inspections, we may collect and store information about the properties you inspect, including:
• Property address and details (e.g., size, type, condition)
• Photos, videos, or documents you upload related to the inspection
• Notes and inspection reports

1.3 Usage Information
We automatically collect information on how you interact with the App, such as:
• Device information (e.g., IP address, browser type, operating system)
• Log data (e.g., date and time of access, pages viewed, time spent on each page)
• Cookies and similar technologies to enhance user experience

2. How We Use Your Information
We use the information we collect to:
• Provide, maintain, and improve the App’s features and functionality
• Manage user accounts and provide customer support
• Generate inspection reports and store property information
• Communicate updates, services, or promotional materials (you can opt out at any time)
• Analyze usage trends and enhance user experience

3. How We Share Your Information
We do not sell your personal information. We may share your information in the following circumstances:
• Service Providers: We may share your information with third-party vendors or service providers who assist us in operating the App (e.g., cloud storage, analytics services).
• Legal Compliance: We may disclose your information to comply with legal obligations, court orders, or government requests.
• Business Transfers: In the event of a merger, acquisition, or sale of all or a portion of our assets, your information may be transferred as part of that transaction.

4. Data Security
We implement appropriate technical and organizational measures to protect your information from unauthorized access, alteration, or disclosure. However, no method of transmission over the internet is 100% secure, so we cannot guarantee absolute security.

5. Data Retention
We retain your personal information only as long as necessary to fulfill the purposes for which it was collected or as required by law. When no longer needed, we securely delete or anonymize your data.

6. Your Privacy Rights
Depending on your jurisdiction, you may have the following rights regarding your personal information:
• Access: You can request access to the personal information we hold about you.
• Correction: You can request corrections to inaccurate or incomplete personal information.
• Deletion: You may request the deletion of your personal information, subject to legal obligations.
• Opt-out: You can opt out of marketing communications at any time.
To exercise any of these rights, please contact us at [email address].

7. Third-Party Links
The App may contain links to third-party websites or services. This Privacy Policy does not apply to those websites or services, and we are not responsible for their privacy practices. We encourage you to review their privacy policies.

8. Children’s Privacy
Our App is not intended for individuals under the age of 18, and we do not knowingly collect personal information from children. If you believe we have collected personal information from a child, please contact us to remove the information.

9. Changes to this Privacy Policy
We may update this Privacy Policy from time to time to reflect changes in our practices. We will notify you of any material changes by posting the updated policy on the App. Your continued use of the App after such changes constitutes acceptance of the updated Privacy Policy.

10. Contact Us
If you have any questions about this Privacy Policy or our data practices, please contact us at:
[Company Name]
[Email Address]
[Contact Address]
""")
                    .foregroundColor(.themeWhite)
                    .padding(.top, 8)
                }
                .padding()
            }

        }
        .background(AIDesignTokens.bgBase)
        .ignoresSafeArea(.container, edges: .bottom)
    }
}
#Preview {
    PrivacyPolicyView()
}
