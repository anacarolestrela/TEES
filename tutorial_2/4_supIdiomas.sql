
--cria coluna de lingua na tabela post
--só precisa ser executada uma vez
ALTER TABLE post ADD language text NOT NULL DEFAULT('english');

--o reconfig representa uma configuração de idioma para as buscas
--isso é muito importante para a normalização dos lexemas
SELECT to_tsvector(post.language::regconfig, post.title) ||
   	to_tsvector(post.language::regconfig, post.content) ||
   	to_tsvector('simple', author.name) ||
   	to_tsvector('simple', coalesce((string_agg(tag.name, ' ')), '')) as document
FROM post
JOIN author ON author.id = post.author_id
JOIN posts_tags ON posts_tags.post_id = post.id
JOIN tag ON tag.id = posts_tags.tag_id
GROUP BY post.id, author.id;