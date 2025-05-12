-- 1) Find the top restaurants by cuisine orders
WITH rest AS (
    SELECT 
        restaurant_id, 
        cuisine, 
        COUNT(*) AS number_of_orders
    FROM orders
    GROUP BY restaurant_id, cuisine
),
top_o AS (
    SELECT 
        restaurant_id, 
        cuisine, 
        number_of_orders,
        ROW_NUMBER() OVER (PARTITION BY cuisine ORDER BY number_of_orders DESC) AS top_outlets
    FROM rest
)
SELECT * 
FROM top_o
WHERE top_outlets = 1;

-- 2) Daily new customer count from the launch date
WITH ord_num AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY customer_code ORDER BY placed_at ASC) AS count_num
    FROM orders
),
new_customers AS (
    SELECT * 
    FROM ord_num 
    WHERE count_num = 1
)
SELECT 
    DATE(placed_at) AS date,
    COUNT(customer_code) AS new_customers
FROM new_customers 
GROUP BY DATE(placed_at) 
ORDER BY DATE(placed_at);

-- Alternate version of new customer acquisition
WITH first_order AS (
    SELECT 
        customer_code, 
        DATE(MIN(placed_at)) AS first_order_date
    FROM orders
    GROUP BY customer_code
)
SELECT 
    first_order_date, 
    COUNT(customer_code) AS count 
FROM first_order
GROUP BY first_order_date 
ORDER BY first_order_date ASC;

-- 3) Customers who ordered only once in January and not again
SELECT 
    customer_code, 
    COUNT(customer_code) AS order_count
FROM orders 
WHERE MONTH(placed_at) = 1 
  AND customer_code NOT IN (
      SELECT DISTINCT customer_code
      FROM orders 
      WHERE MONTH(placed_at) > 1
  )
GROUP BY customer_code
HAVING COUNT(customer_code) = 1;

-- 4) Customers with no orders in last 7 days but were acquired one month ago with a promo
WITH cust AS (
    SELECT 
        customer_code, 
        MIN(DATE(placed_at)) AS first_order, 
        MAX(DATE(placed_at)) AS recent_order
    FROM orders
    GROUP BY customer_code
)
SELECT *
FROM cust c 
JOIN orders o 
    ON c.customer_code = o.customer_code 
   AND DATE(o.placed_at) = c.first_order
WHERE 
    recent_order < DATE_ADD('2025-04-02', INTERVAL -7 DAY)
    AND first_order < DATE_ADD('2025-04-02', INTERVAL -1 MONTH)
    AND promo_code_name IS NOT NULL;

-- 5) Trigger logic: identify customers after every third order
WITH cte AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY customer_code ORDER BY placed_at ASC) AS order_num
    FROM orders
)
SELECT * 
FROM cte
WHERE order_num % 3 = 0 
  AND DATE(placed_at) = CURDATE();

-- 6) Customers who placed multiple orders, all using promo codes
WITH cte AS (
    SELECT 
        customer_code, 
        COUNT(*) AS total 
    FROM orders 
    GROUP BY customer_code 
    HAVING COUNT(*) > 1
)
SELECT 
    o.customer_code, 
    COUNT(promo_code_name) AS promo_used_count, 
    total 
FROM cte 
JOIN orders o ON cte.customer_code = o.customer_code 
GROUP BY o.customer_code
HAVING COUNT(promo_code_name) = total;

-- 7) % of customers acquired organically (no promo) in Jan 2025
WITH cte AS (
    SELECT 
        customer_code, 
        promo_code_name,
        ROW_NUMBER() OVER (PARTITION BY customer_code ORDER BY placed_at) AS order_number
    FROM orders 
    WHERE MONTH(placed_at) = 1
)
SELECT 
    ROUND(
        COUNT(CASE WHEN promo_code_name IS NULL THEN customer_code END) 
        / COUNT(customer_code) * 100, 
        2
    ) AS "%_of_organic"
FROM cte
WHERE order_number = 1;

