import streamlit as st
import psycopg2


session_log = False

def authenticate(username, password):
    conn=None
    try:
        # Connect to the PostgreSQL database
        conn = psycopg2.connect(
            dbname="project",
            user=username,
            password=password,
            host="localhost",
            port="5432"
        )

        # If connection successful, return True
        st.success("Connected to PostgreSQL database successfully!")
    except (Exception, psycopg2.Error) as error:
        st.error("Invalid username or password. Please try again.")
    return conn

def get_all_posts(conn):
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM posts")
    posts = cursor.fetchall()
    cursor.close()
    return posts

def main():
    st.title("DBMS Database Login")
    # Input fields for username and password
    global session_log
    # Login button
    if not session_log:
        username = st.text_input("Username")
        password = st.text_input("Password", type="password")
        if st.button("Login"):
            conn = authenticate(username, password)
            if conn:
                session_log = True

    if session_log:
        st.sidebar.header("Menu")
        if st.sidebar.button("LOGIN"):
            st.experimental_rerun()
        st.header("Home")
        conn = authenticate(username, password)
        if conn:
            posts = get_all_posts(conn)
            if posts:
                st.write("All Entries:")
                for post in posts:
                    st.write(post)
            else:
                st.write("No entries found.")

if __name__ == "__main__":
    main()