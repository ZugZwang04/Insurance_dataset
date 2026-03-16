CREATE DATABASE db_insurance;

USE db_insurance;

-- Provinces table
CREATE TABLE provinces (
    province_id INT PRIMARY KEY,
    province VARCHAR(100) NOT NULL,
    region VARCHAR(100) NOT NULL
);

-- Customers table
CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    province_id INT,
    cust_first_name VARCHAR(100) NOT NULL,
    cust_last_name VARCHAR(100) NOT NULL,
    FOREIGN KEY (province_id) REFERENCES provinces(province_id)
);

-- Services table
CREATE TABLE services (
    insurance_id INT PRIMARY KEY,
    insurance_service VARCHAR(150) NOT NULL,
    policy_term_years INT
);

-- Agents table
CREATE TABLE agents (
    agent_id INT PRIMARY KEY,
    agent_first_name VARCHAR(100) NOT NULL,
    agent_last_name VARCHAR(100) NOT NULL
);

-- Policies table
CREATE TABLE policies (
    policy_id INT PRIMARY KEY,
    customer_id INT,
    agent_id INT,
    insurance_id INT,
    payment_schedule VARCHAR(50),
    policy_status VARCHAR(50),
    payment_status VARCHAR(50),
    start_date DATE,
    claim_date DATE,
    claim_amount DECIMAL(12,2),
    annual_premium DECIMAL(12,2),
    payments_per_year INT,
    total_premium DECIMAL(12,2),

    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (agent_id) REFERENCES agents(agent_id),
    FOREIGN KEY (insurance_id) REFERENCES services(insurance_id)
);


-- For faster JOINs
CREATE INDEX idx_policies_customer ON policies(customer_id);
CREATE INDEX idx_policies_agent ON policies(agent_id);
CREATE INDEX idx_policies_insurance ON policies(insurance_id);

-- Encrypt customer names
ALTER TABLE customers
MODIFY cust_first_name BLOB,
MODIFY cust_last_name BLOB;

UPDATE customers
SET cust_first_name = AES_ENCRYPT(cust_first_name, 'encryption_key'),
    cust_last_name  = AES_ENCRYPT(cust_last_name, 'encryption_key');

--1) Revenue per Region and per province all in descending order (Paid policies only)

WITH province_premium AS (
    SELECT p.province AS Province, 
        p.region AS Region, 
        SUM(pol.total_premium) AS Province_Revenue
    FROM provinces p 
    JOIN customers c
        ON c.province_id = p.province_id
    JOIN policies pol
        ON pol.customer_id = c.customer_id
    WHERE pol.payment_status = 'paid'
    GROUP BY p.region, p.province
)

SELECT Region, Province,
    Province_Revenue,
    SUM(Province_Revenue) OVER(PARTITION BY Region) AS Revenue_per_Region,
    RANK() OVER(ORDER BY SUM(Province_Revenue) DESC) AS Province_Rank
FROM province_premium
GROUP BY Region, Province
ORDER BY Revenue_per_Region DESC, Province_Revenue DESC;    -- 400 rows


-- Index for filtering by policy status
CREATE INDEX idx_policies_status
ON policies(payment_status);

EXPLAIN WITH province_premium AS (
    SELECT p.province AS Province, 
        p.region AS Region, 
        SUM(pol.total_premium) AS Province_Revenue
    FROM provinces p 
    JOIN customers c
        ON c.province_id = p.province_id
    JOIN policies pol
        ON pol.customer_id = c.customer_id
    WHERE pol.payment_status = 'paid'
    GROUP BY p.region, p.province
)

SELECT Region, Province,
    Province_Revenue,
    SUM(Province_Revenue) OVER(PARTITION BY Region) AS Revenue_per_Region,
    RANK () OVER(ORDER BY SUM(Province_Revenue) DESC) AS Province_Rank
FROM province_premium
GROUP BY Region, Province
ORDER BY Revenue_per_Region DESC, Province_Revenue DESC;    -- 203 rows



-- 2) Agents' Performance

SELECT 
    CONCAT(a.agent_first_name, ' ', a.agent_last_name) AS agent_name,
    COUNT(p.policy_id) AS total_policies,
    SUM(p.total_premium) AS total_premium_sold,
    RANK() OVER (ORDER BY SUM(p.total_premium) DESC) AS agent_rank
FROM agents a
LEFT JOIN policies p
    ON a.agent_id = p.agent_id
GROUP BY a.agent_id, agent_name;


SELECT 
    CONCAT(a.agent_first_name, ' ', a.agent_last_name) AS agent_name,
    COUNT(p.policy_id) AS total_policies,
    SUM(p.total_premium) AS total_premium_sold,
    CASE 
        WHEN SUM(p.total_premium) >= 50000 THEN 'Top Performer'
        WHEN SUM(p.total_premium) >= 20000 THEN 'Mid Performer'
        ELSE 'Low Performer'
    END AS performance_category
FROM agents a
JOIN policies p ON a.agent_id = p.agent_id
GROUP BY a.agent_id, a.agent_first_name, a.agent_last_name
HAVING COUNT(p.policy_id) >= 3;  


-- Backup
-- 1) Run cmd line as administrator then enter this:
-- "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqldump" -u root -p -h 127.0.0.1 -P 3307 db_insurance > "C:\Users\Carlo\Documents\backup.sql"

-- Restore
-- 1) Run cmd line as administrator then enter this:
-- mysql -u root -p -h 127.0.0.1 -P 3307 db_insurance < "C:\Users\Carlo\Documents\backup.sql"
-- If db_insurance does not exist, create first.