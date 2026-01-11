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
                Color.charlestonGreen.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Back button

                    
                    VStack {
                        VStack {
                            Image("logoSplash")
                                .resizable()
                                .frame(width: 120, height: 100)
                                .padding(.bottom, 40)
                                .offset(y: welcomeTextOffset)
                                .opacity(welcomeTextOpacity)
                                .onAppear {
                                    withAnimation(.easeOut(duration: 0.8)) {
                                        welcomeTextOffset = 0
                                        welcomeTextOpacity = 1.0
                                    }
                                }
                                .shadow(color: Color.alabaster.opacity(0.5), radius: 10, x: 0, y: 5)
                            Text("Enter Your Email")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.charlestonGreen)
                                .padding(.bottom, 10)
                                .shadow(color: Color.alabaster.opacity(0.5), radius: 10, x: 0, y: 5)

                            Text("Please check and enter your email before configuring the LED, and verify that you are a valid user.")
                                .font(.subheadline)
                                .foregroundColor(Color.charlestonGreen)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding()
                        
                        VStack(spacing: 60) {
                            TextField("Email Address", text: $email, prompt: Text("Email Address")
                                .foregroundColor(.charlestonGreen.opacity(0.6)))
                                .foregroundColor(Color.charlestonGreen)
                                .padding()
                                .background(Color.alabaster)
                                .cornerRadius(10)
                                .padding(.horizontal)
                                .textInputAutocapitalization(.never)  // Prevents first letter capitalization
                        }
                        .padding(.bottom, 40)
                        
                        // Update the Button in body
                        Button(action: {
                            isLoading = true
                            verifyEnmail()
                        }) {
                            ZStack {
                                Text("Send Link")
                                    .font(.headline)
                                    .foregroundColor(.alabaster)
                                    .opacity(isLoading ? 0 : 1)

                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .alabaster))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.charlestonGreen)
                            .cornerRadius(10)
                        }
                        .disabled(isLoading)
                        .padding(.horizontal)
                        
                    }
                    .keyboardResponsive()

                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.charlestonGreen, // Eton

                                        Color.alabaster  // Alabaster
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                    )
                )
                .padding(.bottom, 0)
                .edgesIgnoringSafeArea(.all)
                .shadow(color: Color.charlestonGreen.opacity(0.3), radius: 20)
                
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.alabaster)
                            .font(.system(size: 24))
                            .bold()
                    }
                    .padding(.leading)
                    Spacer()
                }
                .padding(.top, 10)
                .padding(.horizontal)
            
            }
            
            .fullScreenCover(isPresented: $isEmailVerified) {
                AddDeviceView()
            }
            // Add this modifier to your ZStack in the body:
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
            
            guard let url = URL(string: APIConstants.productionUser) else {
                errorMessage = "Invalid URL"
                showErrorAlert = true
                isLoading = false
                return
            }
            
            let parameters = ["email": email]
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
            } catch {
                self.errorMessage = "Error creating request"
                self.showErrorAlert = true
                isLoading = false
                return
            }
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        self.showErrorAlert = true
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse,
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
            }.resume()
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
