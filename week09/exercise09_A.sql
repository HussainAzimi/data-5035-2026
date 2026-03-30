---  Scenario A: Retail Orders & Customers.

--- Q1: Show all purchases with the customer who made them (customer name | order_id  | amount).
--- Join type: INNER JOIN
--- Assumptions: Every order has a valid CUSTOMER_ID in CUSTOMERS. unmatched rows are excluded.
SELECT customers.name, orders.order_id, orders.amount
FROM EXERCISE9.PUBLIC.CUSTOMERS as customers
JOIN EXERCISE9.PUBLIC.ORDERS as orders
ON customers.customer_id =  orders.customer_id;

--- Q2: Show all customers and any orders they may have placed. (customer name | order_id).
--- Join type: RIGHT JOIN.
--- Assumptions: All customers should appear even if they have no orders; ORDER_ID will be NULL for customers without orders.
SELECT orders.order_id, customers.name
FROM EXERCISE9.PUBLIC.ORDERS AS orders
RIGHT JOIN EXERCISE9.PUBLIC.CUSTOMERS AS customers
ON orders.customer_id = customers.customer_Id;

--- Q3: Identify whether each order was returned (order_id | is_returned).
--- Join type: LEFT JOIN.
--- Assumptions: All orders are included. If order was returned (TRUE), otherwise FALSE.
SELECT orders.order_id,
       CASE WHEN returns.order_id IS NOT NULL THEN TRUE ELSE FALSE END AS IS_RETURNED
FROM EXERCISE9.PUBLIC.ORDERS AS orders
LEFT JOIN EXERCISE9.PUBLIC.RETURNS as returns ON orders.order_id = returns.order_id;

--- Q4: Show only orders that were returned and who made them.
--- Join type: INNER JOIN.
--- Assumptions: Every return has a valid ORDER_ID, every order has a valid CUSTOMER_ID, only returned orders appear.
SELECT customers.name, orders.order_id, returns.return_date
FROM EXERCISE9.PUBLIC.RETURNS As returns
JOIN EXERCISE9.PUBLIC.ORDERS as orders ON returns.order_id  = orders.order_id = orders.order_id
JOIN EXERCISE9.PUBLIC.CUSTOMERS customers ON orders.customer_id = customers.customer_id;

--- Q5: Find customers who never made a purchase.
--- Join type: LEFT JOIN + WHERE IS NULL (Anti-join pattern).
--- Assumptions: A NULL ORDER_ID after the LEFT JOIN means the customer has no orders at all.
SELECT customers.name
FROM EXERCISE9.PUBLIC.CUSTOMERS AS customers
LEFT JOIN EXERCISE9.PUBLIC.ORDERS AS orders ON customers.customer_id = orders.customer_id
WHERE orders.order_id IS NULL;
