import Lowtech
import Paddle
import SwiftDate

public class LowtechPro {
    // MARK: Lifecycle

    public init(
        paddleVendorID: String,
        paddleAPIKey: String,
        paddleProductID: String,
        productName: String,
        vendorName: String,
        price: NSNumber,
        currency: String,
        trialDays: NSNumber,
        trialType: PADProductTrialType,
        trialText: String,
        image: String? = nil,
        productDelegate: PADProductDelegate? = nil,
        paddleDelegate: PaddleDelegate? = nil
    ) {
        self.paddleVendorID = paddleVendorID
        self.paddleAPIKey = paddleAPIKey
        self.paddleProductID = paddleProductID
        self.productName = productName
        self.vendorName = vendorName
        self.price = price
        self.currency = currency
        self.trialDays = trialDays
        self.trialType = trialType
        self.trialText = trialText
        self.image = image
        self.productDelegate = productDelegate
        self.paddleDelegate = paddleDelegate

        product.delegate = productDelegate
        product.preventFreeUsageBeforeSubscriptionPurchase = true
        product.canForceExit = true
        product.willContinueAtTrialEnd = false

        if product.activated {
            enablePro()
        }
        checkProLicense()
    }

    // MARK: Internal

    let paddleVendorID: String
    let paddleAPIKey: String
    let paddleProductID: String
    let productName: String
    let vendorName: String
    let price: NSNumber
    let currency: String
    let trialDays: NSNumber
    let trialType: PADProductTrialType
    let trialText: String
    let image: String?

    weak var productDelegate: PADProductDelegate?
    weak var paddleDelegate: PaddleDelegate?

    lazy var productConfig: PADProductConfiguration = {
        let defaultProductConfig = PADProductConfiguration()
        defaultProductConfig.productName = productName
        defaultProductConfig.vendorName = vendorName
        defaultProductConfig.price = price
        defaultProductConfig.currency = currency
        defaultProductConfig.imagePath = image != nil ? Bundle.main.pathForImageResource(image!) : nil
        defaultProductConfig.trialLength = trialDays
        defaultProductConfig.trialType = trialType
        defaultProductConfig.trialText = trialText

        return defaultProductConfig
    }()

    lazy var paddle: Paddle! = Paddle.sharedInstance(
        withVendorID: paddleVendorID, apiKey: paddleAPIKey, productID: paddleProductID,
        configuration: productConfig, delegate: paddleDelegate
    )

    lazy var product: PADProduct! = PADProduct(
        productID: paddleProductID, productType: PADProductType.sdkProduct,
        configuration: productConfig
    )

    var retryUnverified = true
    var onTrial = false

    var productActivated = false

    func showCheckout() {
        paddle.showCheckout(
            for: product, options: nil,
            checkoutStatusCompletion: {
                state, _ in
                switch state {
                case .abandoned:
                    print("Checkout abandoned")
                case .failed:
                    print("Checkout failed")
                case .flagged:
                    print("Checkout flagged")
                case .purchased:
                    print("Checkout purchased")
                case .slowOrderProcessing:
                    print("Checkout slow processing")
                default:
                    print("Checkout unknown state: \(state)")
                }
            }
        )
    }

    func showLicenseActivation() {
        paddle.showLicenseActivationDialog(for: product, email: nil, licenseCode: nil, activationStatusCompletion: { activationStatus in
            switch activationStatus {
            case .activated:
                self.enablePro()
            default:
                return
            }
        })
    }

    func licenseExpired(_ product: PADProduct) -> Bool {
        product.licenseCode != nil && (product.licenseExpiryDate ?? Date.distantFuture).isInPast
    }

    func trialActive(product: PADProduct) -> Bool {
        let hasTrialDaysLeft = (product.trialDaysRemaining ?? NSNumber(value: 0)).intValue > 0

        return hasTrialDaysLeft && (product.licenseCode == nil || licenseExpired(product))
    }

    func checkProLicense() {
        product.refresh {
            (delta: [AnyHashable: Any]?, error: Error?) in
                asyncNow { [self] in
                    if let delta = delta, !delta.isEmpty {
                        print("Differences in \(product.productName ?? "product") after refresh")
                    }
                    if let error = error {
                        printerr("Error on refreshing \(product.productName ?? "product") from Paddle: \(error)")
                    }

                    if trialActive(product: product) || product.activated {
                        self.enablePro()
                    }

                    self.verifyLicense()
                }
        }
    }

    @inline(__always) func enoughTimeHasPassedSinceLastVerification(product: PADProduct) -> Bool {
        guard let verifyDate = product.lastVerifyDate else {
            return true
        }
        if productActivated {
            #if DEBUG
                return true
            #else
                return timeSince(verifyDate) > 1.days.timeInterval
            #endif
        } else {
            return timeSince(verifyDate) > 5.minutes.timeInterval
        }
    }

    func verifyLicense(force: Bool = false) {
        guard force || enoughTimeHasPassedSinceLastVerification(product: product) else { return }

        product.verifyActivation { [self] (state: PADVerificationState, error: Error?) in
            if let verificationError = error {
                printerr(
                    "Error on verifying activation of \(product.productName ?? "product") from Paddle: \(verificationError.localizedDescription)"
                )
            }

            onTrial = trialActive(product: product)

            switch state {
            case .noActivation:
                print("\(product.productName ?? "") noActivation")

                if onTrial {
                    self.enablePro()
                } else {
                    self.disablePro()
                }
                paddle.showProductAccessDialog(with: product)
            case .unableToVerify where error == nil:
                print("\(product.productName ?? "Product") unableToVerify (network problems)")
            case .unverified where error == nil:
                if retryUnverified {
                    retryUnverified = false
                    print("\(product.productName ?? "Product") unverified (revoked remotely), retrying for safe measure")
                    asyncAfter(ms: 3000) {
                        self.verifyLicense(force: true)
                    }
                    return
                }
                print("\(product.productName ?? "Product") unverified (revoked remotely)")

                disablePro()
                paddle.showProductAccessDialog(with: product)
            case .verified:
                print("\(product.productName ?? "Product") verified")
                self.enablePro()
            case PADVerificationState(rawValue: 2):
                printerr("\(product.productName ?? "Product") verification failed because of network connection: \(state)")
            default:
                print("\(product.productName ?? "Product") verification unknown state: \(state)")
            }
        }
    }

    func enablePro() {
        productActivated = true
        onTrial = trialActive(product: product)
    }

    func disablePro() {
        productActivated = false
        onTrial = trialActive(product: product)
    }
}
