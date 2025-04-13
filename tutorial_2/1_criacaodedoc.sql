-- Aqui é criado um documento textual para cada post, contendo seu titulo, conteudo, autor e tags associadas
SELECT post.title || ' ' || post.content || ' ' ||
   	 author.name || ' ' ||
    --  o conteudo do post é concatenado em uma string separada por espaços
   	 coalesce((string_agg(tag.name, ' ')), '') as document
FROM post
   	 JOIN author ON author.id = post.author_id 
	 JOIN posts_tags ON posts_tags.post_id = post.id
   	 JOIN tag ON tag.id = posts_tags.tag_id 
	 GROUP BY post.id, author.id;