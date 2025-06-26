
//
//  XPay Swift SDK
//
//  Created by Amir Ghafoor on 19/06/2025.
//

import SwiftUI
#if os(iOS)

public struct XPayJazzCashPaymentForm: View, XPayFormProtocol {
    @State private var phoneNumber: String = ""
    @State private var isPhoneNumberFieldFocused = false
    @State private var isPhoneNumberError = false
    @State private var cnic: String = ""
    @State private var isCnicFieldFocused = false
    @State private var isCnicError = false
    @State private var clientSecret = ""
    @State private var apiPayload: [String: Any] = [:]
    @State private var triggerPaymentResponse: (([String: Any]) -> Void)? = nil
    public var onReady: ((Bool) -> Void)?
    public var onBinDiscount: (([String: Any]) -> Void)?
    var configuration: CustomStyleConfiguration
    var keysConfiguration: KeysConfiguration
    @ObservedObject var controller: XPayController
    public init(keysConfiguration: KeysConfiguration, customStyle: CustomStyleConfiguration = .defaultConfiguration, onReady: ((Bool) -> Void)? = nil, controller: XPayController) {
        self.configuration = customStyle
        self.onReady = onReady
        self.keysConfiguration = keysConfiguration
        self.controller = controller
    }

    func confirmPayment(customerName: String, clientSecret: String, paymentResponse: @escaping (([String: Any]) -> Void)) {
        self.triggerPaymentResponse = paymentResponse
        self.clientSecret = clientSecret
        let cleanedPhoneNumber = phoneNumber.filter { $0.isWholeNumber }
        let cleanedCnic = cnic.filter { $0.isWholeNumber }
        apiPayload = [
            "payment_method_types": "jazzcash-wallet",
            "wallet": [
                "phone": cleanedPhoneNumber,
                "cnic": cleanedCnic,
            ],
        ]
        Task {
            makeNetworkCall(payload: apiPayload, endPoint: "/public/v1/payment/intent/confirm?pi_client_secret=\(self.clientSecret)", keysConfiguration: keysConfiguration, success: { responseData in
                let lastPaymentResponse = responseData["last_payment_response"] as? [String: Any]
                let error = (lastPaymentResponse?["error"] as? Int) ?? responseData["error"] as? Int ?? 0
                let message = (lastPaymentResponse?["message"] as? String) ?? responseData["message"] as? String ?? "Something Went Wrong"
                let status = (lastPaymentResponse?["status"] as? String) ?? responseData["status"] as? String ?? "Unknown"
                let htmlResponse = responseData["html_response"] as? [String: Any]
                let isHiddenHtml = htmlResponse?["hidden"] as? Int ?? 0
                let redirectData = htmlResponse?["next_action"] as? [String: Any]
                let htmlWebContent = redirectData?["redirect"] as? String ??  htmlResponse?["next_action"] as? String ?? ""
                if (error == 0 && htmlWebContent.isEmpty) {
                    self.triggerPaymentResponse?(["status": status, "error": false, "message": message])
                    clear()
                    return
                } else if (error == 1) {
                    self.triggerPaymentResponse?(["status": status, "error": true, "message": message])
                    return
                }
            }, failure: { error in
                if let apiError = error as? APIError {
                    let errorValue = apiError.details["error"] as? [String: Any]
                    let message = (errorValue?["message"] as? String) ?? (apiError.details["message"] as? String) ?? "Something Went Wrong"
                    self.triggerPaymentResponse?(["error": true, "status": "Failed", "message": message])
                } else {
                    self.triggerPaymentResponse?(["error": true, "data": error])
                }
            })
        }
    }

    func clear() {
        phoneNumber = ""
        cnic = ""
        isPhoneNumberError = false
        isCnicError = false
    }

    private func isValidPhoneNumber(_ text: String) -> Bool {
        let digits = text.filter { $0.isWholeNumber }
        var firstDigit: Character?
        var secondDigit: Character?

        if let first = text.first {
            firstDigit = first
        }
        if text.count > 1 {
            secondDigit = text[text.index(text.startIndex, offsetBy: 1)]
        }
        if (digits.count == 11 && firstDigit == "0" && secondDigit == "3") {
            return true
        } else if (digits.count > 0) {
            return false
        }
        return true
    }

    private func isValidCnic(_ text: String) -> Bool {
        let digits = text.filter { $0.isWholeNumber }
        if (digits.count == 6) {
            return true
        } else if (digits.count > 0) {
            return false
        }
        return true
    }

    private func triggerIsReadyEvent() {
        if (isValidPhoneNumber(phoneNumber) && isValidCnic(cnic) && phoneNumber.count > 0 && cnic.count > 0) {
            self.onReady?(true)
        } else {
            self.onReady?(false)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(configuration.inputConfiguration.phoneNumber.label)
                    .font(.system(size: configuration.inputLabelStyle.fontSize))
                    .foregroundColor(configuration.inputLabelStyle.textColor)
                HStack {
                    UITextFieldWrapper(
                        text: $phoneNumber,
                        placeholder: configuration.inputConfiguration.phoneNumber.placeholder,
                        keyboardType: .numberPad,
                        textColor: isPhoneNumberFieldFocused ? configuration.onFocusInputStyle.textColor : isPhoneNumberError ? configuration.invalidStyle.textColor : configuration.inputStyle.textColor,
                        textSize: isPhoneNumberFieldFocused ? configuration.onFocusInputStyle.textSize : isPhoneNumberError ? configuration.invalidStyle.textSize : configuration.inputStyle.textSize,
                        onEditingChanged: { edit in
                            self.isPhoneNumberFieldFocused = edit
                            if !edit && !isValidPhoneNumber(phoneNumber) {
                                self.isPhoneNumberError = true
                            } else if isPhoneNumberError && edit {
                                self.isPhoneNumberError = false
                            }
                        },
                        maxLength: 11,
                        formatType: .phoneNumber
                    )
                    .onChange(of: phoneNumber) { newValue in
                        triggerIsReadyEvent()
                    }
                    .frame(height: configuration.inputStyle.height)
                }
                .padding(.maximum(0, 7))
                .overlay(
                    RoundedRectangle(cornerRadius: configuration.inputStyle.borderRadius)
                        .stroke(isPhoneNumberFieldFocused ? configuration.onFocusInputStyle.borderColor : isPhoneNumberError ? configuration.invalidStyle.borderColor : configuration.inputStyle.borderColor, lineWidth: isPhoneNumberFieldFocused ? configuration.onFocusInputStyle.borderWidth : isPhoneNumberError ? configuration.invalidStyle.borderWidth : configuration.inputStyle.borderWidth)
                )
                if (isPhoneNumberError) {
                    Text("Phone Number is invalid")
                        .font(.system(size: configuration.errorMessageStyle.textSize))
                        .foregroundColor(configuration.errorMessageStyle.textColor)
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(configuration.inputConfiguration.cnic.label)
                    .font(.system(size: configuration.inputLabelStyle.fontSize))
                    .foregroundColor(configuration.inputLabelStyle.textColor)
                HStack {
                    UITextFieldWrapper(
                        text: $cnic,
                        placeholder: configuration.inputConfiguration.cnic.placeholder,
                        keyboardType: .numberPad,
                        textColor: isCnicFieldFocused ? configuration.onFocusInputStyle.textColor : isCnicError ? configuration.invalidStyle.textColor : configuration.inputStyle.textColor,
                        textSize: isCnicFieldFocused ? configuration.onFocusInputStyle.textSize : isCnicError ? configuration.invalidStyle.textSize : configuration.inputStyle.textSize,
                        onEditingChanged: { edit in
                            self.isCnicFieldFocused = edit
                            if !edit && !isValidCnic(cnic) {
                                self.isCnicError = true
                            } else if isCnicError && edit {
                                self.isCnicError = false
                            }
                        },
                        maxLength: 6,
                        formatType: .none
                    )
                    .onChange(of: cnic) { newValue in
                        triggerIsReadyEvent()
                    }
                    .frame(height: configuration.inputStyle.height)
                }
                .padding(.maximum(0, 7))
                .overlay(
                    RoundedRectangle(cornerRadius: configuration.inputStyle.borderRadius)
                        .stroke(isCnicFieldFocused ? configuration.onFocusInputStyle.borderColor : isCnicError ? configuration.invalidStyle.borderColor : configuration.inputStyle.borderColor, lineWidth: isCnicFieldFocused ? configuration.onFocusInputStyle.borderWidth : isCnicError ? configuration.invalidStyle.borderWidth : configuration.inputStyle.borderWidth)
                )
                if (isCnicError) {
                    Text("CNIC number is invalid")
                        .font(.system(size: configuration.errorMessageStyle.textSize))
                        .foregroundColor(configuration.errorMessageStyle.textColor)
                }
            }
        }.onAppear {
            controller.setElement(self)
        }

    }
}
#endif
