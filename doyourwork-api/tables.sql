CREATE TABLE Users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(60) NOT NULL,
    stripe_customer_id VARCHAR(255) NOT NULL,
    stripe_connect_id VARCHAR(255) NULL,
    device_token TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Friends (
    id INT AUTO_INCREMENT PRIMARY KEY,
    requester_id INT NOT NULL,
    addressee_id INT NOT NULL,
    status ENUM('pending', 'accepted', 'blocked') NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_friendship (requester_id, addressee_id),
    FOREIGN KEY (requester_id) REFERENCES Users(id) ON DELETE CASCADE,
    FOREIGN KEY (addressee_id) REFERENCES Users(id) ON DELETE CASCADE
);

CREATE TABLE Wagers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    pledger_id INT NOT NULL,
    referee_id INT NOT NULL,
    task_description TEXT NOT NULL,
    wager_amount DECIMAL(10, 2) NOT NULL,
    deadline TIMESTAMP NOT NULL,
    status ENUM('active', 'verifying', 'completed_success', 'completed_failure', 'payout_complete') NOT NULL DEFAULT 'active',
    stripe_payment_intent_id VARCHAR(255) NOT NULL UNIQUE,
    stripe_transfer_id VARCHAR(255) NULL,
    proof_image_url VARCHAR(1024) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (pledger_id) REFERENCES Users(id) ON DELETE CASCADE,
    FOREIGN KEY (referee_id) REFERENCES Users(id) ON DELETE CASCADE
);
