// ===== FPT Shop Graph Model — load script =====

// ---- Constraints (uniqueness + implicit index) ----
CREATE CONSTRAINT user_id      IF NOT EXISTS FOR (u:User)      REQUIRE u.user_id      IS UNIQUE;
CREATE CONSTRAINT product_id   IF NOT EXISTS FOR (p:Product)   REQUIRE p.product_id   IS UNIQUE;
CREATE CONSTRAINT brand_id     IF NOT EXISTS FOR (b:Brand)     REQUIRE b.brand_id     IS UNIQUE;
CREATE CONSTRAINT category_id  IF NOT EXISTS FOR (c:Category)  REQUIRE c.category_id  IS UNIQUE;
CREATE CONSTRAINT variant_id   IF NOT EXISTS FOR (v:Variant)   REQUIRE v.variant_id   IS UNIQUE;
CREATE CONSTRAINT promotion_id IF NOT EXISTS FOR (pr:Promotion) REQUIRE pr.promotion_id IS UNIQUE;

// ---- Nodes ----
LOAD CSV WITH HEADERS FROM 'file:///users.csv' AS row
MERGE (u:User {user_id: row.user_id})
SET u.name = row.name, u.age = toInteger(row.age), u.location = row.location;

LOAD CSV WITH HEADERS FROM 'file:///products.csv' AS row
MERGE (p:Product {product_id: row.product_id})
SET p.product_name = row.product_name,
    p.price  = toInteger(row.price),
    p.rating = toFloat(row.rating),
    p.url    = row.url;

LOAD CSV WITH HEADERS FROM 'file:///brands.csv' AS row
MERGE (b:Brand {brand_id: row.brand_id})
SET b.brand_name = row.brand_name;

LOAD CSV WITH HEADERS FROM 'file:///categories.csv' AS row
MERGE (c:Category {category_id: row.category_id})
SET c.category_name = row.category_name;

LOAD CSV WITH HEADERS FROM 'file:///variants.csv' AS row
MERGE (v:Variant {variant_id: row.variant_id})
SET v.label = row.label;

LOAD CSV WITH HEADERS FROM 'file:///promotions.csv' AS row
MERGE (pr:Promotion {promotion_id: row.promotion_id})
SET pr.title = row.title, pr.discount = row.discount,
    pr.description = row.description, pr.expiry = row.expiry, pr.url = row.url;

// ---- Relationships ----
// User -PURCHASED-> Product
LOAD CSV WITH HEADERS FROM 'file:///purchased.csv' AS row
MATCH (u:User {user_id: row.user_id})
MATCH (p:Product {product_id: row.product_id})
MERGE (u)-[r:PURCHASED {purchase_date: row.purchase_date}]->(p)
SET r.rating = toInteger(row.rating);

// User -FRIENDS_WITH- User (undirected friendship; store one direction)
LOAD CSV WITH HEADERS FROM 'file:///friends_with.csv' AS row
MATCH (a:User {user_id: row.user_id_1})
MATCH (b:User {user_id: row.user_id_2})
MERGE (a)-[:FRIENDS_WITH]->(b);

// Product -HAS_BRAND-> Brand
LOAD CSV WITH HEADERS FROM 'file:///product_brand.csv' AS row
MATCH (p:Product {product_id: row.product_id})
MATCH (b:Brand {brand_id: row.brand_id})
MERGE (p)-[:HAS_BRAND]->(b);

// Product -IN_CATEGORY-> Category
LOAD CSV WITH HEADERS FROM 'file:///product_category.csv' AS row
MATCH (p:Product {product_id: row.product_id})
MATCH (c:Category {category_id: row.category_id})
MERGE (p)-[:IN_CATEGORY]->(c);

// Product -HAS_VARIANT-> Variant
LOAD CSV WITH HEADERS FROM 'file:///product_variant.csv' AS row
MATCH (p:Product {product_id: row.product_id})
MATCH (v:Variant {variant_id: row.variant_id})
MERGE (p)-[:HAS_VARIANT]->(v);
