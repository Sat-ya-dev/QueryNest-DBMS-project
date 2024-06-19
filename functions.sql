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

-- SELECT grantee, table_name, privilege_type
-- FROM information_schema.role_table_grants
-- WHERE grantee = 'user_213';

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
-- CREATE OR REPLACE FUNCTION loop_user_roles() RETURNS VOID AS $$
-- DECLARE
--     i INTEGER; tt text;
-- BEGIN
--     FOR i IN (select user_id from users) LOOP
-- 		tt := i :: text;
--         call create_user(i,tt);
--     END LOOP;
-- END;
-- $$ LANGUAGE plpgsql;

-- select loop_user_roles();

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
		if(current_user != 'postgres' and current_user!='moderator') then
			raise notice 'not authenticated procedure for you';
		else
		FOR i in (select user_id from users) loop
          if ((select user_bio from users where user_id=i) = 'user_id_to_be_deleted' ) then
		  		update users set user_bio = 'deleted' where user_id =i;
		  		tt := 'user_' || i::text;
				EXECUTE 'drop role ' || quote_ident(tt);
		end if;
		end loop;
		end if;

end;
$$;

call to_be_deleted()