-- IMS Database Initialization
-- Users table for IMS registration

CREATE DATABASE IF NOT EXISTS ims;
USE ims;

-- IMS subscribers
CREATE TABLE IF NOT EXISTS subscribers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    imsi VARCHAR(20) NOT NULL UNIQUE,
    msisdn VARCHAR(20) NOT NULL,
    domain VARCHAR(100) DEFAULT 'ims.free5gc.org',
    password VARCHAR(100),
    k VARCHAR(64),
    op VARCHAR(64),
    amf VARCHAR(8),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert test subscribers
INSERT INTO subscribers (imsi, msisdn, domain, password, k, op, amf) VALUES
('460119999999001', '0000000001', 'ims.free5gc.org', 'test123', '12345678901234567890123456789012', '12345678901234561234567890123456', '8000'),
('460119999999002', '0000000002', 'ims.free5gc.org', 'test123', '12345678901234567890123456789012', '12345678901234561234567890123456', '8000'),
('460119999999003', '0000000003', 'ims.free5gc.org', 'test123', '12345678901234567890123456789012', '12345678901234561234567890123456', '8000');

-- SIP location table
CREATE TABLE IF NOT EXISTS location (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ruid VARCHAR(64) NOT NULL,
    username VARCHAR(64) NOT NULL,
    domain VARCHAR(64),
    contact VARCHAR(255),
    received VARCHAR(255),
    path VARCHAR(255),
    expires TIMESTAMP,
    q FLOAT DEFAULT 1.0,
    callid VARCHAR(255),
    cseq INT,
    user_agent VARCHAR(255),
    instance VARCHAR(255)
);

-- Dialog table for call tracking
CREATE TABLE IF NOT EXISTS dialog (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hash_entry INT NOT NULL,
    hash_id INT NOT NULL,
    callid VARCHAR(255) NOT NULL,
    from_uri VARCHAR(255) NOT NULL,
    from_tag VARCHAR(64),
    to_uri VARCHAR(255),
    to_tag VARCHAR(64),
    caller_cseq INT,
    callee_cseq INT,
    caller_contact VARCHAR(255),
    callee_contact VARCHAR(255),
    state INT DEFAULT 1,
    start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    timeout INT DEFAULT 3600
);