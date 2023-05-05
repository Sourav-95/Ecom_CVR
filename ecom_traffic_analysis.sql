USE mavenfuzzyfactory;

-- Tables of the schemas
SHOW TABLES;

/* 1. Gsearch seems to be the biggest driver of our business. 
Can you pull monthly trends for gsearch sessions and orders so that we can showcase the growth there?
The project mail is sent on 2012-11-27, hence we will extract the data before this date
*/

-- Top Traffic Source
SELECT
	utm_source,
    utm_campaign,
    http_referer,
    COUNT(DISTINCT website_session_id) AS sessions
FROM website_sessions
WHERE created_at < '2012-11-27'
GROUP BY 
	utm_source,
    utm_campaign,
    http_referer
ORDER BY sessions DESC;

-- Trend of session to order over the 8 months
SELECT
	YEAR(website_sessions.created_at) AS Yr,
    MONTH(website_sessions.created_at) AS Months,
	COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT orders.order_id) AS orders,
    COUNT(DISTINCT orders.order_id)/COUNT(DISTINCT website_sessions.website_session_id) AS conv_rate
FROM website_sessions
LEFT JOIN orders
	ON orders.website_session_id = website_sessions.website_session_id
WHERE website_sessions.created_at < '2012-11-27'
	AND website_sessions.utm_source = 'gsearch'
GROUP BY 1,2;

/* 2. Next it would be great to see a similar monthly trend for Gsearch, 
but this time splitting out nonbrand and brand campaigns separately. 
I am wondering if brand is picking up at all. If so, this is a good story to tell.
*/

SELECT
	YEAR(website_sessions.created_at) AS Yr,
    MONTH(website_sessions.created_at) AS Months,
    COUNT(DISTINCT CASE WHEN utm_campaign = 'nonbrand' THEN website_sessions.website_session_id ELSE NULL END) AS nonbrand_sessions,
    COUNT(DISTINCT CASE WHEN utm_campaign = 'nonbrand' THEN orders.order_id ELSE NULL END) AS nonbrand_orders,
    COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' THEN website_sessions.website_session_id ELSE NULL END) AS brand_sessions,
    COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' THEN orders.order_id ELSE NULL END) AS brand_orders
FROM website_sessions
LEFT JOIN orders
	ON orders.website_session_id = website_sessions.website_session_id
WHERE website_sessions.created_at < '2012-11-27'
	AND website_sessions.utm_source = 'gsearch'
GROUP BY 1,2;

/* 3. While we are on Gsearch, could you dive into nonbrand, and pull monthly sessions and orders split by device type? 
I want to flex our analytical muscles a little and show the board we really know our traffic sources.
*/
SELECT
	YEAR(website_sessions.created_at) AS Yr,
    MONTH(website_sessions.created_at) AS Months,
    COUNT(DISTINCT CASE WHEN device_type = 'desktop' THEN website_sessions.website_session_id ELSE NULL END) AS desktop_sessions,
    COUNT(DISTINCT CASE WHEN device_type = 'desktop' THEN orders.order_id ELSE NULL END) AS desktop_orders,
    COUNT(DISTINCT CASE WHEN device_type = 'mobile' THEN website_sessions.website_session_id ELSE NULL END) AS mobile_sessions,
    COUNT(DISTINCT CASE WHEN device_type = 'mobile' THEN orders.order_id ELSE NULL END) AS mobile_orders
FROM website_sessions
LEFT JOIN orders
	ON orders.website_session_id = website_sessions.website_session_id
WHERE website_sessions.created_at < '2012-11-27'
	AND website_sessions.utm_source = 'gsearch'
    AND website_sessions.utm_campaign = 'nonbrand'
GROUP BY 1,2;

/* 4. Pessimistic board member may be concerned about the large % of traffic from Gsearch. 
Pulling the monthly trend for Gsearch along side monthly trends for each of our channels?
*/

-- Finding various utm_sources and http referrer
SELECT DISTINCT
	utm_source,
    utm_campaign,
    http_referer
FROM website_sessions
WHERE created_at < '2012-11-27';

-- Monthly trend of all the traffic channels
SELECT
	YEAR(website_sessions.created_at) AS Yr,
    MONTH(website_sessions.created_at) AS Months,
    COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' THEN website_sessions.website_session_id ELSE NULL END) AS gsearch_sessions,
    COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' THEN website_sessions.website_session_id ELSE NULL END) AS bsearch_sessions,
    COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NULL THEN website_sessions.website_session_id ELSE NULL END) AS direct_sessions,
    COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NOT NULL THEN website_sessions.website_session_id ELSE NULL END) AS organic_sessions
FROM website_sessions
LEFT JOIN orders
	ON orders.website_session_id = website_sessions.website_session_id
WHERE website_sessions.created_at < '2012-11-27'
GROUP BY 1,2;

/* 5. For Gsearch lander test estimate the revenue that earned us. (Look at increase in CVR from the test (Jun 19- Jul 28) 
and use nonbrand sessions and revenue since then to calculate the incremental value)
*/

-- First we will look into the minimum test id when the test started?
SELECT
	MIN(website_pageview_id)
FROM website_pageviews
WHERE pageview_url = '/lander-1';

-- The minimum page view id is 23504
-- We will use this minimum page view id to limit our next query untill the test was running where we will link the sessions with minimum pageview_id giving the first pageview as result

CREATE TEMPORARY TABLE first_pageviews
SELECT
	website_pageviews.website_session_id AS sessions,
    MIN(website_pageviews.website_pageview_id) AS min_pv_id
FROM website_pageviews
INNER JOIN website_sessions
	ON website_sessions.website_session_id = website_pageviews.website_session_id
WHERE website_sessions.created_at < '2012-07-28'
	AND website_pageviews.website_pageview_id >= 23504
    AND website_sessions.utm_source = 'gsearch'
    AND website_sessions.utm_campaign = 'nonbrand'
GROUP BY 1;

-- Each of the sessions are linked with the first pageview_id
-- Now we will link to the landing page. 
-- So we will join this table with website_pageviews to link the pageview_url

CREATE TEMPORARY TABLE nonbrand_test_w_landing_page
SELECT 
 first_pageviews.sessions,
 website_pageviews.pageview_url AS landing_page
FROM first_pageviews
LEFT JOIN website_pageviews
	ON website_pageviews.website_pageview_id = first_pageviews.min_pv_id
WHERE website_pageviews.pageview_url IN ('/home', '/lander-1');

-- So untill now we have fetched the sessions with landing pages by using the minimum pageview_id as key parameter.
-- Now we will link with the orders. which landing pages have orders. This will help us to determine the Conversion rate
-- So we will link the above temporary table with order table

CREATE TEMPORARY TABLE nonbrand_sessions_w_orders
SELECT 
	nonbrand_test_w_landing_page.sessions,
    nonbrand_test_w_landing_page.landing_page,
    orders.order_id
FROM nonbrand_test_w_landing_page
LEFT JOIN orders
	ON orders.website_session_id = nonbrand_test_w_landing_page.sessions;
    
-- Now we will make a table to count the sessions and orders
-- OUTPUT
SELECT 
	landing_page,
    COUNT(DISTINCT sessions) AS count_of_sessions,
    COUNT(DISTINCT order_id) AS count_of_orders,
    COUNT(DISTINCT order_id)/COUNT(DISTINCT sessions) AS cvr
FROM nonbrand_sessions_w_orders
GROUP BY 1;
-- There is an increase in conversion_rate by 0.0088 per sessions by lander-1 from /home
-- Now we will check the most recent pageviews for gsearch nonbrand traffic sent to home

SELECT 
	MAX(website_sessions.website_session_id) AS most_recent_gsearch_nonbrand_home_pageview
FROM website_sessions
LEFT JOIN website_pageviews
	ON website_pageviews.website_session_id = website_sessions.website_session_id
WHERE utm_source='gsearch'
	AND utm_campaign = 'nonbrand'
    AND pageview_url = '/home'
    AND website_sessions.created_at < '2012-11-27';
    
-- Session_id : 17145 id the maximum when gsearch nonbrand traffic is going to home page
-- Then the traffic was routed to another home page '/lander-1'
-- We can count the no.of session after the test was initiated

SELECT 
	COUNT(website_sessions.website_session_id) AS sessions
FROM website_sessions
WHERE created_at < '2012-11-27'
	AND website_session_id > 17145
    AND utm_source = 'gsearch'
    AND utm_campaign = 'nonbrand'
;
-- There were 22972 sessions which were re routed to another landing page

/* 6. For the landing page test page analyzed previously it would be great to show a full conversion funnel from each of the tow pages to orders.
We can use the same time_period that we analyzed lastly (Jun 19 - Jul 28)
*/

CREATE TEMPORARY TABLE session_label_madeitflag
SELECT 
	website_session_id, 
    MAX(home_page) AS saw_home_page,
    MAX(lander_page) AS saw_lander_page,
    MAX(product_page) AS product_madeit,
    MAX(mr_fuzzy_page) AS fuzzy_madeit,
    MAX(cart_page) AS cart_madeit,
    MAX(shipping_page) AS shipping_madeit,
    MAX(billing_page) AS billing_madeit,
    MAX(thankyou_page) AS thankyou_madeit
FROM(
SELECT
	website_sessions.website_session_id,
    website_pageviews.pageview_url,
    -- website_pageviews.created_at AS pageview_created_at,																
    CASE WHEN pageview_url = '/home' THEN 1 ELSE 0 END AS home_page,
    CASE WHEN pageview_url = '/lander-1' THEN 1 ELSE 0 END AS lander_page,
    CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END AS product_page,
    CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mr_fuzzy_page,
    CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
    CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
    CASE WHEN pageview_url = '/billing' THEN 1 ELSE 0 END AS billing_page,
    CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page
FROM website_sessions
LEFT JOIN website_pageviews
	ON website_sessions.website_session_id = website_pageviews.website_session_id
WHERE website_sessions.created_at BETWEEN '2012-06-19' AND '2012-07-28'													
	AND website_sessions.utm_source = 'gsearch'
    AND website_sessions.utm_campaign = 'nonbrand'
ORDER BY 
	website_sessions.website_session_id,
    pageview_url
    ) AS pageview_level
GROUP BY website_session_id;

-- SELECT * FROM session_label_madeitflag;
-- SEGMENT OF HOME PAGE & LANDER-1 PAGE CONVERSION
SELECT 
	CASE
		WHEN saw_home_page = 1 THEN 'saw_homepage'
        WHEN saw_lander_page = 1 THEN 'saw_landerpage'
        ELSE 'check logic'
	END AS segment,
	COUNT(DISTINCT CASE WHEN product_madeit = 1 THEN website_session_id ELSE NULL END) AS to_products,
    COUNT(DISTINCT CASE WHEN fuzzy_madeit = 1 THEN website_session_id ELSE NULL END) AS to_fuzzy,
    COUNT(DISTINCT CASE WHEN cart_madeit = 1 THEN website_session_id ELSE NULL END) AS to_carts,
    COUNT(DISTINCT CASE WHEN shipping_madeit = 1 THEN website_session_id ELSE NULL END) AS to_shipping,
    COUNT(DISTINCT CASE WHEN billing_madeit = 1 THEN website_session_id ELSE NULL END) AS to_bill,
    COUNT(DISTINCT CASE WHEN thankyou_madeit = 1 THEN website_session_id ELSE NULL END) AS to_thankyou
FROM session_label_madeitflag
GROUP BY 1;

-- FINAL OUTPUT CONVERSION FUNNEL WITH CVR
SELECT 
	CASE
		WHEN saw_home_page = 1 THEN 'saw_homepage'
        WHEN saw_lander_page = 1 THEN 'saw_landerpage'
        ELSE 'check logic'
	END AS segment,
	COUNT(DISTINCT CASE WHEN product_madeit = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT website_session_id) AS lander_clickrate,
    COUNT(DISTINCT CASE WHEN fuzzy_madeit = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN product_madeit = 1 THEN website_session_id ELSE NULL END) AS product_clickrate,
    COUNT(DISTINCT CASE WHEN cart_madeit = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN fuzzy_madeit = 1 THEN website_session_id ELSE NULL END) AS fuzzy_clickrate,
    COUNT(DISTINCT CASE WHEN shipping_madeit = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN cart_madeit = 1 THEN website_session_id ELSE NULL END) AS cart_clickrate,
    COUNT(DISTINCT CASE WHEN billing_madeit = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN shipping_madeit = 1 THEN website_session_id ELSE NULL END) AS shipping_clickrate,
    COUNT(DISTINCT CASE WHEN thankyou_madeit = 1 THEN website_session_id ELSE NULL END)/COUNT(DISTINCT CASE WHEN billing_madeit = 1 THEN website_session_id ELSE NULL END) AS billing_clickrate
FROM session_label_madeitflag
GROUP BY 1;

/* 7. Quantify the impact of our Billing test. Analyze the lift generated from the test in terms of revenue per billing page sessions 
(Sep 10- Nov 10) and pulling the no of billilng page sessions from the past month to understand the monthly impact
*/

-- CALCULATING THE LIFT
-- $ 22.82 revenue per billing page seen for old version
-- $ 31.34 revenue for the new version
-- LIFT : $8.51 per billing pageview

SELECT
	billing_version,
	COUNT(DISTINCT website_session_id) AS sessions,
    SUM(price_usd)/COUNT(DISTINCT website_session_id) AS revenue_per_billing_seen
FROM(
SELECT
	website_pageviews.website_session_id,
    website_pageviews.pageview_url AS billing_version,
    orders.order_id,
    orders.price_usd
FROM website_pageviews
LEFT JOIN orders
	ON orders.website_session_id = website_pageviews.website_session_id
WHERE website_pageviews.created_at > '2012-09-10'
	AND website_pageviews.created_at < '2012-11-10'
    AND website_pageviews.pageview_url IN ('/billing', '/billing-2')
    ) AS billing_pageview_and_order_data
GROUP BY 1
;

-- COUNTING THE SESSION OF LAST MONTH THEN MULTIPLYING BY THE LIFT
SELECT
	COUNT(website_session_id) AS billing_session_past_month
FROM website_pageviews
WHERE pageview_url IN ('/billing', '/billing-2')
	AND created_at BETWEEN '2012-10-27' AND '2012-11-27'
;

-- 1193 billing sessions past month
-- LIFT : $8.51 per billing pageview
-- VALUE OF BILLING TEST: $10,152















