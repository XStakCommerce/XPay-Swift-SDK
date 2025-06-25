import Foundation
import CryptoKit
import Combine
import SwiftUI
#if os(iOS)
internal struct APIError: Error {
    let details: [String: Any]
}
#if swift(>=6.0)
extension APIError: @unchecked Sendable {}
#endif
private func generateHash(payload: [String: Any], hmacKey: String) -> String? {
    guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
        return nil
    }
    guard let jsonString = String(data: jsonData, encoding: .utf8) else {
        return nil
    }
    guard let secretKeyString = hmacKey.data(using: .utf8) else {
        return nil
    }
    let hmac = HMAC<SHA256>.authenticationCode(for: Data(jsonString.utf8), using: SymmetricKey(data: secretKeyString))
    let hmacHex = hmac.map { String(format: "%02x", $0) }.joined()
    return hmacHex
}

internal func makeNetworkCall(
    payload: [String: Any],
    endPoint: String,
    keysConfiguration: KeysConfiguration,
    success: @escaping ([String: Any]) -> Void,
    failure: ((Error) -> Void)? = nil
) {
    var baseURL: String = "https://xstak-pay-stg.xstak.com"
    guard let url = URL(string: baseURL + endPoint) else {
        failure?(URLError(.badURL))
        return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(keysConfiguration.publicKey, forHTTPHeaderField: "x-api-key")
    request.setValue(keysConfiguration.accountId, forHTTPHeaderField: "x-account-id")
    request.setValue(generateHash(payload: payload, hmacKey:keysConfiguration.hmacKey) ?? "", forHTTPHeaderField: "x-signature")
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

// ui services
internal enum FormatType {
    case none
    case creditCard
    case expiryDate
    case phoneNumber
}

internal struct UITextFieldWrapper: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var keyboardType: UIKeyboardType
    var textColor: Color
    var textSize: CGFloat
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
        textField.textColor = UIColor(textColor)
        textField.font = UIFont.systemFont(ofSize: textSize)
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.textColor = UIColor(textColor)
        uiView.font = UIFont.systemFont(ofSize: textSize)
    }

    func formatText(_ text: String) -> String {
        switch formatType {
        case .none:
            return text
        case .phoneNumber:
            return formatPhoneNumber(text)
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
    private func formatPhoneNumber(_ text: String) -> String {
        let digits = text.filter { $0.isWholeNumber }
        if digits.count <= 4 {
            return digits
        } else {
            let prefix = digits.prefix(4)
            let suffix = digits.dropFirst(4)
            return "\(prefix)-\(suffix)"
        }
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
#endif
