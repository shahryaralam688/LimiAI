//
    //  PULoginView.swift
    //  Limi
    //
    //  Created by Mac Mini on 28/03/2025.
    //

    import SwiftUI


    struct PULoginView: View {
        @Environment(\.dismiss) private var dismiss
        @State private var email: String = ""
        @State private var isEmailVerified: Bool = false
        @State private var showErrorAlert: Bool = false
        @State private var errorMessage: String = ""
        @State private var welcomeTextOffset: CGFloat = 100
        @State private var welcomeTextOpacity: Double = 0.0
        @State private var isLoading: Bool = false
        
        var body: some View {
            ZStack(alignment: .top) {
                DeepSpaceBackground()

                VStack(spacing: 0) {
                    HStack {
                        LimiBackButton { dismiss() }
                        Spacer()
                    }
                    .padding(.horizontal, LimiSpacing.screenHorizontal)
                    .padding(.top, LimiSpacing.screenTop)

                    VStack(spacing: LimiSpacing.sectionGap) {
                        Image("logoSplash")
                            .resizable()
                            .frame(width: 120, height: 100)
                            .padding(.bottom, 20)
                            .offset(y: welcomeTextOffset)
                            .opacity(welcomeTextOpacity)
                            .onAppear {
                                withAnimation(.easeOut(duration: 0.8)) {
                                    welcomeTextOffset = 0
                                    welcomeTextOpacity = 1.0
                                }
                            }

                        Text("Enter Your Email")
                            .font(LimiTypography.title)
                            .foregroundColor(.appTextPrimary)
                            .padding(.bottom, 4)

                        Text("Please check and enter your email before configuring the LED, and verify that you are a valid user.")
                            .font(LimiTypography.subheadline)
                            .foregroundColor(.appTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        LimiTextField(placeholder: "Email Address", text: $email, keyboardType: .emailAddress)
                            .textInputAutocapitalization(.never)
                            .padding(.horizontal)
                            .padding(.top, 20)

                        LimiPrimaryButton(title: "Send Link", isEnabled: !isLoading) {
                            isLoading = true
                            verifyEnmail()
                        }
                        .padding(.horizontal)
                        .overlay {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .appTextPrimary))
                            }
                        }
                    }
                    .keyboardResponsive()

                    Spacer()
                }
            }
            .fullScreenCover(isPresented: $isEmailVerified) {
                AddDeviceCoordinator.destination(for: .legacyInstallerFlow)
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }

        // Modified verifyEnmail function
            func verifyEnmail() {
            guard !email.isEmpty else {
                errorMessage = "Please enter an email address"
                showErrorAlert = true
                isLoading = false
                return
            }

            LimiHTTPClient.postJSON(
                urlString: APIConstants.productionUser,
                body: ["email": email],
                auth: .none
            ) { data, response, error in
                DispatchQueue.main.async {
                    isLoading = false

                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        self.showErrorAlert = true
                        return
                    }

                    guard let httpResponse = response,
                          let data = data else {
                        self.errorMessage = "Invalid response from server"
                        self.showErrorAlert = true
                        return
                    }

                    do {
                        let decoder = JSONDecoder()
                        let response = try decoder.decode(EmailVerificationResponse.self, from: data)

                        switch httpResponse.statusCode {
                        case 200:
                            self.isEmailVerified = true
                        case 500:
                            self.errorMessage = response.error_message ?? "User is Invalid"
                            self.showErrorAlert = true
                        default:
                            self.errorMessage = "Unexpected error occurred"
                            self.showErrorAlert = true
                        }
                    } catch {
                        self.errorMessage = "Failed to process response"
                        self.showErrorAlert = true
                    }
                }
            }
        }


        // Response model
        struct EmailVerificationResponse: Codable {
            let success: Bool
            let message: String?
            let error_message: String?
            let production_user: Bool?
        }
    }

    #Preview {
        PULoginView()
    }
