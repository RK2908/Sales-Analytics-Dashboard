-- 1. Customers
CREATE TABLE customers (
    customer_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name       VARCHAR(50) NOT NULL,
    last_name        VARCHAR(50) NOT NULL,
    email            VARCHAR(100) UNIQUE NOT NULL,
    phone            VARCHAR(20),
    city             VARCHAR(50),
    state            VARCHAR(50),
    created_at       TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 2. Products
CREATE TABLE products (
    product_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_name     VARCHAR(100) NOT NULL,
    category         VARCHAR(50) NOT NULL,
    unit_price       NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
    active           BOOLEAN NOT NULL DEFAULT TRUE
);

-- 3. Orders
CREATE TABLE orders (
    order_id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id      BIGINT NOT NULL,
    order_date       DATE NOT NULL,
    order_status     VARCHAR(20) NOT NULL CHECK (order_status IN ('PENDING','PAID','CANCELLED','REFUNDED')),
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- 4. Order items (line items per order)
CREATE TABLE order_items (
    order_item_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id         BIGINT NOT NULL,
    product_id       BIGINT NOT NULL,
    quantity         INT NOT NULL CHECK (quantity > 0),
    unit_price       NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- 5. Payments
CREATE TABLE payments (
    payment_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id         BIGINT NOT NULL,
    payment_date     DATE NOT NULL,
    amount           NUMERIC(10,2) NOT NULL CHECK (amount >= 0),
    payment_method   VARCHAR(20) NOT NULL CHECK (payment_method IN ('CARD','UPI','CASH','NETBANKING')),
    CONSTRAINT fk_payments_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

-- Insertion of data --
INSERT INTO customers (first_name, last_name, email, phone, city, state)
VALUES
('Ravi',   'Kumar',     'ravi.kumar@example.com',   '9876543210', 'Chennai',        'Tamil Nadu'),
('Priya',  'Sharma',    'priya.sharma@example.com','9988776655', 'Coimbatore',     'Tamil Nadu'),
('Arjun',  'Reddy',     'arjun.reddy@example.com', '9123456789', 'Hyderabad',      'Telangana'),
('Meera',  'Nair',      'meera.nair@example.com',  '9012345678', 'Kochi',          'Kerala'),
('Vikram', 'Singh',     'vikram.singh@example.com','9090909090', 'Bangalore',      'Karnataka');

INSERT INTO products (product_name, category, unit_price)
VALUES
('Wireless Mouse',          'Electronics', 599.00),
('Mechanical Keyboard',     'Electronics', 2499.00),
('Laptop Backpack',         'Accessories', 1499.00),
('Noise Cancelling Headset','Electronics', 3499.00),
('USB-C Cable',             'Accessories', 299.00);

INSERT INTO orders (customer_id, order_date, order_status)
VALUES
(1, '2025-11-01', 'PAID'),
(1, '2025-11-05', 'PENDING'),
(2, '2025-11-02', 'PAID'),
(3, '2025-11-03', 'CANCELLED'),
(4, '2025-11-04', 'PAID'),
(5, '2025-11-06', 'PAID');

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES
-- Order 1 (customer 1)
(1, 1, 1, 599.00),    -- Wireless Mouse
(1, 2, 1, 2499.00),  -- Mechanical Keyboard

-- Order 2 (customer 1 - pending)
(2, 3, 1, 1499.00),

-- Order 3 (customer 2)
(3, 4, 1, 3499.00),

-- Order 4 (customer 3 - cancelled)
(4, 5, 2, 299.00),

-- Order 5 (customer 4)
(5, 2, 1, 2499.00),
(5, 5, 3, 299.00),

-- Order 6 (customer 5)
(6, 1, 2, 599.00),
(6, 3, 1, 1499.00);

INSERT INTO payments (order_id, payment_date, amount, payment_method)
VALUES
(1, '2025-11-01', 3098.00, 'CARD'),       -- mouse + keyboard
(3, '2025-11-02', 3499.00, 'UPI'),
(5, '2025-11-04', 3396.00, 'NETBANKING'), -- keyboard + 3 cables
(6, '2025-11-06', 2697.00, 'CARD');       -- 2 mouse + backpack

-- checking data
SELECT * FROM customers;
SELECT * FROM products;
SELECT * FROM orders;
SELECT * FROM order_items;
SELECT * FROM payments;

-- Total Revenue
SELECT 
    SUM(amount) AS total_revenue
FROM payments;

-- Revenue by payment method
SELECT 
    payment_method,
    SUM(amount) AS total_revenue,
    COUNT(*)    AS num_payments
FROM payments
GROUP BY payment_method
ORDER BY total_revenue DESC;

-- Total amount of each order (from order_items)
SELECT 
    o.order_id,
    o.order_date,
    o.order_status,
    SUM(oi.quantity * oi.unit_price) AS order_total
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, o.order_date, o.order_status
ORDER BY o.order_id;

-- Compare order total vs payment (to check under/over payments)
WITH order_totals AS (
    SELECT 
        o.order_id,
        SUM(oi.quantity * oi.unit_price) AS order_total
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.order_id
)
SELECT 
    ot.order_id,
    ot.order_total,
    COALESCE(SUM(p.amount), 0) AS paid_amount,
    (COALESCE(SUM(p.amount), 0) - ot.order_total) AS difference
FROM order_totals ot
LEFT JOIN payments p ON ot.order_id = p.order_id
GROUP BY ot.order_id, ot.order_total
ORDER BY ot.order_id;

-- Top customers by total spending
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    SUM(p.amount) AS total_spent
FROM customers c
JOIN orders o    ON c.customer_id = o.customer_id
JOIN payments p  ON o.order_id = p.order_id
GROUP BY c.customer_id, customer_name
ORDER BY total_spent DESC;

-- Best-selling products (by quantity)
SELECT 
    p.product_id,
    p.product_name,
    SUM(oi.quantity) AS total_quantity_sold
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN orders o       ON oi.order_id = o.order_id
WHERE o.order_status = 'PAID'
GROUP BY p.product_id, p.product_name
ORDER BY total_quantity_sold DESC;

-- Sales by day
SELECT 
    o.order_date,
    SUM(oi.quantity * oi.unit_price) AS daily_sales
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'PAID'
GROUP BY o.order_date
ORDER BY o.order_date;

-- Slightly advanced: window function example : Get each order’s value and show rank of orders by value:
SELECT
    o.order_id,
    o.order_date,
    c.first_name || ' ' || c.last_name AS customer_name,
    SUM(oi.quantity * oi.unit_price) AS order_total,
    RANK() OVER (ORDER BY SUM(oi.quantity * oi.unit_price) DESC) AS order_value_rank
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'PAID'
GROUP BY o.order_id, o.order_date, customer_name
ORDER BY order_value_rank;

-- Create a view (for reuse & project feel)
CREATE VIEW vw_order_summary AS
SELECT
    o.order_id,
    o.order_date,
    c.first_name || ' ' || c.last_name AS customer_name,
    o.order_status,
    SUM(oi.quantity * oi.unit_price) AS order_total
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, o.order_date, customer_name, o.order_status;


-- Use the view:
SELECT * FROM vw_order_summary ORDER BY order_id;

COPY (
    SELECT * FROM vw_order_summary ORDER BY order_id
) TO 'C:/order_summary.csv' WITH CSV HEADER;







