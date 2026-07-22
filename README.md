# fptshop-graph

Graph data backup cho FPT Shop e-commerce knowledge graph (Neo4j).

## Nội dung
- `*.csv` — dữ liệu nguồn (users, products, brands, categories, variants, promotions, purchased, friends_with, product_brand, product_category, product_variant, product_promotion)
- `load_graph.cypher` — script tạo constraint + import toàn bộ node/relationship vào Neo4j

## Rebuild
```
cypher-shell -a bolt://<host>:<port> -u neo4j -p <password> --file load_graph.cypher
```
(các file .csv phải nằm trong thư mục `import/` của Neo4j)
