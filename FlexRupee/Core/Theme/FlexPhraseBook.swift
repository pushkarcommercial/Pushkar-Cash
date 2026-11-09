import Foundation

enum FlexPhraseBook {
    static let appName = "Pushkar Cash"
    enum Gate {
        static let welcome = FlexPhraseBook.appName
        static let secureSubtitle = "Finance with greater clarity"
        static let mobileTitle = "Mobile Number"
        static let otpTitle = "OTP"
        static let mobilePlaceholder = "Your mobile number"
        static let otpPlaceholder = "Enter OTP"
        static let getOTP = "Get OTP"
        static let otpResend = "Reacquire"
        static func otpCountdown(_ seconds: Int) -> String { "\(seconds)s" }
        static let signIn = "Sign in"
        static let legalPrefix = "I agree to the "
        static let privacyPolicy = "Privacy Policy"
        static let legalConnector = " and "
        static let serviceAgreement = "Service Agreement"
        static let mobileEmpty = "Please enter mobile number"
        static let mobileInvalid = "Please enter correct mobile number"
        static let otpEmpty = "Enter OTP"
        static let otpInvalid = "Please enter correct OTP"
        static let signInRejected = "Sign-in was not accepted. Check your mobile number and code, then retry."
        static let signInFailedTitle = "Sign-in failed"
        static let closedAccountTitle = "Account closed"
        static let closedAccountMessage = "This account has been closed and can no longer be used to sign in. Please contact customer support if you need help."
        static let otpSent = "A verification code is on its way"
        static let agreementRequired = "Accept the Privacy Policy and Service Agreement before signing in"
        static let policyUnavailable = "This document could not be opened. Please try again shortly."
    }

    enum Hub {
        static let homeTitle = "Home"
        static let checkInHint = "Regular check-ins may help keep your application review on track."
        static let checkInAction = "Check in now"
        static let readyBanner = "Your verification is up to date. Explore the available loan options."
        static let statusPending = "Your account status is being updated. Refresh to check again."
        static let kycBanner = "Complete your verification details so your application can be reviewed."
        static let applyNow = "Apply Now"
        static let apply = "APPLY"
        static let applyProduct = "Apply"
        static let payOverdue = "Pay Overdue"
        static let changeBankAccount = "Change Bank Account"
        static let getLoan = "Get loan"
        static let submitApplication = "Submit Application"
        static let maxLoanAmount = "Available borrowing limit"
        static let ratePerDay = "%/day"
        static let termDays = "days"
        static let underReview = "Under review"
        static let repay = "Repay"
        static let quotaRange = "Quota range"
        static let matchingTitle = "Finding suitable options…"
        static let matchingBody = "We are checking the available loan options. Please keep this page open while the search finishes."
        /// 4102007 failure page — LoanEase `LELocalCopy.Recommend.noMatch`.
        static let noRecommendCopy = "You do not currently meet the requirements for this product. Once a more suitable loan product becomes available, we will notify you through the app. Please stay tuned."
        static let noRecommendTitle = "Accurate Recommendation"
        static let viewNow = "View Now"
        static let selectOneProduct = "Choose at least one product to continue"
        static let selectLoanAmount = "Choose borrowing amount"
        static let selectAmountManually = "Choose the amount you wish to borrow (₹)"
        static let loanAmountRupee = "Borrowing amount (₹)"
        static let loanDetailsExpand = "View loan details ›"
        static let totalAmount = "Total amount"
        static let totalFee = "Total fee"
        static let withdrawPending = "An order is awaiting withdrawal. Open it to continue."
        static let withdrawBody = "Your withdrawal is waiting for confirmation. Review the order and confirm your bank details to proceed."
        static let withdrawAction = "Awaiting your withdrawal"
        static let withdrawGo = "Withdraw"
        static let applyPrompt = "Your application still needs a final submission. Open the order to finish it."
        static let emptyOffers = "There are no offers to show at the moment."
        static let loadFailed = "Home could not be refreshed. Pull down to reload."
        static let checkInDone = "Check-in successful"
        static let rejectVolumeBanner = "Explore other available recommendations"
        static let rejectVolumeTitle = "Accurate Recommendation"
    }

    enum Ledger {
        static let title = "Order history"
        static let empty = "No order"
        /// Detail + list — align with LoanEase field title.
        static let applyDate = "Date of application"
        static let paymentDate = "Payment date"
        static let repaymentDate = "Repayment date"
        static let dueDate = "Due date"
        static let repay = "Repay"
        static let deferAction = "Defer"
        static let withdraw = "Withdraw"
        static let confirm = "Confirm"
        static let continueSubmit = "Continue submitting"
        static let changeBank = "Change Bank Account"
        static let repayLinkMissing = "The payment page is not available right now."
        static let deferLinkMissing = "The extension page could not be opened."
        static let repayWebTitle = "Repayment"
        static let deferWebTitle = "Deferment"
        static let externalAppUnavailable = "Install the required app to open this link."
        static let withdrawSubmitted = "Your withdrawal request has been sent."
        static let deferSubmitted = "Your extension request has been sent."
        static let detailTitle = "Credit information"
        static let bannerReview = "Your file is under assessment; the final amount follows the credit check. Strong repayment history can improve the approved sum."
        static let bannerRepay = "Pay by the due date shown in the app. On-time repayment helps raise your future limit."
        static let bannerWithdraw = "You have a pending withdrawal order, and we need your confirmation. Once confirmed, we will transfer the funds to your bank account immediately."
        static let upiWarning = "This UPI link expires after 15 minutes. Use the Repay button to generate a fresh link before paying."
        static let noteContinueSubmit = "Finish uploading your materials to move this application forward faster."
        static let noteReview = "Your file is under assessment; the final amount follows the credit check. Strong repayment history can improve the approved sum."
        static let noteReject = "Your loan review was not approved this time."
        static func noteReject(nextApplyDate: String) -> String {
            "Your loan review was not approved this time. You may try again after \(nextApplyDate)."
        }
        static let noteDisbursing = "Approval is done. Funds should arrive in your account shortly—please watch for the credit."
        static let noteRepay = "Pay by the due date shown in the app. On-time repayment helps raise your future limit."
        static let noteRepayAlt = "Timely repayment strengthens your credit score and can unlock a larger borrowing amount."
        static let noteOverdue = "This installment is past due, and late charges grow each day. Please clear the balance as soon as you can."
        static let noteChangeBank = "Your bank details cannot receive the payout. Update them soon so disbursement is not delayed."
        static let noteCancel = "This order was cancelled. If you need further help, contact our customer service team."
        static let notePaidOff = "Your last order is cleared. You may now request a higher amount when you need more funding."
        static let notePaidOffHigher = "This order is settled, and a larger facility is ready. You can apply for it now."
        static let pickAmountTitle = "Choose borrowing amount"
        static let pickTermTitle = "Choose repayment term"
        static let withdrawSuccessBody = "Withdrawal is successful, the funds will be transferred to your bank account, please check."
    }

    enum Verify {
        static let hubTitle = "Verification"
        static let fieldEmptyFormat = "Please enter %@"
        static let selectRequiredFormat = "Please choose %@"
        static let fieldInvalidFormat = "Check %@ and provide a valid value."
        static let formRejected = "Check your answers and complete every required field before continuing."
        static let stagesUnavailable = "Verification steps are unavailable right now. Please reopen verification."
        static let emailInvalid = "Use a valid email address"
        static let contactPhoneInvalid = "Check the selected contact’s mobile number"
        static let whatsappInvalid = "Please enter a valid WhatsApp number."
        static let whatsappEmpty = "Please enter WhatsApp number."
        static let contactNameEmpty = "Add a name for this contact"
        static let contactNameInvalid = "Check the selected contact’s name"
        static let aadhaarUpload = "Add clear images of both sides of your Aadhaar"
        static let panUpload = "Add your PAN card image"
        static let ifscRequired = "Choose the bank state, city, bank and branch before continuing."
        static let ifscEmpty = "Please select or enter IFSC."
        static let ifscInvalid = "Please enter a valid IFSC."
        static let creditCardOptional = "Optional"
        static let returnConfirmTitle = "Leave this step?"
        static let returnConfirmBody = "Pause verification and return to the home screen?"
        static let continueAction = "Continue"
        static let applyAction = "Apply"
        static let startAction = "Start"
        static let pleaseChoose = "Please choose"
        static let pleaseEnter = "Please enter"
        static let ifscPlaceholder = "Type or select a code"
        static let findIFSCTitle = "Find IFSC"
        static let bankAccountHint = "Provide an active, unrestricted bank account that can receive the loan transfer."
        static let accountMismatch = "Enter the same account number in both fields."
        static let submitAction = "Submit"
        static let aadhaarInvalid = "Check the Aadhaar number and enter it again."
        static let panInvalid = "Check the PAN number and enter it again."
        static let imageUploadFailed = "The image could not be uploaded. Please retry."
        static let uploadErrorTitle = "Verification failed."
        static let uploadErrorBody = "Choose a clearer image and upload it again."
        static let uploadErrorTipSmall = "Move closer so the document is readable."
        static let uploadErrorTipCovered = "Keep every part of the document visible."
        static let uploadErrorTipClear = "Use a sharp, fully visible image."
        static let uploadAgain = "Upload again"
        static let bankState = "BANK State"
        static let bankCity = "BANK City"
        static let bankName = "BANK Name"
        static let bankBranch = "BANK Branch"
        static let selectBankState = "Choose the state where the bank is located."
        static let selectBankCity = "Choose the bank’s city to continue."
        static let selectBankName = "Choose a bank before selecting its branch."
        static let noIFSCOptions = "No bank details are available for this selection. Choose another option."
        static let selectBankBranch = "Choose the branch to finish the selection."
        static let uploadAadhaarTitle = "Add your Aadhaar images"
        static let aadhaarFront = "Front"
        static let aadhaarBack = "Back"
        static let aadhaarNumber = "Aadhaar Number"
        static let panNumber = "PAN Number"
        static let aadhaarTip1 = "Use your own current and valid Aadhaar card."
        static let aadhaarTip2 = "Include the whole card in a well-lit, readable photo so the details can be checked."
        static let faceInstruction = "Centre your face inside the outline and take a sharp selfie."
        static let faceInstructionHi = "चेहरा दिखाई गई सीमा के बीच रखें और साफ़ सेल्फी खींचें।"
        static let aadhaarFrontMissing = "Add an image of the Aadhaar front"
        static let aadhaarBackMissing = "Add an image of the Aadhaar back"
        static let contactRelationMissing = "Choose the relationship for %@ before continuing."
        static let contactMissing = "Add the details for emergency contact %@."
        static let contactDuplicate = "This phone number is already listed. Choose a different contact."
        static let captureSheetCamera = "Use the camera"
        static let captureSheetLibrary = "Choose from photos"
        static let uploadPanTitle = "Add your PAN card image"
        static let uploadPanSubtitleHi = "अपने पैन कार्ड के सामने की साफ़ तस्वीर जोड़ें।"
        static let panFront = "PAN front image"
        static let panFrontHi = "सामना"
        static let panRetakeTip = "If the details are incorrect, take a new photo of the PAN front and upload it."
        static let panRetakeTipHi = "जानकारी गलत होने पर पैन कार्ड के सामने की नई तस्वीर खींचकर अपलोड करें।"
        static let takePhoto = "Capture a photo"
        static let restart = "Restart"
    }

    enum Coffer {
        static let profileTitle = "Me"
        static let userNamePlaceholder = FlexPhraseBook.appName
        static let bankAccount = "Bank account"
        static let contactUs = "Contact Us"
        static let privacyPolicy = "Privacy policy"
        static let loanTerms = "Loan terms and conditions"
        static let repaymentInstructions = "Repayment Instructions"
        static let officialWebsite = "Official Website"
        static let about = "About"
        static let signOut = "Sign out"
        static let signOutTitle = "Sign Out"
        static let signOutBody = "Sign out of Pushkar Cash on this device?"
        static let signOutFailed = "Sign-out could not be completed. Please try again."
        static let signOutFailedTitle = "Sign-out failed"
        static let deleteTitle = "Delete Account"
        static let deleteBody = "Account closure is unavailable while an application is under review, a loan is being processed, or an order remains unsettled. Closing an eligible account is permanent and cannot be reversed. Check your orders before confirming."
        static let deleteSuccessTitle = "Success"
        static let deleteSuccessBody = "Your account has been closed."
        static let deleteFailedTitle = "Failed"
        static let deleteFailedBody = "Your account could not be closed. Review any outstanding orders before retrying."
        static let bankHint = "Tap the bank card to update its details. Changes are unavailable while a loan application is being reviewed."
        static let bankEmpty = "No bank"
        static let contactHint = "Keep any relevant receipts or screenshots and contact our support team for help."
        static let officialHint = "You can also access application and repayment services on our official website. Copy and save the address for later use."
        static let feedback = "Feedback"
        static let feedbackHint = "Tell us what happened below, or email our support team. Include a way to contact you if you would like a reply."
        static let feedbackQuestion = "Your question"
        static let feedbackUpload = "Upload Pictures"
        static let feedbackUploadAction = "Upload"
        static let feedbackPlaceholder = "Please enter"
        static let aboutBody = "Pushkar Cash provides flexible options for everyday financial challenges. We focus on making finance simpler and more approachable."
        static func versionLabel(_ build: String) -> String { "Version V \(build)" }
        static let copy = "Copy"
        static let copied = "Copied"
        static let feedbackEmpty = "Describe the issue before sending your feedback"
        static let feedbackSubmitted = "Your feedback has been received"
        static let feedbackUploadFailed = "Your attachment was not uploaded. Please retry."
        static let feedbackFailedTitle = "Feedback not sent"
        static let feedbackLimit = "Keep your feedback within 1,000 characters"
        static let repayHint1 = "Use the payment link generated in Pushkar Cash or on its official website. Other links may not correctly record a repayment against your order."
        static let repayHint2 = "If a payment request looks suspicious, email support before proceeding."
        static let repayHint3 = "If you are asked to split a payment or use an unfamiliar link, confirm it with support first. A service-fee waiver applies only after support verifies the reported situation."
    }

    enum Loan {
        static let title = "Loan confirmation"
        static let applyNow = "Apply Now"
        static let amountTip = "Choose an amount before selecting a term"
        static let loanAmountLabel = "Loan amount"
        static let creditBanner = "Your credit assessment helps determine the available amount and borrowing terms."
        static let selectTerm = "Choose repayment period"
        static let loanTerm = "Loan term"
        static let loanPeriod = "Loan period"
        static let selectEMIs = "Select EMIs"
        static let emis = "EMIs"
        static let emiDate = "First instalment date"
        static let emiAmount = "EMI Amount"
        static let amountReceived = "Amount received"
        static let serviceFee = "Service fee"
        static let interest = "Interest"
        static let gst = "GST"
        static let applyDate = "Date of application"
        static let dueDate = "Due date"
        static let termsPrefix = "I accept the "
        static let termsLink = "Loan terms and conditions"
        static let agreementRequired = "Accept the loan terms before sending this application"
        static let amountOutOfRange = "Choose an amount within this product’s available range"
        static let submitSuccess = "Your application has been sent"
        static let submitting = "Sending your application. Please keep this page open."
        static let productUnavailable = "Loan details are unavailable. Reopen this offer and try again."
        static let pendingOrderTitle = "Processing application"
        static let pendingOrderBody = "An application for this product is already being processed. Open its order details for updates, or return to explore other products."
        static let orderTipTitle = "Tip"
        static let orderTipBack = "Back"
        static let knowMore = "Know More"
        static let successHeadline = "Success!"
        static let successDesc = "Your application has entered review. If it is approved, the transfer will be arranged to your bank account."
        static let underReview = "Under review"
        static let loanDetailsTitle = "Loan details"
    }

    enum FieldHint {
        static let interest = "Interest is worked out using the selected amount, repayment term and the product’s interest rate."
        static let serviceFee = "The lender charges this fee for providing the loan service."
        static let amountReceivedProduct = "The amount paid to you is the loan amount less the service fee and GST."
        static let amountReceivedOrder = "The amount paid to you is the loan amount less the service fee and GST."

        static func message(for kind: FlexFieldHintKind, scene: FlexFieldHintScene) -> String {
            switch kind {
            case .interest: return interest
            case .serviceFee: return serviceFee
            case .amountReceived:
                switch scene {
                case .orderDetail: return amountReceivedOrder
                case .product, .success: return amountReceivedProduct
                }
            }
        }
    }

    enum Consent {
        static let locationTitle = "Location"
        static let locationSettings = "To continue with this application, enable location access for Pushkar Cash in Settings."
        static let contactsTitle = "Contacts"
        static let contactsBody = "Pushkar Cash uploads the contacts you authorize to its server for identity and fraud-risk checks. Full access is required by the current verification flow. You can review or change this permission in Settings."
        static let uploadFailed = "The required application data could not be sent. Please retry."
    }

    enum EMI {
        static let title = "EMI Calculator"
        static let loanAmountTitle = "Amount to calculate"
        static let durationTitle = "Duration"
        static let rateTitle = "Interest rate"
        static let amountRangeHint = "₹1–₹1,00,00,000"
        static let durationRangeHint = "1–25 years"
        static let rateRangeHint = "1%–22%"
        static let ratePlaceholder = "Please enter"
        static let submit = "Submit"
        static let amountRequired = "Use an amount from ₹1 to ₹1,00,00,000"
        static let durationRequired = "Use a whole-year duration from 1 to 25"
        static let rateRequired = "Use an annual interest rate between 1% and 22%"
        static let totalPayment = "Total payment"
        static let monthlyEMI = "Monthly EMI"
        static let totalInterest = "Total interest"
        static let summaryAmount = "Amount to calculate (₹)"
        static let summaryDuration = "Duration (Year)"
        static let summaryRate = "Annual interest (%)"
    }

    enum Network {
        static let busy = "We could not complete this request. Please try again shortly."
        static let businessRejected = "This action could not be completed. Check the details and try again."
        static let decodeFailed = "The response could not be read. Please retry."
        static let sessionExpired = "Your sign-in has expired. Log in again to continue."
        static let updateRequired = "Install the latest Pushkar Cash version to continue."

        static func message(for code: Int?) -> String {
            switch code {
            case 2000001, 2000002, 2002001: return sessionExpired
            case 2009006: return updateRequired
            case 6212011, 6212201: return Verify.uploadErrorBody
            case 6230002: return Loan.pendingOrderBody
            case 6230003: return Hub.withdrawPending
            case 6234303, 4102007: return Hub.noRecommendCopy
            default: return businessRejected
            }
        }

    }

    enum Release {
        static let upgradeTitle = "Upgrade"
        static let forceTitle = "Update Required"
        static let upgradeBody = "An updated Pushkar Cash version is ready. Install it to receive the latest improvements."
        static let upgradeAction = "Upgrade"
        static func versionFound(_ build: String) -> String { "Available version: \(build)" }
    }

    enum Rating {
        static let title = "Support us!"
        static let body = "Enjoying Pushkar Cash? Share your rating to help us understand your experience."
        static let submit = "Submit"
        static let selectStarsHint = "Choose a star rating before continuing."
        static let thanksTitle = "Thanks"
        static let thanksBody = "We appreciate your feedback. It helps us identify what to improve in Pushkar Cash."
    }

    enum Capture {
        static let cameraTitle = "Camera"
        static let cameraBody = "Enable camera access for Pushkar Cash in Settings to photograph your documents or take a verification selfie."
        static let unavailable = "This device has no available camera."
        static let captureFace = "Take Selfie"
        static let captureFront = "Capture Front"
        static let captureBack = "Capture Back"
        static let capturePan = "Photograph PAN card"
        static let missingPhoto = "Take the required photo before continuing."
    }

    enum Dialog {
        static let cancel = "Cancel"
        static let confirm = "Confirm"
        static let delete = "Delete"
    }
}
