# fptshop-graph

Graph data backup for the FPT Shop e-commerce knowledge graph (Neo4j).
This backup exists so that if the original server/instance is lost, cloning this repo
is enough to rebuild the graph from scratch.

## Contents
- `*.csv` — source data (users, products, brands, categories, variants, promotions,
  purchased, friends_with, product_brand, product_category, product_variant, product_promotion)
- `load_graph.cypher` — script that creates constraints and imports all nodes/relationships into Neo4j

## Model
Nodes: `User, Product, Brand, Category, Variant, Promotion`
Relationships: `(User)-[:PURCHASED]->(Product)`, `(User)-[:FRIENDS_WITH]->(User)`,
`(Product)-[:HAS_BRAND]->(Brand)`, `(Product)-[:IN_CATEGORY]->(Category)`,
`(Product)-[:HAS_VARIANT]->(Variant)`

Expected counts after a successful load (use this to verify):
| Label/Type | Count |
|---|---|
| User | 500 |
| Product | 223 |
| Brand | 8 |
| Category | 4 |
| Variant | 860 |
| Promotion | 11 |
| PURCHASED | 7500 |
| FRIENDS_WITH | 2500 |
| HAS_BRAND | 223 |
| IN_CATEGORY | 223 |
| HAS_VARIANT | 860 |

`product_promotion.csv` currently only has a header row (and uses a `product_slug` column
instead of `product_id`), so there is no Promotion↔Product relationship in the model yet.
Fix the column and populate rows there if that relationship is needed later.

---

## Rebuilding from scratch

### Option A — Docker (simplest, most portable, recommended)

```bash
git clone git@github.com:frostyOtter/fptshop-graph.git
cd fptshop-graph

docker run -d \
  --name neo4j-graph \
  -p 7474:7474 -p 7687:7687 \
  -v "$(pwd):/var/lib/neo4j/import" \
  -e NEO4J_AUTH=neo4j/YOUR_NEW_PASSWORD \
  neo4j:5.26

# wait ~15s for the container to come up
sleep 15

# run the build script
docker exec -it neo4j-graph cypher-shell -u neo4j -p YOUR_NEW_PASSWORD \
  --file /var/lib/neo4j/import/load_graph.cypher

# verify
docker exec -it neo4j-graph cypher-shell -u neo4j -p YOUR_NEW_PASSWORD \
  "MATCH (n) RETURN labels(n)[0] AS label, count(*) AS cnt ORDER BY label"
docker exec -it neo4j-graph cypher-shell -u neo4j -p YOUR_NEW_PASSWORD \
  "MATCH ()-[r]->() RETURN type(r) AS rel, count(*) AS cnt ORDER BY rel"
```
Compare the output against the "Expected counts" table above. Neo4j Browser: `http://localhost:7474`.

### Option B — Native install (binary tarball, matches the original setup)

```bash
git clone git@github.com:frostyOtter/fptshop-graph.git
cd fptshop-graph

# 1. Download and extract Neo4j Community
curl -fL -o neo4j.tar.gz https://dist.neo4j.org/neo4j-community-5.26.0-unix.tar.gz
tar -xzf neo4j.tar.gz && mv neo4j-community-5.26.0 neo4j-server && rm neo4j.tar.gz

# 2. Bolt/HTTP are enabled by default in the tarball — only set listen/advertised
#    addresses in neo4j-server/conf/neo4j.conf if you need to expose it externally.
echo "dbms.security.allow_csv_import_from_file_urls=true" >> neo4j-server/conf/neo4j.conf

# 3. Set the password BEFORE the first start (required — cannot be set after)
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64   # point this at your JDK 17 path
neo4j-server/bin/neo4j-admin dbms set-initial-password YOUR_NEW_PASSWORD

# 4. Copy data + script into import/
cp *.csv load_graph.cypher neo4j-server/import/

# 5. Start
neo4j-server/bin/neo4j console &
sleep 15

# 6. Run the build script
neo4j-server/bin/cypher-shell -a bolt://localhost:7687 -u neo4j -p YOUR_NEW_PASSWORD \
  --file neo4j-server/import/load_graph.cypher

# 7. Verify — compare against the "Expected counts" table above
neo4j-server/bin/cypher-shell -a bolt://localhost:7687 -u neo4j -p YOUR_NEW_PASSWORD \
  "MATCH (n) RETURN labels(n)[0] AS label, count(*) AS cnt ORDER BY label"
neo4j-server/bin/cypher-shell -a bolt://localhost:7687 -u neo4j -p YOUR_NEW_PASSWORD \
  "MATCH ()-[r]->() RETURN type(r) AS rel, count(*) AS cnt ORDER BY rel"
```

### Common errors
- `Failed to read config: ... declared multiple times` → `neo4j.conf` has a duplicate key
  (usually from appending config to the end of the file when the tarball's default already
  sets it, e.g. `server.bolt.enabled`, `server.http.enabled`, `server.https.enabled`,
  `server.directories.import`). Check with:
  `grep -v '^#' neo4j.conf | grep -v '^$' | awk -F= '{print $1}' | sort | uniq -d`
  then remove the duplicate lines (keep exactly one per key, except `server.jvm.additional`,
  which is allowed to repeat).
- `InvalidPasswordException: A password must be at least 8 characters` → use a longer password.
- `The client is unauthorized due to authentication failure` when running `cypher-shell` →
  wrong password, or Neo4j was started once before the password was set (it must be set
  before the very first start).
