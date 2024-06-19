--create group role -client_user
create role client_user login password 'postgres';

-- grant prieveleges to client_user 
grant select, insert,update on users to client_user;
 grant select on badges to client_user;
 grant all on comments to client_user;
 grant select, insert, delete,update on posts to client_user;
 grant insert on votes to client_user;
 grant select,update,insert on tags to client_user;
 
-- create group role - managers
create role managers;
ALTER ROLE managers WITH PASSWORD 'postgres';

--create two manager roles 
create role leaderboard_manager;
ALTER ROLE leaderboard_manager WITH PASSWORD 'postgres';

create role moderator;
ALTER ROLE moderator WITH PASSWORD 'postgres';

--grant prieveleges to manager
grant select on all tables in schema "public" to managers;
grant update on badges to leaderboard_manager;

grant managers to leaderboard_manager;
grant update on badges to leaderboard_manager;

grant managers to moderator;
grant delete,update on users,posts to moderator;

-- TRIGGERS 
--CREATE TRIGGER DEL_POST: User can only delete a post created by the user.
create or replace trigger del_post
before delete
on posts
for each row
execute procedure check_del_post();

create or replace function check_del_post()
returns trigger
language plpgsql
as $$
begin
if (('user_' || old.owner_user_id :: text != current_user) and current_user !='postgres' ) then
	raise exception 'You cannot delete the posts that are not created by you';
end if;

return old;
end;
$$;
select owner_user_id from posts where post_id=11;
delete from posts where post_id=11;
--CREATE TRIGGER : INSERT IN BADGES:
create or replace trigger insert_badge
after insert
on users
for each row
execute procedure insert_badge_user();

create or replace function insert_badge_user()
returns trigger
language plpgsql
as $$
declare
	tt int; 
begin
tt:=(select max(badge_id) from badges)+1;
insert into badges values (tt,new.user_id,3);
return NULL;
end;
$$;

--CREATE TRIGGER : DEL_USER ( USER CAN UPDATE ONLY HIS RECORD)
create or replace trigger del_user
before delete
on users
for each row
execute procedure check_upd_user();
create or replace function check_upd_user()
returns trigger
language plpgsql
as $$
begin
raise notice '%',current_user;
if ('user_' || old.user_id :: text != current_user) and (current_user!='postgres') then
	raise exception 'Incorrect user_id % given for current user % logged in',old.user_id,current_user;
	
end if;
return old;
end;$$;
select * from users;
--CREATE TRIGGER : UPDATE SCORE OF POST, SCORE OF USERS,BEST ANS ID OF QUESTION POST
--VIEW COUNT INCREMENTED WHEN THERE IS AN INSERTION IN VOTES
create or replace trigger best_ans_upd
after insert
on votes
for each row
execute procedure check_best_ans();
create or replace function check_best_ans()
returns trigger
language plpgsql
as $$
DECLARE
     i int; q int;
Begin
if (new.vote_type_id =2) then
			update 	posts set score = score+1 where posts.post_id = new.post_id;
			update posts set upvotes=upvotes+1 where posts.post_id=new.post_id;
			update users set score = score + 15 where users.user_id in
			(select posts.owner_user_id from posts where posts.post_id= new.post_id limit 1);
			update users set up_votes = up_votes + 1 where users.user_id= new.user_id ;

		elsif(new.vote_type_id =3) then
			update 	posts set score = score-1 where posts.post_id = new.post_id;
			update posts set downvotes=downvotes+1 where posts.post_id=new.post_id;
			update users set score = score - 8 where users.user_id in
			(select posts.owner_user_id from posts where posts.post_id= new.post_id);
			update users set down_votes = down_votes + 1 where users.user_id= new.user_id ;

end if;

if ((select posts.post_type_id from posts where posts.post_id = new.post_id)=2) then
q:=(select parent_id from posts where post_id=new.post_id);
i:=(select post_id from (select * from posts where parent_id=q) where score in 
	(select max(score) from posts where post_id in (select post_id from posts where parent_id=q))limit 1); 
update posts set best_answer_id = i  where posts.post_id =(select parent_id from posts where post_id=new.post_id);	
end if;
update users set views = views+1 where users.user_id in 
(select owner_user_id from posts where posts.post_id =new.post_id );
return NULL;
end;
$$;
select * from posts;
call create_vote(1915,2);
select * from posts;
update posts set best_answer_id=(select post_id from (select post_id,score from posts where parent_id=2092)
											 where score = (select
											max(score) from posts where parent_id=2092) limit 1) where post_id=2092;
select post_id,score from posts where parent_id=2092;
select best_answer_id from posts where post_id=2092;
select parent_id,post_type_id,best_answer_id,score,upvotes,downvotes,owner_user_id from posts where post_id=2099;
select score,up_votes,down_votes from users where user_id=11604;
call create_vote(2099,3)
--TRIGGER TO INCREMENT ANSWER COUNT ON INSERTION OF ANSWER POST IN POSTS
create or replace trigger upd_ans_ct
after insert
on posts
for each row
execute procedure check_ans_ct();
create or replace function check_ans_ct()
returns trigger
language plpgsql
as $$
DECLARE
     i int; 
Begin
 
 if (new.post_type_id = 2) then
	update posts set answer_count = answer_count+1 where posts.post_id = new.parent_id;
 elseif(new.post_type_id=1)then
		update posts set answer_count = answer_count where posts.post_id = new.parent_id;

	end if;
end;
$$;
select * from posts;
select post_type_id,answer_count from posts where post_id=2918;
call create_new_post (2,'test_answer',2918,'newtag');

-- TRIGGER FOR TAG UPDATION.
create or replace trigger upd_tag_ct
after insert
on posts
for each row
execute procedure check_tag_ct();

create or replace function check_tag_ct()
returns trigger
language plpgsql
as $$
DECLARE
     i int; t_id int;
Begin
 	t_id := (select max(tag_id) from tags)+1;
 	IF NOT EXISTS (select * from tags where tag_desc = new.tags) then
		insert into tags values(t_id,new.tags,1);
	ELSE 
		update tags set count=count+1 where tag_desc=new.tags;
	END IF;
	return NULL;
end;
$$;
select * from tags where tag_desc = 'newtag'
--TRIGGER TO DECREMENT ANSWER COUNT ON DELETION OF ANSWER POST AND TAG COUNT IN POSTS

create or replace trigger upd_ans_ct_del
after delete
on posts
for each row
execute procedure check_del_ans_ct();
create or replace function check_del_ans_ct()
returns trigger
language plpgsql
as $$
DECLARE
     i int;
Begin
if (old.post_type_id = 2) then
	update posts set answer_count = answer_count-1 where posts.post_id = old.parent_id;
		end if;
	
	update tags set count=count-1 where tags.tag_desc=old.tags;
	return NULL;
end;
$$;
select parent_id,tags from posts where post_id=3096;
select answer_count from posts where post_id =2918;
select * from tags where tag_desc = 'newtag'
delete from posts where post_id =3096
--TRIGGER TO INCREMENT COMMENT COUNT ON INSERTION IN COMMENTS TABLE FOR THAT POST
create or replace trigger upd_comm_ct
after insert on comments
for each row
execute procedure check_comm_ct();

create or replace function check_comm_ct()
returns trigger
language plpgsql
as $$
DECLARE
     i int;
Begin

update posts set comment_count = comment_count+1 where posts.post_id = new.post_id;
	return NULL;
end;
$$;

--TRIGGER TO DECREMENT COMMENT COUNT ON DELETION IN COMMENTS TABLE FOR THAT POST
create or replace trigger upd_del_comm_ct
after delete on comments
for each row
execute procedure check_del_comm_ct();

create or replace function check_del_comm_ct()
returns trigger
language plpgsql
as $$
DECLARE
     i int;
Begin

update posts set comment_count = comment_count-1 where posts.post_id = old.post_id;
	return NULL;
end;
$$;
-- PROCEDURES
--PROCEDURE TO INSERT INTO BADGES ALL THE USER_ID VALUES, WITH A DEAFULT CLASS=3
create or replace procedure upd_badges_table()
language plpgsql
as $$
DECLARE
    role_name TEXT; i int; tt int;
Begin
tt:=1;
FOR i IN (select user_id from users) LOOP
	insert into badges values (tt,i,3);
	tt=tt+1;
    END LOOP;
end;
$$;
call upd_badges_table()

--UPDATE BADGES TABLE: FIRST 20 SCORES = CLASS 1, ABOVE AVG: CLASS 2, BELOW AVG: CLASS 3
create or replace procedure update_badge_class()
language plpgsql
as $$
begin
if(current_user !='leaderboard_manager') then
	raise notice 'not authorised to exexute this';
else
	Update badges set class = 1 where user_id in
	(select user_id from users where score in (select score from users order by score desc limit 20) );
	Update badges set class = 2 where user_id in
	(select user_id from users where score in (select score from users order by score desc offset 20) );

	Update badges set class = 3 where user_id in
	(select user_id from users where score<(select avg(score) from users));
end if;
end;
$$;
update users set score=0 where user_id=213;
select * from badges where user_id=213;
call update_badge_class();
select * from badges where user_id=213;

select * from badges
select * from votes

--PROCEDURE TO INSERT VOTES
create or replace procedure create_vote(p_id int, vot_type int) 
language plpgsql
as $$
DECLARE
   us_id int;v_id int;
BEGIN
 us_id := (SELECT SUBSTRING(current_user FROM POSITION('_' IN current_user) + 1))::int;
  v_id := (select max(vote_id) from votes)+1;

 insert into votes values (v_id,us_id,p_id,vot_type,CURRENT_TIMESTAMP AT TIME ZONE 'UTC'); 
end;
$$;
call create_vote(197,3)
select * from votes where post_id= 197
select upvotes,downvotes from posts where post_id=197;
select * from users where user_id=1686
GRANT INSERT,SELECT ON votes TO client_user;
select current_user;
select * from votes
select * from users;

-- to create new role
create or replace procedure create_user_role ( user_id int, pswd text) 
language plpgsql
as $$
DECLARE
    role_name TEXT;
BEGIN
    role_name := 'user_' || user_id::text;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = role_name) THEN
        EXECUTE 'CREATE ROLE ' || quote_ident(role_name) || ' LOGIN PASSWORD ' || quote_literal(pswd);
		EXECUTE 'grant client_user to ' || quote_ident(role_name) ;
        RAISE NOTICE 'Role % created successfully.', role_name;
 ELSE
        RAISE NOTICE 'Role % already exists.', role_name;
 END IF;
end;
$$;

-- by moderator : to ban users
create or replace procedure ban_users()
language plpgsql
as $$
DECLARE
    role_name TEXT; i int; tt text;
Begin
if (current_user != 'moderator') then
 	raise notice 'not authorised procedure';
else
 FOR i IN (select user_id from users) LOOP
		if ((select score from users where user_id=i) < -50) then
			update users set score=NULL where user_id=i; 
			update users set views=NULL where user_id=i; 
			update users set down_votes=NULL where user_id=i; 
			update users set up_votes=NULL where user_id=i; 
			update users set location=NULL where user_id=i; 
			update users set user_bio=NULL where user_id=i; 
			update users set creation_date=NULL where user_id=i; 
			tt := 'user_' || i::text;
			EXECUTE 'drop role' || quote_ident(tt);
	END IF;
    END LOOP;
	end if;
end;
$$;
call ban_users();
--PROCEDURE TO CREATE NEW_USER INSERTION INTO USER TABLE.
create or replace procedure create_new_user (pwd text,us_name text, 
											 loc text DEFAULT 'UTC',
											 us_bio text DEFAULT NULL) 
language plpgsql
as $$
DECLARE
    role_name TEXT;us_id int;
BEGIN
 us_id := (select max(user_id) from users)+1;
 call create_user_role(us_id,pwd);
 insert into users(user_id,user_name,location,user_bio,creation_date,last_access_date)
 values (us_id,us_name,loc,us_bio,current_date,current_date);
end;
$$;

call create_new_user ('test_password','Black Adam','US','testing_data');

select * from users where user_name='Black Adam'

SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'user_213';

-- grant insert,update(body),delete on posts to client_user;

--PROCEDURE TO CREATE NEW_post: INSERTION INTO POSTS TABLE.

create or replace procedure create_new_post (p_type int,pos_body text DEFAULT NULL, 
											 par_id int default NULL, tag text DEFAULT NULL) 
language plpgsql
as $$
DECLARE
    role_name TEXT;p_id int;us_id int;us_name text;ans_ct int;
BEGIN
 p_id := (select max(post_id) from posts)+1;
 us_id := (SELECT SUBSTRING(current_user FROM POSITION('_' IN current_user) + 1))::int;
 raise notice '% ', us_id;
 if (p_type = 1) then
 insert into posts(post_id,owner_user_id,post_type_id,parent_id,answer_count,
				   comment_count,tags, body, creation_date)
 values (p_id,us_id,p_type,par_id,0,0,tag,pos_body,current_date);
 elsif(p_type = 2) then
 insert into posts(post_id,owner_user_id,post_type_id,parent_id,answer_count,
				   comment_count,tags, body, creation_date)
 values (p_id,us_id,p_type,par_id,NULL,0,tag,pos_body,current_date);
 end if;
end;
$$;
call create_new_post (2,'Black Adam answer',3095,'newtag');
select * from posts where post_id=3096;

call create_new_post (1,'Black Adam',NULL,'<buggs>');
call create_new_post (2,'Black Adam answer',3095,'newtag');
delete from posts where post_id=3096;
select * from posts where post_id=3096;
select * from tags where tag_desc='newtag';
select * from posts where body = 'Black Adam'
update posts set answer_count=0 where post_id=3095;
delete from posts where body = 'Black Adam'
call delete_post(3096);
select * from posts where post_id=3096;

select * from comments

--PROCEDURE TO CREATE NEW_COMMENT: INSERTION INTO comments TABLE.

create or replace procedure create_new_comment(p_id int, body text DEFAULT NULL) 
language plpgsql
as $$
DECLARE
   us_id int;c_id int;
BEGIN
 c_id := (select max(comment_id) from comments)+1;
 us_id := (SELECT SUBSTRING(current_user FROM POSITION('_' IN current_user) + 1))::int;
 insert into comments values (c_id,p_id,us_id,body); 
end;
$$;
select comment_count from posts where post_id=2918;
call create_new_comment (2918,'Black Adam');
select * from comments where comment_text = 'Black Adam'
delete from comments where comment_text = 'Black Adam'

--FUNCTION TO DELETE A POST
create or replace procedure delete_post(p_id int) 
language plpgsql
as $$
DECLARE
   us_id int;c_id int;
BEGIN
	
 		delete from posts where post_id=p_id;
	
end;
$$;
call delete_post (2654);
select * from posts where owner_user_id =213;
--CHANGES TO EXISTING DATA: RENAMED COLUMN TO COMMENT_TEXT
ALTER TABLE comments
RENAME COLUMN text TO comment_text;

--FUNCTION TO GET_ALL ANSWERS TO A QUESTION POST
create or replace function get_ans_of_post(p_id int)
returns SETOF posts
language plpgsql

as $$
DECLARE
   us_id int;c_id int;
BEGIN
 if ((select post_type_id from posts where post_id = p_id)!=1) then
 raise exception 'Given post is an answer post';
 end if;
 return query
 select * from posts where parent_id=p_id;
end;
$$;
select * from posts;
select get_ans_of_post (493);
select * from comments where comment_text = 'Black Adam'
delete from comments where comment_text = 'Black Adam'
select * from posts
drop procedure get_ans_of_post

--FUNCTION TO GET USER INFO GIVEN USER_ID 
create or replace function get_user_info(u_id int)
returns SETOF users
language plpgsql

as $$
BEGIN
 
 return query
 select * from users where user_id=u_id;
end;
$$;
select get_user_info (213);

-- FUNCTION TO get all the questions related to a tag
create or replace function get_tag_posts(tag text)
returns SETOF posts
language plpgsql

as $$

BEGIN
 
 return query
 select * from posts where tags like '%'||tag||'%';
end;
$$;
select get_tag_posts ('bug');

--FUNCTION TO GET_ALL COMMENTS TO A POST
create or replace function get_comm_of_post(p_id int)
returns SETOF comments
language plpgsql

as $$
DECLARE
   us_id int;c_id int;
BEGIN
 
 return query
 select * from comments where post_id=p_id;
end;
$$;
select * from comments;
select get_comm_of_post(1);
--CREATE PROCEDURE Create_user_Role : given the new user credentials : create role and assign priveleges.

create or replace procedure create_user_role ( user_id int, pswd text) 
language plpgsql
as $$
DECLARE
    role_name TEXT;
BEGIN
    role_name := 'user_' || user_id::text;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = role_name) THEN
        EXECUTE 'CREATE ROLE ' || quote_ident(role_name) || ' LOGIN PASSWORD ' || quote_literal(pswd);
		EXECUTE 'grant client_user to ' || quote_ident(role_name) ;
        RAISE NOTICE 'Role % created successfully.', role_name;
 ELSE
        RAISE NOTICE 'Role % already exists.', role_name;
 END IF;
end;
$$;
--call create_user(221,'ssss');


-- ALTER ROLE moderator LOGIN PASSWORD 'postgres';

--CREATE PROCEDURE Create_user : given the new user credentials : create role and assign priveleges.

create or replace procedure create_user ( user_id int, pswd text) 
language plpgsql
as $$
DECLARE
    role_name TEXT;
BEGIN
    role_name := 'user_' || user_id::text;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = role_name) THEN
        EXECUTE 'CREATE ROLE ' || quote_ident(role_name) || ' LOGIN PASSWORD ' || quote_literal(pswd);
		EXECUTE 'grant client_user to ' || quote_ident(role_name) ;
        RAISE NOTICE 'Role % created successfully.', role_name;
 ELSE
        RAISE NOTICE 'Role % already exists.', role_name;
 END IF;
end;
$$;
--call create_user(221,'ssss');
--FUNCTION TO CREATE ROLES FOR THE EXISTING USERS.
CREATE OR REPLACE FUNCTION loop_user_roles() RETURNS VOID AS $$
DECLARE
    i INTEGER; tt text;
BEGIN
    FOR i IN (select user_id from users) LOOP
		tt := i :: text;
        call create_user(i,tt);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

select loop_user_roles();

-- CREATE PROCEDURE: Ban_users(): MODERATOR CAN BAN USER IF HIS SCORE GOES BELOW -50
create or replace procedure ban_users()
language plpgsql
as $$
DECLARE
    role_name TEXT; i int; tt text;
Begin
if (current_user != 'moderator') then
 raise notice ' dont have authorisation for the procedure';
 else
 FOR i IN (select user_id from users) LOOP
 
		if ((select score from users where user_id=i) < -50) then
			
			update users set user_bio='user_id_to_be_deleted' where user_id=i; 
			
	END IF;
    END LOOP;
	end if;
end;
$$;
update users set score =-60 where user_id=121939
call ban_users();
select user_bio from users where user_id=121939;
-- CREATE PROCEDURE: del_users():user can delete his own account
create or replace procedure del_users(i int)
language plpgsql
as $$
DECLARE
    role_name TEXT; tt text;
Begin	
		 
       role_name := 'user_' || i::text;
 		IF(current_user!=role_name) then
			raise notice 'You cant delete other accounts';
		else
			update users set user_bio='user_id_to_be_deleted' where user_id=i;
		
		end if;

end;
$$;
call del_users(121941);
update users set location = 'user_id_to_be_deleted' where user_id=121941
select user_bio from users where user_id=121941;
select * from users where user_id=221;
create or replace procedure to_be_deleted()
language plpgsql
as $$
DECLARE
    role_name TEXT; tt text;i int;
Begin	
		if(current_user != 'postgres') then
			raise notice 'not authenticated procedure for you';
		else
		FOR i in (select user_id from users) loop
          if ((select user_bio from users where user_id=i) = 'user_id_to_be_deleted' ) then
		  		tt := 'user_' || i::text;
				EXECUTE 'drop role ' || quote_ident(tt);
		end if;
		end loop;
		end if;

end;
$$;
call to_be_deleted()
--VIEW 1: TOP 50 IN LEADERBOARD
create or replace view leader_board
as 
select users.user_id,users.user_name,users.score,badges.class,users.user_bio 
from users, badges where users.user_id = badges.user_id order by users.score desc limit 50;

select * from leader_board
select * from users

--View 2: top 15 HIGH SCORED QUESTIONS
create or replace view featured_questions
as 
select posts.post_id,posts.owner_user_id , posts.body, posts.score, posts.tags
from posts where posts.post_type_id=1 order by posts.score desc limit 15;
select * from featured_questions

--Top Tags with question count
create or replace view top5_tags
as 
select tag_desc,count from tags order by count desc limit 5;
select * from top5_tags;
 
 
--QUERIES :
--Query 1 : delete all the posts of the current user which has a tag count <5
create or replace procedure query_1(p_id int)
language plpgsql
as $$
DECLARE
    role_name TEXT; tt text;
Begin	
		if((select score from posts where post_id=p_id)<3)then
			call create_new_comment(p_id,'you have score<3');
		end if;
       end;
$$;
call query_1(1);
select comment_text from comments where post_id=1;
select * from posts where post_id=1;
drop index users_pkey;
create index user_id_index on users using hash(user_id); 
create index user_id_index2 on posts using hash(post_id); 
create index user_id_index3 on votes using hash(vote_id); 
create index user_index4 on users (score);
DO $$
DECLARE
    i INTEGER;
begin
for i in (select post_id from posts where tags like '%bug%' and owner_user_id = 
		  (SELECT SUBSTRING(current_user FROM POSITION('_' IN current_user) + 1))::int)loop
		  call delete_post(i);
		end loop;
end;$$;
select * from posts where tags like '%bug%';
select * from posts where owner_user_id=2998 and tags like '%bug%';

DO $$
DECLARE
    i INTEGER;
begin
for i in (select post_id from posts where tags like '%meta%')loop
		  call create_new_comment(i,'this is a meta post');
		end loop;
end;$$;

select * from posts where tags like '%meta%'


update users set score=0 where user_id=121939

explain analyze select * from users where user_id=213;





 
 
--QUERIES

