SELECT pid, p_title
FROM (SELECT post.id as pid,
         	post.title as p_title,
         	to_tsvector(post.title) ||
         	to_tsvector(post.content) ||
         	to_tsvector(author.name) ||
         	to_tsvector(coalesce(string_agg(tag.name, ' '))) as document
  	FROM post
  	JOIN author ON author.id = post.author_id
  	JOIN posts_tags ON posts_tags.post_id = post.id
  	JOIN tag ON tag.id = posts_tags.tag_id
  	GROUP BY post.id, author.id) p_search
    --  uso de tsquery  com @@ vai devolver se existe ou nao correspondencia 
    -- caso exista, o pid e titulo do post serao o output
WHERE p_search.document @@ to_tsquery('Endangered & Species');