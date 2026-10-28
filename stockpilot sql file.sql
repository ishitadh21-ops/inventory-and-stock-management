
-- =====================================================
-- INVENTORY AND STOCK MANAGEMENT SYSTEM
-- Technology: MySQL 8.x
-- =====================================================

CREATE DATABASE IF NOT EXISTS inventory_management;
USE inventory_management;

-- =====================================================
-- 1. CATEGORY TABLE
-- =====================================================

CREATE TABLE categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    description VARCHAR(255)
);

-- =====================================================
-- 2. SUPPLIER TABLE
-- =====================================================

CREATE TABLE suppliers (
    supplier_id INT AUTO_INCREMENT PRIMARY KEY,
    supplier_name VARCHAR(150) NOT NULL,
    contact_person VARCHAR(100),
    phone VARCHAR(20),
    email VARCHAR(150),
    address VARCHAR(255)
);

-- =====================================================
-- 3. PRODUCT TABLE
-- =====================================================

CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(150) NOT NULL,
    category_id INT NOT NULL,
    supplier_id INT,
    unit_price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    current_stock INT NOT NULL DEFAULT 0,
    reorder_level INT NOT NULL DEFAULT 10,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_product_price
        CHECK (unit_price >= 0),

    CONSTRAINT chk_product_stock
        CHECK (current_stock >= 0),

    CONSTRAINT chk_reorder_level
        CHECK (reorder_level >= 0),

    CONSTRAINT fk_product_category
        FOREIGN KEY (category_id)
        REFERENCES categories(category_id),

    CONSTRAINT fk_product_supplier
        FOREIGN KEY (supplier_id)
        REFERENCES suppliers(supplier_id)
);

-- =====================================================
-- 4. STOCK TRANSACTION TABLE
-- =====================================================

CREATE TABLE stock_transactions (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    transaction_type ENUM('IN', 'OUT') NOT NULL,
    quantity INT NOT NULL,
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    remarks VARCHAR(255),

    CONSTRAINT chk_transaction_quantity
        CHECK (quantity > 0),

    CONSTRAINT fk_transaction_product
        FOREIGN KEY (product_id)
        REFERENCES products(product_id)
);

-- =====================================================
-- 5. TRIGGER: VALIDATE STOCK-OUT TRANSACTIONS
-- =====================================================

DELIMITER $$

CREATE TRIGGER before_stock_transaction_insert
BEFORE INSERT ON stock_transactions
FOR EACH ROW
BEGIN
    DECLARE available_stock INT DEFAULT NULL;

    IF NEW.quantity <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Quantity must be greater than zero';
    END IF;

    IF NEW.transaction_type = 'OUT' THEN

        SELECT current_stock
        INTO available_stock
        FROM products
        WHERE product_id = NEW.product_id
        FOR UPDATE;

        IF available_stock IS NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Product does not exist';
        END IF;

        IF available_stock < NEW.quantity THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Insufficient stock available';
        END IF;

    END IF;
END$$

-- =====================================================
-- 6. TRIGGER: AUTOMATICALLY UPDATE PRODUCT STOCK
-- =====================================================

CREATE TRIGGER after_stock_transaction_insert
AFTER INSERT ON stock_transactions
FOR EACH ROW
BEGIN
    IF NEW.transaction_type = 'IN' THEN

        UPDATE products
        SET current_stock = current_stock + NEW.quantity
        WHERE product_id = NEW.product_id;

    ELSEIF NEW.transaction_type = 'OUT' THEN

        UPDATE products
        SET current_stock = current_stock - NEW.quantity
        WHERE product_id = NEW.product_id;

    END IF;
END$$

DELIMITER ;

-- =====================================================
-- 7. SAMPLE CATEGORY DATA
-- =====================================================

INSERT INTO categories (category_name, description)
VALUES
('Electronics', 'Electronic devices and accessories'),
('Stationery', 'Office and educational supplies'),
('Furniture', 'Office and household furniture'),
('Accessories', 'General accessories');

-- =====================================================
-- 8. SAMPLE SUPPLIER DATA
-- =====================================================

INSERT INTO suppliers
(supplier_name, contact_person, phone, email, address)
VALUES
('Tech World', 'Rahul Shah', '9876543210',
 'tech@example.com', 'Vadodara'),

('Office Supplies Co.', 'Neha Patel', '9876501234',
 'office@example.com', 'Anand'),

('Furniture Hub', 'Amit Mehta', '9876512345',
 'furniture@example.com', 'Ahmedabad');

-- =====================================================
-- 9. SAMPLE PRODUCT DATA
-- =====================================================

INSERT INTO products
(product_name, category_id, supplier_id,
 unit_price, current_stock, reorder_level)
VALUES
('Wireless Mouse', 1, 1, 599.00, 0, 10),
('Keyboard', 1, 1, 899.00, 0, 8),
('Notebook', 2, 2, 60.00, 0, 20),
('Office Chair', 3, 3, 4500.00, 0, 3),
('USB Cable', 4, 1, 199.00, 0, 15);

-- =====================================================
-- 10. STORED PROCEDURE: ADD STOCK
-- =====================================================

DELIMITER $$

CREATE PROCEDURE add_stock(
    IN p_product_id INT,
    IN p_quantity INT,
    IN p_remarks VARCHAR(255)
)
BEGIN
    IF p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Quantity must be greater than zero';
    END IF;

    INSERT INTO stock_transactions
        (product_id, transaction_type, quantity, remarks)
    VALUES
        (p_product_id, 'IN', p_quantity, p_remarks);
END$$

-- =====================================================
-- 11. STORED PROCEDURE: REMOVE STOCK
-- =====================================================

CREATE PROCEDURE remove_stock(
    IN p_product_id INT,
    IN p_quantity INT,
    IN p_remarks VARCHAR(255)
)
BEGIN
    IF p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Quantity must be greater than zero';
    END IF;

    INSERT INTO stock_transactions
        (product_id, transaction_type, quantity, remarks)
    VALUES
        (p_product_id, 'OUT', p_quantity, p_remarks);
END$$

DELIMITER ;

-- =====================================================
-- 12. VIEW: COMPLETE INVENTORY REPORT
-- =====================================================

CREATE VIEW inventory_report AS
SELECT
    p.product_id,
    p.product_name,
    c.category_name,
    s.supplier_name,
    p.unit_price,
    p.current_stock,
    p.reorder_level,
    (p.unit_price * p.current_stock) AS stock_value,
    CASE
        WHEN p.current_stock = 0 THEN 'OUT OF STOCK'
        WHEN p.current_stock <= p.reorder_level THEN 'LOW STOCK'
        ELSE 'IN STOCK'
    END AS stock_status
FROM products p
JOIN categories c
    ON p.category_id = c.category_id
LEFT JOIN suppliers s
    ON p.supplier_id = s.supplier_id;

-- =====================================================
-- 13. VIEW: LOW-STOCK ALERTS
-- =====================================================

CREATE VIEW low_stock_alerts AS
SELECT
    product_id,
    product_name,
    current_stock,
    reorder_level
FROM products
WHERE current_stock <= reorder_level;

-- =====================================================
-- 14. VIEW: TRANSACTION HISTORY
-- =====================================================

CREATE VIEW transaction_history AS
SELECT
    t.transaction_id,
    p.product_name,
    t.transaction_type,
    t.quantity,
    t.transaction_date,
    t.remarks
FROM stock_transactions t
JOIN products p
    ON t.product_id = p.product_id;

-- =====================================================
-- 15. SAMPLE STOCK TRANSACTIONS
-- =====================================================

CALL add_stock(1, 50, 'Initial stock received');
CALL add_stock(2, 30, 'Initial stock received');
CALL add_stock(3, 100, 'Initial stock received');
CALL add_stock(4, 10, 'Initial stock received');
CALL add_stock(5, 40, 'Initial stock received');

CALL remove_stock(1, 5, 'Items sold');
CALL remove_stock(3, 85, 'Items issued');

-- =====================================================
-- 16. TEST AND REPORT QUERIES
-- =====================================================

-- A. Display all products
SELECT * FROM products;

-- B. Display the complete inventory report
SELECT * FROM inventory_report;

-- C. Display low-stock products
SELECT * FROM low_stock_alerts;

-- D. Display transaction history
SELECT * FROM transaction_history
ORDER BY transaction_date DESC;

-- E. Calculate total inventory value
SELECT SUM(unit_price * current_stock) AS total_inventory_value
FROM products;

-- F. Count products in each category
SELECT
    c.category_name,
    COUNT(p.product_id) AS total_products
FROM categories c
LEFT JOIN products p
    ON c.category_id = p.category_id
GROUP BY c.category_id, c.category_name;

-- G. Calculate total units available in each category
SELECT
    c.category_name,
    COALESCE(SUM(p.current_stock), 0) AS total_units
FROM categories c
LEFT JOIN products p
    ON c.category_id = p.category_id
GROUP BY c.category_id, c.category_name;

-- H. Find products with stock greater than 20
SELECT product_name, current_stock
FROM products
WHERE current_stock > 20
ORDER BY current_stock DESC;

-- I. Show the total quantity received for each product
SELECT
    p.product_name,
    COALESCE(SUM(
        CASE WHEN t.transaction_type = 'IN'
             THEN t.quantity ELSE 0 END
    ), 0) AS total_received
FROM products p
LEFT JOIN stock_transactions t
    ON p.product_id = t.product_id
GROUP BY p.product_id, p.product_name;

-- J. Search for a product by name
SELECT *
FROM products
WHERE product_name LIKE '%Mouse%';

-- K. Test stock-in procedure
CALL add_stock(1, 10, 'Restock test');
SELECT * FROM inventory_report WHERE product_id = 1;

-- L. Test stock-out procedure
CALL remove_stock(1, 3, 'Stock issue test');
SELECT * FROM inventory_report WHERE product_id = 1;

