SELECT 
--uso do unaccent para remover acentos dos lexemas
--auxilia na normalização
    to_tsvector(post.language::regconfig, unaccent(post.title)) ||
    to_tsvector(post.language::regconfig, unaccent(post.content)) ||
    to_tsvector('simple'::regconfig, unaccent(author.name)) ||
    to_tsvector('simple'::regconfig, unaccent(coalesce(string_agg(tag.name, ' '), '')))
FROM post
JOIN author ON author.id = post.author_id
JOIN posts_tags ON posts_tags.post_id = post.id
JOIN tag ON tag.id = posts_tags.tag_id 
GROUP BY post.id, author.id; 