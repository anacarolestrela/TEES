-- conversao para tsvector, que quebra o texto em palavras(tokenização), faz uma normalização,
--  remove stopwords dependendo do idioma e armazena as posições das palavras no texto
SELECT to_tsvector(post.title) ||
    to_tsvector(post.content) ||
    to_tsvector(author.name) ||
    to_tsvector(coalesce((string_agg(tag.name, ' ')), '')) as document
FROM post
    JOIN author ON author.id = post.author_id 
    JOIN posts_tags ON posts_tags.post_id = post.id
    JOIN tag ON tag.id = posts_tags.tag_id
GROUP BY post.id, author.id;