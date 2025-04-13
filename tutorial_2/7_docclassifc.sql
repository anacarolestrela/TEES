SELECT pid, p_title
FROM (SELECT post.id as pid,
         	post.title as p_title,
            --a setweight atribui o valor de A a D a um tsvector, representad sua relevancia

         	setweight(to_tsvector(post.language::regconfig, post.title), 'A') ||
         	setweight(to_tsvector(post.language::regconfig, post.content), 'B') ||
         	setweight(to_tsvector('simple', author.name), 'C') ||
         	setweight(to_tsvector('simple', coalesce(string_agg(tag.name, ' '))), 'B') as document
  	FROM post
  	JOIN author ON author.id = post.author_id
  	JOIN posts_tags ON posts_tags.post_id = post.id
  	JOIN tag ON tag.id = posts_tags.tag_id
  	GROUP BY post.id, author.id) p_search
    -- O @@ é utilizado para consultar o documento com uma tsquery
WHERE p_search.document @@ to_tsquery('english', 'Endangered & Species')
ORDER BY ts_rank(p_search.document, to_tsquery('english', 'Endangered & Species')) DESC;