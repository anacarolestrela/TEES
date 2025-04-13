--config para remover os acents de lexemas de ligua francesa
CREATE TEXT SEARCH CONFIGURATION fr (COPY = french);
ALTER TEXT SEARCH CONFIGURATION fr ALTER MAPPING
FOR hword, hword_part, word WITH unaccent, french_stem;


SELECT 
-- o reconfig se torna mais optimizado 
    to_tsvector(post.language::regconfig, post.title) ||
    to_tsvector(post.language::regconfig, post.content) ||
    to_tsvector('simple'::regconfig, author.name) ||
    to_tsvector('simple'::regconfig, coalesce(string_agg(tag.name, ' '), ''))
FROM post
JOIN author ON author.id = post.author_id
JOIN posts_tags ON posts_tags.post_id = post.id
JOIN tag ON tag.id = posts_tags.tag_id  
GROUP BY post.id, author.id;  