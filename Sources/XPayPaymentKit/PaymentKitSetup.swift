import SwiftUI

// controller setup
@MainActor
protocol XPayFormProtocol {
    func confirmPayment(
        customerName: String,
        clientSecret: String,
        paymentResponse: @escaping ([String: Any]) -> Void
    )
    func clear()
}
@MainActor
public class XPayController: ObservableObject {
    @Published var xPayElement: XPayFormProtocol?

    public init() {}

    func setElement(_ element: XPayFormProtocol) {
        DispatchQueue.main.async {
            self.xPayElement = element
        }
    }

    public func confirmPayment(
        customerName: String,
        clientSecret: String,
        paymentResponse: @escaping (([String: Any]) -> Void)
    ) {
        DispatchQueue.main.async {
            self.xPayElement?.confirmPayment(
                customerName: customerName,
                clientSecret: clientSecret,
                paymentResponse: paymentResponse
            )
        }
    }

    public func clear() {
        DispatchQueue.main.async {
            self.xPayElement?.clear()
        }
    }
}

// keys setup
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

//styles
public struct CustomStyleConfiguration {
    public var inputConfiguration: InputConfiguration
    public var inputStyle: InputStyle
    public var inputLabelStyle: InputLabelStyle
    public var onFocusInputStyle: OnFocusInputStyle
    public var invalidStyle: InvalidStyle
    public var errorMessageStyle: ErrorMessageStyle

    public init(
        inputConfiguration: InputConfiguration = InputConfiguration(),
        inputStyle: InputStyle = InputStyle(),
        inputLabelStyle: InputLabelStyle = InputLabelStyle(),
        onFocusInputStyle: OnFocusInputStyle = OnFocusInputStyle(),
        invalidStyle: InvalidStyle = InvalidStyle(),
        errorMessageStyle: ErrorMessageStyle = ErrorMessageStyle()
    ) {
        self.inputConfiguration = inputConfiguration
        self.inputStyle = inputStyle
        self.inputLabelStyle = inputLabelStyle
        self.onFocusInputStyle = onFocusInputStyle
        self.invalidStyle = invalidStyle
        self.errorMessageStyle = errorMessageStyle
    }

    public static let defaultConfiguration = CustomStyleConfiguration()
}
#if swift(>=6.0)
extension CustomStyleConfiguration: @unchecked Sendable {}
#endif

public struct InputConfiguration {
    public var cardNumber: InputField
    public var expiry: InputField
    public var cvc: InputField
    public var phoneNumber: InputField
    public var cnic: InputField

    public init(
        cardNumber: InputField = InputField(
            label: "Card Number",
            placeholder: "Enter card number"
        ),
        expiry: InputField = InputField(
            label: "Expiry Date",
            placeholder: "MM/YY"
        ),
        cvc: InputField = InputField(label: "CVC", placeholder: "Enter cvc"),
        phoneNumber: InputField = InputField(
            label: "Phone Number",
            placeholder: "0301-2345678"
        ),
        cnic: InputField = InputField(
            label: "CNIC",
            placeholder: "Enter last 6 digits of CNIC"
        )
    ) {
        self.cardNumber = cardNumber
        self.expiry = expiry
        self.cvc = cvc
        self.phoneNumber = phoneNumber
        self.cnic = cnic
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

    public init(
        height: CGFloat = 25,
        textColor: Color = .black,
        textSize: CGFloat = 17,
        borderColor: Color = .gray,
        borderRadius: CGFloat = 5,
        borderWidth: CGFloat = 1
    ) {
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

    public init(
        textColor: Color = .black,
        textSize: CGFloat = 17,
        borderColor: Color = .blue,
        borderWidth: CGFloat = 1
    ) {
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

    public init(
        borderColor: Color = .red,
        borderWidth: CGFloat = 1,
        textColor: Color = .red,
        textSize: CGFloat = 14
    ) {
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
