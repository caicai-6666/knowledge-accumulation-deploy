-- ready 文件的 HNSW 索引缓存；业务身份与审核状态仍以 resources 为准。
CREATE TABLE IF NOT EXISTS myvector_documents (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    node_id VARCHAR(128) COLLATE utf8mb4_0900_bin NOT NULL COMMENT 'LlamaIndex 文件节点标识',
    model_name VARCHAR(200) COLLATE utf8mb4_0900_bin NOT NULL COMMENT '文件向量生成模型，检索时隔离不同模型',
    dimensions SMALLINT UNSIGNED NOT NULL COMMENT '文件向量维度',
    ref_doc_id VARCHAR(128) COLLATE utf8mb4_0900_bin NULL COMMENT '文件文档标识',
    source_platform VARCHAR(128) COLLATE utf8mb4_0900_bin NULL COMMENT '文件来源平台',
    status VARCHAR(32) NULL COMMENT '文件审核状态',
    metadata JSON NOT NULL COMMENT 'LlamaIndex 文件节点内容及元数据',
    embedding BLOB NOT NULL COMMENT 'MYVECTOR COLUMN |type=HNSW,dim=4096,size=10000,dist=Cosine,M=16,ef=100,idcol=id',
    UNIQUE KEY uq_myvector_node_model (node_id, model_name),
    KEY idx_myvector_filter (model_name, dimensions, source_platform, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
