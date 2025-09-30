
-- E-commerce relational database schema — MySQL 8.0+ compatible
DROP DATABASE IF EXISTS ecommerce_db;
CREATE DATABASE ecommerce_db
  CHARACTER SET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;
USE ecommerce_db;

-- -----------------------------------------------------
-- Users / Customers
-- -----------------------------------------------------
CREATE TABLE users (
  user_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  phone VARCHAR(30),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- Addresses (one-to-many: that is a user can have multiple addresses)
-- -----------------------------------------------------
CREATE TABLE addresses (
  address_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  label VARCHAR(50),
  street VARCHAR(255) NOT NULL,
  city VARCHAR(100) NOT NULL,
  state VARCHAR(100),
  postal_code VARCHAR(20),
  country VARCHAR(100) NOT NULL,
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  -- generated column used to enforce single default address per user
  default_flag TINYINT(1) AS (CASE WHEN is_default THEN 1 ELSE NULL END) VIRTUAL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_addresses_user FOREIGN KEY (user_id)
    REFERENCES users(user_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  UNIQUE KEY ux_user_default_address (user_id, default_flag)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- Categories
-- -----------------------------------------------------
CREATE TABLE categories (
  category_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- Products
-- -----------------------------------------------------
CREATE TABLE products (
  product_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sku VARCHAR(100) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  price DECIMAL(12,2) NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT chk_price_nonnegative CHECK (price >= 0)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- Many-to-many: product_categories
-- -----------------------------------------------------
CREATE TABLE product_categories (
  product_id BIGINT UNSIGNED NOT NULL,
  category_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (product_id, category_id),
  CONSTRAINT fk_pc_product FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_pc_category FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- Suppliers
-- -----------------------------------------------------
CREATE TABLE suppliers (
  supplier_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  contact_email VARCHAR(255),
  phone VARCHAR(50),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- supplier_products
-- -----------------------------------------------------
CREATE TABLE supplier_products (
  supplier_id INT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  supplier_sku VARCHAR(100),
  lead_time_days INT UNSIGNED DEFAULT 0,
  price DECIMAL(12,2),
  PRIMARY KEY (supplier_id, product_id),
  CONSTRAINT fk_sp_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_sp_product FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_sp_price_nonnegative CHECK (price IS NULL OR price >= 0)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- Inventory
-- -----------------------------------------------------
CREATE TABLE inventory (
  inventory_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_id BIGINT UNSIGNED NOT NULL,
  quantity INT NOT NULL DEFAULT 0,
  reserved INT NOT NULL DEFAULT 0,
  location VARCHAR(255),
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_inventory_product FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_inventory_nonnegative CHECK (quantity >= 0 AND reserved >= 0)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- Orders
-- -----------------------------------------------------
CREATE TABLE orders (
  order_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  order_number VARCHAR(50) NOT NULL UNIQUE,
  order_status ENUM('pending','processing','shipped','delivered','cancelled','refunded') NOT NULL DEFAULT 'pending',
  shipping_address_id BIGINT UNSIGNED,
  billing_address_id BIGINT UNSIGNED,
  total_amount DECIMAL(12,2) NOT NULL,
  placed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_orders_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_orders_ship_addr FOREIGN KEY (shipping_address_id) REFERENCES addresses(address_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_orders_bill_addr FOREIGN KEY (billing_address_id) REFERENCES addresses(address_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT chk_orders_total_nonnegative CHECK (total_amount >= 0)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- Order items
-- -----------------------------------------------------
CREATE TABLE order_items (
  order_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  quantity INT UNSIGNED NOT NULL,
  unit_price DECIMAL(12,2) NOT NULL,
  discount DECIMAL(12,2) NOT NULL DEFAULT 0,
  PRIMARY KEY (order_id, product_id),
  CONSTRAINT fk_oi_order FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_oi_product FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_oi_quantity_pos CHECK (quantity > 0),
  CONSTRAINT chk_oi_price_nonnegative CHECK (unit_price >= 0),
  CONSTRAINT chk_oi_discount_nonnegative CHECK (discount >= 0)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- Payments (one-to-one-relationship)
-- -----------------------------------------------------
CREATE TABLE payments (
  payment_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id BIGINT UNSIGNED NOT NULL UNIQUE,
  payment_method ENUM('card','paypal','bank_transfer','wallet') NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  status ENUM('initiated','succeeded','failed','refunded') NOT NULL DEFAULT 'initiated',
  paid_at TIMESTAMP NULL DEFAULT NULL,
  transaction_reference VARCHAR(255) UNIQUE,
  CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_payments_amount_nonnegative CHECK (amount >= 0)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- Reviews (allow user_id NULL so ON DELETE SET NULL is valid)
-- -----------------------------------------------------
CREATE TABLE reviews (
  review_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NULL,
  rating TINYINT UNSIGNED NOT NULL,
  title VARCHAR(255),
  body TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_reviews_product FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_reviews_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT chk_reviews_rating_range CHECK (rating BETWEEN 1 AND 5)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- Wishlist (many-to-many)
-- -----------------------------------------------------
CREATE TABLE wishlists (
  user_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  added_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, product_id),
  CONSTRAINT fk_wishlist_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_wishlist_product FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- Admins (one-to-one with users.user_id)
-- -----------------------------------------------------
CREATE TABLE admins (
  admin_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL UNIQUE,
  role ENUM('manager','inventory','support','superadmin') NOT NULL DEFAULT 'manager',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_admin_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- Creating Indexes
-- -----------------------------------------------------
CREATE INDEX idx_products_name ON products(name(100));
CREATE INDEX idx_orders_user ON orders(user_id);
CREATE INDEX idx_inventory_product ON inventory(product_id);
CREATE INDEX idx_reviews_product ON reviews(product_id);


-- -----------------------------------------------------
-- Inserting Sample Data
-- -----------------------------------------------------

-- Users
INSERT INTO users (email, password_hash, first_name, last_name, phone)
VALUES
('alice@example.com', 'hash1', 'Alice', 'Johnson', '+2348011111111'),
('bob@example.com', 'hash2', 'Bob', 'Smith', '+2348022222222'),
('carol@example.com', 'hash3', 'Carol', 'Williams', '+2348033333333');

-- Addresses
INSERT INTO addresses (user_id, label, street, city, state, postal_code, country, is_default)
VALUES
(1, 'Home', '12 Main Street', 'Ibadan', 'Oyo', '200001', 'Nigeria', TRUE),
(1, 'Office', 'Tech Hub, Ring Road', 'Ibadan', 'Oyo', '200002', 'Nigeria', FALSE),
(2, 'Home', '5 Broad Avenue', 'Lagos', 'Lagos', '100001', 'Nigeria', TRUE);

-- Categories
INSERT INTO categories (name, description)
VALUES
('Electronics', 'Devices and gadgets'),
('Books', 'Printed and digital books'),
('Clothing', 'Apparel and accessories');

-- Products
INSERT INTO products (sku, name, description, price)
VALUES
('SKU1001', 'Wireless Headphones', 'Noise cancelling headphones', 199.99),
('SKU2001', 'Python Programming Book', 'Learn Python programming step by step', 29.95),
('SKU3001', 'T-Shirt', 'Cotton round-neck T-shirt', 15.50);

-- Product Categories (many-to-many links)
INSERT INTO product_categories (product_id, category_id)
VALUES
(1, 1), -- Headphones -> Electronics
(2, 2), -- Book -> Books
(3, 3); -- T-shirt -> Clothing

-- Suppliers
INSERT INTO suppliers (name, contact_email, phone)
VALUES
('TechSupply Ltd', 'contact@techsupply.com', '+2348044444444'),
('BookWorld', 'sales@bookworld.com', '+2348055555555');

-- Supplier Products
INSERT INTO supplier_products (supplier_id, product_id, supplier_sku, lead_time_days, price)
VALUES
(1, 1, 'SUP-SKU1001', 5, 150.00),
(2, 2, 'SUP-SKU2001', 7, 20.00);

-- Inventory
INSERT INTO inventory (product_id, quantity, reserved, location)
VALUES
(1, 50, 5, 'Main Warehouse'),
(2, 100, 10, 'Book Depot'),
(3, 200, 15, 'Clothing Section');

-- Orders
INSERT INTO orders (user_id, order_number, order_status, shipping_address_id, billing_address_id, total_amount)
VALUES
(1, 'ORD-0001', 'processing', 1, 1, 229.94),
(2, 'ORD-0002', 'pending', 3, 3, 15.50);

-- Order Items
INSERT INTO order_items (order_id, product_id, quantity, unit_price, discount)
VALUES
(1, 1, 1, 199.99, 0),   -- Headphones
(1, 2, 1, 29.95, 0),    -- Book
(2, 3, 1, 15.50, 0);    -- T-shirt

-- Payments
INSERT INTO payments (order_id, payment_method, amount, currency, status, paid_at, transaction_reference)
VALUES
(1, 'card', 229.94, 'USD', 'succeeded', NOW(), 'TXN123456'),
(2, 'wallet', 15.50, 'USD', 'initiated', NULL, 'TXN654321');

-- Reviews
INSERT INTO reviews (product_id, user_id, rating, title, body)
VALUES
(1, 1, 5, 'Amazing sound', 'The headphones are really great with noise cancellation!'),
(2, 2, 4, 'Good book', 'Helped me understand Python basics.'),
(3, 3, 3, 'Okay shirt', 'Quality is average, but fine for the price.');

-- Wishlist
INSERT INTO wishlists (user_id, product_id)
VALUES
(1, 3), -- Alice wants a T-shirt
(2, 1); -- Bob wants headphones

-- Admins
INSERT INTO admins (user_id, role)
VALUES
(1, 'superadmin'),
(2, 'inventory');


-- ------------------------------------------
-- Sample Query
-- ------------------------------------------

-- Show all orders with user details
SELECT o.order_number, u.first_name, u.last_name, o.total_amount, o.order_status
FROM orders o
JOIN users u ON o.user_id = u.user_id;

-- Show products with their category
SELECT p.name AS product, c.name AS category
FROM products p
JOIN product_categories pc ON p.product_id = pc.product_id
JOIN categories c ON pc.category_id = c.category_id;

-- Show reviews for each product
SELECT p.name AS product, r.rating, r.title, r.body
FROM reviews r
JOIN products p ON r.product_id = p.product_id;


