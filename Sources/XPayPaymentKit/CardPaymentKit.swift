
//
//  XPay Swift SDK
//
//  Created by Amir Ghafoor on 21/05/2024.
//

import SwiftUI
import WebKit
import Foundation
import Combine
import CryptoKit
#if os(iOS)

struct WebView: UIViewRepresentable {
    let htmlContent: String
    let messageHandler: (String) -> Void
    @Binding var isLoading: Bool
    var shouldHide: Bool = false

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebView
        var cancellables = Set<AnyCancellable>()
        var isLoadingSubject = CurrentValueSubject<Bool, Never>(true)

        init(parent: WebView) {
            self.parent = parent
            super.init()
            isLoadingSubject
                .receive(on: RunLoop.main)
                .sink { isLoading in
                    if !isLoading {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            self.parent.isLoading = false
                        }
                    } else {
                        self.parent.isLoading = true
                    }
                }
                .store(in: &cancellables)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoadingSubject.send(false)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoadingSubject.send(false)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoadingSubject.send(false)
            let js = """
            var meta = document.createElement('meta');
            meta.setAttribute('name', 'viewport');
            meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');
            document.getElementsByTagName('head')[0].appendChild(meta);
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.request.url != nil {
                decisionHandler(.allow)
                return
            }
            decisionHandler(.cancel)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            decisionHandler(.allow)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "XPayPostServerEvent", let messageBody = message.body as? String {
                parent.messageHandler(messageBody)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        let contentController = webView.configuration.userContentController
        contentController.add(context.coordinator, name: "XPayPostServerEvent")
        webView.navigationDelegate = context.coordinator
        webView.isHidden = shouldHide
        if let url = URL(string: htmlContent), url.scheme != nil {
            let urlRequest = URLRequest(url: url)
            webView.load(urlRequest)
        } else{
            webView.loadHTMLString(htmlContent, baseURL: nil)
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url == nil || webView.url?.absoluteString == "about:blank" {
            webView.isHidden = shouldHide
            if let url = URL(string: htmlContent), url.scheme != nil {
                let urlRequest = URLRequest(url: url)
                webView.load(urlRequest)
            } else{
                webView.loadHTMLString(htmlContent, baseURL: nil)
            }
        }
    }
}

public struct XPayPaymentForm: View, XPayFormProtocol {
    @State private var cardNumber: String = ""
    @State private var expiryDate: String = ""
    @State private var cvv: String = ""
    @State private var cardIcon: String = "visa_master_card"
    @State private var isCardFieldFocused = false
    @State private var isCardNumberError = false
    @State private var isExpiryFieldFocused = false
    @State private var isExpiryDateError = false
    @State private var isCVCFieldFocused = false
    @State private var isCVCError = false
    @State private var showWebView = false
    @State private var htmlContent = ""
    @State private var csHiddenhtmlContent = ""
    @State private var clientSecret = ""
    @State private var apiPayload: [String: Any] = [:]
    @State private var triggerPaymentResponse: (([String: Any]) -> Void)? = nil
    @State private var isLoading = true
    public var onReady: ((Bool) -> Void)?
    public var onBinDiscount: (([String: Any]) -> Void)?
    var configuration: CustomStyleConfiguration
    var keysConfiguration: KeysConfiguration
    @ObservedObject var controller: XPayController
    public init(keysConfiguration: KeysConfiguration, customStyle: CustomStyleConfiguration = .defaultConfiguration, onBinDiscount: (([String: Any]) -> Void)? = nil, onReady: ((Bool) -> Void)? = nil, controller: XPayController) {
        self.configuration = customStyle
        self.onReady = onReady
        self.keysConfiguration = keysConfiguration
        self.onBinDiscount = onBinDiscount
        self.controller = controller
    }

    func confirmPayment(customerName: String, clientSecret: String, paymentResponse: @escaping (([String: Any]) -> Void)) {
        self.triggerPaymentResponse = paymentResponse
        self.clientSecret = clientSecret
        let splitedExpiryDate = expiryDate.components(separatedBy: "/")
        let expiryMonth = splitedExpiryDate[0]
        let expiryYear = splitedExpiryDate[1]
        let cardNumber = cardNumber.filter { $0.isWholeNumber }
        apiPayload = [
            "payment_method_types": "card",
            "card": [
                "number": cardNumber,
                "cvc": cvv,
                "exp_month": expiryMonth,
                "exp_year": expiryYear,
                "cardholder_name": customerName
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
                
                if (!htmlWebContent.isEmpty && isHiddenHtml == 0) {
                    DispatchQueue.main.async {
                        self.htmlContent = htmlWebContent
                        self.csHiddenhtmlContent = ""
                    }
                } else if (!htmlWebContent.isEmpty && isHiddenHtml == 1) {
                    DispatchQueue.main.async {
                        self.csHiddenhtmlContent = htmlWebContent
                        self.htmlContent = ""
                    }
                } else if (error == 0 && htmlWebContent.isEmpty) {
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
        cardNumber = ""
        expiryDate = ""
        cvv = ""
        isCardNumberError = false
        isExpiryDateError = false
        isCVCError = false
    }

    private func isValidCardNumber(_ text: String) -> Bool {
        let digits = text.filter { $0.isWholeNumber }
        var firstDigit: Character?
        if let char = text.first {
            firstDigit = char
        } else {
            firstDigit = nil
        }
        if (digits.count == 16 && (firstDigit == "4" || firstDigit == "5")) {
            return true
        } else if (digits.count > 0) {
            return false
        }
        return true
    }

    private func isValidExpiryDate(_ text: String) -> Bool {
        let digits = text.filter { $0.isWholeNumber }
        if (digits.count == 4) {
            return true
        } else if (digits.count > 0) {
            return false
        }
        return true
    }

    private func getCardIcon(_ text: String) -> String {
        guard let firstChar = text.first else {
            return "visa_master_card"
        }
        switch firstChar {
        case "4":
            return "visa"
        case "5":
            return "mastercard"
        default:
            return "visa_master_card"
        }
    }

    private func triggerIsReadyEvent() {
        if (isValidCardNumber(cardNumber) && isValidExpiryDate(expiryDate) && cvv.count == 3 && cardNumber.count > 0 && expiryDate.count > 0) {
            self.onReady?(true)
        } else {
            self.onReady?(false)
        }
    }

    private func handleBinDiscount() {
        if (isValidCardNumber(cardNumber) && cardNumber.count > 0) {
            let digits = cardNumber.filter { $0.isWholeNumber }
            let bin = String(digits.prefix(6))
            Task {
                makeNetworkCall(payload: ["account_id": keysConfiguration.accountId, "bin": bin], endPoint: "/public/v1/bin/config", keysConfiguration: keysConfiguration, success: { responseData in
                    self.onBinDiscount?(responseData)
                })
            }
        }
    }

    func handleCSIframePostMessage(eventResponse: String) {
        if let jsonData = eventResponse.data(using: .utf8) {
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                    let event = jsonResponse["event"] as? String ?? "none"
                    let dataString = jsonResponse["data"] as? String ?? ""
                    var messageType = ""
                    if let innerJsonData = dataString.data(using: .utf8) {
                        if let innerJsonResponse = try JSONSerialization.jsonObject(with: innerJsonData, options: []) as? [String: Any] {
                            messageType = innerJsonResponse["MessageType"] as? String ?? ""
                        }
                    }
                    if (event == "cardinal-commerce-session-id" && messageType == "profile.completed") {
                        self.csHiddenhtmlContent = ""
                        makeNetworkCall(payload: apiPayload, endPoint: "/public/v1/payment/cybersource/enroll/authentication?pi_client_secret=\(self.clientSecret)", keysConfiguration: keysConfiguration, success: { responseData in
                            let lastPaymentResponse = responseData["last_payment_response"] as? [String: Any]
                            let error = (lastPaymentResponse?["error"] as? Int) ?? responseData["error"] as? Int ?? 0
                            let message = (lastPaymentResponse?["message"] as? String) ?? responseData["message"] as? String ?? "Something Went Wrong"
                            let status = (lastPaymentResponse?["status"] as? String) ?? responseData["status"] as? String ?? "Unknown"
                            let htmlResponse = responseData["html_response"] as? [String: Any]
                            let htmlWebContent = htmlResponse?["next_action"] as? String ?? ""
                            if (!htmlWebContent.isEmpty) {
                                DispatchQueue.main.async {
                                    self.htmlContent = htmlWebContent
                                }
                            } else if (error == 0 && htmlWebContent.isEmpty) {
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
            } catch {
                print("ERROR WHILE PARSING DATA FROM SERVER EVENT: \(error)")
            }
        }
    }

    func handlePostMessage(eventResponse: String) {
        if let jsonData = eventResponse.data(using: .utf8) {
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                    let event = jsonResponse["event"] as? String ?? "none"
                    if (event == "3ds-done") {
                        self.htmlContent = ""
                        let data = jsonResponse["data"] as? [String: Any]
                        let lastPaymentResponse = data?["last_payment_response"] as? [String: Any]
                        let error = (lastPaymentResponse?["error"] as? Int) ?? jsonResponse["error"] as? Int ?? 0
                        let message = (lastPaymentResponse?["message"] as? String) ?? jsonResponse["message"] as? String ?? "Something Went Wrong"
                        let status = (lastPaymentResponse?["status"] as? String) ?? jsonResponse["status"] as? String ?? "Unknown"
                        if (error == 0) {
                            clear()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.triggerPaymentResponse?(["status": status, "error": error == 0 ? false : true, "message": message])
                        }

                    }
                }
            } catch {
                print("ERROR WHILE PARSING DATA FROM SERVER EVENT: \(error)")
            }
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(configuration.inputConfiguration.cardNumber.label)
                    .font(.system(size: configuration.inputLabelStyle.fontSize))
                    .foregroundColor(configuration.inputLabelStyle.textColor)
                HStack {
                    UITextFieldWrapper(
                        text: $cardNumber,
                        placeholder: configuration.inputConfiguration.cardNumber.placeholder,
                        keyboardType: .numberPad,
                        textColor: isCardFieldFocused ? configuration.onFocusInputStyle.textColor : isCardNumberError ? configuration.invalidStyle.textColor : configuration.inputStyle.textColor,
                        textSize:  isCardFieldFocused ? configuration.onFocusInputStyle.textSize : isCardNumberError ? configuration.invalidStyle.textSize : configuration.inputStyle.textSize,
                        onEditingChanged: { edit in
                            self.isCardFieldFocused = edit
                            if !edit && !isValidCardNumber(cardNumber) {
                                self.isCardNumberError = true
                                self.cardIcon = "error"
                            } else if isCardNumberError && edit {
                                self.isCardNumberError = false
                                self.cardIcon = getCardIcon(cardNumber)
                            }
                        },
                        maxLength: 16,
                        formatType: .creditCard
                    )
                    .onChange(of: cardNumber) { newValue in
                        if cardNumber.count <= 1 {
                            self.cardIcon = getCardIcon(cardNumber)
                        }
                        triggerIsReadyEvent()
                        handleBinDiscount()
                    }
                    .frame(height: configuration.inputStyle.height)
                    AsyncImage(url: URL(string: "https://js.xstak.com/images/\(cardIcon).png")) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: cardIcon == "visa_master_card" ? 70 : 30, height: 24)
                        } else {
                            ProgressView()
                                .frame(width: 24, height: 24)
                        }
                    }
                }
                .padding(.maximum(0, 7))
                .overlay(
                    RoundedRectangle(cornerRadius: configuration.inputStyle.borderRadius)
                        .stroke(isCardFieldFocused ? configuration.onFocusInputStyle.borderColor : isCardNumberError ? configuration.invalidStyle.borderColor : configuration.inputStyle.borderColor, lineWidth: isCardFieldFocused ? configuration.onFocusInputStyle.borderWidth : isCardNumberError ? configuration.invalidStyle.borderWidth : configuration.inputStyle.borderWidth)
                )
                if (isCardNumberError) {
                    Text("Card Number is invalid")
                        .font(.system(size: configuration.errorMessageStyle.textSize))
                        .foregroundColor(configuration.errorMessageStyle.textColor)
                }
            }
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(configuration.inputConfiguration.expiry.label)
                        .font(.system(size: configuration.inputLabelStyle.fontSize))
                        .foregroundColor(configuration.inputLabelStyle.textColor)
                    UITextFieldWrapper(
                        text: $expiryDate,
                        placeholder: configuration.inputConfiguration.expiry.placeholder,
                        keyboardType: .numberPad,
                        textColor: isExpiryFieldFocused ? configuration.onFocusInputStyle.textColor : isExpiryDateError ? configuration.invalidStyle.textColor : configuration.inputStyle.textColor,
                        textSize:isExpiryFieldFocused ? configuration.onFocusInputStyle.textSize : isExpiryDateError ? configuration.invalidStyle.textSize : configuration.inputStyle.textSize,
                        onEditingChanged: { edit in
                            self.isExpiryFieldFocused = edit
                            if !edit && !isValidExpiryDate(expiryDate) {
                                self.isExpiryDateError = true
                            } else if isExpiryDateError && edit {
                                self.isExpiryDateError = false
                            }
                        },
                        maxLength: 4,
                        formatType: .expiryDate
                    )
                    .onChange(of: expiryDate) { newValue in
                        triggerIsReadyEvent()
                    }
                    .frame(height: configuration.inputStyle.height)
                    .padding(.maximum(0, 7))
                    .overlay(
                        RoundedRectangle(cornerRadius: configuration.inputStyle.borderRadius)
                            .stroke(isExpiryFieldFocused ? configuration.onFocusInputStyle.borderColor : isExpiryDateError ? configuration.invalidStyle.borderColor : configuration.inputStyle.borderColor, lineWidth: isExpiryFieldFocused ? configuration.onFocusInputStyle.borderWidth : isExpiryDateError ? configuration.invalidStyle.borderWidth : configuration.inputStyle.borderWidth)
                    )
                    if (isExpiryDateError) {
                        Text("Expiry Date is invalid")
                            .font(.system(size: configuration.errorMessageStyle.textSize))
                            .foregroundColor(configuration.errorMessageStyle.textColor)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(configuration.inputConfiguration.cvc.label)
                        .font(.system(size: configuration.inputLabelStyle.fontSize))
                        .foregroundColor(configuration.inputLabelStyle.textColor)
                    HStack {
                        UITextFieldWrapper(
                            text: $cvv,
                            placeholder: configuration.inputConfiguration.cvc.placeholder,
                            keyboardType: .numberPad,
                            textColor: isCVCFieldFocused ? configuration.onFocusInputStyle.textColor : isCVCError ? configuration.invalidStyle.textColor : configuration.inputStyle.textColor,
                            textSize:isCVCFieldFocused ? configuration.onFocusInputStyle.textSize : isCVCError ? configuration.invalidStyle.textSize : configuration.inputStyle.textSize,
                            onEditingChanged: { edit in
                                self.isCVCFieldFocused = edit
                                if !edit && cvv.count > 0 && cvv.count < 3 {
                                    self.isCVCError = true
                                } else if isCVCError && edit {
                                    self.isCVCError = false
                                }
                            },
                            maxLength: 3
                        )
                        .onChange(of: cvv) { newValue in
                            triggerIsReadyEvent()
                        }
                        .frame(height: configuration.inputStyle.height)
                        AsyncImage(url: URL(string: "https://js.xstak.com/images/cvc.png")) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 30, height: 24)
                            } else {
                                ProgressView()
                                    .frame(width: 24, height: 24)
                            }
                        }
                    }
                    .padding(.maximum(0, 7))
                    .overlay(
                        RoundedRectangle(cornerRadius: configuration.inputStyle.borderRadius)
                            .stroke(isCVCFieldFocused ? configuration.onFocusInputStyle.borderColor : isCVCError ? configuration.invalidStyle.borderColor : configuration.inputStyle.borderColor, lineWidth: isCVCFieldFocused ? configuration.onFocusInputStyle.borderWidth : isCVCError ? configuration.invalidStyle.borderWidth : configuration.inputStyle.borderWidth)
                    )
                    if (isCVCError) {
                        Text("CVC is invalid")
                            .font(.system(size: configuration.errorMessageStyle.textSize))
                            .foregroundColor(configuration.errorMessageStyle.textColor)
                    }
                }
            }
        }.onAppear {
            controller.setElement(self)
        }.fullScreenCover(isPresented: Binding<Bool>(
            get: { !htmlContent.isEmpty },
            set: { _ in }
        )) {
            ZStack {
                WebView(htmlContent: htmlContent, messageHandler: handlePostMessage, isLoading: $isLoading)
                    .edgesIgnoringSafeArea(.all)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .edgesIgnoringSafeArea(.all)
                }
            }
        }.background(
            Group {
                if !csHiddenhtmlContent.isEmpty {
                    WebView(htmlContent: csHiddenhtmlContent, messageHandler: handleCSIframePostMessage, isLoading: $isLoading, shouldHide: true)
                        .frame(width: 0, height: 0)
                }
            }
        )

    }
}
#endif
