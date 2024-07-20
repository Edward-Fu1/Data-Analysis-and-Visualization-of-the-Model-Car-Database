# Goal:Should we close any warehouse, if so, which one and why

SELECT *
FROM warehouses;

SELECT *
FROM products;

SELECT *
FROM productlines;

SELECT *
FROM orderdetails;

SELECT *
FROM orders;

SELECT *
FROM customers;

SELECT *
FROM payments;

SELECT *
FROM employees;

SELECT *
FROM offices;

SELECT *
FROM product_sold_summary;

SELECT *
FROM product_country_sale;

-- Retrieves all orders that are not shipped or in process
SELECT *
FROM orders
WHERE status NOT IN ('Shipped', 'In Process');

-- Creates a temporary table of successful orders with their details
CREATE TEMPORARY TABLE temp_success_orders AS
WITH success_order AS (
    SELECT *
    FROM orders
    WHERE status IN ('Shipped', 'In Process')
)
SELECT 
    so.orderNumber,
    od.productCode, 
    od.quantityOrdered, 
    od.priceEach
FROM success_order so
LEFT JOIN orderdetails od ON so.orderNumber = od.orderNumber;

SELECT*
FROM temp_success_orders;

-- Creates a summary table of product sales including quantity, revenue, and average price
CREATE TABLE product_sold_summary AS
SELECT 
    productCode,
    SUM(quantityOrdered) AS totalQuantity,
    SUM(quantityOrdered * priceEach) AS totalRevenue,
    SUM(quantityOrdered * priceEach) / SUM(quantityOrdered) AS avg_price_sold
FROM 
    temp_success_orders
GROUP BY 
    productCode
ORDER BY 
    totalRevenue DESC;

SELECT*
FROM product_sold_summary;

-- Creates a comprehensive summary table of product sales including profit and price metrics
CREATE TABLE product_sold_summary_total AS
SELECT 
    ps.productCode, 
    ps.totalRevenue, 
    ps.avg_per_sold, 
    p.buyPrice, 
    p.MSRP,
    ROUND((ps.avg_per_sold - p.buyPrice) * ps.totalQuantity, 2) AS total_profit,
    ROUND((ps.avg_per_sold / p.MSRP * 100), 2) AS perc_of_MSRP
FROM 
    product_sold_summary ps
LEFT JOIN 
    products p ON ps.productCode = p.productCode;

SELECT*
FROM product_sold_summary_2;



-- Identifies products with low total revenue and low percentage of MSRP
WITH ranking_table AS (
    SELECT 
        productCode,
        buyPrice,
        MSRP,
        totalRevenue, 
        perc_of_MSRP,
        ROW_NUMBER() OVER (ORDER BY totalRevenue DESC) AS totalRevenue_rank,
        ROW_NUMBER() OVER (ORDER BY perc_of_MSRP DESC) AS closest_to_MSRP
    FROM 
        product_sold_summary_total
)
SELECT 
    productCode, 
    buyPrice, 
    MSRP,
    totalRevenue, 
    perc_of_MSRP, 
    totalRevenue_rank, 
    closest_to_MSRP
FROM 
    ranking_table
WHERE 
    totalRevenue_rank > 80 
    AND closest_to_MSRP > 80;

-- Identifies top-performing products based on both total revenue and percentage of MSRP
WITH ranking_table AS (
    SELECT 
        productCode,
        buyPrice,
        MSRP,
        totalRevenue, 
        perc_of_MSRP,
        ROW_NUMBER() OVER (ORDER BY totalRevenue DESC) AS totalRevenue_rank,
        ROW_NUMBER() OVER (ORDER BY perc_of_MSRP DESC) AS closest_to_MSRP
    FROM 
        product_sold_summary_2
)
SELECT 
    productCode, 
    buyPrice, 
    MSRP,
    totalRevenue, 
    perc_of_MSRP, 
    totalRevenue_rank, 
    closest_to_MSRP
FROM 
    ranking_table
WHERE 
    totalRevenue_rank < 12 
    AND closest_to_MSRP < 12;

-- Creates a table ranking products based on profit, revenue, and MSRP percentage
CREATE TABLE product_ranking AS
WITH ranking_table AS (
    SELECT 
        productCode,
        buyPrice,
        avg_per_sold,
        MSRP,
        totalRevenue, 
        total_profit,
        perc_of_MSRP,
        ROW_NUMBER() OVER (ORDER BY total_profit DESC) AS totalProfit_rank,
        ROW_NUMBER() OVER (ORDER BY totalRevenue DESC) AS totalRevenue_rank,
        ROW_NUMBER() OVER (ORDER BY perc_of_MSRP DESC) AS closest_to_MSRP
    FROM 
        product_sold_summary_total
)
SELECT 
    productCode, 
    buyPrice, 
    avg_per_sold, 
    MSRP, 
    total_profit,
    totalRevenue, 
    perc_of_MSRP, 
    totalProfit_rank,
    totalRevenue_rank, 
    closest_to_MSRP
FROM 
    ranking_table;
    
-- Create Temporary Table to Join Product Rankings and Product Information
CREATE TEMPORARY TABLE top_productLine AS
SELECT 
  product_ranking.*,
  products.productLine
FROM 
  product_ranking
  LEFT JOIN products ON product_ranking.productCode = products.productCode;
  
-- Get products with total profit and revenue ranks < 10
SELECT 
  productCode, 
  productLine
FROM 
  top_productLine
WHERE 
  totalprofit_rank < 10 
  AND totalRevenue_rank < 10;


-- Get products with total profit and revenue ranks > 95
SELECT 
  productCode, 
  productLine
FROM 
  top_productLine
WHERE 
  totalprofit_rank > 100 
  AND totalRevenue_rank > 100;
  
  

-- Calculates total profit and count by product line, joining product sold summary with product details.
WITH product_Line AS (
  SELECT 
    psst.* ,
    p.productLine
  FROM 
    product_sold_summary_total psst
  LEFT JOIN 
    products p
  ON 
    psst.productCode = p.productCode
)
SELECT 
  productLine, 
  SUM(total_profit) AS total_profit_by_product_line,
  COUNT(total_profit) AS total_count_by_product_line
FROM 
  product_Line
GROUP BY 
  productLine;

-- Counts the number of products stored in each warehouse
SELECT 
    warehouseCode,
    COUNT(warehouseCode) AS product_count
FROM 
    products
GROUP BY 
    warehouseCode;

-- Counts the number of customers in each country
SELECT 
    country,
    COUNT(country) AS customer_count
FROM 
    customers
GROUP BY 
    country
ORDER BY 
    customer_count DESC;

-- Counts the number of offices in each country
SELECT 
    country,
    COUNT(country) AS office_count
FROM 
    offices
GROUP BY 
    country
ORDER BY 
    office_count DESC;
    

-- Create a temporary table to store order and customer information
CREATE TEMPORARY TABLE order_customer_summary AS
SELECT 
  od.orderNumber,
  od.productCode,
  o.customerNumber,
  c.country
FROM 
  orderdetails od
  LEFT JOIN orders o ON od.orderNumber = o.orderNumber
  LEFT JOIN customers c ON o.customerNumber = c.customerNumber;

-- Create a table to store product sales by country
CREATE TABLE product_country_sale AS
SELECT 
  productCode,
  country,
  COUNT(*) AS sale_count
FROM 
  order_customer_summary
GROUP BY 
  productCode, country
ORDER BY 
  sale_count DESC, productCode, country;

SELECT*
FROM product_country_sale;

SELECT count(DISTINCT country)
FROM product_country_sale;


-- Identify products with no transactions (i.e., no orders)
WITH product_no_transaction AS (
  SELECT 
    p.productCode, 
    COUNT(od.productCode) AS product_count
  FROM 
    products p
  LEFT JOIN 
    orderdetails od ON p.productCode = od.productCode
  GROUP BY 
    p.productCode
)

-- Select products with no orders
SELECT 
  productCode
FROM 
  product_no_transaction
WHERE 
  product_count = 0;



-- First, let's create a temporary table with all distinct countries
-- Create a temporary table with all unique countries
CREATE TEMPORARY TABLE all_countries AS
SELECT DISTINCT country FROM order_customer_summary;

-- Count the number of unique countries
SELECT count(distinct country)
FROM all_countries;

-- Create a temporary table with all possible product-country combinations
CREATE TEMPORARY TABLE temp_product_country AS (
  SELECT p.productCode, c.country
  FROM all_countries c
  CROSS JOIN products p
);

-- View all product-country combinations
SELECT *
FROM temp_product_country;

-- View product sales by country
SELECT *
FROM product_country_sale;

-- Create a table with product sales counts, filling in 0 for missing values
CREATE TABLE product_country_count AS
SELECT 
  temp_product_country.productCode,
  temp_product_country.country,
  COALESCE(product_country_sale.`count`, 0) AS count
FROM 
  temp_product_country
  LEFT JOIN product_country_sale
    ON temp_product_country.productCode = product_country_sale.productCode 
    AND temp_product_country.country = product_country_sale.country;

-- Find products with no sales in any country
SELECT productCode, COUNT(productCode)
FROM product_country_count
WHERE `count` = 0
GROUP BY productCode;

-- Find orders for a specific product
SELECT orderNumber
FROM orderdetails
WHERE productCode = 'S18_3233';

-- View all warehouse information
SELECT *
FROM warehouses;


-- Calculate total stock and capacity till 80% for each warehouse
WITH ware_house_quantity AS (
  SELECT 
    warehouseCode, 
    SUM(quantityInStock) AS total_stock
  FROM 
    products
  GROUP BY 
    warehouseCode
)
SELECT 
  ware_house_quantity.warehouseCode, 
  ware_house_quantity.total_stock, 
  warehouses.warehousePctCap,
  ROUND((ware_house_quantity.total_stock / warehouses.warehousePctCap) * (80 - warehouses.warehousePctCap), 2) AS capacity_till_80
FROM 
  ware_house_quantity
  LEFT JOIN warehouses
    ON warehouses.warehouseCode = ware_house_quantity.warehouseCode;

-- View all products
SELECT *
FROM products;

-- Count products in warehouse D
SELECT count(*)
FROM products
WHERE warehouseCode = 'd';

-- Combine ranking with each item in warehouse D
WITH warehouse_d_prod AS (
  SELECT 
    productCode, 
    quantityInStock
  FROM 
    products
  WHERE 
    warehouseCode = 'd'
)
SELECT 
  warehouse_d_prod.productCode, 
  warehouse_d_prod.quantityInStock,
  pr.totalRevenue_rank, 
  pr.closest_to_MSRP, 
  pr.totalProfit_rank
FROM 
  warehouse_d_prod
  LEFT JOIN product_ranking pr
    ON warehouse_d_prod.productCode = pr.productCode;




-- Identify destinations for warehouse D shipments
CREATE TABLE destination_warehouse_D AS
WITH warehouse_d_client AS (
  WITH warehouse_d AS (
    SELECT orderNumber, productCode
    FROM orderdetails
    WHERE productCode IN ('S24_2300', 'S12_4473', 'S18_1097', 'S12_1666', 'S18_2319', 'S50_1392', 'S700_2047', 'S700_3505', 'S18_2432')
  )
  SELECT warehouse_d.orderNumber, warehouse_d.productCode, orders.customerNumber
  FROM warehouse_d
  LEFT JOIN orders
    ON warehouse_d.orderNumber = orders.orderNumber
)
SELECT warehouse_d_client.orderNumber, warehouse_d_client.productCode, warehouse_d_client.customerNumber, customers.state, customers.country
FROM warehouse_d_client
LEFT JOIN customers
  ON warehouse_d_client.customerNumber = customers.customerNumber;

-- Determine the most frequent destinations for warehouse D shipments
WITH country_count_total AS (
  SELECT
    ROW_NUMBER() OVER (ORDER BY count(country) DESC) AS row_num,
    country,
    state,
    count(country) AS country_count
  FROM
    destination_warehouse_D
  GROUP BY
    country,
    state
)
SELECT
  *,
  SUM(country_count) OVER (ORDER BY row_num) AS rolling_count
FROM
  country_count_total
ORDER BY
  country_count DESC;