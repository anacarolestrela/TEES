# Tutorial Full Text Search

inicialmente criei um docker com Postgres em um dockerfile já contendo as tabelas *author, post, post_tags* e *tag* apresentados no tutorial.

Full text search é utilizado para buscas em um unico documento, podendo este estar armazendo e um computador ou um banco de dados de text completo.

 o FTS é diferente das buscas por metadados pois não si limita a correspndencias exatas ou parciais de termos. Ele remove stop words(e, a, ou, de , do), normaliza as palavras(permite encontrar referencias com o mesmo radical), permite busca por relevancia entre outras vantagens.

## O Documento

Aqui é criado um documento textual para cada post, contendo seu titulo, conteudo, autor e tags associadas

o conteudo do post é concatenado em uma string separada por espaços pela coalesce((string_agg(tag.name, ' ')), '') 
```sql 
SELECT post.title || ' ' || post.content || ' ' || author.name || ' ' || 
coalesce((string_agg(tag.name, ' ')), '') as document FROM post JOIN author ON author.id = post.author_id 
JOIN posts_tags ON posts_tags.post_id = post.id 
JOIN tag ON tag.id = posts_tags.tag_id 
GROUP BY post.id, author.id;
```
 o resultado é
```
 Endangered species Pandas are an endangered species Pete Graham science
 ```

 O que ainda não é util para buscas inteligentes no postgres, para mudar isso, é necessario converter a string para o formato tsvector, um formato indexavel e pesquisavel com FTS

 O tsvector *quebra* o texto em palavras(tokenização), faz uma *normalização*, remove *stopwords* dependendo do idioma e armazena as *posições das palavras* no texto

 ```sql
 SELECT to_tsvector(post.title) ||
    to_tsvector(post.content) ||
    to_tsvector(author.name) ||
    to_tsvector(coalesce((string_agg(tag.name, ' ')), '')) as document
FROM post
    JOIN author ON author.id = post.author_id JOIN posts_tags ON posts_tags.post_id = post.id
    JOIN tag ON tag.id = posts_tags.tag_id
GROUP BY post.id, author.id;
 ```

 o resultado é o seguinte 

 ```
 'endang':1,6 'graham':9 'panda':3 'pete':8 'scienc':10 'speci':2,7
 ```

 Os numeros que acompanham os lexemas sao sua localização na string original

 ## Consulta ao documento

 O *@@* é utilizado para consultar o documento com uma tsquery

 exemplo
 ```sql
 SELECT to_tsvector('If you can dream it, you can do it') @@ 'dream';

 ```

 vai devolver se existe ou nao correspondencia de dream na string.

 o correto é fazer um cast do que esta sendo consultado para tsquery, para que seja feita uma conversão dos dois lados. desse modo:

 ```sql
SELECT to_tsvector('It''s kind of fun to do the impossible') @@ to_tsquery('impossible');

 ```
é possivel utilizar operadores logicos(OR, AND, !) nessas consultas

para utilizar as tsquerys no banco criando:
```sql
SELECT pid, p_title
FROM (
    SELECT 
        post.id as pid,
        post.title as p_title,
        to_tsvector(post.title) ||
        to_tsvector(post.content) ||
        to_tsvector(author.name) ||
        to_tsvector(coalesce(string_agg(tag.name, ' '), '')) as document
    FROM post
    JOIN author ON author.id = post.author_id
    JOIN posts_tags ON posts_tags.post_id = post.id 
    JOIN tag ON tag.id = posts_tags.tag_id
    GROUP BY post.id, author.id
) AS p_search
WHERE p_search.document @@ to_tsquery('Endangered & Species');
```
O filtro  @@ e tsquery adicionados fazem uma consulta no documento, prcurando posts que contenham o conteudo da query
o retorno é:
```
Endangered species
```

## Suporte a idiomas

A normalização de palavras e dependente do idioma delas, por exemplo, o radical da palavra correr e corr, em inglês, o radical de running é run, por isso o idioma deve passado para que o processamento do texto seja feito corretamente.

```sql
SELECT to_tsvector('english', 'We are running');
```

lidando com um banco de dados com conteudos de varios idiomas, uma forma de lidar com esse suporte é criar um campo na tabela que armazene o idioma do conteudo

```SQL
ALTER TABLE post ADD language text NOT NULL DEFAULT('english');

SELECT to_tsvector(post.language::regconfig, post.title) ||
   	to_tsvector(post.language::regconfig, post.content) ||
   	to_tsvector('simple', author.name) ||
   	to_tsvector('simple', coalesce((string_agg(tag.name, ' ')), '')) as document
FROM post
JOIN author ON author.id = post.author_id
JOIN posts_tags ON posts_tags.post_id = posts_tags.tag_id
JOIN tag ON tag.id = posts_tags.tag_id
GROUP BY post.id, author.id;

```

o *reconfig* representa uma configuração de idioma para as buscas

## Caracteres acentuados
para lidar com multiplos idiomas , é importante remover acentos para as buscas. para isso se utiliza o *unaccent*
```sql
SELECT to_tsvector(post.language, unaccent(post.title)) ||
   	to_tsvector(post.language, unaccent(post.content)) ||
   	to_tsvector('simple', unaccent(author.name)) ||
   	to_tsvector('simple', unaccent(coalesce(string_agg(tag.name, ' '))))
FROM post
JOIN author ON author.id = post.author_id
JOIN posts_tags ON posts_tags.post_id = posts_tags.tag_id
JOIN tag ON author.id = post.author_id
GROUP BY p.id
```
o unaccent apesar de funcional, nao é muito eficiente. mas existem outras formas de fazer essas cosultas a idiomas com acentos

## Classificação de documentos
O postgres permite que buscas sejam ordenadas por relevacia utiizando ts_rank() e setweight()

a setweight atribui o valor de A a D a um tsvector

```sql
SELECT pid, p_title
FROM (SELECT post.id as pid,
         	post.title as p_title,
         	setweight(to_tsvector(post.language::regconfig, post.title), 'A') ||
         	setweight(to_tsvector(post.language::regconfig, post.content), 'B') ||
         	setweight(to_tsvector('simple', author.name), 'C') ||
         	setweight(to_tsvector('simple', coalesce(string_agg(tag.name, ' '))), 'B') as document
  	FROM post
  	JOIN author ON author.id = post.author_id
  	JOIN posts_tags ON posts_tags.post_id = posts_tags.tag_id
  	JOIN tag ON tag.id = posts_tags.tag_id
  	GROUP BY post.id, author.id) p_search
WHERE p_search.document @@ to_tsquery('english', 'Endangered & Species')
ORDER BY ts_rank(p_search.document, to_tsquery('english', 'Endangered & Species')) DESC;
```


## Otimização e indexação

O postgres permite criar um indice do tipo GIN em torno da função tsvector() para acelerar as buscas

ele cria um mapeamento de cada termo (lexema) para os documentos que o contêm

```sql
CREATE MATERIALIZED VIEW search_index AS
SELECT 
    post.id,
    post.title,
    setweight(to_tsvector(post.language::regconfig, post.title), 'A') ||
    setweight(to_tsvector(post.language::regconfig, post.content), 'B') ||
    setweight(to_tsvector('simple'::regconfig, author.name), 'C') ||
    setweight(to_tsvector('simple'::regconfig, coalesce(string_agg(tag.name, ' '), '')), 'A') as document
FROM post
JOIN author ON author.id = post.author_id
JOIN posts_tags ON posts_tags.post_id = post.id 
JOIN tag ON tag.id = posts_tags.tag_id
GROUP BY post.id, author.id;

CREATE INDEX idx_fts_search ON search_index USING gin(document);

SELECT id as post_id, title
FROM search_index
WHERE document @@ to_tsquery('english', 'Endangered & Species')
ORDER BY ts_rank(document, to_tsquery('english', 'Endangered & Species')) DESC;
```


## Erros de ortografia

a extensao pg_trgm que permite encontrar string semelhantes, o que é util para lidar com typos nas consultas
```sql
SELECT similarity('Something', 'something');
```
o retorno é um numero flutuante que representa a similaridade das strings


primeiro é necessario criar uma lista de lexemas exclusivos usados pelo documento
```sql
CREATE MATERIALIZED VIEW unique_lexeme AS
SELECT word FROM ts_stat(
$$SELECT to_tsvector('simple', post.title) ||
    to_tsvector('simple', post.content) ||
    to_tsvector('simple', author.name) ||
    to_tsvector('simple', coalesce(string_agg(tag.name, ' '), ''))
FROM public.post
JOIN public.author ON author.id = post.author_id
JOIN public.posts_tags ON posts_tags.post_id = post.id  
JOIN public.tag ON tag.id = posts_tags.tag_id
GROUP BY post.id, author.id$$);
```
e entap é necessaio criar um idice de consulta de similaridade

```sql
CREATE INDEX words_idx ON unique_lexeme USING gin(word gin_trgm_ops);
```