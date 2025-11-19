Do Your Work: A Full-Stack Technical Design Specification

I. Architectural Overview and System Setup

This document provides a comprehensive technical blueprint for the 'Do Your Work' application. The architecture is designed for security, scalability, and maintainability, establishing a clear separation of concerns between the client, the server, and external services.

The system comprises five core components:

    iOS App (SwiftUI): The primary user interface. It communicates exclusively with the Backend API. It will never store secret keys or have direct database access.

    Backend API (Node.js/Express): The central-services layer. All business logic, authentication, and external service communication are processed here. This is the only component authorized to communicate with the database, the Stripe API (via secret key), and the Apple Push Notification service (APNs).

    MySQL Database: The persistent data store. It acts as the system's "ledger," storing the state of users, wagers, and relationships.

    Stripe Connect: The external payment-processing service. It is managed by the Backend API and handles all user onboarding (Know Your Customer - KYC), payment authorizations (holds), captures, and transfers.

    APNs: The external push notification service. It is triggered by the Backend API to send real-time alerts to the iOS app.

1.1 Phase 1: Project Setup (iOS - Xcode)

The foundation of the iOS application begins with the Xcode project configuration

    Create Project: Launch Xcode and create a new project.

        Template: Select iOS > App.   

    Product Name: DoYourWork.

    Interface: Select SwiftUI.

    Language: Select Swift.

Configure Capabilities: This is a critical step that provisions the application for essential OS-level services. Navigate to the project target, select the "Signing & Capabilities" tab, and add the following:

    Push Notifications: This capability is mandatory for APNs. It generates the necessary entitlements in the app's provisioning profile, which links the app's Bundle ID to the Apple Developer account. This linkage is a prerequisite for generating APNs authentication keys later.   

        Sign in with Apple: This is a highly recommended (and often required) authentication method for App Store apps that offer third-party social logins.

    Configure Info.plist: Add human-readable descriptions for hardware access. This is essential for user trust and App Store approval.

        NSCameraUsageDescription: "To upload a photo as proof of task completion."

        NSPhotoLibraryUsageDescription: "To select a photo as proof of task completion."

1.2 Phase 2: Project Setup (Backend - Node.js/Express)

The backend API server is initialized as a standard Node.js project.

    Initialize Project:
    Bash

mkdir doyourwork-api
cd doyourwork-api
npm init -y

This creates the package.json file that manages project dependencies.  

Install Dependencies: Install the core libraries required for the application's functionality.
Bash

# Core server and environment
npm install express dotenv

# Functional dependencies
npm install mysql2 jsonwebtoken bcryptjs stripe node-apn

# Development dependencies
npm install --save-dev nodemon

The selection of these packages is deliberate:

    mysql2: Chosen over the older mysql package, mysql2 provides a robust, Promise-based interface. This is an architectural decision to enable the use of modern async/await syntax across the entire API, which is essential for managing the complex, multi-step asynchronous logic of the Stripe payment flows.   

bcryptjs: The industry standard for hashing and comparing passwords securely.  

jsonwebtoken: For creating and verifying the JSON Web Tokens (JWTs) that will manage user sessions.  

stripe: The official Stripe Node.js library for all payment and Connect-related API calls.

node-apn: A well-maintained and robust library for communicating with APNs from a Node.js server.  

    Establish Project Structure: A logical directory structure is key to a maintainable API.

        /config: Contains connection configurations (database, Stripe, APNs).

        /routes: Defines the API endpoints (e.g., users.js, wagers.js).

        /controllers: Contains the business logic for each route.

        /middleware: Holds shared middleware, such as the auth.js JWT verifier.

        server.js: The main Express application file that initializes the server.

1.3 Phase 3: Environment and Database Configuration

All sensitive keys and environment-specific settings will be stored in a .env file and loaded via dotenv. This file must never be committed to source control.  

Table 1: .env Configuration Variables
Variable	Purpose	Example
PORT	API server port.	3000
DB_HOST	MySQL database host.	localhost
DB_USER	MySQL database user.	doyourwork_user
DB_PASS	MySQL database password.	secure_password
DB_NAME	MySQL database name.	doyourwork_db
JWT_SECRET	Secret key for signing all JWTs.	a-very-long-random-cryptographic-string
STRIPE_SECRET_KEY	Stripe API Secret Key (sk_test_...).	sk_test_...
STRIPE_PUBLISHABLE_KEY	Stripe API Publishable Key (pk_test_...).	pk_test_...
APNS_KEY	Base64-encoded content of the.p8 auth key.	(file-content)
APNS_KEY_ID	Apple Developer Key ID.	A1B2C3D4E5
APNS_TEAM_ID	Apple Developer Team ID.	F1G2H3I4J5
APNS_BUNDLE_ID	iOS App Bundle ID (com.company.app).	com.yourcompany.doyourwork

Before the API can run, the MySQL database and a dedicated user must be created.

MySQL Initial Setup SQL:
SQL

/* Create the database with modern character set support */
CREATE DATABASE doyourwork_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

/* Create a dedicated user for the API */
CREATE USER 'doyourwork_user'@'localhost'
  IDENTIFIED BY 'secure_password';

/* Grant this user full permissions *only* on the new database */
GRANT ALL PRIVILEGES ON doyourwork_db.*
  TO 'doyourwork_user'@'localhost';

FLUSH PRIVILEGES;

II. Database Schema (MySQL)

The following SQL statements define the database tables. The design is normalized and uses foreign keys to maintain relational integrity.

2.1 Table: Users

This table stores user authentication credentials, their identity within Stripe, and their device token for push notifications.
SQL

CREATE TABLE Users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(60) NOT NULL,
    
    /* 
      For Pledger actions:
      Stores the Stripe Customer ID to charge their saved payment methods.
    */
    stripe_customer_id VARCHAR(255) NOT NULL,
    
    /* 
      For Referee actions:
      Stores the Stripe Express Account ID for receiving payouts.[11]
      This is NULL until the user completes the Connect onboarding.
    */
    stripe_connect_id VARCHAR(255) NULL,
    
    /* 
      The unique token for sending APNs to this user's device.
      Updated on every app launch.
    */
    device_token TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

2.2 Table: Friends

This table manages the many-to-many relationship between users. The design must support a "pending" request state, making a simple symmetric table insufficient. This design clearly defines the relationship originator (requester_id) and target (addressee_id).  

SQL

CREATE TABLE Friends (
    id INT AUTO_INCREMENT PRIMARY KEY,
    requester_id INT NOT NULL,
    addressee_id INT NOT NULL,
    
    /* Tracks the state of the friendship request */
    status ENUM('pending', 'accepted', 'blocked') NOT NULL DEFAULT 'pending',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    /* Ensures a relationship cannot be duplicated */
    UNIQUE KEY unique_friendship (requester_id, addressee_id),
    
    FOREIGN KEY (requester_id) REFERENCES Users(id) ON DELETE CASCADE,
    FOREIGN KEY (addressee_id) REFERENCES Users(id) ON DELETE CASCADE
);

2.3 Table: Wagers

This table is the single source of truth for the application's core logic. It is not a passive data store but a state machine. The status column is the most critical field, as it dictates all payment logic. Every core API function will be a transaction that attempts to move this status from one state to the next.
SQL

CREATE TABLE Wagers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    pledger_id INT NOT NULL,
    referee_id INT NOT NULL,
    
    task_description TEXT NOT NULL,
    wager_amount DECIMAL(10, 2) NOT NULL,
    deadline TIMESTAMP NOT NULL,
    
    /* 
      The State Machine:
      This enum defines the entire business logic flow.
    */
    status ENUM(
        'active',           /* Wager set, Stripe hold placed. Awaiting deadline. */
        'verifying',        /* Deadline passed, awaiting Referee's judgment. */
        'completed_success',/* Referee marked success. Stripe hold released. */
        'completed_failure',/* Referee marked failure. Stripe hold captured. */
        'payout_complete'   /* Transfer to Referee complete. Final state. */
    ) NOT NULL DEFAULT 'active',
    
    /* 
      Stores the ID of the Stripe PaymentIntent.[14]
      This ID represents the 'hold' on the Pledger's card.
    */
    stripe_payment_intent_id VARCHAR(255) NOT NULL UNIQUE,
    
    /* 
      Stores the ID of the Stripe Transfer.
      This ID represents the 'payout' to the Referee.
    */
    stripe_transfer_id VARCHAR(255) NULL,
    
    proof_image_url VARCHAR(1024) NULL,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (pledger_id) REFERENCES Users(id) ON DELETE CASCADE,
    FOREIGN KEY (referee_id) REFERENCES Users(id) ON DELETE CASCADE
);

III. Backend API (Node.js/Express)

This section details all API endpoints. All endpoints, except for register and login, will be protected by JWT authentication middleware.

3.1 Middleware (/middleware/auth.js)

This middleware is essential for securing the API. It inspects the Authorization header for a JWT, verifies its signature, and attaches the decoded user payload to the request object.  

This step is the foundation of all authorization (AuthZ), not just authentication (AuthN). By providing req.user, subsequent controllers can check if the authenticated user is authorized to perform the requested action (e.g., if (req.user.id!== wager.referee_id) { return 403; }).
JavaScript

// /middleware/auth.js (Simplified)
const jwt = require('jsonwebtoken');

module.exports = function(req, res, next) {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ');
    
    if (!token) {
        return res.status(401).send('Access denied. No token provided.');
    }
    
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = decoded; // Attaches { id, username } to the request
        next();
    } catch (ex) {
        res.status(400).send('Invalid token.');
    }
}

3.2 User Auth Endpoints (/api/users)

    POST /register

        Logic: Hashes the provided password using bcrypt.hash. Calls stripe.customers.create({ email }) to create a Stripe Customer ID. INSERTs the new user into the Users table with the password_hash and stripe_customer_id.   

POST /login

    Logic: Finds the user by email. Compares the provided password with the stored password_hash using bcrypt.compare. If successful, issues a new JWT signed with process.env.JWT_SECRET, containing the user's id and username.   

POST /device-token (Authenticated)

    Logic: Receives the APNs device token from the iOS app. UPDATE Users SET device_token =? WHERE id =?. This endpoint must be idempotent, as the iOS app will call it on every launch to ensure the token is current.   

3.3 Friends Endpoints (/api/friends)

    POST /add (Authenticated)

        Body: {"email": "friend@example.com"}

        Logic: Finds the user ID associated with the email. INSERTs a new row into the Friends table with requester_id (from req.user.id), addressee_id, and status = 'pending'.

    GET / (Authenticated)

        Logic: SELECT * FROM Friends WHERE (requester_id =? OR addressee_id =?) AND status = 'accepted'.

    GET /pending (Authenticated)

        Logic: SELECT * FROM Friends WHERE addressee_id =? AND status = 'pending'.

    POST /respond (Authenticated)

        Body: {"requester_id": 123, "response": "accepted" | "rejected"}

        Logic: If response == "accepted", UPDATE Friends SET status = 'accepted' WHERE requester_id =? AND addressee_id =?. If response == "rejected", DELETE the row.

3.4 Wagers Endpoints (/api/wagers)

    POST /create (Authenticated)

        Body: {"task_description": "...", "wager_amount": 50, "deadline": "...", "referee_id": 456}

        Logic: This is a high-risk, multi-step transactional endpoint. It involves a local database write and an external API call to Stripe. The entire operation must be wrapped in a MySQL transaction (BEGIN, COMMIT, ROLLBACK) to prevent orphaned data (e.g., a Stripe charge with no corresponding wager).

        Stripe Flow:

            Call stripe.paymentIntents.create with:

                amount: wager_amount * 100 (Stripe requires cents).

                currency: 'usd'.

                customer: The Pledger's stripe_customer_id.

                capture_method: 'manual'. This is the core logic: it only authorizes (holds) the funds, it does not capture them.   

        Database Flow:

            INSERT the new wager into the Wagers table, including the stripe_payment_intent_id returned from Stripe.

        Response: Returns the client_secret of the new PaymentIntent to the iOS app. The app will use this secret to confirm the payment hold on the client side.

        Notification: Triggers an APNs push notification to the referee_id ("You have a new wager to judge").

    GET /active (Authenticated)

        Logic: SELECT * FROM Wagers WHERE pledger_id =? AND status = 'active'.

    GET /pending (Authenticated)

        Logic: SELECT * FROM Wagers WHERE referee_id =? AND status = 'verifying'. (A background job or API logic will transition wagers from active to verifying once deadline has passed).

3.5 Verification Endpoint (/api/wagers/:id/verify)

    POST / (Authenticated)

        Body: {"outcome": "success" | "failure"}

        Authorization: This is the most critical authorization check in the app.

            The auth middleware provides the req.user.id.

            SELECT * FROM Wagers WHERE id =?.

            if (wager.referee_id!== req.user.id) return res.status(403).send('Forbidden: You are not the Referee for this wager.');

        Success Logic (outcome == "success"):

            Call stripe.paymentIntents.cancel(wager.stripe_payment_intent_id). This action releases the hold on the Pledger's card. No money is moved.   

    UPDATE Wagers SET status = 'completed_success' WHERE id =?.

    Send APNs to Pledger: "Success! Your task was verified."

Failure Logic (outcome == "failure"):

    This is the complete money-moving flow. See Section V for the full implementation.

    UPDATE Wagers SET status = 'completed_failure' WHERE id =?.

    Call stripe.paymentIntents.capture(wager.stripe_payment_intent_id). This captures the held funds.   

Call stripe.transfers.create({ amount, destination: (Referee's stripe_connect_id),... }).  

            UPDATE Wagers SET status = 'payout_complete', stripe_transfer_id =? WHERE id =?.

            Send APNs to Pledger: "Failure. Your wager has been transferred."

IV. iOS App (SwiftUI & MVVM)

The iOS application will be architected using the Model-View-ViewModel (MVVM) pattern. This separates concerns:  

    Model: Simple Codable structs that mirror the API's JSON responses.   

View: SwiftUI views responsible only for layout and user interaction.

ViewModel: @ObservableObject classes that contain all business logic, state, and networking calls for a given view.  

4.1 Core Services

These singleton or environment objects will be accessible throughout the app.

    NetworkService.swift: A wrapper around URLSession managing all async/await API calls. It will be responsible for attaching the JWT to the Authorization header of protected requests.   

    AuthService.swift: Manages the user's authentication state. It handles saving and deleting the JWT from the device Keychain and publishes an isAuthenticated boolean.

    StripeService.swift: A wrapper for the Stripe SDK, primarily used to confirmPayment on the client side using the client_secret provided by the API.

4.2 View and ViewModel Directory

This file structure defines the application's UI and navigation flow.

Table 2: SwiftUI View & ViewModel File Structure
File Path	Purpose & Key Logic
DoYourWorkApp.swift	

@main app entry point. Uses @StateObject for AuthService. Displays LoginView or HomeView based on authService.isAuthenticated. Attaches the AppDelegate.
/Auth/LoginView.swift	UI for user login. Binds to AuthViewModel.
/Auth/RegistrationView.swift	UI for user registration. Binds to AuthViewModel.
/Auth/AuthViewModel.swift	@ObservableObject with login() and register() functions. Calls NetworkService and saves the token via AuthService.
/Main/HomeView.swift	

The main TabView component, providing the app's root navigation. Contains three tabs: My Wagers, To Verify, and Create.
/MyWagers/MyWagersView.swift	

Tab 1 Root. Contains a NavigationStack for pushing detail views. Displays a list of wagers from MyWagersViewModel.
/MyWagers/MyWagersViewModel.swift	Fetches data from /api/wagers/active. Manages timers to update wager countdowns.
/MyWagers/WagerDetailView.swift	Pushed onto the NavigationStack. Shows wager details. Displays conditional UI: If Pledger, shows "Upload Proof." If Referee, shows "Verify" (disabled until deadline).
/ToVerify/ToVerifyView.swift	Tab 2 Root. NavigationStack. Displays a list of wagers from ToVerifyViewModel.
/ToVerify/ToVerifyViewModel.swift	Fetches data from /api/wagers/pending.
/ToVerify/VerifyDetailView.swift	Pushed onto the NavigationStack. Shows wager details. Critically, displays "Mark Success" and "Mark Failure" buttons. Tapping these calls viewModel.verify(wagerId, outcome).
/Create/CreateWagerView.swift	Tab 3 Root. A form to create a new wager (task, amount, deadline, select friend). Binds to CreateWagerViewModel.
/Create/CreateWagerViewModel.swift	POSTs the form data to /api/wagers/create. On success, receives the client_secret and immediately calls StripeService.confirmPayment(...) to place the hold.
/Friends/FriendsListView.swift	A view (likely presented from SettingsView) to see, add, and respond to friend requests.
/Friends/FriendsListViewModel.swift	Manages all state and API calls for /api/friends.
/Settings/SettingsView.swift	A view (e.g., a modal) for "Logout" and "Manage Payments." The "Manage Payments" button triggers the Stripe Connect onboarding flow.
 

V. CRITICAL: Stripe Connect Integration

This is the most complex and high-risk component of the application. The logic must be precise to handle funds securely. The chosen model is "Separate Charges and Transfers," which allows the platform to sit between the Pledger and Referee.  

5.1 Phase 1: Onboarding (Pledger AND Referee)

To comply with global KYC and tax regulations, any user who can receive money (a Referee) must have a Stripe Connect account. The simplest solution is to onboard all users with a Stripe Express account, as it provides a Stripe-hosted UI and handles the verification process.  

Onboarding Flow:

    User taps "Manage Payments" in the SettingsView.

    The app calls an authenticated endpoint: POST /api/stripe/onboard.

    Backend: a. Checks if the user already has a stripe_connect_id. b. If not, it calls stripe.accounts.create({ type: 'express', email: user.email }) and saves the new stripe_connect_id to the Users table. c. It then calls stripe.accountLinks.create({ account: user.stripe_connect_id, refresh_url: '...', return_url: '...', type: 'account_onboarding' }).   

Backend: Responds to the app with the url from the account link object.

iOS App: Opens this url in a SFSafariViewController (a secure, in-app browser).

User: Completes the Stripe-hosted Express onboarding form.  

    Stripe: Redirects the user to the return_url. The app detects this, dismisses the SFSafariViewController, and the user is now fully onboarded and capable of receiving payouts.

5.2 Phase 2: The Wager Payment Lifecycle

This is the "playbook" for the application's core money-moving logic.

Table 3: Stripe API Logic Flow
Scenario	Trigger	App Action	Backend Endpoint	Stripe API Calls (in order)
1. Create Hold	Pledger submits CreateWagerView.	viewModel.createWager(...)	POST /api/wagers/create	

1. stripe.paymentIntents.create({ amount: (amt\*100), currency: 'usd', customer: (Pledger's cust_id), capture_method: 'manual' })
2. Confirm Hold	createWager returns client_secret.	stripeService.confirmPayment(client_secret)	(Client-side)	(Stripe iOS SDK handles confirmation. Pledger's bank shows a "Pending Charge".)
3. Success	Referee taps "Success" in VerifyDetailView.	viewModel.verify(id, "success")	POST /api/wagers/:id/verify	

1. stripe.paymentIntents.cancel(wager.stripe_payment_intent_id) Result: The hold is released. No money moves.
4. Failure	Referee taps "Failure" in VerifyDetailView.	viewModel.verify(id, "failure")	POST /api/wagers/:id/verify	

1. stripe.paymentIntents.capture(wager.stripe_payment_intent_id) 2. stripe.transfers.create({ amount, currency: 'usd', destination: (Referee's connect_id), source_transaction: (charge_id from step 1) }) Result: Hold is captured. Funds are transferred to the Referee.
 

5.3 Risk Mitigation: The "Stuck Money" Problem

A critical failure point exists in Scenario 4 (Failure). The logic involves two separate API calls: capture and transfer. If the capture() call succeeds but the transfer() call fails (e.g., Referee's Connect account is suspended, network blip, API key issue), the Pledger's money is now captured and stuck in the platform's Stripe account.

This represents the single greatest financial risk in the system. The architecture must be designed to handle this failure state.

Solution:

    Stateful Logic: The Wagers table status enum is the solution.

        The verify endpoint, upon capture() success, must first UPDATE Wagers SET status = 'completed_failure'. The money is now secured by the platform.

        Then, it attempts the transfer().

        If the transfer() succeeds, it performs a final UPDATE Wagers SET status = 'payout_complete', stripe_transfer_id =?.

    Idempotent Retry Job: If the transfer() fails, the wager remains in the completed_failure state. A separate, scheduled background job (e.g., a daily cron) must run on the server.

        This job will SELECT * FROM Wagers WHERE status = 'completed_failure'.

        It will loop through the results and re-attempt the stripe.transfers.create(...) for each one.

        This ensures that no funds are permanently stuck and that all failed transfers are eventually retried, guaranteeing the Referee is paid.

VI. Push Notifications (APNs) Implementation

This system provides the real-time alerts that make the app responsive and engaging.

6.1 Phase 1: Configuration

    Apple Developer Portal: Navigate to "Keys" and generate a new key with "Apple Push Notification service (APNs)" enabled. Download the .p8 authentication key. Note the Key ID and your Team ID.

    Backend (/config/apn.js): Configure the node-apn provider using the credentials from the .env file.   

JavaScript

    // /config/apn.js
    const apn = require('node-apn');

    const options = {
      token: {
        key: Buffer.from(process.env.APNS_KEY, 'base64'), // Load key from.env
        keyId: process.env.APNS_KEY_ID,
        teamId: process.env.APNS_TEAM_ID
      },
      production: false // Set to true for App Store deployment
    };

    const apnProvider = new apn.Provider(options);
    module.exports = apnProvider;

6.2 Phase 2: App Registration (SwiftUI)

Even in a SwiftUI-first application, registering for remote notifications requires using the UIApplicationDelegate lifecycle.  

    DoYourWorkApp.swift: Connect the AppDelegate using the @UIApplicationDelegateAdaptor property wrapper.   

Swift

import SwiftUI

@main
struct DoYourWorkApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup {
      ContentView() // This view will show Login or Home
    }
  }
}

AppDelegate.swift: This file will handle the APNs registration process.  

Swift

    import UIKit
    import UserNotifications

    class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

      func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        UNUserNotificationCenter.current().delegate = self

        // Request notification permission from the user
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.badge,.sound]) { granted, error in
          if granted {
            DispatchQueue.main.async {
              // Register with APNs *after* permission is granted
              application.registerForRemoteNotifications()
            }
          }
        }
        return true
      }

      // ** This function captures the device token **
      func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("APNs Device Token: \(tokenString)")

        // ** ACTION: Send this token to the backend **
        // Task {
        //   await NetworkService.shared.postDeviceToken(tokenString)
        // }
      }

      func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for APNs: \(error.localizedDescription)")
      }

      // Handle notifications that arrive while the app is in the foreground
      func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner,.sound,.badge]
      }
    }

6.3 Phase 3: Sending Notifications (Node.js)

Notifications should be "actionable," meaning they carry a data payload that the app can use to navigate the user to the correct screen.  

Example: Sending a "New Wager" Notification (This code is executed within the POST /api/wagers/create controller)
JavaScript

// 1. Find the Referee's device token
// const referee = await db.query('SELECT device_token FROM Users WHERE id =?', [referee_id]);
// const deviceToken = referee.device_token;
// 2. Get the apnProvider
// const apnProvider = require('../config/apn');
// const apn = require('node-apn');

const note = new apn.Notification();
note.expiry = Math.floor(Date.now() / 1000) + 3600; // 1 hour
note.badge = 1;
note.sound = "default";
note.alert = "You have a new wager to judge!";
note.topic = process.env.APNS_BUNDLE_ID;

// ** Actionable Payload **
// The app will receive this JSON and can use it to deep-link.
note.payload = {
  'action': 'VIEW_WAGER',
  'wager_id': newWager.id 
};

// Send the notification
apnProvider.send(note, deviceToken).then( (result) => {
  console.log('APNs send result:', result.sent, result.failed);
});

VII. Optional Web Component (React)

This fallback provides a web interface for Referees who do not have the iOS app. This flow cannot use the app's standard JWTs and must be secured using ephemeral, one-time-use tokens.

7.1 The "Magic Link" Verification Flow

    Email Trigger: When a Pledger creates a wager and selects a Referee (e.g., by email) who is not on the platform, the API triggers this flow instead of sending an APNs notification.

    Backend Token Generation: a. Generate a secure, 64-byte token: const token = crypto.randomBytes(64).toString('hex'). b. Hash the token: const hash = await bcrypt.hash(token, 10). c. Store the hash in a new column, Wagers.web_verification_token. d. Send an email to the Referee containing the raw token in a URL: https://doyourwork.com/verify?token=abc123rawtoken....   

React App (/verify) Page Load: a. The React app loads and extracts the token from the URL query parameters. b. It immediately sends this raw token to a new endpoint: POST /api/wagers/validate-web-token (Body: {"token": "abc123rawtoken..."}). c. Backend: Finds the wager by hashing the incoming token and comparing it to the stored web_verification_token. d. If it matches, the backend generates a new, special, short-lived JWT (e.g., 1-hour expiry) that is scoped only to this single wager (e.g., Payload: { "wager_id": 123, "role": "web_referee" }). e. The React app receives and stores this wager_jwt.

React Form Submission: a. The React app displays a simple "Success" / "Failure" verification form. b. When the Referee clicks a button, the app uses axios.post to call the exact same verification endpoint as the native app: POST /api/wagers/123/verify. c. It attaches the wager_jwt as the Authorization: Bearer token.  

    Modified Backend Auth: The auth.js middleware will be updated to accept either a standard user_id JWT (from the app) or a wager_id JWT (from the web). The verification controller logic then proceeds identically, triggering the Stripe capture/transfer or cancel flow.

VIII. Conclusion

This technical specification outlines a robust, secure, and scalable architecture for the 'Do Your Work' application. The plan's foundation rests on a clear separation of concerns, with a central Node.js API managing all business logic and state.

The most critical component, the payment system, is designed for resilience. By leveraging Stripe Connect for onboarding, manual capture for wagers, and a stateful, idempotent design for fund transfers, the system ensures financial integrity and mitigates risks such as "stuck" funds. The integration of APNs with actionable payloads and an optional "magic link" web component provides a comprehensive, real-time user experience. This blueprint provides a complete, step-by-step path from project initialization to a deployed, production-ready application.