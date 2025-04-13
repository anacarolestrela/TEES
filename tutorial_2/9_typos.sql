--ambas só precisam rodar uma vez
CREATE EXTENSION pg_trgm;
--criação de um mapa de lexemas unicos
CREATE MATERIALIZED VIEW unique_lexeme AS


SELECT word FROM ts_stat(
'SELECT to_tsvector('simple', post.title) ||
	to_tsvector('simple', post.content) ||
	to_tsvector('simple', author.name) ||
	to_tsvector('simple', coalesce(string_agg(tag.name, ' ')))
FROM post
JOIN author ON author.id = post.author_id
JOIN posts_tags ON posts_tags.post_id = post.id
JOIN tag ON tag.id = posts_tags.tag_id
GROUP BY post.id, author.id');

--craição do index de palavras a partir dos lexemas unicos
CREATE INDEX words_idx ON unique_lexeme USING gin(word gin_trgm_ops);

--consulta utilizando o index
SELECT word
FROM unique_lexeme  
WHERE similarity(word, 'spech') > 0.5
ORDER BY word <-> 'spech'
LIMIT 1;