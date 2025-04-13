--só precisa rodar uma vez.
--cria o index para acelerar as buscas
CREATE MATERIALIZED VIEW search_index AS

SELECT post.id,
   	post.title,
   	setweight(to_tsvector(post.language::regconfig, post.title), 'A') ||
   	setweight(to_tsvector(post.language::regconfig, post.content), 'B') ||
   	setweight(to_tsvector('simple', author.name), 'C') ||
   	setweight(to_tsvector('simple', coalesce(string_agg(tag.name, ' '))), 'A') as document
FROM post
JOIN author ON author.id = post.author_id
JOIN posts_tags ON posts_tags.post_id = post.id
JOIN tag ON tag.id = posts_tags.tag_id
GROUP BY post.id, author.id


--só precisa rodar uma vez.
CREATE INDEX idx_fts_search ON search_index USING gin(document);

--select utilizando o index para otimização das buscs
SELECT id as post_id, title
FROM search_index
WHERE document @@ to_tsquery('english', 'Endangered & Species')
ORDER BY ts_rank(document, to_tsquery('english', 'Endangered & Species')) DESC;