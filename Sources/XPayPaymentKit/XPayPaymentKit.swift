
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
public struct CustomStyleConfiguration {
    public var inputConfiguration: InputConfiguration
    public var inputStyle: InputStyle
    public var inputLabelStyle: InputLabelStyle
    public var onFocusInputStyle: OnFocusInputStyle
    public var invalidStyle: InvalidStyle
    public var errorMessageStyle: ErrorMessageStyle

    public init(inputConfiguration: InputConfiguration = InputConfiguration(),
                inputStyle: InputStyle = InputStyle(),
                inputLabelStyle: InputLabelStyle = InputLabelStyle(),
                onFocusInputStyle: OnFocusInputStyle = OnFocusInputStyle(),
                invalidStyle: InvalidStyle = InvalidStyle(),
                errorMessageStyle: ErrorMessageStyle = ErrorMessageStyle()) {
        self.inputConfiguration = inputConfiguration
        self.inputStyle = inputStyle
        self.inputLabelStyle = inputLabelStyle
        self.onFocusInputStyle = onFocusInputStyle
        self.invalidStyle = invalidStyle
        self.errorMessageStyle = errorMessageStyle
    }

    public static let defaultConfiguration = CustomStyleConfiguration()
}

public struct InputConfiguration {
    public var cardNumber: InputField
    public var expiry: InputField
    public var cvc: InputField

    public init(cardNumber: InputField = InputField(label: "Card Number", placeholder: "Enter card number"),
                expiry: InputField = InputField(label: "Expiry Date", placeholder: "MM/YY"),
                cvc: InputField = InputField(label: "CVC", placeholder: "Enter cvc")) {
        self.cardNumber = cardNumber
        self.expiry = expiry
        self.cvc = cvc
    }
}

public struct InputField {
    public var label: String
    public var placeholder: String

    public init(label: String, placeholder: String) {
        self.label = label
        self.placeholder = placeholder
    }
}

public struct InputStyle {
    public var height: CGFloat
    public var textColor: Color
    public var textSize: CGFloat
    public var borderColor: Color
    public var borderRadius: CGFloat
    public var borderWidth: CGFloat

    public init(height: CGFloat = 25,
                textColor: Color = .black,
                textSize: CGFloat = 17,
                borderColor: Color = .gray,
                borderRadius: CGFloat = 5,
                borderWidth: CGFloat = 1) {
        self.height = height
        self.textColor = textColor
        self.textSize = textSize
        self.borderColor = borderColor
        self.borderRadius = borderRadius
        self.borderWidth = borderWidth
    }
}

public struct InputLabelStyle {
    public var fontSize: CGFloat
    public var textColor: Color

    public init(fontSize: CGFloat = 17, textColor: Color = .gray) {
        self.fontSize = fontSize
        self.textColor = textColor
    }
}

public struct OnFocusInputStyle {
    public var textColor: Color
    public var textSize: CGFloat
    public var borderColor: Color
    public var borderWidth: CGFloat

    public init(textColor: Color = .black, textSize: CGFloat = 17, borderColor: Color = .blue, borderWidth: CGFloat = 1) {
        self.textColor = textColor
        self.textSize = textSize
        self.borderColor = borderColor
        self.borderWidth = borderWidth
    }
}

public struct InvalidStyle {
    public var borderColor: Color
    public var borderWidth: CGFloat
    public var textColor: Color
    public var textSize: CGFloat

    public init(borderColor: Color = .red, borderWidth: CGFloat = 1, textColor: Color = .red, textSize: CGFloat = 14) {
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.textColor = textColor
        self.textSize = textSize
    }
}

public struct ErrorMessageStyle {
    public var textColor: Color
    public var textSize: CGFloat

    public init(textColor: Color = .red, textSize: CGFloat = 14) {
        self.textColor = textColor
        self.textSize = textSize
    }
}
public struct KeysConfiguration {
    public var accountId: String
    public var publicKey: String
    public var hmacKey: String

    public init(accountId: String, publicKey: String, hmacKey: String) {
        self.accountId = accountId
        self.publicKey = publicKey
        self.hmacKey = hmacKey
    }
}

private enum FormatType {
    case none
    case creditCard
    case expiryDate
}

private struct UITextFieldWrapper: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var keyboardType: UIKeyboardType
    var onEditingChanged: (Bool) -> Void
    var maxLength: Int
    var formatType: FormatType = .none

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: UITextFieldWrapper

        init(parent: UITextFieldWrapper) {
            self.parent = parent
        }

        @objc func textFieldDidChange(_ textField: UITextField) {
            guard let selectedTextRange = textField.selectedTextRange else { return }

            let currentText = textField.text ?? ""
            let cursorPosition = textField.offset(from: textField.beginningOfDocument, to: selectedTextRange.start)

            let formattedText = parent.formatText(currentText)
            textField.text = formattedText
            parent.text = formattedText

            let newCursorPosition = cursorPosition + (formattedText.count - currentText.count)
            if let newPosition = textField.position(from: textField.beginningOfDocument, offset: newCursorPosition) {
                DispatchQueue.main.async {
                    textField.selectedTextRange = textField.textRange(from: newPosition, to: newPosition)
                }
            }
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let currentText = (textField.text as NSString?)?.replacingCharacters(in: range, with: string) ?? string
            let digits = currentText.filter { $0.isWholeNumber }
            return digits.count <= parent.maxLength
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.onEditingChanged(true)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.onEditingChanged(false)
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.keyboardType = keyboardType
        textField.placeholder = placeholder
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func formatText(_ text: String) -> String {
        switch formatType {
        case .none:
            return text
        case .creditCard:
            return formatCreditCardNumber(text)
        case .expiryDate:
            return formatExpiryDate(text)
        }
    }

    private func formatCreditCardNumber(_ text: String) -> String {
        let digits = text.filter { $0.isWholeNumber }
        let limitedDigits = String(digits.prefix(maxLength))
        var formattedText = ""
        for (index, character) in limitedDigits.enumerated() {
            if index % 4 == 0 && index != 0 {
                formattedText.append(" ")
            }
            formattedText.append(character)
        }
        return formattedText
    }

    private func formatExpiryDate(_ text: String) -> String {
        let digits = text.filter { $0.isWholeNumber }
        let limitedDigits = String(digits.prefix(maxLength))
        var formattedText = ""
        for (index, character) in limitedDigits.enumerated() {
            if index == 2 {
                formattedText.append("/")
            }
            formattedText.append(character)
        }
        return formattedText
    }
}

public class XPayController: ObservableObject {
    @Published var xPayElement: XPayPaymentForm?

    public init() {}

    public func setElement(_ element: XPayPaymentForm) {
        DispatchQueue.main.async {
            self.xPayElement = element
        }
    }

    public func confirmPayment(customerName: String, clientSecret: String, paymentResponse: @escaping (([String: Any]) -> Void)) {
        xPayElement?.confirmPayment(customerName: customerName, clientSecret: clientSecret, paymentResponse: paymentResponse)
    }

    public func clear() {
        xPayElement?.clear()
    }
}

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

public struct XPayPaymentForm: View {
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
    @State private var baseURL: String = "https://xstak-pay.xstak.com"
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

    private func generateHash(payload: [String: Any]) -> String? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return nil
        }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        guard let secretKeyString = keysConfiguration.hmacKey.data(using: .utf8) else {
            return nil
        }
        let hmac = HMAC<SHA256>.authenticationCode(for: Data(jsonString.utf8), using: SymmetricKey(data: secretKeyString))
        let hmacHex = hmac.map { String(format: "%02x", $0) }.joined()
        return hmacHex
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
            makeNetworkCall(payload: apiPayload, endPoint: "/public/v1/payment/intent/confirm?pi_client_secret=\(self.clientSecret)", success: { responseData in
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
                makeNetworkCall(payload: ["account_id": keysConfiguration.accountId, "bin": bin], endPoint: "/public/v1/bin/config", success: { responseData in
                    self.onBinDiscount?(responseData)
                })
            }
        }
    }

    struct APIError: Error {
        let details: [String: Any]
    }

    private func makeNetworkCall(
        payload: [String: Any],
        endPoint: String,
        success: @escaping ([String: Any]) -> Void,
        failure: ((Error) -> Void)? = nil
    ) {
        guard let url = URL(string: baseURL + endPoint) else {
            failure?(URLError(.badURL))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(keysConfiguration.publicKey, forHTTPHeaderField: "x-api-key")
        request.setValue(keysConfiguration.accountId, forHTTPHeaderField: "x-account-id")
        request.setValue(generateHash(payload: payload) ?? "", forHTTPHeaderField: "x-signature")
        request.setValue("iOS-SDK", forHTTPHeaderField: "x-sdk-source")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            failure?(error)
            return
        }
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                failure?(error)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                failure?(URLError(.badServerResponse))
                return
            }
            if !(200...299).contains(httpResponse.statusCode) {
                if let data = data, let errorDetails = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    failure?(APIError(details: errorDetails))
                } else {
                    failure?(URLError(.badServerResponse))
                }
                return
            }

            guard let data = data,
                  let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                  let jsonResponse = jsonObject as? [String: Any],
                  let dataObject = jsonResponse["data"] as? [String: Any] else {
                failure?(URLError(.cannotParseResponse))
                return
            }
            success(dataObject)
        }

        task.resume()
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
                        makeNetworkCall(payload: apiPayload, endPoint: "/public/v1/payment/cybersource/enroll/authentication?pi_client_secret=\(self.clientSecret)", success: { responseData in
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
                print("POST SERVER EVENT DATA: \(eventResponse)")
                print("ERROR WHILE PARSING DATA FROM SERVER EVENT: \(error)")
            }
        } else {
            print("POST SERVER EVENT DATA: \(eventResponse)")
            print("ERROR WHILE CREATING DATA FROM SERVER EVENT JSON STRING")
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
                print("POST SERVER EVENT DATA: \(eventResponse)")
                print("ERROR WHILE PARSING DATA FROM SERVER EVENT: \(error)")
            }
        } else {
            print("POST SERVER EVENT DATA: \(eventResponse)")
            print("ERROR WHILE CREATING DATA FROM SERVER EVENT JSON STRING")
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
                    .keyboardType(.numberPad)
                    .frame(height: configuration.inputStyle.height)
                    .foregroundColor(isCardFieldFocused ? configuration.onFocusInputStyle.textColor : isCardNumberError ? configuration.invalidStyle.textColor : configuration.inputStyle.textColor)
                    .font(.system(size: isCardFieldFocused ? configuration.onFocusInputStyle.textSize : isCardNumberError ? configuration.invalidStyle.textSize : configuration.inputStyle.textSize))
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
                    .keyboardType(.numberPad)
                    .frame(height: configuration.inputStyle.height)
                    .foregroundColor(isExpiryFieldFocused ? configuration.onFocusInputStyle.textColor : isExpiryDateError ? configuration.invalidStyle.textColor : configuration.inputStyle.textColor)
                    .font(.system(size: isExpiryFieldFocused ? configuration.onFocusInputStyle.textSize : isExpiryDateError ? configuration.invalidStyle.textSize : configuration.inputStyle.textSize))
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
                        .keyboardType(.numberPad)
                        .frame(height: configuration.inputStyle.height)
                        .foregroundColor(isCVCFieldFocused ? configuration.onFocusInputStyle.textColor : isCVCError ? configuration.invalidStyle.textColor : configuration.inputStyle.textColor)
                        .font(.system(size: isCVCFieldFocused ? configuration.onFocusInputStyle.textSize : isCVCError ? configuration.invalidStyle.textSize : configuration.inputStyle.textSize))
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
