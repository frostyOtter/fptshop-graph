# fptshop-graph

Graph data backup cho FPT Shop e-commerce knowledge graph (Neo4j).
Backup này để dùng khi server/instance cũ bị sập/mất — clone repo này về là đủ để dựng lại graph từ đầu.

## Nội dung
- `*.csv` — dữ liệu nguồn (users, products, brands, categories, variants, promotions,
  purchased, friends_with, product_brand, product_category, product_variant, product_promotion)
- `load_graph.cypher` — script tạo constraint + import toàn bộ node/relationship vào Neo4j

## Model
Node: `User, Product, Brand, Category, Variant, Promotion`
Relationship: `(User)-[:PURCHASED]->(Product)`, `(User)-[:FRIENDS_WITH]->(User)`,
`(Product)-[:HAS_BRAND]->(Brand)`, `(Product)-[:IN_CATEGORY]->(Category)`,
`(Product)-[:HAS_VARIANT]->(Variant)`

Số lượng kỳ vọng sau khi load xong (dùng để verify):
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

`product_promotion.csv` hiện rỗng (chỉ có header, dùng cột `product_slug` thay vì `product_id`)
nên chưa có relationship Promotion↔Product trong model — cần bổ sung data đúng cột `product_id`
nếu sau này muốn dùng.

---

## Cách dựng lại từ đầu

### Option A — Docker (đơn giản, portable nhất, khuyên dùng)

```bash
git clone git@github.com:frostyOtter/fptshop-graph.git
cd fptshop-graph

docker run -d \
  --name neo4j-graph \
  -p 7474:7474 -p 7687:7687 \
  -v "$(pwd):/var/lib/neo4j/import" \
  -e NEO4J_AUTH=neo4j/YOUR_NEW_PASSWORD \
  neo4j:5.26

# đợi ~15s cho container sẵn sàng
sleep 15

# chạy script build graph
docker exec -it neo4j-graph cypher-shell -u neo4j -p YOUR_NEW_PASSWORD \
  --file /var/lib/neo4j/import/load_graph.cypher

# verify
docker exec -it neo4j-graph cypher-shell -u neo4j -p YOUR_NEW_PASSWORD \
  "MATCH (n) RETURN labels(n)[0] AS label, count(*) AS cnt ORDER BY label"
docker exec -it neo4j-graph cypher-shell -u neo4j -p YOUR_NEW_PASSWORD \
  "MATCH ()-[r]->() RETURN type(r) AS rel, count(*) AS cnt ORDER BY rel"
```
So khớp kết quả với bảng "Số lượng kỳ vọng" ở trên. Neo4j Browser: `http://localhost:7474`.

### Option B — Cài Neo4j native (binary tarball, giống setup gốc)

```bash
git clone git@github.com:frostyOtter/fptshop-graph.git
cd fptshop-graph

# 1. Tải + giải nén Neo4j Community
curl -fL -o neo4j.tar.gz https://dist.neo4j.org/neo4j-community-5.26.0-unix.tar.gz
tar -xzf neo4j.tar.gz && mv neo4j-community-5.26.0 neo4j-server && rm neo4j.tar.gz

# 2. Bật bolt/http (mặc định của tarball đã bật sẵn — chỉ cần set địa chỉ nếu muốn expose ra ngoài)
#    Sửa neo4j-server/conf/neo4j.conf nếu cần: server.bolt.listen_address, server.http.listen_address, ...
echo "dbms.security.allow_csv_import_from_file_urls=true" >> neo4j-server/conf/neo4j.conf

# 3. Đặt mật khẩu TRƯỚC lần start đầu tiên (bắt buộc, không set được sau khi đã start)
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64   # chỉnh path JDK 17 phù hợp máy bạn
neo4j-server/bin/neo4j-admin dbms set-initial-password YOUR_NEW_PASSWORD

# 4. Copy data + script vào import/
cp *.csv load_graph.cypher neo4j-server/import/

# 5. Start
neo4j-server/bin/neo4j console &
sleep 15

# 6. Chạy script build graph
neo4j-server/bin/cypher-shell -a bolt://localhost:7687 -u neo4j -p YOUR_NEW_PASSWORD \
  --file neo4j-server/import/load_graph.cypher

# 7. Verify — so với bảng "Số lượng kỳ vọng" ở trên
neo4j-server/bin/cypher-shell -a bolt://localhost:7687 -u neo4j -p YOUR_NEW_PASSWORD \
  "MATCH (n) RETURN labels(n)[0] AS label, count(*) AS cnt ORDER BY label"
neo4j-server/bin/cypher-shell -a bolt://localhost:7687 -u neo4j -p YOUR_NEW_PASSWORD \
  "MATCH ()-[r]->() RETURN type(r) AS rel, count(*) AS cnt ORDER BY rel"
```

### Lỗi thường gặp
- `Failed to read config: ... declared multiple times` → file `neo4j.conf` có key bị khai báo trùng
  (thường do append thêm config vào cuối file mà tarball mặc định đã có sẵn key đó, ví dụ
  `server.bolt.enabled`, `server.http.enabled`, `server.https.enabled`, `server.directories.import`).
  Kiểm tra bằng: `grep -v '^#' neo4j.conf | grep -v '^$' | awk -F= '{print $1}' | sort | uniq -d`
  rồi xoá bớt dòng trùng (giữ lại 1 dòng duy nhất mỗi key, trừ `server.jvm.additional` — key này
  vốn được phép lặp lại nhiều lần).
- `InvalidPasswordException: A password must be at least 8 characters` → đặt mật khẩu dài hơn.
- `The client is unauthorized due to authentication failure` khi chạy `cypher-shell` → sai mật khẩu,
  hoặc đã start Neo4j lần đầu trước khi set mật khẩu (phải set trước lần start đầu tiên).
