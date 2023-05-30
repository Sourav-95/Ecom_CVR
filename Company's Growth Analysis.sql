USE mavenfuzzyfactory;
-- 1. VOLUME GROWTH TRENDED BY QUATERs
SELECT
	YEAR(website_sessions.created_at) AS yr,
    QUARTER(website_sessions.created_at) AS quater,
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT orders.order_id) AS orders
FROM website_sessions
LEFT JOIN orders
	ON website_sessions.website_session_id = orders.website_session_id
GROUP BY 1,2
ORDER BY 1,2
;
/* 2. Showcase of company’s efficient improvement. 
Quarterly figures for ‘session-to-order conversion rate’, ‘revenue per order’, ‘revenue per session’.
*/
SELECT
	YEAR(website_sessions.created_at) AS yr,
    QUARTER(website_sessions.created_at) AS quater,
    COUNT(DISTINCT orders.order_id)/COUNT(DISTINCT website_sessions.website_session_id) AS sessions_to_order_conv_rate,
    SUM(orders.price_usd)/COUNT(DISTINCT orders.order_id) AS revenue_per_order,
    SUM(orders.price_usd)/COUNT(DISTINCT website_sessions.website_session_id) AS revenue_per_session
FROM website_sessions
LEFT JOIN orders
	ON website_sessions.website_session_id = orders.website_session_id
GROUP BY 1,2
ORDER BY 1,2
;

/* 3. Quarterly view of orders from 
Gsearch nonbrand, Bsearch non brand, brand search overall, organic search & direct type in
*/
-- Step 1: checking the distinct names of the channels
/* SELECT DISTINCT 
	utm_source,
    utm_campaign,
    http_referer
FROM website_sessions;
*/
-- Step 2: Analyzing the channels growth
SELECT
	YEAR(website_sessions.created_at) AS yr,
    QUARTER(website_sessions.created_at) AS quater,
    COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' AND utm_campaign = 'nonbrand' THEN orders.order_id ELSE NULL END) AS gsearch_nonbrand_orders,
    COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' AND utm_campaign = 'nonbrand' THEN orders.order_id ELSE NULL END) AS bsearch_nonbrand_orders,
    COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' THEN orders.order_id ELSE NULL END) AS brand_orders,
    COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NOT NULL THEN orders.order_id ELSE NULL END) AS organic_search_orders,
    COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NULL THEN orders.order_id ELSE NULL END) AS direct_type_in_orders
FROM website_sessions
LEFT JOIN orders
	ON website_sessions.website_session_id = orders.website_session_id
GROUP BY 1,2
ORDER BY 1,2
;

/*4. CONVERSION RATE TREND QUARTERLY BY CHANNELS*/

SELECT
	YEAR(website_sessions.created_at) AS yr,
    QUARTER(website_sessions.created_at) AS quater,
    COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' AND utm_campaign = 'nonbrand' THEN orders.order_id ELSE NULL END)/
		COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' AND utm_campaign = 'nonbrand' THEN website_sessions.website_session_id ELSE NULL END) AS gsearch_nonbrand_cvr,
    COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' AND utm_campaign = 'nonbrand' THEN orders.order_id ELSE NULL END)/
		COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' AND utm_campaign = 'nonbrand' THEN website_sessions.website_session_id ELSE NULL END) AS bsearch_nonbrand_cvr, 
	COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' THEN orders.order_id ELSE NULL END)/
		COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' THEN website_sessions.website_session_id ELSE NULL END) AS brand_cvr,
	COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NOT NULL THEN orders.order_id ELSE NULL END)/
		COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NOT NULL THEN website_sessions.website_session_id ELSE NULL END) AS organic_cvr,
	COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NULL THEN orders.order_id ELSE NULL END)/
		COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NULL THEN website_sessions.website_session_id ELSE NULL END) AS direct_type_in_cvr
FROM website_sessions
LEFT JOIN orders
	ON website_sessions.website_session_id = orders.website_session_id
GROUP BY 1,2
ORDER BY 1,2
;

/* 5. MONTHLY TREND FOR REVENUE AND MARGIN BY PRODUCTS
*/
-- checking the distinct products
SELECT DISTINCT 
	product_id
FROM order_items;

-- there are 4 categories of product (1,2,3,4)
SELECT * FROM products;

SELECT
	YEAR(created_at) AS yr,
    MONTH(created_at) AS months,
    SUM(CASE WHEN product_id = 1 THEN price_usd ELSE NULL END) AS fuzzy_rev,
    SUM(CASE WHEN product_id = 1 THEN price_usd-cogs_usd ELSE NULL END) AS fuzzy_marg,
    SUM(CASE WHEN product_id = 2 THEN price_usd ELSE NULL END) AS bear_rev,
    SUM(CASE WHEN product_id = 2 THEN price_usd-cogs_usd ELSE NULL END) AS bear_marg,
    SUM(CASE WHEN product_id = 3 THEN price_usd ELSE NULL END) AS panda_rev,
    SUM(CASE WHEN product_id = 3 THEN price_usd-cogs_usd ELSE NULL END) AS panda_marg,
    SUM(CASE WHEN product_id = 4 THEN price_usd ELSE NULL END) AS minibear_rev,
    SUM(CASE WHEN product_id = 4 THEN price_usd-cogs_usd ELSE NULL END) AS minibear_marg,
    SUM(price_usd) AS total_rev,
    SUM(price_usd-cogs_usd) AS total_margin
FROM order_items
GROUP BY 1,2
ORDER BY 1,2
;

/* 6. IMPACT OF INTRODUCING NEW PRODUCT
*/
-- Step 1:we are going to identify the vews of the /product page

CREATE TEMPORARY TABLE product_pageview
SELECT
	website_session_id,
    website_pageview_id,
    created_at AS product_seen_at
FROM website_pageviews
WHERE pageview_url = '/products'
ORDER BY 1
;
-- Now we are going to join this temporary table to the table 'website_pageview' when the pageview_id > temp table pageview_id,this will give the next page data

SELECT
	YEAR(product_seen_at) AS yr,
    MONTH(product_seen_at) AS months,
    COUNT(DISTINCT product_pageview.website_session_id) AS sessions_to_product,
    COUNT(DISTINCT website_pageviews.website_session_id) AS clicked_to_next_page,
    COUNT(DISTINCT website_pageviews.website_session_id)/COUNT(DISTINCT product_pageview.website_session_id) AS click_through_rate,
    COUNT(DISTINCT orders.order_id) AS orders,
    COUNT(DISTINCT orders.order_id)/COUNT(DISTINCT product_pageview.website_session_id) AS product_to_order_rate
FROM product_pageview
LEFT JOIN website_pageviews
	ON website_pageviews.website_session_id = product_pageview.website_session_id      -- same session
    AND website_pageviews.website_pageview_id > product_pageview.website_pageview_id   -- had another page after the product page
LEFT JOIN orders
	ON orders.website_session_id = product_pageview.website_session_id
GROUP BY 1,2
ORDER BY 1,2
;

/* 7. PERFORMANCE OF ALL PRODUCT AFTER 4TH PRODUCT WAS MADE AVAILABLE AS PRIMARY PRODUCT */

-- Step 1: table of primary products
CREATE TEMPORARY TABLE primary_product
SELECT
	order_id,
    primary_product_id,
    created_at AS order_at
FROM orders
WHERE created_at > '2014-12-05'    -- when the 4th product was added
;

-- Step 2: bringing the cross sell product_id (temp table 1 = order_items)
SELECT
	primary_product_id,
    COUNT(DISTINCT order_id) AS orders,
    COUNT(DISTINCT CASE WHEN cross_sell_product_id = 1 THEN order_id ELSE NULL END) AS xsell_p1,
    COUNT(DISTINCT CASE WHEN cross_sell_product_id = 2 THEN order_id ELSE NULL END) AS xsell_p2,
    COUNT(DISTINCT CASE WHEN cross_sell_product_id = 3 THEN order_id ELSE NULL END) AS xsell_p3,
    COUNT(DISTINCT CASE WHEN cross_sell_product_id = 4 THEN order_id ELSE NULL END) AS xsell_p4,
    COUNT(DISTINCT CASE WHEN cross_sell_product_id = 1 THEN order_id ELSE NULL END)/COUNT(DISTINCT order_id) AS p1_xsell_rt,
    COUNT(DISTINCT CASE WHEN cross_sell_product_id = 2 THEN order_id ELSE NULL END)/COUNT(DISTINCT order_id) AS p2_xsell_rt,
    COUNT(DISTINCT CASE WHEN cross_sell_product_id = 3 THEN order_id ELSE NULL END)/COUNT(DISTINCT order_id) AS p3_xsell_rt,
    COUNT(DISTINCT CASE WHEN cross_sell_product_id = 4 THEN order_id ELSE NULL END)/COUNT(DISTINCT order_id) AS p4_xsell_rt
FROM(
SELECT
	primary_product.*,
    order_items.product_id AS cross_sell_product_id
FROM primary_product
LEFT JOIN order_items
	ON order_items.order_id = primary_product.order_id
    AND order_items.is_primary_item = 0                   -- only bringing the cross sell product
 ) AS primary_crossell
 GROUP BY 1
;