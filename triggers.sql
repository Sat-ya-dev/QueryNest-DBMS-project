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
if (old.post_id in (select best_answer_id from posts))then
		update posts set best_answer_id=(select post_id from posts where post_id in (select post_id from posts where parent_id=old.parent_id) 
										 and score = (select
											score from posts where parent_id=old.parent_id order by score desc 
																				  offset 1 limit 1)limit 1 ) 
											where post_id=old.parent_id ;
	end if;

return old;
end;
$$;
insert into posts (post_id,owner_user_id,post_type_id,creation_date) values(11,91,1,current_date)
select owner_user_id from posts where post_id=11;
call delete_post(11);

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
call create_new_user ('test_pswd','Black Adam 2','US','testing_data');
select * from users where user_id=121941;
select * from badges where user_id=121941;

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

select * from posts where parent_id=246;
select * from posts where post_id=246;
select * from users where user_id=149;

call create_vote(248,2);
select * from users where user_id=91;
select * from posts where parent_id=246;
select * from posts where post_id=246;
select * from users where user_id=149;

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
	if (new.tags is not NULL)then
 	IF NOT EXISTS (select * from tags where tag_desc = new.tags) then
		insert into tags values(t_id,new.tags,1);
	ELSE 
		update tags set count=count+1 where tag_desc=new.tags;
	END IF;
	end if;
	return NULL;
end;
$$;
select * from posts where tags = 'newtag'
select * from tags where tag_desc = 'newtag'
call create_new_post (2,'test_answer',2918,'newtag');
select post_type_id,answer_count from posts where post_id=2918;

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
select * from posts where post_id =3097;
select * from tags where tag_desc = 'newtag';
delete from posts where post_id =3097;
--TRIGGER TO INCREMENT COMMENT COUNT ON INSERTION IN COMMENTS TABLE FOR THAT POST
create or replace trigger upd_comm_ct
after insert on comments
for each row
execute procedure check_comm_ct();
call delete_post(363);
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
